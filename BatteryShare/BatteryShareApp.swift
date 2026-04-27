//
//  BatteryShareApp.swift
//  BatteryShare
//
//  Created by Jack Kroll on 2/26/26.
//

import SwiftUI
import SwiftData

@main
struct BatteryShareApp: App {
    private let sharedModelContainer: ModelContainer
    #if os(iOS)
    @UIApplicationDelegateAdaptor(BatteryShareAppDelegate.self) private var appDelegate
    #endif

    #if os(macOS)
    @State private var scheduler = NSBackgroundActivityScheduler(identifier: "com.JackKroll.BatteryShare.report")
    #endif
    init() {
        do {
            sharedModelContainer = try BatteryStoreConfiguration.makeSharedModelContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        #if os(macOS)
        let container = sharedModelContainer
        scheduler.repeats = true
        scheduler.interval = 5 * 60 // Repeat every 5 minutes
        scheduler.tolerance = 30 // 30s tolerance
        scheduler.qualityOfService = .utility
        scheduler.schedule { completion in
            Task { @MainActor in
                if let battery = fetchBatteryStatus() {
                    // Mark this entry as coming from macOS so we can prune per-device type
                    battery.deviceType = .mac
                    try? BatteryStore.ensureDeviceNickname(for: battery, in: container.mainContext)
                    container.mainContext.insert(battery)
                    do {
                        try container.mainContext.save()
                        BatteryWidgetReloader.requestReload()
                    } catch {
                        completion(.deferred)
                        return
                    }
                }

                // Attempt to prune older entries for macOS, keeping only the 10 most recent
                do {
                    let descriptor = FetchDescriptor<BatteryStatus>()
                    let allEntries = try container.mainContext.fetch(descriptor)
                    let selfEntires = allEntries.filter { $0.deviceID == DeviceIdentityManager.getDeviceIdentifier()  }

                    // Sort by timestamp descending (treat nil as distant past)
                    let sorted = selfEntires.sorted { (a, b) in
                        (a.timestamp ?? .distantPast) > (b.timestamp ?? .distantPast)
                    }
                    
                    let maxLength = 10
                    if sorted.count > maxLength {
                        for old in sorted.dropFirst(maxLength) {
                            container.mainContext.delete(old)
                        }
                        try? container.mainContext.save()
                        BatteryWidgetReloader.requestReload()
                    }
                } catch {
                    // Ignore pruning errors; the next cycle can try again
                }
                completion(.finished)
            }
        }
        #endif
    }
    
    var body: some Scene {
        #if os(macOS)
        MenuBarExtra("Test" ,systemImage: "bolt.fill"){
            MenuBar()
                .modelContainer(sharedModelContainer)
        } /*label: {
            MenuBarLabel()
        }*/
        .menuBarExtraStyle(.menu)
        .modelContainer(sharedModelContainer)
        #else
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        #endif
    }
}
