import SwiftUI
import SwiftData

struct TripListsSection: View {
    @Environment(\.modelContext) private var modelContext
    let trip: TripEntity

    @State private var newItemTexts: [UUID: String] = [:]
    @State private var dayPickerItem: TripListItemEntity?
    @State private var showingAddList = false
    @State private var newListName = ""

    /// Default list templates available for quick creation.
    private static let listTemplates: [(name: String, icon: String)] = [
        ("Checklist", "checklist"),
        ("Packing", "suitcase.fill"),
        ("Shopping", "bag.fill"),
        ("To-Do", "list.clipboard"),
    ]

    private var sortedLists: [TripListEntity] {
        trip.lists.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var sortedDays: [DayEntity] {
        trip.days.sorted { $0.dayNumber < $1.dayNumber }
    }

    var body: some View {
        ForEach(sortedLists) { list in
            listSection(list)
        }
        addListSection
            .sheet(item: $dayPickerItem) { item in
                addToDaySheet(item: item)
            }
    }

    // MARK: - List Section

    private func listSection(_ list: TripListEntity) -> some View {
        let items = list.items.sorted { $0.sortOrder < $1.sortOrder }
        let checkedCount = items.filter(\.isChecked).count

        return Section {
            ForEach(items) { item in
                itemRow(item, list: list)
            }
            .onDelete { offsets in
                deleteItems(at: offsets, from: list)
            }

            addItemRow(for: list)
        } header: {
            HStack {
                Label(list.name, systemImage: list.icon)
                Spacer()
                if !items.isEmpty {
                    Text("\(checkedCount)/\(items.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Item Row

    private func itemRow(_ item: TripListItemEntity, list: TripListEntity) -> some View {
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

            // Only show "Add to Day" for Checklist-type lists (not Packing)
            if list.name == "Checklist" || list.name == "To-Do" {
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
    }

    // MARK: - Add Item Row

    private func addItemRow(for list: TripListEntity) -> some View {
        HStack(spacing: 8) {
            TextField("Add item...", text: bindingForList(list))
                .font(.subheadline)
                .onSubmit {
                    addItem(to: list)
                }
            Button {
                addItem(to: list)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(
                        (newItemTexts[list.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue
                    )
            }
            .disabled((newItemTexts[list.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
            .buttonStyle(.plain)
        }
    }

    private func bindingForList(_ list: TripListEntity) -> Binding<String> {
        Binding(
            get: { newItemTexts[list.id] ?? "" },
            set: { newItemTexts[list.id] = $0 }
        )
    }

    // MARK: - Add List Section

    private var addListSection: some View {
        Section {
            let existingNames = Set(trip.lists.map(\.name))
            let available = Self.listTemplates.filter { !existingNames.contains($0.name) }

            if !available.isEmpty {
                Menu {
                    ForEach(available, id: \.name) { template in
                        Button {
                            createList(name: template.name, icon: template.icon)
                        } label: {
                            Label(template.name, systemImage: template.icon)
                        }
                    }
                    Divider()
                    Button {
                        showingAddList = true
                    } label: {
                        Label("Custom List...", systemImage: "plus")
                    }
                } label: {
                    Label("Add List", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            } else {
                Button {
                    showingAddList = true
                } label: {
                    Label("Add Custom List", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
        }
        .alert("New List", isPresented: $showingAddList) {
            TextField("List name", text: $newListName)
            Button("Add") {
                let trimmed = newListName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    createList(name: trimmed, icon: "list.bullet")
                    newListName = ""
                }
            }
            Button("Cancel", role: .cancel) { newListName = "" }
        } message: {
            Text("Enter a name for the new list.")
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

    private func createList(name: String, icon: String) {
        let list = TripListEntity(name: name, icon: icon, sortOrder: trip.lists.count)
        list.trip = trip
        trip.lists.append(list)
        modelContext.insert(list)
        try? modelContext.save()
    }

    private func addItem(to list: TripListEntity) {
        let trimmed = (newItemTexts[list.id] ?? "").trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let item = TripListItemEntity(text: trimmed, sortOrder: list.items.count)
        item.list = list
        list.items.append(item)
        modelContext.insert(item)
        try? modelContext.save()
        newItemTexts[list.id] = ""
    }

    private func deleteItems(at offsets: IndexSet, from list: TripListEntity) {
        let items = list.items.sorted { $0.sortOrder < $1.sortOrder }
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
        item.isChecked = true
        try? modelContext.save()
    }
}
