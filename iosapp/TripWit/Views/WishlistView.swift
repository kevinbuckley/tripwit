import SwiftUI
import CoreData
import MapKit
import TripCore

struct WishlistView: View {

    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \WishlistItemEntity.createdAt, ascending: false)]) private var items: FetchedResults<WishlistItemEntity>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)]) private var allTrips: FetchedResults<TripEntity>

    @State private var showingAddItem = false
    @State private var itemToAddToTrip: WishlistItemEntity?
    @State private var itemToEdit: WishlistItemEntity?
    @State private var itemToDelete: WishlistItemEntity?
    @State private var showingDeleteConfirmation = false
    @State private var selectedCity: String = "All"

    private var uniqueCities: [String] {
        let cities = items.compactMap { $0.wrappedDestination.isEmpty ? nil : $0.wrappedDestination }
        return Array(Set(cities)).sorted()
    }

    private var filterOptions: [String] {
        var options = ["All"] + uniqueCities
        let hasUncategorized = items.contains { $0.wrappedDestination.isEmpty }
        if hasUncategorized && !uniqueCities.isEmpty {
            options.append("Other")
        }
        return options
    }

    private var filteredItems: [WishlistItemEntity] {
        switch selectedCity {
        case "All": return Array(items)
        case "Other": return items.filter { $0.wrappedDestination.isEmpty }
        default: return items.filter { $0.wrappedDestination == selectedCity }
        }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .navigationTitle("Wishlist")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddItem = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddWishlistItemSheet()
        }
        .sheet(item: $itemToAddToTrip) { item in
            AddWishlistToTripSheet(item: item, trips: Array(allTrips))
        }
        .sheet(item: $itemToEdit) { item in
            EditWishlistItemSheet(item: item)
        }
        .alert("Delete Place?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    viewContext.delete(item)
                    try? viewContext.save()
                }
                itemToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            Text("\"\(itemToDelete?.wrappedName ?? "")\" will be permanently removed from your wishlist.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "heart.circle")
                .font(.system(size: 64))
                .foregroundStyle(.pink.opacity(0.6))
            Text("No Saved Places")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Save places you want to visit.\nAdd them to trips later.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { showingAddItem = true } label: {
                Label("Save a Place", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            Spacer()
        }
        .padding()
    }

    private var listContent: some View {
        VStack(spacing: 0) {
            if filterOptions.count > 2 {
                cityFilterBar
            }
            List {
                ForEach(filteredItems) { item in
                    Button { itemToEdit = item } label: {
                        wishlistRow(item)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            itemToDelete = item
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            itemToAddToTrip = item
                        } label: {
                            Label("Add to Trip", systemImage: "plus.circle")
                        }
                        .tint(.blue)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var cityFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filterOptions, id: \.self) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCity = option
                        }
                    } label: {
                        Text(option)
                            .font(.subheadline)
                            .fontWeight(selectedCity == option ? .semibold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selectedCity == option ? Color.pink : Color(.systemGray5))
                            .foregroundStyle(selectedCity == option ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func wishlistRow(_ item: WishlistItemEntity) -> some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon(item.category))
                .font(.body)
                .foregroundStyle(categoryColor(item.category))
                .frame(width: 32, height: 32)
                .background(categoryColor(item.category).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.wrappedName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !item.wrappedDestination.isEmpty {
                    Text(item.wrappedDestination)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !item.wrappedNotes.isEmpty {
                    Text(item.wrappedNotes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button {
                itemToAddToTrip = item
            } label: {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func categoryIcon(_ cat: StopCategory) -> String {
        switch cat {
        case .accommodation: "bed.double.fill"
        case .restaurant: "fork.knife"
        case .attraction: "star.fill"
        case .transport: "airplane"
        case .activity: "figure.run"
        case .other: "mappin"
        }
    }

    private func categoryColor(_ cat: StopCategory) -> Color {
        switch cat {
        case .accommodation: .purple
        case .restaurant: .orange
        case .attraction: .yellow
        case .transport: .blue
        case .activity: .green
        case .other: .gray
        }
    }
}

// MARK: - Add Wishlist Item Sheet

struct AddWishlistItemSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: StopCategory = .attraction
    @State private var notes = ""
    @State private var latitude: Double = 0
    @State private var longitude: Double = 0
    @State private var locationName = ""
    @State private var locationCity = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Place Name", text: $name)
                    CategoryPicker(selection: $category)
                } header: { Text("Details") }

                Section {
                    LocationSearchView(
                        selectedName: $locationName,
                        selectedLatitude: $latitude,
                        selectedLongitude: $longitude,
                        selectedCity: $locationCity
                    )
                    .listRowInsets(EdgeInsets())
                } header: { Text("Location") }

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: { Text("Notes") }
            }
            .navigationTitle("Save a Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveItem() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: locationName) { _, newValue in
                if name.isEmpty { name = newValue }
            }
        }
    }

    private func saveItem() {
        let item = WishlistItemEntity.create(
            in: viewContext,
            name: name.trimmingCharacters(in: .whitespaces),
            destination: locationCity.trimmingCharacters(in: .whitespaces),
            latitude: latitude,
            longitude: longitude,
            category: category,
            notes: notes.trimmingCharacters(in: .whitespaces)
        )
        _ = item
        try? viewContext.save()
        dismiss()
    }
}

// MARK: - Add Wishlist Item to Trip Sheet

struct AddWishlistToTripSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let item: WishlistItemEntity
    let trips: [TripEntity]

    @State private var selectedTrip: TripEntity?
    @State private var selectedDay: DayEntity?
    @State private var added = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(trips.filter { $0.status != .completed }) { trip in
                        Button {
                            selectedTrip = trip
                            selectedDay = trip.daysArray.sorted(by: { $0.dayNumber < $1.dayNumber }).first
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(trip.wrappedName).font(.subheadline).fontWeight(.medium)
                                    Text(trip.wrappedDestination).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedTrip?.id == trip.id {
                                    Image(systemName: "checkmark").foregroundStyle(.blue)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                } header: { Text("Select Trip") }

                if let trip = selectedTrip {
                    let sortedDays = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }
                    if !sortedDays.isEmpty {
                        Section {
                            ForEach(sortedDays) { day in
                                Button {
                                    selectedDay = day
                                } label: {
                                    HStack {
                                        Text("Day \(day.dayNumber)").font(.subheadline)
                                        Text(day.formattedDate).font(.caption).foregroundStyle(.secondary)
                                        Spacer()
                                        if selectedDay?.id == day.id {
                                            Image(systemName: "checkmark").foregroundStyle(.blue)
                                        }
                                    }
                                    .foregroundStyle(.primary)
                                }
                            }
                        } header: { Text("Select Day") }
                    }
                }

                if added {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("Added \(item.wrappedName) to the trip!")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Add to Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addToTrip() }
                        .disabled(selectedDay == nil)
                }
            }
        }
    }

    private func addToTrip() {
        guard let day = selectedDay else { return }
        let manager = DataManager(context: viewContext)
        let stop = manager.addStop(
            to: day,
            name: item.wrappedName,
            latitude: item.latitude,
            longitude: item.longitude,
            category: item.category,
            notes: item.wrappedNotes
        )
        stop.address = item.address
        stop.phone = item.phone
        stop.website = item.website
        try? viewContext.save()
        added = true

        // Auto-dismiss after showing success
        Task {
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run { dismiss() }
        }
    }
}

// MARK: - Edit Wishlist Item Sheet

struct EditWishlistItemSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var item: WishlistItemEntity

    @State private var name: String = ""
    @State private var category: StopCategory = .attraction
    @State private var notes: String = ""
    @State private var latitude: Double = 0
    @State private var longitude: Double = 0
    @State private var locationName: String = ""
    @State private var locationCity: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Place Name", text: $name)
                    CategoryPicker(selection: $category)
                } header: { Text("Details") }

                Section {
                    LocationSearchView(
                        selectedName: $locationName,
                        selectedLatitude: $latitude,
                        selectedLongitude: $longitude,
                        selectedCity: $locationCity
                    )
                    .listRowInsets(EdgeInsets())
                } header: { Text("Location") }

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: { Text("Notes") }
            }
            .navigationTitle("Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadItem() }
        }
    }

    private func loadItem() {
        name = item.wrappedName
        category = item.category
        notes = item.wrappedNotes
        latitude = item.latitude
        longitude = item.longitude
        locationName = item.wrappedName
        locationCity = item.wrappedDestination
    }

    private func saveChanges() {
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.category = category
        item.notes = notes.trimmingCharacters(in: .whitespaces)
        item.latitude = latitude
        item.longitude = longitude
        item.destination = locationCity.trimmingCharacters(in: .whitespaces)
        try? viewContext.save()
        dismiss()
    }
}
