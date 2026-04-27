//
//  BatteryWidgetSyncController.swift
//  BatteryShare
//
//  Created by Codex on 4/18/26.
//

import Foundation

#if os(iOS)
import SwiftData
import UIKit
import CoreData

final class BatteryWidgetSyncController {
    static let shared = BatteryWidgetSyncController()

    private var sharedModelContainer: ModelContainer?
    private var remoteChangeObserver: NSObjectProtocol?
    private var pendingBackgroundFetchCompletion: ((UIBackgroundFetchResult) -> Void)?
    private var backgroundFetchTimeoutWorkItem: DispatchWorkItem?

    private init() {}

    func start() {
        guard remoteChangeObserver == nil else {
            return
        }

        sharedModelContainer = try? BatteryStoreConfiguration.makeSharedModelContainer()

        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleImportedChanges()
        }
    }

    func prepareForBackgroundFetch(completion: @escaping (UIBackgroundFetchResult) -> Void) {
        start()

        finishBackgroundFetch(with: .noData)
        pendingBackgroundFetchCompletion = completion

        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.finishBackgroundFetch(with: .noData)
        }
        backgroundFetchTimeoutWorkItem = timeoutWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: timeoutWorkItem)

        warmSharedStore()
    }

    private func warmSharedStore() {
        if sharedModelContainer == nil {
            sharedModelContainer = try? BatteryStoreConfiguration.makeSharedModelContainer()
        }

        guard let sharedModelContainer else {
            finishBackgroundFetch(with: .failed)
            return
        }

        _ = try? BatteryStore.fetchLatestSnapshots(from: sharedModelContainer.mainContext, limit: 1)
    }

    private func handleImportedChanges() {
        BatteryWidgetReloader.requestReload(isAppActive: UIApplication.shared.applicationState == .active)
        finishBackgroundFetch(with: .newData)
    }

    private func finishBackgroundFetch(with result: UIBackgroundFetchResult) {
        backgroundFetchTimeoutWorkItem?.cancel()
        backgroundFetchTimeoutWorkItem = nil

        let completion = pendingBackgroundFetchCompletion
        pendingBackgroundFetchCompletion = nil
        completion?(result)
    }
}

final class BatteryShareAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BatteryWidgetSyncController.shared.start()
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        BatteryWidgetSyncController.shared.prepareForBackgroundFetch(completion: completionHandler)
    }
}
#endif
