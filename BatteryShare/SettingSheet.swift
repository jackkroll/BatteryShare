//
//  SettingSheet.swift
//  BatteryShare
//
//  Created by Jack Kroll on 3/1/26.
//

#if os(macOS)
#else
import SwiftUI
struct SettingSheet: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("macName") var macName: String = "My Mac"
   
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Mac Name", text: $macName)
                } header: {
                    Text("Device Name")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(role: .close) {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    SettingSheet()
}
#endif
