import SwiftUI
import CoreData
import MapKit
import TripCore

struct TimelineStopRow: View {

    @Environment(\.managedObjectContext) private var viewContext

    let stop: StopEntity
    let isFirst: Bool
    let isLast: Bool
    let isNextUpcoming: Bool
    let isPast: Bool

    private var categoryColor: Color {
        switch stop.category {
        case .accommodation: .purple
        case .restaurant: .orange
        case .attraction: .yellow
        case .transport: .blue
        case .activity: .green
        case .other: .gray
        }
    }

    private var categoryIcon: String {
        switch stop.category {
        case .accommodation: "bed.double.fill"
        case .restaurant: "fork.knife"
        case .attraction: "star.fill"
        case .transport: "airplane"
        case .activity: "figure.run"
        case .other: "mappin"
        }
    }

    private var categoryLabel: String {
        switch stop.category {
        case .accommodation: "Accommodation"
        case .restaurant: "Restaurant"
        case .attraction: "Attraction"
        case .transport: "Transport"
        case .activity: "Activity"
        case .other: "Other"
        }
    }

    private var timeText: String {
        guard let arrival = stop.arrivalTime else { return "\u{2014}" }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: arrival)
    }

    private var rowOpacity: Double {
        isPast && !isNextUpcoming ? 0.55 : 1.0
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timelineColumn
            stopInfoColumn
            Spacer(minLength: 4)
            visitedToggleButton
            directionsButton
        }
        .padding(.vertical, 6)
        .opacity(rowOpacity)
    }

    // MARK: - Timeline Column

    private var timelineColumn: some View {
        VStack(spacing: 0) {
            topLine
            dot
            bottomLine
        }
        .frame(width: 20)
    }

    private var topLine: some View {
        Rectangle()
            .fill(isFirst ? Color.clear : categoryColor.opacity(0.4))
            .frame(width: 2, height: 10)
    }

    private var dot: some View {
        ZStack {
            if isNextUpcoming {
                Circle()
                    .fill(categoryColor.opacity(0.25))
                    .frame(width: 20, height: 20)
            }
            Circle()
                .fill(categoryColor)
                .frame(width: 10, height: 10)
        }
        .frame(width: 20, height: 20)
    }

    private var bottomLine: some View {
        Rectangle()
            .fill(isLast ? Color.clear : categoryColor.opacity(0.4))
            .frame(width: 2)
            .frame(maxHeight: .infinity)
    }

    // MARK: - Stop Info Column

    private var stopInfoColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            timeLabel
            nameLabel
            categoryTag
        }
    }

    private var timeLabel: some View {
        Text(timeText)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
    }

    private var nameLabel: some View {
        Text(stop.wrappedName)
            .font(.subheadline)
            .fontWeight(isNextUpcoming ? .bold : .semibold)
            .foregroundStyle(isNextUpcoming ? categoryColor : .primary)
            .lineLimit(1)
    }

    private var categoryTag: some View {
        HStack(spacing: 4) {
            Image(systemName: categoryIcon)
                .font(.caption2)
            Text(categoryLabel)
                .font(.caption2)
        }
        .foregroundStyle(categoryColor)
    }

    // MARK: - Directions Button

    private var directionsButton: some View {
        Button {
            openDirections()
        } label: {
            Image(systemName: "arrow.triangle.turn.up.right.diamond")
                .font(.caption)
                .foregroundStyle(.blue)
                .padding(6)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.top, 14)
    }

    // MARK: - Visited Toggle

    private var visitedToggleButton: some View {
        Button {
            toggleVisited()
        } label: {
            visitedToggleIcon
        }
        .buttonStyle(.plain)
        .padding(.top, 14)
    }

    private var visitedToggleIcon: some View {
        Group {
            if stop.isVisited {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(6)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Circle())
            } else {
                Image(systemName: "circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    private func toggleVisited() {
        stop.isVisited.toggle()
        stop.visitedAt = stop.isVisited ? Date() : nil
        stop.day?.trip?.updatedAt = Date()
        try? viewContext.save()
    }

    // MARK: - Actions

    private func openDirections() {
        let coordinate = CLLocationCoordinate2D(
            latitude: stop.latitude,
            longitude: stop.longitude
        )
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = stop.wrappedName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}
