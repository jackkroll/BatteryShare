//
//  DeviceID.swift
//  BatteryShare
//
//  Created by Jack Kroll on 3/7/26.
//


import Foundation
import Security

// Helper class to manage a unique, persistent identifier in the Keychain
class DeviceIdentityManager {
    static let deviceIDKey = "deviceUUID"

    static func getDeviceIdentifier() -> String {
        if let existingId = loadFromUserDefaults() {
            return existingId
        }
        // Generate and save new ID if none exists
        let newId = UUID().uuidString
        saveToUserDefaults(newId)
        return newId
    }

    private static func loadFromUserDefaults() -> String? {
        return UserDefaults.standard.string(forKey: deviceIDKey)
    }

    private static func saveToUserDefaults(_ id: String) {
        UserDefaults.standard.set(id, forKey: deviceIDKey)
    }
}
