import SwiftUI
import CoreData

struct ImportTripSheet: View {

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let transfer: TripTransfer
    var onImported: ((UUID) -> Void)?

    @State private var isImporting = false
    @State private var showingDuplicateWarning = false

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(transfer.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(.red)
                            Text(transfer.destination)
                                .font(.subheadline)
                        }
                        if transfer.hasCustomDates {
                            Text("\(dateFormatter.string(from: transfer.startDate)) – \(dateFormatter.string(from: transfer.endDate))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Contents") {
                    Label("\(transfer.days.count) days", systemImage: "calendar")
                    let stopCount = transfer.days.reduce(0) { $0 + $1.stops.count }
                    Label("\(stopCount) stops", systemImage: "mappin")
                    if transfer.bookings.count > 0 {
                        Label("\(transfer.bookings.count) bookings", systemImage: "suitcase")
                    }
                    if transfer.lists.count > 0 {
                        Label("\(transfer.lists.count) lists", systemImage: "checklist")
                    }
                    if transfer.expenses.count > 0 {
                        Label("\(transfer.expenses.count) expenses", systemImage: "dollarsign.circle")
                    }
                }

                if !transfer.notes.isEmpty {
                    Section("Notes") {
                        Text(transfer.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Import Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        attemptImport()
                    }
                    .fontWeight(.semibold)
                    .disabled(isImporting)
                }
            }
            .alert("Possible Duplicate", isPresented: $showingDuplicateWarning) {
                Button("Import as Copy") {
                    importTrip()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("A trip named \"\(transfer.name)\" with similar dates already exists. Import anyway?")
            }
        }
    }

    private func attemptImport() {
        if hasDuplicate() {
            showingDuplicateWarning = true
        } else {
            importTrip()
        }
    }

    private func hasDuplicate() -> Bool {
        let request = TripEntity.fetchRequest() as! NSFetchRequest<TripEntity>
        request.predicate = NSPredicate(format: "name ==[c] %@", transfer.name)
        guard let matches = try? viewContext.fetch(request) else { return false }
        return matches.contains { trip in
            guard let tripStart = trip.startDate, let tripEnd = trip.endDate else { return false }
            // Check for date overlap: trips overlap if one starts before the other ends
            return tripStart <= transfer.endDate && transfer.startDate <= tripEnd
        }
    }

    private func importTrip() {
        isImporting = true
        let trip = TripShareService.importTrip(transfer, into: viewContext)
        try? viewContext.save()
        let tripID = trip.id ?? UUID()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onImported?(tripID)
        }
    }
}
