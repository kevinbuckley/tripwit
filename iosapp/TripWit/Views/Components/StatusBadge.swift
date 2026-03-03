import SwiftUI
import TripCore

struct StatusBadge: View {

    let status: TripStatus

    private var label: String {
        switch status {
        case .planning: "Planning"
        case .active: "Active"
        case .completed: "Completed"
        }
    }

    private var color: Color {
        switch status {
        case .planning: .blue
        case .active: .green
        case .completed: .gray
        }
    }

    var body: some View {
        Text(label)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .accessibilityLabel("Trip status: \(label)")
    }
}

#Preview {
    HStack(spacing: 12) {
        StatusBadge(status: .planning)
        StatusBadge(status: .active)
        StatusBadge(status: .completed)
    }
    .padding()
}
