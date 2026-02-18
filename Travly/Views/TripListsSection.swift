import SwiftUI
import SwiftData

struct TripListsSection: View {
    @Environment(\.modelContext) private var modelContext
    let trip: TripEntity

    @State private var newItemText = ""
    @State private var dayPickerItem: TripListItemEntity?

    /// The single checklist for this trip. Auto-created if none exists.
    private var checklist: TripListEntity? {
        trip.lists.first
    }

    private var sortedItems: [TripListItemEntity] {
        guard let list = checklist else { return [] }
        return list.items.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var sortedDays: [DayEntity] {
        trip.days.sorted { $0.dayNumber < $1.dayNumber }
    }

    private var checkedCount: Int {
        sortedItems.filter(\.isChecked).count
    }

    var body: some View {
        Section {
            ForEach(sortedItems) { item in
                itemRow(item)
            }
            .onDelete { offsets in
                deleteItems(at: offsets)
            }

            addItemRow
        } header: {
            HStack {
                Label("Checklist", systemImage: "checklist")
                Spacer()
                if !sortedItems.isEmpty {
                    Text("\(checkedCount)/\(sortedItems.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(item: $dayPickerItem) { item in
            addToDaySheet(item: item)
        }
    }

    // MARK: - Item Row

    private func itemRow(_ item: TripListItemEntity) -> some View {
        HStack(spacing: 10) {
            Button {
                item.isChecked.toggle()
                try? modelContext.save()
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isChecked ? .green : .gray)
            }
            .buttonStyle(.plain)

            Text(item.text)
                .font(.subheadline)
                .strikethrough(item.isChecked)
                .foregroundColor(item.isChecked ? .secondary : .primary)

            Spacer()

            // Add to Day button
            Button {
                dayPickerItem = item
            } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Add Item Row

    private var addItemRow: some View {
        HStack(spacing: 8) {
            TextField("Add item...", text: $newItemText)
                .font(.subheadline)
                .onSubmit {
                    addItem()
                }
            Button {
                addItem()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(newItemText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
            }
            .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
            .buttonStyle(.plain)
        }
    }

    // MARK: - Add to Day Sheet

    private func addToDaySheet(item: TripListItemEntity) -> some View {
        NavigationStack {
            List {
                ForEach(sortedDays) { day in
                    Button {
                        addItemAsStop(item, to: day)
                        dayPickerItem = nil
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Day \(day.dayNumber)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text(day.formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if !day.location.isEmpty {
                                Text(day.location)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Text("\(day.stops.count) stops")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add to Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dayPickerItem = nil }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func ensureChecklist() -> TripListEntity {
        if let existing = checklist {
            return existing
        }
        let list = TripListEntity(name: "Checklist", sortOrder: 0)
        list.trip = trip
        trip.lists.append(list)
        modelContext.insert(list)
        try? modelContext.save()
        return list
    }

    private func addItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let list = ensureChecklist()
        let item = TripListItemEntity(text: trimmed, sortOrder: list.items.count)
        item.list = list
        list.items.append(item)
        modelContext.insert(item)
        try? modelContext.save()
        newItemText = ""
    }

    private func deleteItems(at offsets: IndexSet) {
        let items = sortedItems
        for index in offsets {
            modelContext.delete(items[index])
        }
        try? modelContext.save()
    }

    private func addItemAsStop(_ item: TripListItemEntity, to day: DayEntity) {
        let manager = DataManager(modelContext: modelContext)
        manager.addStop(
            to: day,
            name: item.text,
            latitude: 0,
            longitude: 0,
            category: .other,
            notes: ""
        )
        // Mark the checklist item as done
        item.isChecked = true
        try? modelContext.save()
    }
}
