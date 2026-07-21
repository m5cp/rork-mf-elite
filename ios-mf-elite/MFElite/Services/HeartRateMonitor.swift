//
//  HeartRateMonitor.swift
//  MFElite
//
//  Optional Bluetooth LE heart-rate strap support. Scans for the standard
//  Heart Rate service (0x180D) and reports live BPM. Entirely opt-in: nothing
//  connects unless the athlete taps "Connect HR", and a run works fine without it.
//

import Foundation
import CoreBluetooth
import Observation

@MainActor
@Observable
final class HeartRateMonitor: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private static let hrService = CBUUID(string: "180D")
    private static let hrMeasurement = CBUUID(string: "2A37")

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?

    enum Status: Equatable {
        case idle, scanning, connected, unavailable
    }

    private(set) var status: Status = .idle
    private(set) var bpm: Int = 0

    /// Begin scanning for a heart-rate strap. Triggers the Bluetooth prompt.
    func start() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: nil)
        } else {
            beginScan()
        }
    }

    func stop() {
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        central?.stopScan()
        status = .idle
        bpm = 0
    }

    private func beginScan() {
        guard central?.state == .poweredOn else { return }
        status = .scanning
        central?.scanForPeripherals(withServices: [Self.hrService])
    }

    // MARK: - CBCentralManagerDelegate

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn: self.beginScan()
            case .unauthorized, .unsupported, .poweredOff: self.status = .unavailable
            default: break
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            guard self.peripheral == nil else { return }
            self.peripheral = peripheral
            peripheral.delegate = self
            central.stopScan()
            central.connect(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.status = .connected
            peripheral.discoverServices([Self.hrService])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.peripheral = nil
            self.bpm = 0
            if self.status == .connected { self.status = .idle }
        }
    }

    // MARK: - CBPeripheralDelegate

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] where service.uuid == Self.hrService {
            peripheral.discoverCharacteristics([Self.hrMeasurement], for: service)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] where characteristic.uuid == Self.hrMeasurement {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.hrMeasurement, let data = characteristic.value else { return }
        let value = Self.parseBPM(data)
        Task { @MainActor in self.bpm = value }
    }

    /// Parse a Heart Rate Measurement characteristic per the BLE spec.
    private nonisolated static func parseBPM(_ data: Data) -> Int {
        let bytes = [UInt8](data)
        guard let flags = bytes.first else { return 0 }
        if flags & 0x01 == 0 {
            return bytes.count > 1 ? Int(bytes[1]) : 0
        } else {
            return bytes.count > 2 ? Int(bytes[1]) | (Int(bytes[2]) << 8) : 0
        }
    }
}
