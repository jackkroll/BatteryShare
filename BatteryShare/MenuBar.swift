//
//  MenuBar.swift
//  BatteryShare
//
//  Created by Jack Kroll on 2/26/26.
//

#if os(macOS)
import SwiftUI
import IOKit.ps
import SwiftData
import ServiceManagement

struct MenuBar: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor<BatteryStatus>(\.timestamp)]) var battery: [BatteryStatus]
    @State var selectedBattery : BatteryStatus? = nil
    @State var launchOnLogin: Bool? = nil
    var body: some View {
        VStack {
            Text(selectedBattery?.currentCharge?.formatted(.percent) ?? "Unknown Charge state")
                .fontWeight(.bold)
                .foregroundStyle(selectedBattery?.isLowPower ?? false ? .yellow : .primary)
            /*if let estDepleteTime = battery?.estDepleteTime {
                HStack {
                    Text(Date.now + estDepleteTime, style: .relative)
                        .padding()
                        .glassEffect()
                }
            }*/
            Button(launchOnLogin ?? false ? "Disable Launch on Login" : "Enable Launch on Login") {
                launchOnLogin = !(launchOnLogin ?? false)
            }
            .onChange(of: launchOnLogin) { oldValue, newValue in
                if oldValue != nil, let newValue = newValue {
                    if newValue {
                        try? SMAppService.mainApp.register()
                    }
                    else {
                        try? SMAppService.mainApp.unregister()
                    }
                }
            }
            .keyboardShortcut("l")
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onAppear {
            selectedBattery = battery.last
            if SMAppService.mainApp.status == .enabled {
                launchOnLogin = true
            } else {
                launchOnLogin = false
            }
        }
        .onChange(of: battery) {
            selectedBattery = battery.last
        }
        .padding()
    }
}

func fetchBatteryStatus() -> BatteryStatus? {
    let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
    
    let battery = BatteryStatus()
    battery.timestamp = .now
    for source in sources {
        if let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
            for (key, value) in description {
                switch key {
                case "Is Charging":
                    if let isCharging = value as? NSNumber {
                        battery.isCharging = Bool(truncating: isCharging)
                    }
                case "Time to Empty":
                    if let estDepleteTime = value as? Int {
                        battery.estDepleteTime = TimeInterval(estDepleteTime * 60)
                    }
                case "Time to Full Charge":
                    if let estChargeTime = value as? Int {
                        battery.estChargeTime = TimeInterval(estChargeTime * 60)
                    }
                case "Current Capacity":
                    if let currentCapacity = value as? Int {
                        battery.currentCharge = currentCapacity
                    }
                case "LPM Active":
                    if let isLPM = value as? NSNumber {
                        battery.isLowPower = Bool(truncating: isLPM)
                    }
                default:
                    continue
                }
            }
            return battery
        }
    }
    return nil
}

#Preview {
    MenuBar()
        .modelContainer(for: BatteryStatus.self, inMemory: true)
}
#endif

