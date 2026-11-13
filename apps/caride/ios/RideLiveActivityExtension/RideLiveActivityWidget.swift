import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct RideLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideActivityAttributes.self) { context in
            // Lock Screen / Notification Center Trip Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("CaRide", systemImage: "car.fill")
                        .font(.caption.bold())
                        .foregroundColor(Color(red: 0.04, green: 0.53, blue: 0.33))
                    Spacer()
                    Text("\(context.state.etaMinutes) min")
                        .font(.headline.bold())
                        .foregroundColor(.primary)
                }

                Text(context.state.status)
                    .font(.subheadline.bold())

                Text("\(context.attributes.driverName) • \(context.attributes.vehicleInfo)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(context.attributes.pickup) → \(context.attributes.dropoff)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(14)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "car.fill")
                        .foregroundColor(Color(red: 0.04, green: 0.53, blue: 0.33))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.etaMinutes)m")
                        .font(.headline.bold())
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.status)
                        .font(.caption.bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.driverName) • \(context.attributes.vehicleInfo)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } compactLeading: {
                Image(systemName: "car.fill")
                    .foregroundColor(Color(red: 0.04, green: 0.53, blue: 0.33))
            } compactTrailing: {
                Text("\(context.state.etaMinutes)m")
                    .font(.caption.bold())
            } minimal: {
                Image(systemName: "car.fill")
                    .foregroundColor(Color(red: 0.04, green: 0.53, blue: 0.33))
            }
        }
    }
}

