import SwiftUI
import CoreData
import TripCore

struct EditTripSheet: View {

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let trip: TripEntity

    @State private var name: String
    @State private var destination: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var notes: String
    @State private var showingDateChangeWarning = false
    @State private var dateChangeWarningMessage = ""
    @State private var budgetText: String
    @State private var budgetCurrency: String
    @State private var showingPasteItinerary = false

    private static let currencyOptions = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "MXN", "CNY", "KRW", "THB", "INR", "BRL"]

    init(trip: TripEntity) {
        self.trip = trip
        _name = State(initialValue: trip.name ?? "")
        _destination = State(initialValue: trip.destination ?? "")
        _startDate = State(initialValue: trip.startDate ?? Date())
        _endDate = State(initialValue: trip.endDate ?? Date())
        _notes = State(initialValue: trip.notes ?? "")
        _budgetText = State(initialValue: trip.budgetAmount > 0 ? String(format: "%.0f", trip.budgetAmount) : "")
        _budgetCurrency = State(initialValue: trip.budgetCurrencyCode ?? "USD")
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !destination.trimmingCharacters(in: .whitespaces).isEmpty &&
        endDate >= startDate
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
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                } header: {
                    Text("Dates")
                }

                Section {
                    HStack {
                        Text(currencySymbol)
                            .foregroundStyle(.secondary)
                        TextField("No budget", text: $budgetText)
                            .keyboardType(.decimalPad)
                    }
                    Picker("Currency", selection: $budgetCurrency) {
                        ForEach(Self.currencyOptions, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Budget")
                } footer: {
                    Text("Leave blank for no budget. Expenses are tracked in the trip detail.")
                }

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                }

                Section {
                    Button {
                        showingPasteItinerary = true
                    } label: {
                        Label("Paste Itinerary", systemImage: "doc.on.clipboard")
                            .foregroundStyle(.purple)
                    }
                } footer: {
                    Text("Import stops from ChatGPT, a blog, or any text.")
                }
            }
            .sheet(isPresented: $showingPasteItinerary) {
                PasteItinerarySheet(trip: trip)
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        attemptSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .alert("Change Trip Dates?", isPresented: $showingDateChangeWarning) {
                Button("Change Dates", role: .destructive) {
                    saveChanges(syncDays: true)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(dateChangeWarningMessage)
            }
        }
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = budgetCurrency
        return formatter.currencySymbol ?? "$"
    }

    private func attemptSave() {
        let datesChanged = trip.wrappedStartDate != startDate || trip.wrappedEndDate != endDate

        if datesChanged {
            let manager = DataManager(context: viewContext)
            let lostDays = manager.daysWithStopsOutsideRange(for: trip, newStart: startDate, newEnd: endDate)

            if lostDays > 0 {
                // Some days with stops will be removed — warn the user
                let dayWord = lostDays == 1 ? "day" : "days"
                dateChangeWarningMessage = "\(lostDays) \(dayWord) with stops will be removed (outside the new date range). Days within the new range will keep their stops."
                showingDateChangeWarning = true
            } else {
                // No data loss — sync silently
                saveChanges(syncDays: true)
            }
        } else {
            saveChanges(syncDays: false)
        }
    }

    private func saveChanges(syncDays: Bool) {
        let manager = DataManager(context: viewContext)
        let oldDestination = trip.destination ?? ""
        let newDestination = destination.trimmingCharacters(in: .whitespaces)

        trip.name = name.trimmingCharacters(in: .whitespaces)
        trip.destination = newDestination
        trip.startDate = startDate
        trip.endDate = endDate
        trip.notes = notes.trimmingCharacters(in: .whitespaces)
        trip.budgetAmount = Double(budgetText) ?? 0
        trip.budgetCurrencyCode = budgetCurrency

        // Update day locations that still match the old destination to the new one.
        // Custom per-day locations (e.g. multi-city trips) are left alone.
        if !oldDestination.isEmpty && oldDestination != newDestination {
            for day in trip.daysArray where day.location == oldDestination {
                day.location = newDestination
            }
        }

        if syncDays {
            manager.syncDays(for: trip)
        }

        manager.updateTrip(trip)
        dismiss()
    }
}
