import SwiftUI
import CoreData

struct BudgetSection: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var trip: TripEntity
    var canEdit: Bool = true

    @State private var showingAddExpense = false
    @State private var expenseToEdit: ExpenseEntity?
    @State private var expenseToDelete: ExpenseEntity?

    private var sortedExpenses: [ExpenseEntity] {
        trip.expensesArray.sorted { $0.wrappedDateIncurred > $1.wrappedDateIncurred }
    }

    private var totalSpent: Double {
        trip.expensesArray.reduce(0) { $0 + $1.amount }
    }

    private var hasBudget: Bool {
        trip.budgetAmount > 0
    }

    private var spendingRatio: Double {
        guard hasBudget else { return 0 }
        return totalSpent / trip.budgetAmount
    }

    private var progressColor: Color {
        if spendingRatio < 0.75 { return .green }
        if spendingRatio < 0.9 { return .yellow }
        return .red
    }

    var body: some View {
        Section {
            // Summary
            if hasBudget || !trip.expensesArray.isEmpty {
                budgetSummary
            }

            // Category breakdown
            if !trip.expensesArray.isEmpty {
                categoryBreakdown
            }

            // Expense list
            if sortedExpenses.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No expenses yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } else {
                ForEach(sortedExpenses) { expense in
                    Button {
                        if canEdit {
                            expenseToEdit = expense
                        }
                    } label: {
                        expenseRow(expense)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        if canEdit {
                            Button(role: .destructive) {
                                expenseToDelete = expense
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            // Add button
            if canEdit {
                Button {
                    showingAddExpense = true
                } label: {
                    Label("Add Expense", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
        } header: {
            HStack {
                Text("Budget")
                Spacer()
                if !trip.expensesArray.isEmpty {
                    Text(formatCurrency(totalSpent))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseSheet(trip: trip)
        }
        .sheet(item: $expenseToEdit) { expense in
            AddExpenseSheet(trip: trip, existingExpense: expense)
        }
        .alert("Delete Expense?", isPresented: Binding(
            get: { expenseToDelete != nil },
            set: { if !$0 { expenseToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let expense = expenseToDelete {
                    DataManager(context: viewContext).deleteExpense(expense)
                    expenseToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { expenseToDelete = nil }
        } message: {
            if let expense = expenseToDelete {
                Text("Delete \"\(expense.wrappedTitle)\"?")
            }
        }
    }

    // MARK: - Budget Summary

    private var budgetSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if hasBudget {
                    Text("\(formatCurrency(totalSpent)) of \(formatCurrency(trip.budgetAmount))")
                        .font(.headline)
                    Spacer()
                    let remaining = trip.budgetAmount - totalSpent
                    Text(remaining >= 0 ? "\(formatCurrency(remaining)) left" : "\(formatCurrency(-remaining)) over")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(remaining >= 0 ? .green : .red)
                } else {
                    Text("\(formatCurrency(totalSpent)) spent")
                        .font(.headline)
                    Spacer()
                    Text("No budget set")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if hasBudget {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        Capsule()
                            .fill(progressColor)
                            .frame(width: min(geo.size.width * spendingRatio, geo.size.width), height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Category Breakdown

    private var categoryBreakdown: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categoryTotals, id: \.category) { item in
                    HStack(spacing: 4) {
                        Image(systemName: item.category.icon)
                            .font(.caption2)
                        Text(formatCurrency(item.total))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(item.category.color.opacity(0.12))
                    .foregroundStyle(item.category.color)
                    .clipShape(Capsule())
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }

    private struct CategoryTotal {
        let category: ExpenseCategory
        let total: Double
    }

    private var categoryTotals: [CategoryTotal] {
        var totals: [ExpenseCategory: Double] = [:]
        for expense in trip.expensesArray {
            totals[expense.category, default: 0] += expense.amount
        }
        return totals
            .map { CategoryTotal(category: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    // MARK: - Expense Row

    private func expenseRow(_ expense: ExpenseEntity) -> some View {
        HStack(spacing: 12) {
            Image(systemName: expense.category.icon)
                .font(.body)
                .foregroundStyle(expense.category.color)
                .frame(width: 32, height: 32)
                .background(expense.category.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.wrappedTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(expense.wrappedDateIncurred, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatCurrency(expense.amount))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Formatting

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = trip.wrappedBudgetCurrencyCode
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}
