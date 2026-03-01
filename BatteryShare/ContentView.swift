//
//  ContentView.swift
//  BatteryShare
//
//  Created by Jack Kroll on 2/26/26.
//

import SwiftUI
import SwiftData
import Shimmer

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var recentStatus: [BatteryStatus]
    @State var lastStatus : BatteryStatus?
    var body: some View {
        NavigationStack {
            VStack {
                if recentStatus.isEmpty {
                    Text("No battery status available")
                } else {
                    if lastStatus != nil {
                        /*
                        HStack {
                            if let lastCharge = lastStatus.currentCharge {
                                Gauge(value: Float(lastCharge)/100) {
                                    Image(systemName: "macbook")
                                        .resizable()
                                        .scaledToFit()
                                        .padding(2)
                                }
                                .gaugeStyle(.accessoryCircularCapacity)
                                
                            }
                        }
                         */
                        
                        if let timestamp = lastStatus?.timestamp {
                            HStack {
                                HStack {
                                    Text("Last Synced:")
                                    Text(timestamp, style: .time)
                                        .contentTransition(.numericText())
                                }
                                
                                .padding(10)
                                .glassEffect()
                                
                                HStack {
                                    Image(systemName: lastStatus?.isCharging ?? false ? "bolt.fill" : "battery.100percent")
                                    Text(lastStatus?.isCharging ?? false ? "Charging" : "On Battery")
                                }
                                .shimmering(active: lastStatus?.isCharging ?? false)
                                .brightness(lastStatus?.isCharging ?? false ? 1.2 : 0)
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
            .navigationTitle("My Mac")
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
        }
    }
}
/*
#Preview {
    ContentView()
        .modelContainer(for: BatteryStatus.self, inMemory: true)
}
 */
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

