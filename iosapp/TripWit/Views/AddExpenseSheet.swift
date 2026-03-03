import SwiftUI
import CoreData

struct AddExpenseSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let trip: TripEntity
    var existingExpense: ExpenseEntity?

    @State private var title = ""
    @State private var amountText = ""
    @State private var category: ExpenseCategory = .other
    @State private var dateIncurred = Date()
    @State private var notes = ""

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(amountText) ?? 0) > 0
    }

    private var isEditing: Bool { existingExpense != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What did you spend on?", text: $title)
                    HStack {
                        Text(currencySymbol)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            Label(cat.label, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                } header: { Text("Details") }

                Section {
                    DatePicker("Date", selection: $dateIncurred, displayedComponents: .date)
                } header: { Text("When") }

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: { Text("Notes") }
            }
            .navigationTitle(isEditing ? "Edit Expense" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = trip.wrappedBudgetCurrencyCode
        return formatter.currencySymbol ?? "$"
    }

    private func loadExisting() {
        guard let expense = existingExpense else { return }
        title = expense.wrappedTitle
        amountText = String(format: "%.2f", expense.amount)
        category = expense.category
        dateIncurred = expense.wrappedDateIncurred
        notes = expense.wrappedNotes
    }

    private func save() {
        let amount = Double(amountText) ?? 0

        if let expense = existingExpense {
            expense.title = title.trimmingCharacters(in: .whitespaces)
            expense.amount = amount
            expense.category = category
            expense.dateIncurred = dateIncurred
            expense.notes = notes.trimmingCharacters(in: .whitespaces)
            expense.trip?.updatedAt = Date()
            try? viewContext.save()
        } else {
            let manager = DataManager(context: viewContext)
            manager.addExpense(
                to: trip,
                title: title.trimmingCharacters(in: .whitespaces),
                amount: amount,
                category: category,
                date: dateIncurred,
                notes: notes.trimmingCharacters(in: .whitespaces)
            )
        }
        dismiss()
    }
}
