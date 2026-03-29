//
//  BatteryShareWidgets.swift
//  BatteryShareWidgets
//
//  Created by Codex on 3/22/26.
//

import SwiftUI
import SwiftData
import WidgetKit

private enum BatteryWidgetRefreshSchedule {
    static let interval: TimeInterval = 15 * 60
}

struct BatteryStatusEntry: TimelineEntry {
    enum State {
        case loaded
        case empty
        case unavailable
    }

    let date: Date
    let devices: [BatteryDeviceSnapshot]
    let state: State

    var primaryDevice: BatteryDeviceSnapshot? {
        devices.first
    }
}

struct BatteryStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryStatusEntry {
        BatteryStatusEntry(
            date: .now,
            devices: BatteryWidgetPreviewData.devices,
            state: .loaded
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BatteryStatusEntry) -> Void) {
        completion(loadEntry(usePreviewData: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryStatusEntry>) -> Void) {
        let entry = loadEntry()
        let refreshDate = Date.now.addingTimeInterval(BatteryWidgetRefreshSchedule.interval)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func loadEntry(usePreviewData: Bool = false) -> BatteryStatusEntry {
        if usePreviewData {
            return BatteryStatusEntry(
                date: .now,
                devices: BatteryWidgetPreviewData.devices,
                state: .loaded
            )
        }

        do {
            let container = try BatteryStoreConfiguration.makeSharedModelContainer()
            let devices = try BatteryStore.fetchLatestSnapshots(from: container.mainContext, limit: 4)
            let state: BatteryStatusEntry.State = devices.isEmpty ? .empty : .loaded
            return BatteryStatusEntry(date: .now, devices: devices, state: state)
        } catch {
            return BatteryStatusEntry(date: .now, devices: [], state: .unavailable)
        }
    }
}

@main
struct BatteryShareWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LatestBatteryWidget()
        BatteryOverviewWidget()
    }
}

struct LatestBatteryWidget: Widget {
    private let kind = "BatteryShareLatestBatteryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BatteryStatusProvider()) { entry in
            LatestBatteryWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Latest Battery")
        .description("Shows the newest battery reading synced through BatteryShare.")
        .supportedFamilies([
            .systemSmall,
            .accessoryInline,
            .accessoryRectangular,
            .accessoryCircular,
        ])
    }
}

struct BatteryOverviewWidget: Widget {
    private let kind = "BatteryShareOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BatteryStatusProvider()) { entry in
            BatteryOverviewWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Battery Overview")
        .description("Shows the most recent battery levels for your devices.")
        .supportedFamilies([
            .systemMedium,
        ])
    }
}

private struct LatestBatteryWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: BatteryStatusEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallBody
            case .accessoryRectangular:
                rectangularBody
            case .accessoryCircular:
                circularBody
            case .accessoryInline:
                inlineBody
            default:
                smallBody
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var smallBody: some View {
        if let device = entry.primaryDevice {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Label(device.deviceNickname, systemImage: symbolName(for: device))
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if family == .systemLarge {
                        statusLabel(for: device)
                            .frame(maxWidth: 30)
                    }
                    
                }
                if family == .systemLarge {
                    Spacer()
                }
                HStack(alignment: .bottom){
                    Text(chargeText(for: device))
                        .font(.system(size: 144, weight: .bold, design: .rounded))
                        .foregroundStyle(chargeColor(for: device))
                        .minimumScaleFactor(0.05)
                    Spacer()
                    if family == .systemMedium {
                        statusLabel(for: device)
                            .frame(maxWidth: 50)
                    }
                    
                }
                if family == .systemLarge {
                    Spacer()
                }
                Gauge(value: Double(device.currentCharge ?? 0), in: 0...100) {
                    EmptyView()
                }
                .gaugeStyle(.linearCapacity)
                .tint(LinearGradient(colors: [.red, .yellow, .green], startPoint: .leading, endPoint: .trailing))

                Text(detailLine(for: device))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            unavailableState
        }
    }

    @ViewBuilder
    private var rectangularBody: some View {
        if let device = entry.primaryDevice {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(device.deviceNickname, systemImage: symbolName(for: device))
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                }

                Gauge(value: Double(device.currentCharge ?? 0), in: 0...100) {
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(LinearGradient(colors: [.red, .yellow, .green], startPoint: .leading, endPoint: .trailing))
                HStack {
                    Text(chargeText(for: device))
                    Text(detailShort(for: device))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                .font(.caption)
            }
        } else {
            unavailableState
        }
    }

    @ViewBuilder
    private var circularBody: some View {
        if let device = entry.primaryDevice, let currentCharge = device.currentCharge {
            Gauge(value: Double(currentCharge), in: 0...100) {
                Image(systemName: symbolName(for: device))
                    .padding(5)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(chargeColor(for: device))
        } else {
            Image(systemName: "icloud.slash")
        }
    }

    @ViewBuilder
    private var inlineBody: some View {
        if let device = entry.primaryDevice {
            Text("\(device.deviceNickname) \(chargeText(for: device))")
        } else {
            Text(emptyMessage)
        }
    }

    @ViewBuilder
    private var unavailableState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: entry.state == .unavailable ? "icloud.slash" : "bolt.badge.clock")
                .font(.title2)
            Text(emptyTitle)
                .font(.headline)
            Text(emptyMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var emptyTitle: String {
        switch entry.state {
        case .loaded:
            return "BatteryShare"
        case .empty:
            return "No Batteries Yet"
        case .unavailable:
            return "Sync Unavailable"
        }
    }

    private var emptyMessage: String {
        switch entry.state {
        case .loaded:
            return "BatteryShare"
        case .empty:
            return "Open the app to finish your first sync."
        case .unavailable:
            return "The shared SwiftData store could not be loaded."
        }
    }

    @ViewBuilder
    private func statusLabel(for device: BatteryDeviceSnapshot) -> some View {
        if device.isCharging {
            Image(systemName: "bolt.fill")
                .resizable()
                .foregroundStyle(.yellow)
                .scaledToFit()
                .padding(5)
            
        } else if device.isLowPower {
            Image(systemName: "leaf.fill")
                .foregroundStyle(.green)
        } else {
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        }
    }
}

private struct BatteryOverviewWidgetEntryView: View {
    let entry: BatteryStatusEntry
    @Environment(\.widgetFamily) var family
    var body: some View {
        Group {
            if entry.devices.isEmpty {
                emptyBody
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(entry.devices.prefix(3)) { device in
                        HStack(spacing: 10) {
                            if family != .systemSmall {
                                Image(systemName: symbolName(for: device))
                                    .foregroundStyle(chargeColor(for: device))
                                    .frame(width:20, height: 20)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.deviceNickname)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                if family != .systemSmall {
                                    Text(detailLine(for: device))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Text(chargeText(for: device))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(chargeColor(for: device))
                        }
                        .fontDesign(.rounded)
                    }
                    if family == .systemLarge {
                        Spacer()
                    }
                    if family != .systemSmall {
                        HStack {
                            if let timestamp = entry.primaryDevice?.timestamp {
                                Group {
                                    Text("Last Synced:")
                                    Text(timestamp, style: .relative)
                                    Spacer()
                                }
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.state == .unavailable ? "Sync Unavailable" : "No Synced Batteries")
                .font(.headline)
            Text(entry.state == .unavailable ? "BatteryShare could not open the shared store." : "Keep the BatteryShare app installed on your Mac and iPhone to populate this widget.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private enum BatteryWidgetPreviewData {
    static let devices: [BatteryDeviceSnapshot] = [
        BatteryDeviceSnapshot(
            id: "preview-mac",
            deviceNickname: "My Mac",
            deviceType: .mac,
            timestamp: .now.addingTimeInterval(-120),
            currentCharge: 72,
            isCharging: true,
            isLowPower: false,
            estChargeTime: 45 * 60,
            estDepleteTime: nil
        ),
        BatteryDeviceSnapshot(
            id: "preview-phone",
            deviceNickname: "My iPhone",
            deviceType: .iphone,
            timestamp: .now.addingTimeInterval(-300),
            currentCharge: 38,
            isCharging: false,
            isLowPower: true,
            estChargeTime: nil,
            estDepleteTime: 2 * 60 * 60
        ),
        BatteryDeviceSnapshot(
            id: "preview-ipad",
            deviceNickname: "My iPad",
            deviceType: .ipad,
            timestamp: .now.addingTimeInterval(-480),
            currentCharge: 91,
            isCharging: false,
            isLowPower: false,
            estChargeTime: nil,
            estDepleteTime: 6 * 60 * 60
        ),
    ]
}

private func symbolName(for device: BatteryDeviceSnapshot) -> String {
    switch device.deviceType {
    case .mac:
        return "laptopcomputer"
    case .iphone:
        return "iphone"
    case .ipad:
        return "ipad"
    case nil:
        return "bolt.batteryblock"
    }
}

private func chargeText(for device: BatteryDeviceSnapshot) -> String {
    guard let currentCharge = device.currentCharge else {
        return "--"
    }

    return "\(currentCharge)%"
}

private func chargeColor(for device: BatteryDeviceSnapshot) -> Color {
    guard let currentCharge = device.currentCharge else {
        return .secondary
    }
    return Color.red.mix(with: .green, by: Double(currentCharge)/85)
    
}

private func detailLine(for device: BatteryDeviceSnapshot) -> String {
    if device.isCharging {
        if let estChargeTime = device.estChargeTime, estChargeTime > 0 {
            return "Charging, full in \(relativeDurationText(for: estChargeTime))"
        }

        return "Charging now"
    }

    if let estDepleteTime = device.estDepleteTime, estDepleteTime > 0 {
        return "On battery, empty in \(relativeDurationText(for: estDepleteTime))"
    }

    if device.isLowPower {
        return "Low Power Mode"
    }

    if let timestamp = device.timestamp {
        return "Updated \(timestamp.formatted(.relative(presentation: .named)))"
    }

    return "Waiting for a fresh sync"
}

private func detailShort(for device: BatteryDeviceSnapshot) -> String {
    if device.isCharging {
        return "Charging"
    }
    if device.isLowPower {
        return "Battery Saver"
    }
    if let timestamp = device.timestamp {
        return "Updated \(timestamp.formatted(.relative(presentation: .named)))"
    }
    else {
        return "Waiting for sync"
    }
}

private func relativeDurationText(for interval: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute]
    formatter.unitsStyle = .abbreviated
    formatter.maximumUnitCount = 2
    return formatter.string(from: interval) ?? "soon"
}

#Preview("Latest Small", as: .systemSmall) {
    LatestBatteryWidget()
} timeline: {
    BatteryStatusEntry(date: .now, devices: BatteryWidgetPreviewData.devices, state: .loaded)
}

#Preview("Overview Medium", as: .systemMedium) {
    BatteryOverviewWidget()
} timeline: {
    BatteryStatusEntry(date: .now, devices: BatteryWidgetPreviewData.devices, state: .loaded)
}
