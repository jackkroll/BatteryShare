//
//  ContentView.swift
//  BatteryShare
//
//  Created by Jack Kroll on 2/26/26.
//
#if os(macOS)
#else
import SwiftUI
import SwiftData
import Shimmer
import iCloudSyncStatusKit
import CloudKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var recentStatus: [BatteryStatus]
    @Query private var deviceNicknames: [DeviceNickname]
    @State var deviceStatus : [BatteryStatus] = []
    @State var displaySettings: Bool = false
    @State var quotaExceeded: Bool = false
    @State private var syncManager = SyncStatusAsyncManager(
        monitoringOptions: .syncFocused,
        cloudKitContainerID: BatteryStoreConfiguration.cloudKitContainerID,
    )
    @State private var showSyncNotification: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if showSyncNotification {
                        HStack {
                            Image(systemName: "icloud.and.arrow.down.fill")
                            Text("Syncing from iCloud")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding()
                        .glassEffect()
                    }
                    if recentStatus.isEmpty {
                        VStack {
                            ContentUnavailableView("Battery Status Never Synced", systemImage: "icloud.and.arrow.down.fill")
                            Group {
                                if !syncManager.isNetworkConnected {
                                    Text("Connect to the internet to check iCloud for updates.")
                                }
                                if !syncManager.isAccountAvailable {
                                    Text("Please sign into iCloud on your device in Settings.")
                                }
                                if syncManager.environmentStatus.isSyncReady {
                                    Text("No battery data has been imported yet. Install BatteryShare on your Mac, then tap Check iCloud.")
                                }
                                if syncManager.networkStatus.isLowPowerModeEnabled {
                                    Text("Low Power Mode can delay CloudKit sync.")
                                }
                            }
                            .font(.subheadline)
                            .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(deviceStatus, id: \.deviceID) { device in
                                SingleDeviceView(
                                    deviceStatus: device,
                                    deviceNickname: BatteryStore.deviceNickname(
                                        for: device,
                                        nicknamesByDeviceID: nicknamesByDeviceID
                                    )
                                )
                            }
                        }
                    }
                }
            }
            .refreshable {
                withAnimation {
                    deviceStatus = storeToDevices(store: recentStatus)
                }
            }
            .padding(.horizontal)
            .onChange(of: syncManager.isSyncing) { old, new in
                if !old && new {
                    withAnimation {
                        showSyncNotification = true
                    }
                }
                if old && !new {
                    withAnimation {
                        showSyncNotification = false
                        deviceStatus = storeToDevices(store: recentStatus)
                    }
                }
            }
            .onChange(of: recentStatus) {
                withAnimation {
                    deviceStatus = storeToDevices(store: recentStatus)
                }
            }
            .onAppear {
                withAnimation {
                    deviceStatus = storeToDevices(store: recentStatus)
                }
            }
        }
    }

    private var nicknamesByDeviceID: [String: DeviceNickname] {
        BatteryStore.nicknamesByDeviceID(from: deviceNicknames)
    }
    
    func storeToDevices(store: [BatteryStatus]) -> [BatteryStatus] {
        var latestByDevice: [(String, BatteryStatus)] = []
        print(store)
        for status in store {
            if let deviceID = status.deviceID {
                if let givenStatus = latestByDevice.first(where: {$0.0 == deviceID})?.1 {
                    if let timestamp = givenStatus.timestamp {
                        if status.timestamp ?? .distantPast > timestamp {
                            if let index = latestByDevice.firstIndex(where: {$0.0 == deviceID}) {
                                latestByDevice[index] = (deviceID, status)
                            }
                        }
                    
                    } else {
                        print("given does not have timestamp???")
                    }
                } else {
                    latestByDevice.append((deviceID, status))
                }
                
            } else {
                print("no deviceID")
            }
        }
        return latestByDevice.map { device in
            return device.1
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(try! BatteryStoreConfiguration.makeInMemoryModelContainer())
}
 
#Preview("With Example Battery Status") {
    do {
        let container = try BatteryStoreConfiguration.makeInMemoryModelContainer()

        // Create a sample status (100% so that percent formatting looks correct for Int)
        let sample = BatteryStatus(
            deviceType: .iphone,
            currentCharge: 30,
            isCharging: true,
            isLowPower: false,
            estChargeTime: 30 * 60,
            estDepleteTime: 0
        )
        sample.timestamp = .now.addingTimeInterval(-5 * 60) // 5 minutes ago

        container.mainContext.insert(sample)
        return ContentView().modelContainer(container)
    } catch {
        // Fallback empty preview if the container fails to create
        return ContentView()
            .modelContainer(try! BatteryStoreConfiguration.makeInMemoryModelContainer())
    }
}

#endif
