"use client";

import { useState, useEffect } from "react";
import { X, BedDouble, Utensils, Car, Ticket, ShoppingBag, MoreHorizontal, type LucideIcon } from "lucide-react";
import type { Expense, ExpenseCategory } from "@/lib/types";
import { newId, nowISO } from "@/lib/types";
import { cn } from "@/components/ui/cn";

interface ExpenseDialogProps {
  expense?: Expense | null;
  defaultCurrency?: string;
  onSave: (expense: Expense) => void;
  onClose: () => void;
}

// Icons match iOS SF Symbols: bed.double.fill / fork.knife / car.fill / ticket.fill / bag.fill / ellipsis.circle.fill
const EXPENSE_CATEGORIES: { value: ExpenseCategory; label: string; icon: LucideIcon }[] = [
  { value: "accommodation", label: "Stay",     icon: BedDouble },
  { value: "food",          label: "Food",     icon: Utensils },
  { value: "transport",     label: "Travel",   icon: Car },
  { value: "activity",      label: "Activity", icon: Ticket },
  { value: "shopping",      label: "Shopping", icon: ShoppingBag },
  { value: "other",         label: "Other",    icon: MoreHorizontal },
];

const COMMON_CURRENCIES = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "MXN", "BRL"];

function emptyExpense(currency: string): Expense {
  const today = new Date().toISOString().slice(0, 10);
  return { id: newId(), title: "", amount: 0, currencyCode: currency, categoryRaw: "other", notes: "", sortOrder: 0, createdAt: nowISO(), dateIncurred: today };
}

const Label = ({ children }: { children: React.ReactNode }) => (
  <label className="block text-[11px] font-semibold text-slate-500 uppercase tracking-wide mb-1.5">
    {children}
  </label>
);

export default function ExpenseDialog({ expense, defaultCurrency = "USD", onSave, onClose }: ExpenseDialogProps) {
  const [form, setForm] = useState<Expense>(() => expense ?? emptyExpense(defaultCurrency));

  function set<K extends keyof Expense>(key: K, value: Expense[K]) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  useEffect(() => {
    const handler = (e: KeyboardEvent) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [onClose]);

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.title.trim() || form.amount <= 0) return;
    onSave({ ...form, id: form.id || newId() });
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div className="bg-white rounded-2xl shadow-[0_25px_50px_-12px_rgba(0,0,0,0.35)] w-full max-w-sm">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100">
          <h2 className="font-semibold text-slate-900 text-[15px]">
            {expense ? "Edit Expense" : "Add Expense"}
          </h2>
          <button onClick={onClose} className="w-8 h-8 flex items-center justify-center rounded-xl text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors">
            <X className="w-4 h-4" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="px-6 py-5 space-y-5">
          {/* Category grid */}
          <div>
            <Label>Category</Label>
            <div className="grid grid-cols-3 gap-1.5">
              {EXPENSE_CATEGORIES.map((cat) => {
                const CatIcon = cat.icon;
                return (
                  <button
                    key={cat.value}
                    type="button"
                    onClick={() => set("categoryRaw", cat.value)}
                    className={cn(
                      "flex flex-col items-center gap-1.5 py-2.5 rounded-xl border text-xs font-medium transition-all",
                      form.categoryRaw === cat.value
                        ? "bg-blue-600 text-white border-blue-600 shadow-sm"
                        : "bg-slate-50 text-slate-600 border-slate-200 hover:border-slate-300"
                    )}
                  >
                    <CatIcon className="w-5 h-5" />
                    {cat.label}
                  </button>
                );
              })}
            </div>
          </div>

          {/* Title */}
          <div>
            <Label>Title *</Label>
            <input
              type="text"
              value={form.title}
              onChange={(e) => set("title", e.target.value)}
              required
              autoFocus
              placeholder="e.g. Dinner at Le Jules Verne"
              className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2.5 text-sm text-slate-800 placeholder-slate-400 focus:outline-none focus:border-blue-400 focus:bg-white focus:ring-3 focus:ring-blue-100 transition-all"
            />
          </div>

          {/* Amount + Currency */}
          <div className="flex gap-2">
            <div className="flex-1">
              <Label>Amount *</Label>
              <input
                type="number"
                min="0"
                step="0.01"
                value={form.amount || ""}
                onChange={(e) => set("amount", parseFloat(e.target.value) || 0)}
                required
                placeholder="0.00"
                className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2.5 text-sm text-slate-800 placeholder-slate-400 focus:outline-none focus:border-blue-400 focus:bg-white focus:ring-3 focus:ring-blue-100 transition-all"
              />
            </div>
            <div className="w-24">
              <Label>Currency</Label>
              <select
                value={form.currencyCode}
                onChange={(e) => set("currencyCode", e.target.value)}
                className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2.5 text-sm text-slate-800 focus:outline-none focus:border-blue-400 focus:bg-white focus:ring-3 focus:ring-blue-100 transition-all"
              >
                {COMMON_CURRENCIES.map((c) => (
                  <option key={c} value={c}>{c}</option>
                ))}
              </select>
            </div>
          </div>

          {/* Date */}
          <div>
            <Label>Date</Label>
            <input
              type="date"
              value={form.dateIncurred}
              onChange={(e) => set("dateIncurred", e.target.value)}
              className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2.5 text-sm text-slate-800 focus:outline-none focus:border-blue-400 focus:bg-white focus:ring-3 focus:ring-blue-100 transition-all"
            />
          </div>

          {/* Notes */}
          <div>
            <Label>Notes</Label>
            <input
              type="text"
              value={form.notes}
              onChange={(e) => set("notes", e.target.value)}
              placeholder="Optional notes…"
              className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2.5 text-sm text-slate-800 placeholder-slate-400 focus:outline-none focus:border-blue-400 focus:bg-white focus:ring-3 focus:ring-blue-100 transition-all"
            />
          </div>

          <div className="flex justify-end gap-2.5 pt-1">
            <button type="button" onClick={onClose} className="px-4 py-2.5 rounded-xl text-sm font-medium text-slate-600 hover:bg-slate-100 transition-colors">
              Cancel
            </button>
            <button type="submit" className="px-5 py-2.5 rounded-xl text-sm font-semibold bg-blue-600 text-white hover:bg-blue-700 transition-colors shadow-sm">
              {expense ? "Save changes" : "Add Expense"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
