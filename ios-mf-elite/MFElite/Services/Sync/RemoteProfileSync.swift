//
//  RemoteProfileSync.swift
//  MFElite
//
//  Pushes the full local identity (PlayerProfileStore) + avatar photo + player
//  card design to Supabase, and hydrates them back on restore. Fails soft.
//

import Foundation
import UIKit

@MainActor
final class RemoteProfileSync {
    static let shared = RemoteProfileSync()
    private init() {}

    // MARK: - Push

    /// Upsert the complete identity row and upload the avatar photo if present.
    /// Call after onboarding, after profile edits, and after avatar changes.
    func pushProfile() {
        guard SupabaseAuth.shared.isSignedIn else { return }
        Task { await pushProfileNow() }
    }

    func pushProfileNow() async {
        guard let userID = SupabaseAuth.shared.userID, SupabaseAuth.shared.isSignedIn else { return }
        let profile = PlayerProfileStore.shared

        var row: [String: Any] = [
            "id": userID,
            "account_id": userID,
            "display_name": profile.displayName,
            "position": profile.position,
            "kit_number": profile.kitNumber,
            "position_code": profile.positionCode,
            "foot": profile.foot
        ]
        if !profile.username.isEmpty { row["username"] = profile.username }
        if profile.classYear > 0 { row["class_year"] = profile.classYear }
        if profile.birthYear > 0 { row["birth_year"] = profile.birthYear }
        if !profile.trainingLevel.isEmpty { row["training_level"] = profile.trainingLevel }
        if !profile.gender.isEmpty { row["gender"] = profile.gender }

        switch profile.avatar {
        case .builtin(let id):
            row["avatar_kind"] = "builtin"
            row["avatar_builtin"] = id
        case .photo:
            row["avatar_kind"] = "photo"
            if let image = profile.avatarPhoto,
               let data = image.jpegData(compressionQuality: 0.85) {
                let path = "\(userID)/avatar.jpg"
                let ok = await SupabaseClient.shared.uploadStorage(
                    bucket: "player-media", path: path, data: data, contentType: "image/jpeg"
                )
                if ok {
                    row["avatar_url"] = SupabaseClient.shared.publicStorageURL(bucket: "player-media", path: path)
                }
            }
        case .none:
            row["avatar_kind"] = "none"
        }

        await SupabaseClient.shared.upsert(table: "player_profiles", values: row, onConflict: "id")
    }

    // MARK: - Hydrate (restore)

    /// Pull the identity row down and fill the local store. Local values win
    /// when they are real (non-default); remote fills the gaps — so a fresh
    /// install restores everything, and an in-use device is never clobbered.
    func hydrateProfileFromRemote() async {
        guard let userID = SupabaseAuth.shared.userID, SupabaseAuth.shared.isSignedIn else { return }
        guard let row = (await SupabaseClient.shared.get(
            table: "player_profiles",
            query: [
                URLQueryItem(name: "id", value: "eq.\(userID)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        ))?.first else { return }

        let profile = PlayerProfileStore.shared
        let localIsDefault = profile.displayName.isEmpty || profile.displayName == "Player"

        if localIsDefault, let name = row["display_name"] as? String, !name.isEmpty {
            profile.displayName = name
        }
        if profile.username.isEmpty, let v = row["username"] as? String { profile.username = v }
        if profile.kitNumber.isEmpty, let v = row["kit_number"] as? String { profile.kitNumber = v }
        if profile.position.isEmpty, let v = row["position"] as? String { profile.position = v }
        if profile.positionCode.isEmpty, let v = row["position_code"] as? String { profile.positionCode = v }
        if let v = row["foot"] as? String, !v.isEmpty { profile.foot = v }
        if profile.classYear == 0, let v = row["class_year"] as? Int { profile.classYear = v }
        if profile.birthYear == 0, let v = row["birth_year"] as? Int { profile.birthYear = v }
        if profile.gender.isEmpty, let v = row["gender"] as? String { profile.gender = v }
        if profile.trainingLevel.isEmpty, let v = row["training_level"] as? String { profile.trainingLevel = v }

        // Avatar: only fill when the local device has none chosen.
        if profile.avatar == .none {
            switch row["avatar_kind"] as? String {
            case "builtin":
                if let id = row["avatar_builtin"] as? String { profile.setBuiltinAvatar(id) }
            case "photo":
                if let urlString = row["avatar_url"] as? String, let url = URL(string: urlString) {
                    if let (data, _) = try? await URLSession.shared.data(from: url),
                       let image = UIImage(data: data) {
                        profile.setPhotoAvatar(image)
                    }
                }
            default:
                break
            }
        }
    }
}
