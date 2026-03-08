"use client";

import { useState } from "react";
import { Plus, Trash2, ChevronDown, ChevronUp } from "lucide-react";
import type { TripList, TripListItem, Trip } from "@/lib/types";
import { newId } from "@/lib/types";
import { cn } from "@/components/ui/cn";

interface ListsPanelProps {
  trip: Trip;
  onUpdateTrip: (changes: Partial<Trip>) => void;
}

const LIST_ICONS = ["📋", "✅", "🛍️", "📦", "🎒", "🏖️", "📸", "🍽️", "💊", "🔑", "📄", "⭐"];

export default function ListsPanel({ trip, onUpdateTrip }: ListsPanelProps) {
  const [expandedLists, setExpandedLists] = useState<Set<string>>(
    () => new Set(trip.lists[0] ? [trip.lists[0].id] : [])
  );
  const [newListName, setNewListName] = useState("");
  const [newListIcon, setNewListIcon] = useState("📋");
  const [showNewList, setShowNewList] = useState(false);
  const [newItems, setNewItems] = useState<Record<string, string>>({});

  const lists = [...trip.lists].sort((a, b) => a.sortOrder - b.sortOrder);

  function updateLists(updated: TripList[]) {
    onUpdateTrip({ lists: updated });
  }

  function addList() {
    if (!newListName.trim()) return;
    const list: TripList = {
      id: newId(),
      name: newListName.trim(),
      icon: newListIcon,
      sortOrder: trip.lists.length,
      items: [],
    };
    updateLists([...trip.lists, list]);
    setExpandedLists((s) => new Set([...s, list.id]));
    setNewListName("");
    setNewListIcon("📋");
    setShowNewList(false);
  }

  function deleteList(listId: string) {
    updateLists(trip.lists.filter((l) => l.id !== listId));
    setExpandedLists((s) => { const n = new Set(s); n.delete(listId); return n; });
  }

  function toggleExpand(listId: string) {
    setExpandedLists((s) => {
      const n = new Set(s);
      if (n.has(listId)) n.delete(listId); else n.add(listId);
      return n;
    });
  }

  function addItem(listId: string) {
    const text = newItems[listId]?.trim();
    if (!text) return;
    const item: TripListItem = { id: newId(), text, isChecked: false, sortOrder: 0 };
    updateLists(trip.lists.map((l) => {
      if (l.id !== listId) return l;
      return { ...l, items: [...l.items, { ...item, sortOrder: l.items.length }] };
    }));
    setNewItems((prev) => ({ ...prev, [listId]: "" }));
  }

  function toggleItem(listId: string, itemId: string) {
    updateLists(trip.lists.map((l) => {
      if (l.id !== listId) return l;
      return { ...l, items: l.items.map((i) => i.id === itemId ? { ...i, isChecked: !i.isChecked } : i) };
    }));
  }

  function deleteItem(listId: string, itemId: string) {
    updateLists(trip.lists.map((l) => {
      if (l.id !== listId) return l;
      return { ...l, items: l.items.filter((i) => i.id !== itemId) };
    }));
  }

  return (
    <div className="flex-1 overflow-y-auto px-5 py-4 space-y-3">
      {lists.length === 0 && !showNewList && (
        <div className="text-center py-12">
          <div className="w-12 h-12 rounded-2xl bg-slate-100 flex items-center justify-center mx-auto mb-3 text-2xl">
            📋
          </div>
          <p className="text-sm font-medium text-slate-600 mb-1">No lists yet</p>
          <p className="text-xs text-slate-400">Create packing lists, to-dos, or anything else.</p>
        </div>
      )}

      {lists.map((list) => {
        const checkedCount = list.items.filter((i) => i.isChecked).length;
        const totalCount = list.items.length;
        const isExpanded = expandedLists.has(list.id);
        const progress = totalCount > 0 ? (checkedCount / totalCount) * 100 : 0;

        return (
          <div key={list.id} className="rounded-xl border border-slate-200 bg-white shadow-[0_1px_3px_rgba(0,0,0,0.06)] overflow-hidden">
            {/* List header */}
            <div
              className="flex items-center gap-3 px-4 py-3.5 cursor-pointer hover:bg-slate-50/80 group transition-colors"
              onClick={() => toggleExpand(list.id)}
            >
              <span className="text-xl">{list.icon}</span>
              <div className="flex-1 min-w-0">
                <div className="text-sm font-semibold text-slate-800">{list.name}</div>
                {totalCount > 0 && (
                  <div className="flex items-center gap-2 mt-1">
                    <div className="flex-1 h-1 bg-slate-100 rounded-full overflow-hidden max-w-[80px]">
                      <div
                        className="h-full bg-blue-500 rounded-full transition-all"
                        style={{ width: `${progress}%` }}
                      />
                    </div>
                    <span className="text-[10px] text-slate-400">{checkedCount}/{totalCount}</span>
                  </div>
                )}
              </div>
              <button
                onClick={(e) => { e.stopPropagation(); deleteList(list.id); }}
                className="opacity-0 group-hover:opacity-100 p-1 rounded-lg hover:bg-red-50 text-slate-300 hover:text-red-500 transition-all"
              >
                <Trash2 className="w-3.5 h-3.5" />
              </button>
              {isExpanded
                ? <ChevronUp className="w-4 h-4 text-slate-400 shrink-0" />
                : <ChevronDown className="w-4 h-4 text-slate-400 shrink-0" />
              }
            </div>

            {/* Items */}
            {isExpanded && (
              <div className="border-t border-slate-100">
                {list.items
                  .slice()
                  .sort((a, b) => a.sortOrder - b.sortOrder)
                  .map((item) => (
                    <div key={item.id} className="flex items-center gap-3 px-4 py-2.5 group border-b border-slate-50 last:border-0 hover:bg-slate-50/50 transition-colors">
                      <input
                        type="checkbox"
                        checked={item.isChecked}
                        onChange={() => toggleItem(list.id, item.id)}
                        className="w-4 h-4 rounded text-blue-600 border-slate-300 focus:ring-blue-500"
                      />
                      <span className={cn(
                        "flex-1 text-sm transition-colors",
                        item.isChecked ? "line-through text-slate-400" : "text-slate-700"
                      )}>
                        {item.text}
                      </span>
                      <button
                        onClick={() => deleteItem(list.id, item.id)}
                        className="opacity-0 group-hover:opacity-100 p-1 rounded-lg hover:bg-red-50 text-slate-300 hover:text-red-500 transition-all"
                      >
                        <Trash2 className="w-3 h-3" />
                      </button>
                    </div>
                  ))}

                {/* Add item */}
                <div className="flex gap-2 px-4 py-2.5 bg-slate-50/50">
                  <input
                    type="text"
                    value={newItems[list.id] ?? ""}
                    onChange={(e) => setNewItems((prev) => ({ ...prev, [list.id]: e.target.value }))}
                    onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); addItem(list.id); } }}
                    placeholder="Add item…"
                    className="flex-1 bg-white border border-slate-200 rounded-xl px-3 py-1.5 text-sm text-slate-800 placeholder-slate-400 focus:outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-100 transition-all"
                  />
                  <button
                    onClick={() => addItem(list.id)}
                    className="px-3 py-1.5 rounded-xl bg-white border border-slate-200 hover:bg-slate-50 text-slate-500 transition-colors"
                  >
                    <Plus className="w-4 h-4" />
                  </button>
                </div>
              </div>
            )}
          </div>
        );
      })}

      {/* New list form */}
      {showNewList ? (
        <div className="rounded-xl border border-blue-200 bg-blue-50/60 p-4 space-y-4">
          <p className="text-xs font-semibold text-blue-700">New list</p>
          <div>
            <label className="block text-[11px] font-semibold text-slate-500 uppercase tracking-wide mb-1.5">Name</label>
            <input
              type="text"
              value={newListName}
              onChange={(e) => setNewListName(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); addList(); } }}
              placeholder="e.g. Packing List"
              autoFocus
              className="w-full bg-white border border-slate-200 rounded-xl px-3.5 py-2.5 text-sm text-slate-800 placeholder-slate-400 focus:outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-100 transition-all"
            />
          </div>
          <div>
            <label className="block text-[11px] font-semibold text-slate-500 uppercase tracking-wide mb-1.5">Icon</label>
            <div className="flex flex-wrap gap-1.5">
              {LIST_ICONS.map((icon) => (
                <button
                  key={icon}
                  type="button"
                  onClick={() => setNewListIcon(icon)}
                  className={cn(
                    "w-9 h-9 rounded-xl text-lg flex items-center justify-center border transition-all",
                    newListIcon === icon
                      ? "border-blue-400 bg-white shadow-sm scale-110"
                      : "border-transparent bg-white/60 hover:border-slate-200 hover:bg-white"
                  )}
                >
                  {icon}
                </button>
              ))}
            </div>
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => setShowNewList(false)}
              className="flex-1 py-2.5 rounded-xl text-sm font-medium text-slate-600 hover:bg-slate-100 transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={addList}
              className="flex-1 py-2.5 rounded-xl text-sm font-semibold bg-blue-600 text-white hover:bg-blue-700 transition-colors shadow-sm"
            >
              Create list
            </button>
          </div>
        </div>
      ) : (
        <button
          onClick={() => setShowNewList(true)}
          className="flex items-center gap-2 w-full px-4 py-3 rounded-xl border-2 border-dashed border-slate-200 text-sm text-slate-400 hover:border-blue-400 hover:text-blue-500 transition-colors"
        >
          <Plus className="w-4 h-4" />
          New list
        </button>
      )}
    </div>
  );
}
