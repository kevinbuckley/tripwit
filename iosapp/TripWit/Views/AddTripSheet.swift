import SwiftUI
import CoreData
import MapKit
import TripCore

struct AddTripSheet: View {

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var notes = ""
    @State private var hasDates = true
    @State private var itineraryText = ""
    @State private var showItinerary = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !destination.trimmingCharacters(in: .whitespaces).isEmpty &&
        (!hasDates || endDate >= startDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip Name", text: $name)
                    TextField("Destination", text: $destination)
                } header: {
                    Text("Details")
                }

                Section {
                    Toggle("Set Dates", isOn: $hasDates)
                    if hasDates {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                } header: {
                    Text("Dates")
                } footer: {
                    if !hasDates {
                        Text("You can add dates later. A single planning day will be created.")
                    }
                }

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                }

                // MARK: - Paste Itinerary
                Section {
                    if showItinerary {
                        TextEditor(text: $itineraryText)
                            .frame(minHeight: 120)
                            .overlay(
                                Group {
                                    if itineraryText.isEmpty {
                                        Text("Paste your itinerary here...\ne.g. from ChatGPT, a blog, or a friend's message")
                                            .font(.subheadline)
                                            .foregroundStyle(.tertiary)
                                            .padding(.top, 8)
                                            .padding(.leading, 4)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )

                        Button {
                            if let clipboard = UIPasteboard.general.string, !clipboard.isEmpty {
                                itineraryText = clipboard
                            }
                        } label: {
                            Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                                .font(.subheadline)
                        }
                    } else {
                        Button {
                            withAnimation { showItinerary = true }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.on.clipboard.fill")
                                    .font(.body)
                                    .foregroundStyle(.purple)
                                    .frame(width: 28, height: 28)
                                    .background(Color.purple.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Paste Itinerary")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text("Import stops from ChatGPT, a blog, or any text")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    if showItinerary {
                        Text("Paste Itinerary")
                    }
                } footer: {
                    if showItinerary && !itineraryText.isEmpty {
                        Text("Stops will be automatically parsed and added after creating the trip.")
                    }
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Trip") {
                        createTrip()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }

    private func createTrip() {
        let manager = DataManager(context: viewContext)
        let trip = manager.createTrip(
            name: name.trimmingCharacters(in: .whitespaces),
            destination: destination.trimmingCharacters(in: .whitespaces),
            startDate: hasDates ? startDate : Date(),
            endDate: hasDates ? endDate : Date(),
            notes: notes.trimmingCharacters(in: .whitespaces)
        )
        trip.hasCustomDates = hasDates
        try? viewContext.save()

        // Parse and add itinerary stops if text was provided
        let trimmedItinerary = itineraryText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedItinerary.isEmpty {
            let parsedDays = ItineraryTextParser.parse(
                text: trimmedItinerary,
                totalDays: trip.durationInDays
            )
            let sortedDays = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }

            var stopsToGeocode: [(StopEntity, String)] = []

            for parsedDay in parsedDays {
                let dayNum = min(max(parsedDay.dayNumber, 1), sortedDays.count)
                guard dayNum > 0, dayNum <= sortedDays.count else { continue }
                let dayEntity = sortedDays[dayNum - 1]

                for parsedStop in parsedDay.stops {
                    let stop = manager.addStop(
                        to: dayEntity,
                        name: parsedStop.name,
                        latitude: 0,
                        longitude: 0,
                        category: parsedStop.category,
                        notes: parsedStop.note
                    )
                    let geocodeDest = dayEntity.wrappedLocation.isEmpty ? trip.wrappedDestination : dayEntity.wrappedLocation
                    stopsToGeocode.append((stop, geocodeDest))
                }
            }

            // Background geocoding
            if !stopsToGeocode.isEmpty {
                let context = viewContext
                Task {
                    let geocoder = CLGeocoder()
                    for (stop, dest) in stopsToGeocode {
                        let query = "\(stop.wrappedName), \(dest)"
                        do {
                            let placemarks = try await geocoder.geocodeAddressString(query)
                            if let location = placemarks.first?.location {
                                await MainActor.run {
                                    stop.latitude = location.coordinate.latitude
                                    stop.longitude = location.coordinate.longitude
                                    try? context.save()
                                }
                            }
                        } catch {
                            // Geocoding failed — leave at 0,0
                        }
                        try? await Task.sleep(for: .milliseconds(600))
                    }
                }
            }
        }

        dismiss()
    }
}
