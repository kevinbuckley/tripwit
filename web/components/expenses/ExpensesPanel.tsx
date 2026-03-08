"use client";

import { useState } from "react";
import { Plus, Trash2, Pencil, TrendingUp, BedDouble, Utensils, Car, Ticket, ShoppingBag, MoreHorizontal, type LucideIcon } from "lucide-react";
import type { Expense, Trip } from "@/lib/types";
import ExpenseDialog from "./ExpenseDialog";

interface ExpensesPanelProps {
  trip: Trip;
  onUpdateTrip: (changes: Partial<Trip>) => void;
}

// Matches iOS SF Symbols: bed.double.fill / fork.knife / car.fill / ticket.fill / bag.fill / ellipsis.circle.fill
const CATEGORY_ICON_MAP: Record<string, LucideIcon> = {
  accommodation: BedDouble,
  food: Utensils,
  transport: Car,
  activity: Ticket,
  shopping: ShoppingBag,
  other: MoreHorizontal,
};

const CATEGORY_LABELS: Record<string, string> = {
  accommodation: "Accommodation",
  food: "Food & Drink",
  transport: "Transport",
  activity: "Activity",
  shopping: "Shopping",
  other: "Other",
};

const CATEGORY_COLORS: Record<string, string> = {
  accommodation: "bg-purple-100 text-purple-700",
  food: "bg-orange-100 text-orange-700",
  transport: "bg-sky-100 text-sky-700",
  activity: "bg-green-100 text-green-700",
  shopping: "bg-pink-100 text-pink-700",
  other: "bg-slate-100 text-slate-600",
};

function formatAmount(amount: number, currency: string) {
  try {
    return new Intl.NumberFormat(undefined, { style: "currency", currency, minimumFractionDigits: 2 }).format(amount);
  } catch {
    return `${currency} ${amount.toFixed(2)}`;
  }
}

export default function ExpensesPanel({ trip, onUpdateTrip }: ExpensesPanelProps) {
  const [editing, setEditing] = useState<Expense | null | "new">(null);

  const expenses = [...trip.expenses].sort((a, b) => {
    if (a.dateIncurred !== b.dateIncurred) return a.dateIncurred.localeCompare(b.dateIncurred);
    return a.sortOrder - b.sortOrder;
  });

  const budgetCurrency = trip.budgetCurrencyCode || "USD";
  const totalSpent = expenses.filter((e) => e.currencyCode === budgetCurrency).reduce((sum, e) => sum + e.amount, 0);
  const hasBudget = trip.budgetAmount > 0;
  const budgetPct = hasBudget ? Math.min(100, (totalSpent / trip.budgetAmount) * 100) : 0;
  const isOver = hasBudget && totalSpent > trip.budgetAmount;

  function saveExpense(expense: Expense) {
    const exists = trip.expenses.find((e) => e.id === expense.id);
    const updated = exists
      ? trip.expenses.map((e) => (e.id === expense.id ? expense : e))
      : [...trip.expenses, { ...expense, sortOrder: trip.expenses.length }];
    onUpdateTrip({ expenses: updated });
    setEditing(null);
  }

  function deleteExpense(id: string) {
    onUpdateTrip({ expenses: trip.expenses.filter((e) => e.id !== id) });
  }

  return (
    <div className="flex-1 overflow-y-auto tab-content">
      {/* Budget summary card */}
      {(hasBudget || expenses.length > 0) && (
        <div className="mx-5 mt-5 rounded-2xl border border-slate-200 bg-white shadow-[0_1px_3px_rgba(0,0,0,0.06)] overflow-hidden">
          <div className="px-5 pt-4 pb-3">
            <div className="flex items-center gap-2 mb-3">
              <TrendingUp className="w-4 h-4 text-slate-400" />
              <span className="text-xs font-semibold text-slate-500 uppercase tracking-wide">Budget Summary</span>
            </div>
            <div className="flex items-end justify-between">
              <div>
                <div className="text-3xl font-bold text-slate-900 tracking-tight">
                  {formatAmount(totalSpent, budgetCurrency)}
                </div>
                {hasBudget && (
                  <div className="text-xs text-slate-400 mt-0.5">
                    of {formatAmount(trip.budgetAmount, budgetCurrency)} budget
                  </div>
                )}
              </div>
              {hasBudget && (
                <div className={`text-sm font-semibold px-3 py-1.5 rounded-xl ${isOver ? "bg-red-50 text-red-600" : "bg-emerald-50 text-emerald-600"}`}>
                  {isOver
                    ? `${formatAmount(totalSpent - trip.budgetAmount, budgetCurrency)} over`
                    : `${formatAmount(trip.budgetAmount - totalSpent, budgetCurrency)} left`}
                </div>
              )}
            </div>
          </div>
          {hasBudget && (
            <div className="h-1.5 bg-slate-100">
              <div
                className={`h-full transition-all duration-500 ${isOver ? "bg-red-500" : "bg-blue-500"}`}
                style={{ width: `${budgetPct}%` }}
              />
            </div>
          )}
        </div>
      )}

      <div className="px-5 py-4 space-y-2">
        {expenses.length === 0 && (
          <div className="text-center py-12">
            <div className="w-12 h-12 rounded-2xl bg-slate-100 flex items-center justify-center mx-auto mb-3 text-2xl">
              💳
            </div>
            <p className="text-sm font-medium text-slate-600 mb-1">No expenses yet</p>
            <p className="text-xs text-slate-400">Track what you spend on this trip.</p>
          </div>
        )}

        {expenses.map((exp) => (
          <div
            key={exp.id}
            className="flex items-center gap-3 px-4 py-3 rounded-xl border border-slate-100 bg-white shadow-[0_1px_2px_rgba(0,0,0,0.04)] group hover:shadow-[0_2px_8px_rgba(0,0,0,0.08)] transition-shadow"
          >
            {(() => { const Icon = CATEGORY_ICON_MAP[exp.categoryRaw] ?? MoreHorizontal; return <Icon className="w-5 h-5 text-slate-400 shrink-0" />; })()}
            <div className="flex-1 min-w-0">
              <div className="text-sm font-medium text-slate-800 truncate">{exp.title}</div>
              <div className="flex items-center gap-1.5 mt-0.5">
                <span className={`text-[10px] font-semibold px-1.5 py-0.5 rounded-full ${CATEGORY_COLORS[exp.categoryRaw]}`}>
                  {CATEGORY_LABELS[exp.categoryRaw]}
                </span>
                {exp.dateIncurred && (
                  <span className="text-[10px] text-slate-400">
                    {new Date(exp.dateIncurred + "T12:00:00").toLocaleDateString(undefined, { month: "short", day: "numeric" })}
                  </span>
                )}
              </div>
              {exp.notes && (
                <div className="text-xs text-slate-400 italic truncate mt-0.5">{exp.notes}</div>
              )}
            </div>
            <div className="text-sm font-bold text-slate-800 shrink-0">
              {formatAmount(exp.amount, exp.currencyCode)}
            </div>
            <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
              <button onClick={() => setEditing(exp)} className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-700 transition-colors">
                <Pencil className="w-3.5 h-3.5" />
              </button>
              <button onClick={() => deleteExpense(exp.id)} className="p-1.5 rounded-lg hover:bg-red-50 text-slate-400 hover:text-red-500 transition-colors">
                <Trash2 className="w-3.5 h-3.5" />
              </button>
            </div>
          </div>
        ))}

        <button
          onClick={() => setEditing("new")}
          className="flex items-center gap-2 w-full px-4 py-3 rounded-xl border-2 border-dashed border-slate-200 text-sm text-slate-400 hover:border-blue-400 hover:text-blue-500 transition-colors"
        >
          <Plus className="w-4 h-4" />
          Add expense
        </button>
      </div>

      {editing !== null && (
        <ExpenseDialog
          expense={editing === "new" ? null : editing}
          defaultCurrency={trip.budgetCurrencyCode || "USD"}
          onSave={saveExpense}
          onClose={() => setEditing(null)}
        />
      )}
    </div>
  );
}
