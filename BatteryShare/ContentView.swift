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
    @State var deviceStatus : [DeviceBatteryStatus] = []
    @State var displaySettings: Bool = false
    @State var quotaExceeded: Bool = false
    @State private var syncManager = SyncStatusAsyncManager(
        cloudKitContainerID: BatteryStoreConfiguration.cloudKitContainerID,
    )
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if recentStatus.isEmpty {
                    VStack {
                        ContentUnavailableView("Battery Status Never Synced", systemImage: "icloud.and.arrow.down.fill")
                            Group {
                                if !syncManager.isAccountAvailable && !syncManager.isCloudDriveAvailable {
                                    Text("Please sign into iCloud on your device in Settings")
                                }
                                if syncManager.isAccountAvailable && !syncManager.isCloudDriveAvailable {
                                    Text("Please enable iCloud Drive in Settings")
                                }
                                if syncManager.isAccountAvailable && syncManager.isCloudDriveAvailable {
                                    Text("Install BatteryShare on your Mac to sync battery status")
                                }
                            }
                            .font(.subheadline)
                            .padding(.horizontal)
                        
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(deviceStatus, id: \.status.deviceID) { device in
                            SingleDeviceView(syncManager: syncManager, deviceStatus: device)
                        }
                    }
                }
            }
            .refreshable {
                await requestCloudRefresh()
            }
            .padding(.horizontal)
            .onAppear {
                updateDeviceStatuses()
            }
            .onChange(of: recentStatus) { _, _ in
                updateDeviceStatuses()
            }
            .toolbar {
                Button {
                    try? modelContext.delete(model: BatteryStatus.self)
                    try? modelContext.save()
                    
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }
    
    @MainActor
    private func updateDeviceStatuses() {
        // Build the most recent BatteryStatus per deviceID
        var latestByID: [String: BatteryStatus] = [:]
        for status in recentStatus {
            guard let id = status.deviceID else { continue }
            let currentDate = status.timestamp ?? .distantPast
            let existingDate = latestByID[id]?.timestamp ?? .distantPast
            if latestByID[id] == nil || currentDate > existingDate {
                latestByID[id] = status
            }
        }

        // Map to DeviceBatteryStatus and sort by most recent timestamp
        let devices: [DeviceBatteryStatus] = latestByID.values
            .map { status in
                let nickname: String
                nickname = BatteryStore.deviceNickname(for: status.deviceType)
                return DeviceBatteryStatus(deviceNickname: nickname, status: status)
            }
            .sorted { (lhs, rhs) in
                let l = lhs.status.timestamp ?? .distantPast
                let r = rhs.status.timestamp ?? .distantPast
                return l > r
            }

        self.deviceStatus = devices
        BatteryWidgetReloader.reloadAllTimelines()
    }
    func quotaExceededNotice() -> Void {
        quotaExceeded = true
    }
    
    @MainActor
    private func requestCloudRefresh() async {
        let startingSnapshot = StatusSnapshot(statuses: recentStatus)

        syncManager.refreshCloudDriveStatus()
        _ = try? await syncManager.checkAccountStatus()

        guard syncManager.isAccountAvailable else {
            updateDeviceStatuses()
            return
        }

        let container = CKContainer(identifier: BatteryStoreConfiguration.cloudKitContainerID)

        do {
            // SwiftData imports are still managed automatically. This CloudKit round-trip
            // nudges the sync stack to contact iCloud and gives incoming changes time to merge.
            _ = try await container.privateCloudDatabase.allRecordZones()
            await waitForImportedChanges(since: startingSnapshot)
        } catch {
            // Ignore manual refresh failures and fall back to the next automatic sync.
        }

        modelContext.processPendingChanges()
        updateDeviceStatuses()
    }
    
    @MainActor
    private func waitForImportedChanges(since startingSnapshot: StatusSnapshot) async {
        let deadline = Date.now.addingTimeInterval(4)
        var sawSyncActivity = syncManager.isSyncing

        while Date.now < deadline {
            if StatusSnapshot(statuses: recentStatus) != startingSnapshot {
                return
            }

            if syncManager.isSyncing {
                sawSyncActivity = true
            } else if sawSyncActivity {
                return
            }

            try? await Task.sleep(for: .milliseconds(250))
        }
    }
}

private struct StatusSnapshot: Equatable {
    let rows: [String]

    init(statuses: [BatteryStatus]) {
        var snapshotRows: [String] = []
        snapshotRows.reserveCapacity(statuses.count)

        for status in statuses {
            var rowParts: [String] = []
            rowParts.reserveCapacity(9)
            rowParts.append(String(describing: status.persistentModelID))
            rowParts.append(status.deviceID ?? "")
            rowParts.append(status.deviceType?.rawValue ?? "")
            rowParts.append(String(status.timestamp?.timeIntervalSince1970 ?? 0))
            rowParts.append(String(status.currentCharge ?? -1))
            rowParts.append(String(status.isCharging ?? false))
            rowParts.append(String(status.isLowPower ?? false))
            rowParts.append(String(status.estChargeTime ?? -1))
            rowParts.append(String(status.estDepleteTime ?? -1))
            snapshotRows.append(rowParts.joined(separator: "|"))
        }

        rows = snapshotRows.sorted()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: BatteryStatus.self, inMemory: true)
}
 
#Preview("With Example Battery Status") {
    do {
        let container = try ModelContainer(
            for: BatteryStatus.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

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
            .modelContainer(for: BatteryStatus.self, inMemory: true)
    }
}

#endif
