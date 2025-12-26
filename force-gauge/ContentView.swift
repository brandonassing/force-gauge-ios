//
//  ContentView.swift
//  force-gauge
//
//  Created by Brandon Assing on 2024-11-29.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    
    var body: some View {
        NavigationView {
            if bluetoothManager.isConnected {
                ForceGaugeView(bluetoothManager: bluetoothManager)
            } else {
                PairingView(bluetoothManager: bluetoothManager)
            }
        }
    }
}

#Preview {
    ContentView()
}
