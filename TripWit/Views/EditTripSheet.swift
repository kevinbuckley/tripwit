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
    @State private var status: TripStatus
    @State private var showingDateChangeWarning = false
    @State private var budgetText: String
    @State private var budgetCurrency: String

    private static let currencyOptions = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "MXN", "CNY", "KRW", "THB", "INR", "BRL"]

    init(trip: TripEntity) {
        self.trip = trip
        _name = State(initialValue: trip.name ?? "")
        _destination = State(initialValue: trip.destination ?? "")
        _startDate = State(initialValue: trip.startDate ?? Date())
        _endDate = State(initialValue: trip.endDate ?? Date())
        _notes = State(initialValue: trip.notes ?? "")
        _status = State(initialValue: trip.status)
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
                    Picker("Status", selection: $status) {
                        Text("Planning").tag(TripStatus.planning)
                        Text("Active").tag(TripStatus.active)
                        Text("Completed").tag(TripStatus.completed)
                    }
                } header: {
                    Text("Status")
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
                    saveChanges(regenerateDays: true)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Changing dates will regenerate the day-by-day plan. All existing stops and comments will be removed.")
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
        let hasStops = trip.daysArray.contains { !$0.stopsArray.isEmpty }

        if datesChanged && hasStops {
            showingDateChangeWarning = true
        } else {
            saveChanges(regenerateDays: datesChanged)
        }
    }

    private func saveChanges(regenerateDays: Bool) {
        let manager = DataManager(context: viewContext)
        trip.name = name.trimmingCharacters(in: .whitespaces)
        trip.destination = destination.trimmingCharacters(in: .whitespaces)
        trip.startDate = startDate
        trip.endDate = endDate
        trip.notes = notes.trimmingCharacters(in: .whitespaces)
        trip.status = status
        trip.budgetAmount = Double(budgetText) ?? 0
        trip.budgetCurrencyCode = budgetCurrency

        if regenerateDays {
            manager.generateDays(for: trip)
        }

        manager.updateTrip(trip)
        dismiss()
    }
}
