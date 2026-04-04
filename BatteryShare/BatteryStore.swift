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
    static let cloudKitContainerID = "iCloud.JackKroll.BatteryShare.3"
    static let appGroupID = "group.com.JackKroll.BatteryShare"
    static let storeName = cloudKitContainerID

    static let schema = Schema([
        BatteryStatus.self,
        DeviceNickname.self,
    ])

    static func makeInMemoryModelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: [
                ModelConfiguration(isStoredInMemoryOnly: true)
            ]
        )
    }

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
    static func defaultDeviceNickname(for type: BatteryStatus.DeviceType?) -> String {
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

    static func deviceNickname(
        for status: BatteryStatus,
        nicknamesByDeviceID: [String: DeviceNickname] = [:]
    ) -> String {
        if let deviceID = status.deviceID,
           let nickname = sanitizedNickname(nicknamesByDeviceID[deviceID]?.nickname) {
            return nickname
        }

        if let nickname = sanitizedNickname(status.deviceNickname?.nickname) {
            return nickname
        }

        return defaultDeviceNickname(for: status.deviceType)
    }

    static func nicknamesByDeviceID(from nicknames: [DeviceNickname]) -> [String: DeviceNickname] {
        nicknames.reduce(into: [:]) { partialResult, nickname in
            guard let deviceID = nickname.deviceID else {
                return
            }
            partialResult[deviceID] = nickname
        }
    }

    static func fetchNicknamesByDeviceID(from context: ModelContext) throws -> [String: DeviceNickname] {
        try nicknamesByDeviceID(from: context.fetch(FetchDescriptor<DeviceNickname>()))
    }

    static func ensureDeviceNickname(for status: BatteryStatus, in context: ModelContext) throws {
        guard let deviceID = status.deviceID else {
            return
        }

        if let existingNickname = status.deviceNickname {
            if existingNickname.deviceID == nil {
                existingNickname.deviceID = deviceID
            }
            return
        }

        var descriptor = FetchDescriptor<DeviceNickname>(
            predicate: #Predicate { nickname in
                nickname.deviceID == deviceID
            }
        )
        descriptor.fetchLimit = 1

        if let existingNickname = try context.fetch(descriptor).first {
            status.deviceNickname = existingNickname
            if existingNickname.deviceID == nil {
                existingNickname.deviceID = deviceID
            }
        }
    }

    static func fetchLatestSnapshots(
        from context: ModelContext,
        limit: Int? = nil
    ) throws -> [BatteryDeviceSnapshot] {
        let descriptor = FetchDescriptor<BatteryStatus>(
            sortBy: [SortDescriptor(\BatteryStatus.timestamp, order: .reverse)]
        )

        let nicknamesByDeviceID = try fetchNicknamesByDeviceID(from: context)

        return latestSnapshots(
            from: try context.fetch(descriptor),
            nicknamesByDeviceID: nicknamesByDeviceID,
            limit: limit
        )
    }

    static func latestSnapshots(
        from statuses: [BatteryStatus],
        nicknamesByDeviceID: [String: DeviceNickname] = [:],
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
                    deviceNickname: deviceNickname(
                        for: status,
                        nicknamesByDeviceID: nicknamesByDeviceID
                    ),
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

    private static func sanitizedNickname(_ nickname: String?) -> String? {
        guard let nickname else {
            return nil
        }

        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedNickname.isEmpty ? nil : trimmedNickname
    }
}

enum BatteryWidgetReloader {
    static func reloadAllTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
