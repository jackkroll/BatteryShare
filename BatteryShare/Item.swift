//
//  Item.swift
//  BatteryShare
//
//  Created by Jack Kroll on 2/26/26.
//

import Foundation
import SwiftData

@Model
final class BatteryStatus {
    var deviceType: DeviceType?
    var timestamp: Date?
    var currentCharge: Int?
    var isCharging: Bool?
    var isLowPower: Bool?
    var estChargeTime: TimeInterval?
    var estDepleteTime: TimeInterval?
    
    init(deviceType: DeviceType? = nil, currentCharge: Int? = nil, isCharging: Bool? = nil, isLowPower: Bool? = nil, estChargeTime: Double? = nil, estDepleteTime: Double? = nil) {
        self.timestamp = .now
        self.deviceType = deviceType
        self.currentCharge = currentCharge
        self.isCharging = isCharging
        self.isLowPower = isLowPower
        self.estChargeTime = estChargeTime
        self.estDepleteTime = estDepleteTime
    }
    
    enum DeviceType: String, Codable {
        case mac, iphone
    }
}
