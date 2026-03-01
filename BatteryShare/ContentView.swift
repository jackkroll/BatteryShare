//
//  ContentView.swift
//  BatteryShare
//
//  Created by Jack Kroll on 2/26/26.
//
#if os(macOS)
#else
import SwiftUI
import SwiftData
import Shimmer
import iCloudSyncStatusKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("macName") var macName: String = "My Mac"
    @Query private var recentStatus: [BatteryStatus]
    @State var lastStatus : BatteryStatus?
    @State var displaySettings: Bool = false
    @State var quotaExceeded: Bool = false
    @State private var syncManager = SyncStatusAsyncManager(
        cloudKitContainerID: "iCloud.com.JackKroll.BatteryShare",
    )
    
    var body: some View {
        NavigationStack {
            VStack {
                if recentStatus.isEmpty {
                    VStack {
                        Text("Battery status never synced")
                            .font(.title3)
                            .bold()
                        if !syncManager.isAccountAvailable && !syncManager.isCloudDriveAvailable {
                            Text("Please sign into iCloud on your device in Settings")
                        }
                        if syncManager.isAccountAvailable && !syncManager.isCloudDriveAvailable {
                            Text("Please enable iCloud Drive in Settings")
                        }
                        if syncManager.isAccountAvailable && syncManager.isCloudDriveAvailable {
                            Text("Install BatteryShare on your Mac to sync battery status")
                        }
                    }
                } else {
                    if lastStatus != nil {
                        if let timestamp = lastStatus?.timestamp {
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
                                    Image(systemName: lastStatus?.isCharging ?? false ? "bolt.fill" : "battery.100percent")
                                    Text(lastStatus?.isCharging ?? false ? "Charging" : "On Battery")
                                }
                                .shimmering(active: lastStatus?.isCharging ?? false)
                                .brightness(lastStatus?.isCharging ?? false && colorScheme == .dark ? 1.2 : 0)
                                .padding(10)
                                .glassEffect()
                                
                                Spacer()
                            }
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.secondary)
                        }
                        if let lastCharge = lastStatus?.currentCharge {
                            HStack {
                            Text("\(lastCharge)%")
                                .fontDesign(.monospaced)
                                .bold()
                                .font(.system(size: 144))
                                .scaledToFit()
                                .minimumScaleFactor(0.01)
                                .foregroundStyle(.red.mix(with: .green, by: Double(lastCharge)/85))
                                .allowsTightening(true)
                                .shimmering(active: false)
                                .frame(maxWidth: .infinity)
                                .contentTransition(.numericText())

                                Gauge(value: Float(lastCharge)/100) {
                                }
                                .gaugeStyle(VerticalAccessoryGaugeStyle())
                                .padding(.vertical)
                                .tint(Gradient(colors: [.red, .yellow, .green]))
                            }
                            .frame(maxHeight: 144)
                        }
                        if let timeUntilEmpty = lastStatus?.estDepleteTime, let timeUntilCharge = lastStatus?.estChargeTime {
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
                    Spacer()
                }
            }
            .padding(.horizontal)
            .navigationTitle(macName)
            .onAppear {
                withAnimation {
                    lastStatus = recentStatus.sorted { (a, b) in
                        (a.timestamp ?? .distantPast) > (b.timestamp ?? .distantPast)
                        }.first
                }
            }
            .onChange(of: recentStatus){
                withAnimation {
                    lastStatus = recentStatus.sorted { (a, b) in
                        (a.timestamp ?? .distantPast) > (b.timestamp ?? .distantPast)
                        }.first
                }
            }
            .sheet(isPresented: $displaySettings) {
                SettingSheet()
                    .presentationDetents([.fraction(1/4)])
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        withAnimation {
                            displaySettings = true
                        }
                    } label: {
                        Image(systemName: "gear")
                    }
                    
                }
                ToolbarSpacer(placement: .bottomBar)
            }
        }
        
        
       
    }
    func quotaExceededNotice() -> Void {
        quotaExceeded = true
    }
}

#Preview {
    ContentView()
        .modelContainer(for: BatteryStatus.self, inMemory: true)
}
 
#Preview("With Example Battery Status") {
    do {
        let container = try ModelContainer(
            for: BatteryStatus.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        // Create a sample status (100% so that percent formatting looks correct for Int)
        let sample = BatteryStatus(
            deviceType: .iphone,
            currentCharge: 30,
            isCharging: true,
            isLowPower: false,
            estChargeTime: 30 * 60,
            estDepleteTime: 0
        )
        sample.timestamp = .now.addingTimeInterval(-5 * 60) // 5 minutes ago

        container.mainContext.insert(sample)
        return ContentView().modelContainer(container)
    } catch {
        // Fallback empty preview if the container fails to create
        return ContentView()
            .modelContainer(for: BatteryStatus.self, inMemory: true)
    }
}

#endif

