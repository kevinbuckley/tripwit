import SwiftUI
import SwiftData

@main
struct TravlyApp: App {

    let modelContainer: ModelContainer?
    @State private var locationManager = LocationManager()
    private let containerError: String?

    init() {
        do {
            let schema = Schema([TripEntity.self, DayEntity.self, StopEntity.self, CommentEntity.self, BookingEntity.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            containerError = nil
        } catch {
            modelContainer = nil
            containerError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                ContentView()
                    .environment(locationManager)
                    .modelContainer(modelContainer)
            } else {
                dataErrorView
            }
        }
    }

    private var dataErrorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Unable to Load Data")
                .font(.title2)
                .fontWeight(.bold)
            Text("Travly couldn't open its database. Try restarting the app. If the problem persists, reinstalling may help.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if let containerError {
                Text(containerError)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 32)
            }
        }
        .padding()
    }
}
