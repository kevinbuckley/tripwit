import SwiftUI
import TripCore

struct CategoryPicker: View {

    @Binding var selection: StopCategory

    var body: some View {
        Picker("Category", selection: $selection) {
            ForEach(StopCategory.allCases, id: \.self) { category in
                Label(label(for: category), systemImage: iconName(for: category))
                    .tag(category)
            }
        }
        .pickerStyle(.menu)
    }

    private func label(for category: StopCategory) -> String {
        switch category {
        case .accommodation: "Accommodation"
        case .restaurant: "Restaurant"
        case .attraction: "Attraction"
        case .transport: "Transport"
        case .activity: "Activity"
        case .other: "Other"
        }
    }

    private func iconName(for category: StopCategory) -> String {
        switch category {
        case .accommodation: "bed.double.fill"
        case .restaurant: "fork.knife"
        case .attraction: "star.fill"
        case .transport: "airplane"
        case .activity: "figure.run"
        case .other: "mappin"
        }
    }
}
