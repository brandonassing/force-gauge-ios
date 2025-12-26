//
//  PairingView.swift
//  force-gauge
//
//  Created by Brandon Assing on 2024-11-29.
//

import SwiftUI

struct PairingView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Connection Status
            connectionStatusView
            
            // Scan Button
            scanButtonView
            
            // Device List
            if bluetoothManager.isScanning || !bluetoothManager.discoveredDevices.isEmpty {
                deviceListView
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Pair Device")
        .alert("Error", isPresented: .constant(bluetoothManager.errorMessage != nil)) {
            Button("OK") {
                bluetoothManager.errorMessage = nil
            }
        } message: {
            if let error = bluetoothManager.errorMessage {
                Text(error)
            }
        }
    }
    
    private var connectionStatusView: some View {
        HStack {
            Circle()
                .fill(bluetoothManager.isConnected ? Color.green : Color.gray)
                .frame(width: 12, height: 12)
            
            Text(bluetoothManager.isConnected ? "Connected" : "Disconnected")
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var scanButtonView: some View {
        Button(action: {
            if bluetoothManager.isScanning {
                bluetoothManager.stopScanning()
            } else {
                bluetoothManager.startScanning()
            }
        }) {
            Label(bluetoothManager.isScanning ? "Stop Scanning" : "Scan for Devices", 
                  systemImage: bluetoothManager.isScanning ? "stop.circle.fill" : "magnifyingglass.circle.fill")
                .frame(maxWidth: .infinity)
                .padding()
                .background(bluetoothManager.isScanning ? Color.orange : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }
    
    private var deviceListView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Discovered Devices")
                .font(.headline)
                .padding(.horizontal)
            
            List(bluetoothManager.discoveredDevices, id: \.identifier) { device in
                Button(action: {
                    bluetoothManager.connect(to: device)
                }) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name ?? "Unknown Device")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Text(device.identifier.uuidString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if bluetoothManager.isConnected && bluetoothManager.connectedPeripheralIdentifier == device.identifier {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .listStyle(PlainListStyle())
            .frame(maxHeight: 300)
        }
    }
}

#Preview {
    NavigationView {
        PairingView(bluetoothManager: BluetoothManager())
    }
}

