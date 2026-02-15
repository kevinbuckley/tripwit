import SwiftUI
import SwiftData

struct WelcomeView: View {

    @Environment(\.modelContext) private var modelContext
    @Binding var hasCompletedOnboarding: Bool
    @State private var showingAddTrip = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)
                }

                Text("Trav")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Plan trips, track your itinerary,\nand never miss a stop.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Actions
            VStack(spacing: 12) {
                Button {
                    showingAddTrip = true
                } label: {
                    Label("Create Your First Trip", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button {
                    loadExamples()
                } label: {
                    Label("Load Example Trips", systemImage: "tray.and.arrow.down")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showingAddTrip) {
            AddTripSheet()
        }
        .onChange(of: showingAddTrip) { _, isShowing in
            // When AddTripSheet is dismissed (not cancelled), transition to main app
            if !isShowing {
                // Check if a trip was actually created
                let descriptor = FetchDescriptor<TripEntity>()
                let count = (try? modelContext.fetchCount(descriptor)) ?? 0
                if count > 0 {
                    withAnimation {
                        hasCompletedOnboarding = true
                    }
                }
            }
        }
    }

    private func loadExamples() {
        let manager = DataManager(modelContext: modelContext)
        manager.loadSampleDataIfEmpty()
        withAnimation {
            hasCompletedOnboarding = true
        }
    }
}
