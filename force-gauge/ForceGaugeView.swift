//
//  ForceGaugeView.swift
//  force-gauge
//
//  Created by Brandon Assing on 2024-11-29.
//

import SwiftUI

struct ForceGaugeView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var selectedUnit: Unit = .lbs
    
    enum Unit: String, CaseIterable {
        case lbs = "lbs"
        case kgs = "kgs"
    }
    
    // Conversion constant: 1 lb = 0.453592 kg
    private let lbsToKgs: Double = 0.453592
    
    var body: some View {
        VStack(spacing: 20) {
            // Connection Status
            connectionStatusView
            
            // Unit Toggle
            unitToggleView
            
            // Force Value Display
            forceValueView
            
            // Control Buttons
            controlButtonsView
            
            // Disconnect Button
            disconnectButtonView
            
            Spacer()
        }
        .padding()
        .navigationTitle("Force Gauge")
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
            
            if let deviceName = bluetoothManager.connectedDeviceName {
                Text("• \(deviceName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var unitToggleView: some View {
        Picker("Unit", selection: $selectedUnit) {
            ForEach(Unit.allCases, id: \.self) { unit in
                Text(unit.rawValue).tag(unit)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }
    
    private var forceValueView: some View {
        HStack(spacing: 20) {
            // Current Force Value
            VStack(spacing: 8) {
                Text("Force")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.2f", displayForceValue))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(selectedUnit.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Max Force Value
            VStack(spacing: 8) {
                Text("Max Force")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.2f", displayMaxForceValue))
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundColor(.blue)
                
                Text(selectedUnit.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var controlButtonsView: some View {
        HStack(spacing: 15) {
            // Tare Button
            Button(action: {
                bluetoothManager.tare()
            }) {
                Label("Tare", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            // Reset Max Button
            Button(action: {
                bluetoothManager.resetMax()
            }) {
                Label("Reset Max", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
    
    private var disconnectButtonView: some View {
        Button(action: {
            bluetoothManager.disconnect()
        }) {
            Label("Disconnect", systemImage: "xmark.circle.fill")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }
    
    // Computed properties for displaying converted values
    private var displayForceValue: Double {
        if selectedUnit == .kgs {
            return bluetoothManager.forceValueLbs * lbsToKgs
        } else {
            return bluetoothManager.forceValueLbs
        }
    }
    
    private var displayMaxForceValue: Double {
        if selectedUnit == .kgs {
            return bluetoothManager.maxForceValueLbs * lbsToKgs
        } else {
            return bluetoothManager.maxForceValueLbs
        }
    }
}

#Preview {
    NavigationView {
        ForceGaugeView(bluetoothManager: BluetoothManager())
    }
}

