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
            if let timestamp = selectedBattery?.timestamp {
                Text("Last synced: \(Int((timestamp.distance(to: .now))/60)) minutes ago")
            }
            else {
                Text("Not synced yet")
            }
            Button("Sync Now") {
                let battery = fetchBatteryStatus()
                if let battery = battery {
                    try? BatteryStore.ensureDeviceNickname(for: battery, in: modelContext)
                    modelContext.insert(battery)
                }
            }
            .keyboardShortcut("s")
            
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

struct MenuBarLabel: View {
    @Query(sort: [SortDescriptor<BatteryStatus>(\.timestamp)]) private var battery: [BatteryStatus]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            Label {
                Text(menuBarTitle)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            } icon: {
                Image(systemName: menuBarIcon)
            }
        }
    }

    private var menuBarTitle: String {
        guard let status = battery.last else {
            return "Share • No Sync"
        }

        let deviceText: String
        switch status.deviceType {
        case .some(.iphone):
            deviceText = "iPhone"
        case .some(.mac):
            deviceText = "Mac"
        case .none:
            deviceText = "Share"
        case .some(.ipad):
            deviceText = "iPad"
        }

        let percentText = status.currentCharge.map { "\($0)%" } ?? "--"
        let ageText = status.timestamp.map { formatAge($0) } ?? "--"
        return "\(deviceText) \(percentText) • \(ageText)"
    }

    private var menuBarIcon: String {
        switch battery.last?.deviceType {
        case .some(.iphone):
            return "iphone"
        case .some(.mac):
            return "macbook"
        case .some(.ipad):
            return "ipad"
        case .none:
            return "arrow.triangle.2.circlepath"
        }
    }

    private func formatAge(_ date: Date) -> String {
        let minutes = max(0, Int(abs(date.timeIntervalSinceNow) / 60))
        if minutes < 1 {
            return "now"
        }
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h"
        }
        let days = hours / 24
        return "\(days)d"
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
        .modelContainer(try! BatteryStoreConfiguration.makeInMemoryModelContainer())
}
#endif
