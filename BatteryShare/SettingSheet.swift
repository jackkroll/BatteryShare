//
//  SettingSheet.swift
//  BatteryShare
//
//  Created by Jack Kroll on 3/1/26.
//

import SwiftUI
import SwiftData
struct SettingSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @State var nickname: String = ""
    let batteryStatus: BatteryStatus
   
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nickname", text: $nickname)
                } header: {
                    Text("Device Name")
                }
            }
            .navigationTitle("Settings")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                Button(role: .close) {
                    dismiss()
                }
            }
            .onAppear {
                try? BatteryStore.ensureDeviceNickname(for: batteryStatus, in: modelContext)
                let nicknamesByDeviceID = (try? BatteryStore.fetchNicknamesByDeviceID(from: modelContext)) ?? [:]
                nickname = BatteryStore.deviceNickname(
                    for: batteryStatus,
                    nicknamesByDeviceID: nicknamesByDeviceID
                )
            }
            .onChange(of: nickname) {
                if batteryStatus.deviceNickname != nil {
                    batteryStatus.deviceNickname?.nickname = nickname
                    try? modelContext.save()
                }
                else {
                    batteryStatus.deviceNickname = DeviceNickname(deviceID: batteryStatus.deviceID, nickname: nickname)
                    try? modelContext.save()
                }
                
            }
        }
    }
}

#Preview {
    SettingSheet(batteryStatus: BatteryStatus(deviceType: .mac))
}
