//
//  SingleDeviceView.swift
//  BatteryShare
//
//  Created by Jack Kroll on 3/7/26.
//

import SwiftUI
import iCloudSyncStatusKit
import Shimmer

struct SingleDeviceView: View {
    @Environment(\.colorScheme) var colorScheme
    @State var syncManager: SyncStatusAsyncManager
    @State var deviceStatus: DeviceBatteryStatus
    @State var showDeviceID: Bool = false
    var body: some View {
        VStack {
            Group {
                HStack {
                    Text(deviceStatus.deviceNickname)
                        .font(.title)
                        .fontWeight(.bold)
                        .onTapGesture {
                            withAnimation {
                                showDeviceID.toggle()
                            }
                        }
                    Spacer()
                }
                .padding(.top, 8)
                if showDeviceID {
                    HStack {
                        Text(deviceStatus.status.deviceID ?? "ID")
                            .fontDesign(.monospaced)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 8)
            if let timestamp = deviceStatus.status.timestamp {
                if timestamp.distance(to: .now) > 10 * 60 && !syncManager.isSyncing{
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20)
                            .symbolRenderingMode(.multicolor)
                        if syncManager.environmentStatus.isSyncReady {
                            Text("Sync was a while ago, is BatteryShare running on your Mac?")
                        }
                    }
                    .font(.caption)
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .glassEffect()
                }
                HStack {
                    HStack {
                        if syncManager.isSyncing {
                            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.icloud.fill")
                            Text("Syncing...")
                        }
                        else {
                            Text("Last Synced:")
                            Text(timestamp, style: .time)
                                .contentTransition(.numericText())
                        }
                    }
                    
                    .padding(10)
                    .glassEffect()
                    
                    HStack {
                        Image(systemName: deviceStatus.status.isCharging ?? false ? "bolt.fill" : "battery.100percent")
                        Text(deviceStatus.status.isCharging ?? false ? "Charging" : "On Battery")
                    }
                    .shimmering(active: deviceStatus.status.isCharging ?? false)
                    .brightness(deviceStatus.status.isCharging ?? false && colorScheme == .dark ? 1.2 : 0)
                    .padding(10)
                    .glassEffect()
                    
                    Spacer()
                }
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)
            }
            if let lastCharge = deviceStatus.status.currentCharge {
                HStack {
                    Text("\(lastCharge)%")
                        .fontDesign(.monospaced)
                        .bold()
                        .font(.system(size: 144))
                        .scaledToFit()
                        .minimumScaleFactor(0.01)
                        .foregroundStyle(.red.mix(with: .green, by: Double(lastCharge)/85))
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity)
                        .contentTransition(.numericText())
                        .shadow(color: .red.mix(with: .green, by: Double(lastCharge)/85), radius: 3)
                    
                    Gauge(value: Float(lastCharge)/100) {
                    }
                    .gaugeStyle(VerticalAccessoryGaugeStyle())
                    .padding(.vertical)
                    .tint(Gradient(colors: [.red, .yellow, .green]))
                }
                .frame(maxHeight: 144)
            }
            if let timeUntilEmpty = deviceStatus.status.estDepleteTime,
               let timeUntilCharge = deviceStatus.status.estChargeTime {
                Group {
                    if timeUntilCharge > 0 {
                        VStack {
                            Text(Date.now.advanced(by: timeUntilCharge), style: .relative)
                                .font(.title)
                                .bold()
                            Text("until fully charged")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if timeUntilEmpty > 0 {
                        VStack {
                            Text(Date.now.advanced(by: timeUntilEmpty), style: .relative)
                                .font(.title)
                                .bold()
                            Text("until empty")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 50)
                .foregroundStyle(Material.ultraThin)
        }
        .padding()
    }
    
}

#Preview {
    @Previewable @State var status = DeviceBatteryStatus(deviceNickname: "My Macbook Pro", status: BatteryStatus(
        deviceType: .iphone,
        currentCharge: 90,
        isCharging: true,
        isLowPower: false,
        estChargeTime: 30 * 60,
        estDepleteTime: 0
    ))
    @Previewable @State var sync = SyncStatusAsyncManager(cloudKitContainerID: "iCloud.JackKroll.BatteryShare.2")
    SingleDeviceView(syncManager: sync, deviceStatus: status)
}
