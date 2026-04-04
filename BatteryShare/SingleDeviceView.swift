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
    let deviceStatus: BatteryStatus
    let deviceNickname: String
    @State var showDeviceID: Bool = false
    @State var editSheetIsPresented: Bool = false
    var body: some View {
        VStack {
            Group {
                HStack {
                    Text(deviceNickname)
                        .font(.title)
                        .fontWeight(.bold)
                        .onTapGesture {
                            withAnimation {
                                showDeviceID.toggle()
                            }
                        }
                    Spacer()
                    Button {
                        withAnimation {
                            editSheetIsPresented = true
                        }
                    } label: {
                        Image(systemName: "pencil")
                            .padding(5)
                    }
                    .buttonBorderShape(.circle)
                    .buttonStyle(.glass)
                    .sheet(isPresented: $editSheetIsPresented) {
                        SettingSheet(batteryStatus: deviceStatus)
                            .presentationDetents([.fraction(1/3)])
                    }
                }
                .padding(.top, 8)
                if showDeviceID {
                    VStack {
                        HStack {
                            Text(deviceStatus.deviceID ?? "ID")
                                
                            Spacer()
                        }
                        HStack {
                            Text(deviceStatus.deviceType?.rawValue ?? "Device")
                        }
                    }
                    .fontDesign(.monospaced)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            if let timestamp = deviceStatus.timestamp {
                HStack {
                    HStack {
                        Text("Last Synced:")
                            .lineLimit(1)
                        Text(timestamp, style: .time)
                            .contentTransition(.numericText())
                    }
                    .padding(10)
                    .glassEffect()
                    
                    HStack {
                        Image(systemName: deviceStatus.isCharging ?? false ? "bolt.fill" : "battery.100percent")
                        Text(deviceStatus.isCharging ?? false ? "Charging" : "On Battery")
                    }
                    .shimmering(active: deviceStatus.isCharging ?? false)
                    .brightness(deviceStatus.isCharging ?? false && colorScheme == .dark ? 1.2 : 0)
                    .padding(10)
                    .glassEffect()
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)
            }
            if let lastCharge = deviceStatus.currentCharge {
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
            if let timeUntilEmpty = deviceStatus.estDepleteTime,
               let timeUntilCharge = deviceStatus.estChargeTime {
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
    @Previewable @State var status = BatteryStatus(
        deviceType: .mac,
        currentCharge: 90,
        isCharging: false,
        isLowPower: true,
        estChargeTime: 30 * 60,
        estDepleteTime: 0
    )
    SingleDeviceView(
        deviceStatus: status,
        deviceNickname: BatteryStore.defaultDeviceNickname(for: status.deviceType)
    )
}
