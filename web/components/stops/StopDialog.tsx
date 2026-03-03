"use client";

import { useState, useEffect, useRef } from "react";
import { Search, X, MapPin } from "lucide-react";
import type { Stop, StopCategory } from "@/lib/types";
import { CATEGORY_LABELS, newId } from "@/lib/types";
import { searchPlaces, type NominatimResult } from "@/lib/nominatim";
import { cn } from "@/components/ui/cn";

interface StopDialogProps {
  stop?: Stop | null; // null = create new
  onSave: (stop: Stop) => void;
  onClose: () => void;
}

const CATEGORIES: StopCategory[] = [
  "accommodation",
  "restaurant",
  "attraction",
  "transport",
  "activity",
  "other",
];

function emptyStop(): Stop {
  return {
    id: newId(),
    name: "",
    categoryRaw: "attraction",
    sortOrder: 0,
    notes: "",
    latitude: 0,
    longitude: 0,
    isVisited: false,
    rating: 0,
    todos: [],
    links: [],
    comments: [],
  };
}

export default function StopDialog({ stop, onSave, onClose }: StopDialogProps) {
  const [form, setForm] = useState<Stop>(() => stop ?? emptyStop());
  const [searchQuery, setSearchQuery] = useState(stop?.address ?? stop?.name ?? "");
  const [results, setResults] = useState<NominatimResult[]>([]);
  const [searching, setSearching] = useState(false);
  const searchTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  function set<K extends keyof Stop>(key: K, value: Stop[K]) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  useEffect(() => {
    if (searchTimer.current) clearTimeout(searchTimer.current);
    if (!searchQuery.trim()) { setResults([]); return; }
    searchTimer.current = setTimeout(async () => {
      setSearching(true);
      const res = await searchPlaces(searchQuery);
      setResults(res);
      setSearching(false);
    }, 600);
    return () => { if (searchTimer.current) clearTimeout(searchTimer.current); };
  }, [searchQuery]);

  function pickResult(r: NominatimResult) {
    const name = r.display_name.split(",")[0].trim();
    setForm((f) => ({
      ...f,
      name: f.name || name,
      latitude: parseFloat(r.lat),
      longitude: parseFloat(r.lon),
      address: r.display_name,
    }));
    setSearchQuery(r.display_name);
    setResults([]);
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.name.trim()) return;
    onSave({ ...form, id: form.id || newId() });
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className="bg-white rounded-xl shadow-2xl w-full max-w-lg mx-4 max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between px-5 py-4 border-b">
          <h2 className="font-semibold text-slate-800">
            {stop ? "Edit Stop" : "Add Stop"}
          </h2>
          <button onClick={onClose} className="text-slate-400 hover:text-slate-700">
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="px-5 py-4 space-y-4">
          {/* Name */}
          <div>
            <label className="block text-xs font-medium text-slate-600 mb-1">Name *</label>
            <input
              type="text"
              value={form.name}
              onChange={(e) => set("name", e.target.value)}
              required
              placeholder="e.g. Eiffel Tower"
              className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
            />
          </div>

          {/* Category */}
          <div>
            <label className="block text-xs font-medium text-slate-600 mb-1">Category</label>
            <div className="flex flex-wrap gap-2">
              {CATEGORIES.map((cat) => (
                <button
                  key={cat}
                  type="button"
                  onClick={() => set("categoryRaw", cat)}
                  className={cn(
                    "px-3 py-1 rounded-full text-xs font-medium border transition-colors",
                    form.categoryRaw === cat
                      ? "bg-blue-600 text-white border-blue-600"
                      : "bg-white text-slate-600 border-slate-200 hover:border-blue-400"
                  )}
                >
                  {CATEGORY_LABELS[cat]}
                </button>
              ))}
            </div>
          </div>

          {/* Location search */}
          <div>
            <label className="block text-xs font-medium text-slate-600 mb-1">Location</label>
            <div className="relative">
              <Search className="absolute left-2.5 top-2.5 w-4 h-4 text-slate-400" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search for a place…"
                className="w-full border border-slate-200 rounded-lg pl-8 pr-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
              />
              {searching && (
                <div className="absolute right-3 top-2.5 text-xs text-slate-400">…</div>
              )}
            </div>
            {results.length > 0 && (
              <ul className="mt-1 border border-slate-200 rounded-lg shadow-sm overflow-hidden text-sm">
                {results.map((r) => (
                  <li key={r.place_id}>
                    <button
                      type="button"
                      onClick={() => pickResult(r)}
                      className="w-full text-left px-3 py-2 hover:bg-slate-50 flex items-start gap-2"
                    >
                      <MapPin className="w-3.5 h-3.5 mt-0.5 shrink-0 text-slate-400" />
                      <span className="text-xs text-slate-700 leading-snug">{r.display_name}</span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
            {(form.latitude !== 0 || form.longitude !== 0) && (
              <p className="text-xs text-slate-400 mt-1 flex items-center gap-1">
                <MapPin className="w-3 h-3" />
                {form.latitude.toFixed(5)}, {form.longitude.toFixed(5)}
              </p>
            )}
          </div>

          {/* Times */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">Arrival time</label>
              <input
                type="datetime-local"
                value={form.arrivalTime?.slice(0, 16) ?? ""}
                onChange={(e) =>
                  set("arrivalTime", e.target.value ? new Date(e.target.value).toISOString() : undefined)
                }
                className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">Departure time</label>
              <input
                type="datetime-local"
                value={form.departureTime?.slice(0, 16) ?? ""}
                onChange={(e) =>
                  set("departureTime", e.target.value ? new Date(e.target.value).toISOString() : undefined)
                }
                className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
              />
            </div>
          </div>

          {/* Notes */}
          <div>
            <label className="block text-xs font-medium text-slate-600 mb-1">Notes</label>
            <textarea
              value={form.notes}
              onChange={(e) => set("notes", e.target.value)}
              rows={3}
              placeholder="Any details…"
              className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400 resize-none"
            />
          </div>

          {/* Website / Phone */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">Website</label>
              <input
                type="url"
                value={form.website ?? ""}
                onChange={(e) => set("website", e.target.value || undefined)}
                placeholder="https://…"
                className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">Phone</label>
              <input
                type="tel"
                value={form.phone ?? ""}
                onChange={(e) => set("phone", e.target.value || undefined)}
                className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
              />
            </div>
          </div>

          {/* Actions */}
          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-lg text-sm text-slate-600 hover:bg-slate-100 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-4 py-2 rounded-lg text-sm bg-blue-600 text-white font-medium hover:bg-blue-700 transition-colors"
            >
              {stop ? "Save" : "Add Stop"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
