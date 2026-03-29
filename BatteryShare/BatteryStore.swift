//
//  BatteryStore.swift
//  BatteryShare
//
//  Created by Codex on 3/22/26.
//

import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

enum BatteryStoreConfiguration {
    static let cloudKitContainerID = "iCloud.JackKroll.BatteryShare.2"
    static let appGroupID = "group.com.JackKroll.BatteryShare"
    static let storeName = cloudKitContainerID

    static let schema = Schema([
        BatteryStatus.self,
    ])

    static func makeSharedModelContainer() throws -> ModelContainer {
        let modelConfiguration = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier(appGroupID),
            cloudKitDatabase: .automatic
        )

        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
}

struct BatteryDeviceSnapshot: Identifiable, Hashable {
    let id: String
    let deviceNickname: String
    let deviceType: BatteryStatus.DeviceType?
    let timestamp: Date?
    let currentCharge: Int?
    let isCharging: Bool
    let isLowPower: Bool
    let estChargeTime: TimeInterval?
    let estDepleteTime: TimeInterval?
}

enum BatteryStore {
    static func deviceNickname(for type: BatteryStatus.DeviceType?) -> String {
        guard let type else {
            return "Device"
        }

        switch type {
        case .iphone:
            return "My iPhone"
        case .mac:
            return "My Mac"
        case .ipad:
            return "My iPad"
        }
    }

    static func fetchLatestSnapshots(
        from context: ModelContext,
        limit: Int? = nil
    ) throws -> [BatteryDeviceSnapshot] {
        let descriptor = FetchDescriptor<BatteryStatus>(
            sortBy: [SortDescriptor(\BatteryStatus.timestamp, order: .reverse)]
        )

        return latestSnapshots(from: try context.fetch(descriptor), limit: limit)
    }

    static func latestSnapshots(
        from statuses: [BatteryStatus],
        limit: Int? = nil
    ) -> [BatteryDeviceSnapshot] {
        var seenDeviceIDs = Set<String>()
        var snapshots: [BatteryDeviceSnapshot] = []
        snapshots.reserveCapacity(limit ?? statuses.count)

        let sortedStatuses = statuses.sorted {
            ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast)
        }

        for status in sortedStatuses {
            guard let deviceID = status.deviceID else {
                continue
            }

            guard seenDeviceIDs.insert(deviceID).inserted else {
                continue
            }

            snapshots.append(
                BatteryDeviceSnapshot(
                    id: deviceID,
                    deviceNickname: deviceNickname(for: status.deviceType),
                    deviceType: status.deviceType,
                    timestamp: status.timestamp,
                    currentCharge: status.currentCharge,
                    isCharging: status.isCharging ?? false,
                    isLowPower: status.isLowPower ?? false,
                    estChargeTime: status.estChargeTime,
                    estDepleteTime: status.estDepleteTime
                )
            )

            if let limit, snapshots.count >= limit {
                break
            }
        }

        return snapshots
    }
}

enum BatteryWidgetReloader {
    static func reloadAllTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
