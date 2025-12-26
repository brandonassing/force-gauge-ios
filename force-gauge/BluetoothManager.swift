//
//  BluetoothManager.swift
//  force-gauge
//
//  Created by Brandon Assing on 2024-11-29.
//

import Foundation
import CoreBluetooth
import Combine

class BluetoothManager: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var connectedDeviceName: String?
    @Published var forceValueLbs: Double = 0.0
    @Published var maxForceValueLbs: Double = 0.0
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var errorMessage: String?
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var readTimer: Timer?
    private var tareOffset: Double = 0.0
    
    var connectedPeripheralIdentifier: UUID? {
        connectedPeripheral?.identifier
    }
    
    // Common BLE service UUIDs for ESP32 devices
    // You may need to adjust these based on your ESP32 firmware
    private let serviceUUID = CBUUID(string: "38e5fea4-d56b-4178-9a80-015dc896a0d1")
    private let characteristicUUID = CBUUID(string: "55d0591b-4bdd-4207-81f4-d7d1753de97f")
    
    // Alternative: Nordic UART Service (often used with ESP32)
    private let nusServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let nusCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            errorMessage = "Bluetooth is not available. Please enable Bluetooth in Settings."
            return
        }
        
        guard !isScanning else { return }
        
        isScanning = true
        discoveredDevices = []
        errorMessage = nil
        
        // Scan for devices with the service UUID, or scan for all devices
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    
    func stopScanning() {
        guard isScanning else { return }
        centralManager.stopScan()
        isScanning = false
    }
    
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectedPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        stopPeriodicReading()
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    private func discoverServices(for peripheral: CBPeripheral) {
        peripheral.discoverServices(nil) // Discover all services
    }
    
    private func discoverCharacteristics(for service: CBService) {
        guard let peripheral = service.peripheral else { return }
        peripheral.discoverCharacteristics(nil, for: service)
    }
    
    private func subscribeToCharacteristic(_ characteristic: CBCharacteristic) {
        guard let peripheral = characteristic.service?.peripheral else { return }
        // Only attempt to subscribe if the characteristic actually supports notifications or indications
        if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
            peripheral.setNotifyValue(true, for: characteristic)
        } else if characteristic.properties.contains(.read) {
            // If it only supports read, start periodic reading instead
            startPeriodicReading(characteristic)
        }
    }
    
    private func startPeriodicReading(_ characteristic: CBCharacteristic) {
        // Stop any existing timer
        readTimer?.invalidate()
        
        guard let peripheral = characteristic.service?.peripheral else { return }
        
        // Read immediately
        peripheral.readValue(for: characteristic)
        
        // Set up periodic reading (e.g., every 100ms)
        readTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let peripheral = characteristic.service?.peripheral else { return }
            peripheral.readValue(for: characteristic)
        }
    }
    
    private func stopPeriodicReading() {
        readTimer?.invalidate()
        readTimer = nil
    }
    
    func tare() {
        DispatchQueue.main.async {
            // Set the tare offset to the current raw value (forceValueLbs + tareOffset)
            // This way, future readings will be adjusted to show 0 at this point
            self.tareOffset = self.forceValueLbs + self.tareOffset
            self.forceValueLbs = 0.0
        }
    }
    
    func resetMax() {
        DispatchQueue.main.async {
            // Reset max force value in lbs
            self.maxForceValueLbs = 0.0
            // Tare the scale using the same logic as the tare button
            self.tareOffset = self.forceValueLbs + self.tareOffset
            self.forceValueLbs = 0.0
        }
    }
    
    private func parseForceData(_ data: Data) {
        // Parse the incoming data from the ESP32
        // Common formats: ASCII string, binary float, or integer
        // Adjust this based on your ESP32 firmware's data format
        
        // Try parsing as ASCII string first (common for ESP32)
        if let stringValue = String(data: data, encoding: .utf8) {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let rawValue = Double(trimmed) {
                DispatchQueue.main.async {
                    // Apply tare offset to get the adjusted value in lbs
                    let adjustedValue = rawValue - self.tareOffset
                    self.forceValueLbs = adjustedValue
                    if adjustedValue > self.maxForceValueLbs {
                        self.maxForceValueLbs = adjustedValue
                    }
                }
                return
            }
        }
        
        // Try parsing as 32-bit float (little endian)
        if data.count >= 4 {
            let value = data.withUnsafeBytes { bytes in
                Float32(bitPattern: UInt32(littleEndian: bytes.load(as: UInt32.self)))
            }
            DispatchQueue.main.async {
                let rawValue = Double(value)
                // Apply tare offset to get the adjusted value in lbs
                let adjustedValue = rawValue - self.tareOffset
                self.forceValueLbs = adjustedValue
                if adjustedValue > self.maxForceValueLbs {
                    self.maxForceValueLbs = adjustedValue
                }
            }
            return
        }
        
        // Try parsing as 16-bit integer (little endian)
        if data.count >= 2 {
            let value = data.withUnsafeBytes { bytes in
                Int16(littleEndian: bytes.load(as: Int16.self))
            }
            DispatchQueue.main.async {
                let rawValue = Double(value)
                // Apply tare offset to get the adjusted value in lbs
                let adjustedValue = rawValue - self.tareOffset
                self.forceValueLbs = adjustedValue
                if adjustedValue > self.maxForceValueLbs {
                    self.maxForceValueLbs = adjustedValue
                }
            }
            return
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            errorMessage = nil
        case .poweredOff:
            errorMessage = "Bluetooth is turned off. Please enable Bluetooth in Settings."
            isScanning = false
            isConnected = false
        case .unauthorized:
            errorMessage = "Bluetooth permission denied. Please enable Bluetooth access in Settings."
        case .unsupported:
            errorMessage = "Bluetooth is not supported on this device."
        case .resetting:
            errorMessage = "Bluetooth is resetting..."
        case .unknown:
            errorMessage = "Bluetooth state is unknown."
        @unknown default:
            errorMessage = "Bluetooth state is unknown."
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Filter for devices that might be our force gauge
        // You can add name filtering here if your ESP32 has a specific name
        if !discoveredDevices.contains(peripheral) {
            DispatchQueue.main.async {
                self.discoveredDevices.append(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectedDeviceName = peripheral.name ?? "Unknown Device"
            self.errorMessage = nil
            self.maxForceValueLbs = 0.0
            self.tareOffset = 0.0
        }
        
        peripheral.delegate = self
        discoverServices(for: peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedDeviceName = nil
            self.errorMessage = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        stopPeriodicReading()
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedDeviceName = nil
            self.forceValueLbs = 0.0
            self.tareOffset = 0.0
            // Optionally reset max value on disconnect - comment out if you want to keep it
            // self.maxForceValueLbs = 0.0
            if let error = error {
                self.errorMessage = "Disconnected: \(error.localizedDescription)"
            }
        }
        connectedPeripheral = nil
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            // Check if this is a service we're interested in
            if service.uuid == serviceUUID || service.uuid == nusServiceUUID || service.uuid == CBUUID(string: "00001800-0000-1000-8000-00805F9B34FB") {
                discoverCharacteristics(for: service)
            } else {
                // Also try discovering characteristics for unknown services
                discoverCharacteristics(for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            // Check if this is a characteristic we're interested in
            let isExpectedCharacteristic = characteristic.uuid == characteristicUUID || characteristic.uuid == nusCharacteristicUUID
            
            // Try to use expected characteristics or any characteristic with notify/read properties
            if isExpectedCharacteristic || (characteristic.properties.contains(.notify) || characteristic.properties.contains(.read)) {
                subscribeToCharacteristic(characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            // If notifications failed, try falling back to periodic reading
            if characteristic.properties.contains(.read) {
                DispatchQueue.main.async {
                    self.errorMessage = "Notifications not supported, using periodic reads instead"
                }
                startPeriodicReading(characteristic)
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to subscribe to notifications: \(error.localizedDescription)"
                }
            }
            return
        }
        
        // If notifications are enabled successfully, only read the current value if the characteristic also supports reading
        if characteristic.isNotifying && characteristic.properties.contains(.read) {
            peripheral.readValue(for: characteristic)
        }
        // If notifications are working, we don't need to read - notifications will provide the values
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            // Don't show error if reading is not permitted but notifications are working
            // (notifications will provide the values, so reading isn't needed)
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("reading is not permitted") && characteristic.isNotifying {
                // Reading not permitted but notifications are working - this is fine, suppress the error
                return
            }
            
            DispatchQueue.main.async {
                self.errorMessage = "Error reading value: \(error.localizedDescription)"
            }
            return
        }
        
        guard let data = characteristic.value else { return }
        parseForceData(data)
    }
}

