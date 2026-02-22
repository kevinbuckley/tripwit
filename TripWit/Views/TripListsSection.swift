import SwiftUI
import CoreData

struct TripListsSection: View {
    @Environment(\.managedObjectContext) private var viewContext
    let trip: TripEntity
    var canEdit: Bool = true

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
        trip.listsArray.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var sortedDays: [DayEntity] {
        trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }
    }

    var body: some View {
        ForEach(sortedLists) { list in
            listSection(list)
        }
        if canEdit {
            addListSection
        }
        EmptyView()
            .sheet(item: $dayPickerItem) { item in
                addToDaySheet(item: item)
            }
    }

    // MARK: - List Section

    private func listSection(_ list: TripListEntity) -> some View {
        let items = list.itemsArray.sorted { $0.sortOrder < $1.sortOrder }
        let checkedCount = items.filter(\.isChecked).count

        return Section {
            ForEach(items) { item in
                itemRow(item, list: list)
            }
            .onDelete { offsets in
                if canEdit {
                    deleteItems(at: offsets, from: list)
                }
            }
            .deleteDisabled(!canEdit)

            if canEdit {
                addItemRow(for: list)
            }
        } header: {
            HStack {
                Label(list.wrappedName, systemImage: list.wrappedIcon)
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
                if canEdit {
                    item.isChecked.toggle()
                    trip.updatedAt = Date()
                    try? viewContext.save()
                }
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? .green : .gray)
            }
            .buttonStyle(.plain)
            .disabled(!canEdit)

            Text(item.wrappedText)
                .font(.subheadline)
                .strikethrough(item.isChecked)
                .foregroundStyle(item.isChecked ? .secondary : .primary)

            Spacer()

            // Only show "Add to Day" for Checklist-type lists (not Packing)
            if canEdit, list.wrappedName == "Checklist" || list.wrappedName == "To-Do" {
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
                    .foregroundStyle(
                        (list.id.flatMap { newItemTexts[$0] } ?? "").trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue
                    )
            }
            .disabled((list.id.flatMap { newItemTexts[$0] } ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
            .buttonStyle(.plain)
        }
    }

    private func bindingForList(_ list: TripListEntity) -> Binding<String> {
        Binding(
            get: { list.id.flatMap { newItemTexts[$0] } ?? "" },
            set: { if let id = list.id { newItemTexts[id] = $0 } }
        )
    }

    // MARK: - Add List Section

    private var addListSection: some View {
        Section {
            let existingNames = Set(trip.listsArray.map(\.wrappedName))
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
                                    .foregroundStyle(.primary)
                                Text(day.formattedDate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !day.wrappedLocation.isEmpty {
                                Text(day.wrappedLocation)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Text("\(day.stopsArray.count) stops")
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
        let list = TripListEntity.create(in: viewContext, name: name, icon: icon, sortOrder: trip.listsArray.count)
        list.trip = trip
        trip.updatedAt = Date()
        try? viewContext.save()
    }

    private func addItem(to list: TripListEntity) {
        guard let listID = list.id else { return }
        let trimmed = (newItemTexts[listID] ?? "").trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let item = TripListItemEntity.create(in: viewContext, text: trimmed, sortOrder: list.itemsArray.count)
        item.list = list
        trip.updatedAt = Date()
        try? viewContext.save()
        newItemTexts[listID] = ""
    }

    private func deleteItems(at offsets: IndexSet, from list: TripListEntity) {
        let items = list.itemsArray.sorted { $0.sortOrder < $1.sortOrder }
        for index in offsets {
            viewContext.delete(items[index])
        }
        trip.updatedAt = Date()
        try? viewContext.save()
    }

    private func addItemAsStop(_ item: TripListItemEntity, to day: DayEntity) {
        let manager = DataManager(context: viewContext)
        manager.addStop(
            to: day,
            name: item.wrappedText,
            latitude: 0,
            longitude: 0,
            category: .other,
            notes: ""
        )
        item.isChecked = true
        try? viewContext.save()
    }
}
