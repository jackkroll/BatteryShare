//
//  Item.swift
//  BatteryShare
//
//  Created by Jack Kroll on 2/26/26.
//

import Foundation
import SwiftData

@Model
final class DeviceNickname {
    var deviceID: String?
    var nickname: String = ""
    @Relationship(inverse: \BatteryStatus.deviceNickname) var statuses: [BatteryStatus]? = []

    init(deviceID: String? = nil, nickname: String = "") {
        self.deviceID = deviceID
        self.nickname = nickname
    }
}

@Model
final class BatteryStatus {
    var deviceID: String?
    var deviceType: DeviceType?
    var timestamp: Date?
    var currentCharge: Int?
    var isCharging: Bool?
    var isLowPower: Bool?
    var estChargeTime: TimeInterval?
    var estDepleteTime: TimeInterval?
    @Relationship(deleteRule: .nullify) var deviceNickname: DeviceNickname?
    
    init(deviceType: DeviceType? = nil, currentCharge: Int? = nil, isCharging: Bool? = nil, isLowPower: Bool? = nil, estChargeTime: Double? = nil, estDepleteTime: Double? = nil) {
        self.deviceID = DeviceIdentityManager.getDeviceIdentifier()
        self.timestamp = .now
        self.deviceType = deviceType
        self.currentCharge = currentCharge
        self.isCharging = isCharging
        self.isLowPower = isLowPower
        self.estChargeTime = estChargeTime
        self.estDepleteTime = estDepleteTime
    }
    
    enum DeviceType: String, Codable {
        case mac, iphone, ipad
    }
}

struct DeviceBatteryStatus {
    var deviceNickname: String
    var status: BatteryStatus
    
    init(deviceNickname: String, status: BatteryStatus) {
        self.deviceNickname = deviceNickname
        self.status = status
    }
}
