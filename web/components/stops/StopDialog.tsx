"use client";

import { useState, useEffect, useRef } from "react";
import { Search, X, MapPin, Star, Plus, Trash2, ExternalLink, Loader2, BedDouble, Utensils, Plane, Footprints, Clock, Ticket, ShoppingBag, type LucideIcon } from "lucide-react";
import type { Stop, StopCategory, StopBookingStatus, StopTodo, StopLink } from "@/lib/types";
import { CATEGORY_LABELS, newId } from "@/lib/types";
import { searchPlaces, type NominatimResult, type LocationBias } from "@/lib/nominatim";
import { cn } from "@/components/ui/cn";

// ── DateTime helpers ─────────────────────────────────────────────────────────
const TIME_OPTIONS: string[] = Array.from({ length: 48 }, (_, i) => {
  const h = Math.floor(i / 2).toString().padStart(2, "0");
  const m = i % 2 === 0 ? "00" : "30";
  return `${h}:${m}`;
});

function formatTimeOption(t: string): string {
  const [hStr, mStr] = t.split(":");
  const h = parseInt(hStr, 10);
  const ampm = h >= 12 ? "PM" : "AM";
  const hour = h % 12 || 12;
  return `${hour}:${mStr} ${ampm}`;
}

function isoToDate(iso?: string): string {
  if (!iso) return "";
  try {
    const d = new Date(iso);
    if (isNaN(d.getTime())) return "";
    return d.toISOString().slice(0, 10);
  } catch { return ""; }
}

function isoToTime(iso?: string): string {
  if (!iso) return "";
  try {
    const d = new Date(iso);
    if (isNaN(d.getTime())) return "";
    const h = d.getHours().toString().padStart(2, "0");
    const rawMin = d.getMinutes();
    const m = (Math.round(rawMin / 30) * 30) % 60;
    return `${h}:${m.toString().padStart(2, "0")}`;
  } catch { return ""; }
}

function buildISO(date: string, time: string): string | undefined {
  if (!date) return undefined;
  const t = time || "12:00";
  try {
    const iso = new Date(`${date}T${t}:00`).toISOString();
    return iso;
  } catch { return undefined; }
}

const timeSelectClass = "bg-slate-50 border border-slate-200 rounded-xl px-2.5 py-2.5 text-sm text-slate-800 focus:outline-none focus:border-blue-400 focus:bg-white focus:ring-3 focus:ring-blue-100 transition-all";

interface StopDialogProps {
  stop?: Stop | null;
  locationBias?: LocationBias;
  onSave: (stop: Stop) => void;
  onClose: () => void;
}

const CATEGORIES: StopCategory[] = [
  "accommodation",
  "restaurant",
  "attraction",
  "transport",
  "activity",
  "entertainment",
  "shopping",
  "other",
];

// Matches iOS SF Symbols: bed.double.fill / fork.knife / star.fill / airplane / figure.run / mappin
const CATEGORY_ICON_MAP: Record<string, LucideIcon> = {
  accommodation: BedDouble,
  restaurant: Utensils,
  attraction: Star,
  transport: Plane,
  activity: Footprints,
  entertainment: Ticket,
  shopping: ShoppingBag,
  other: MapPin,
};

const CATEGORY_COLORS_BG: Record<string, string> = {
  accommodation: "bg-purple-50 border-purple-200 text-purple-700",
  restaurant: "bg-orange-50 border-orange-200 text-orange-700",
  attraction: "bg-yellow-50 border-yellow-200 text-yellow-700",
  transport: "bg-blue-50 border-blue-200 text-blue-700",
  activity: "bg-green-50 border-green-200 text-green-700",
  entertainment: "bg-pink-50 border-pink-200 text-pink-700",
  shopping: "bg-rose-50 border-rose-200 text-rose-700",
  other: "bg-slate-50 border-slate-200 text-slate-600",
};

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

const Label = ({ children }: { children: React.ReactNode }) => (
  <label className="block text-[11px] font-semibold text-slate-500 uppercase tracking-wide mb-1.5">
    {children}
  </label>
);

const Input = (props: React.InputHTMLAttributes<HTMLInputElement>) => (
  <input
    {...props}
    className={cn(
      "w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2.5 text-sm text-slate-800 placeholder-slate-400",
      "focus:outline-none focus:border-blue-400 focus:bg-white focus:ring-3 focus:ring-blue-100 transition-all",
      props.className
    )}
  />
);

const Textarea = (props: React.TextareaHTMLAttributes<HTMLTextAreaElement>) => (
  <textarea
    {...props}
    className={cn(
      "w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2.5 text-sm text-slate-800 placeholder-slate-400 resize-none",
      "focus:outline-none focus:border-blue-400 focus:bg-white focus:ring-3 focus:ring-blue-100 transition-all",
      props.className
    )}
  />
);

export default function StopDialog({ stop, locationBias, onSave, onClose }: StopDialogProps) {
  const [form, setForm] = useState<Stop>(() => stop ?? emptyStop());
  const [searchQuery, setSearchQuery] = useState(stop?.address ?? stop?.name ?? "");
  const [results, setResults] = useState<NominatimResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [newTodo, setNewTodo] = useState("");
  const [newLinkTitle, setNewLinkTitle] = useState("");
  const [newLinkUrl, setNewLinkUrl] = useState("");
  const searchTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  function set<K extends keyof Stop>(key: K, value: Stop[K]) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  useEffect(() => {
    if (searchTimer.current) clearTimeout(searchTimer.current);
    if (!searchQuery.trim()) { setResults([]); return; }
    searchTimer.current = setTimeout(async () => {
      setSearching(true);
      try {
        const res = await searchPlaces(searchQuery, locationBias);
        setResults(res);
      } catch {
        setResults([]);
      } finally {
        setSearching(false);
      }
    }, 600);
    return () => { if (searchTimer.current) clearTimeout(searchTimer.current); };
  }, [searchQuery, locationBias]);

  // Close on Escape
  useEffect(() => {
    const handler = (e: KeyboardEvent) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [onClose]);

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

  function addTodo() {
    if (!newTodo.trim()) return;
    const todo: StopTodo = { id: newId(), text: newTodo.trim(), isCompleted: false, sortOrder: form.todos.length };
    set("todos", [...form.todos, todo]);
    setNewTodo("");
  }
  function toggleTodo(id: string) {
    set("todos", form.todos.map((t) => t.id === id ? { ...t, isCompleted: !t.isCompleted } : t));
  }
  function deleteTodo(id: string) {
    set("todos", form.todos.filter((t) => t.id !== id));
  }

  function addLink() {
    if (!newLinkUrl.trim()) return;
    const link: StopLink = { id: newId(), title: newLinkTitle.trim() || newLinkUrl.trim(), url: newLinkUrl.trim(), sortOrder: form.links.length };
    set("links", [...form.links, link]);
    setNewLinkTitle("");
    setNewLinkUrl("");
  }
  function deleteLink(id: string) {
    set("links", form.links.filter((l) => l.id !== id));
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.name.trim()) return;
    onSave({ ...form, id: form.id || newId() });
  }

  const isTransport = form.categoryRaw === "transport";
  const isAccommodation = form.categoryRaw === "accommodation";
  const hasLocation = form.latitude !== 0 || form.longitude !== 0;
  const ActiveCategoryIcon = CATEGORY_ICON_MAP[form.categoryRaw] ?? MapPin;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div className="modal-enter bg-white rounded-2xl shadow-[0_25px_50px_-12px_rgba(0,0,0,0.35)] w-full max-w-xl max-h-[92vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100 shrink-0">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-blue-600 flex items-center justify-center">
              <ActiveCategoryIcon className="w-4 h-4 text-white" />
            </div>
            <h2 className="font-semibold text-slate-900 text-[15px]">
              {stop ? "Edit Stop" : "Add Stop"}
            </h2>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 flex items-center justify-center rounded-xl text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Scrollable body */}
        <div className="overflow-y-auto flex-1 px-6 py-5 space-y-5">
          {/* Name */}
          <div>
            <Label>Name *</Label>
            <Input
              type="text"
              value={form.name}
              onChange={(e) => set("name", e.target.value)}
              required
              placeholder="e.g. Eiffel Tower"
              autoFocus
            />
          </div>

          {/* Category */}
          <div>
            <Label>Category</Label>
            <div className="flex flex-wrap gap-1.5">
              {CATEGORIES.map((cat) => {
                const CatIcon = CATEGORY_ICON_MAP[cat] ?? MapPin;
                const isActive = form.categoryRaw === cat;
                return (
                  <button
                    key={cat}
                    type="button"
                    onClick={() => set("categoryRaw", cat)}
                    className={cn(
                      "flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold border transition-all active:scale-95",
                      isActive
                        ? CATEGORY_COLORS_BG[cat] + " shadow-sm scale-[1.03]"
                        : "bg-white text-slate-500 border-slate-200 hover:border-slate-300 hover:text-slate-700 hover:shadow-sm"
                    )}
                  >
                    <CatIcon className={cn("w-4 h-4", isActive ? "" : "text-slate-400")} />
                    {CATEGORY_LABELS[cat]}
                  </button>
                );
              })}
            </div>
          </div>

          {/* Booking status */}
          <div>
            <Label>Booking Status</Label>
            <div className="flex gap-1.5">
              {([
                { value: "none", label: "Not needed", className: "bg-white text-slate-500 border-slate-200 hover:border-slate-300" },
                { value: "need_to_book", label: "Need to Book", className: "bg-amber-50 border-amber-200 text-amber-700" },
                { value: "booked", label: "Booked", className: "bg-emerald-50 border-emerald-200 text-emerald-700" },
              ] as const).map((opt) => {
                const isActive = (form.bookingStatus ?? "none") === opt.value;
                return (
                  <button
                    key={opt.value}
                    type="button"
                    onClick={() => set("bookingStatus", opt.value as StopBookingStatus)}
                    className={cn(
                      "px-3 py-2 rounded-xl text-xs font-semibold border transition-all active:scale-95",
                      isActive
                        ? opt.className + " shadow-sm scale-[1.03]"
                        : "bg-white text-slate-500 border-slate-200 hover:border-slate-300 hover:text-slate-700 hover:shadow-sm"
                    )}
                  >
                    {opt.label}
                  </button>
                );
              })}
            </div>
          </div>

          {/* Location search */}
          <div>
            <Label>Location</Label>
            <div className="relative">
              <Search className="absolute left-3.5 top-3 w-3.5 h-3.5 text-slate-400" />
              <Input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search for a place…"
                className="pl-9 pr-8"
              />
              {searching && (
                <Loader2 className="absolute right-3 top-3 w-3.5 h-3.5 text-slate-400 animate-spin" />
              )}
            </div>
            {results.length > 0 && (
              <ul className="mt-1.5 border border-slate-200 rounded-xl shadow-md overflow-hidden bg-white text-sm divide-y divide-slate-50">
                {results.slice(0, 5).map((r) => (
                  <li key={r.place_id}>
                    <button
                      type="button"
                      onClick={() => pickResult(r)}
                      className="w-full text-left px-3.5 py-2.5 hover:bg-slate-50 flex items-start gap-2.5 transition-colors"
                    >
                      <MapPin className="w-3.5 h-3.5 mt-0.5 shrink-0 text-blue-400" />
                      <span className="text-xs text-slate-700 leading-snug">{r.display_name}</span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
            {hasLocation && (
              <p className="text-[11px] mt-1.5 flex items-center gap-1.5 text-emerald-600 bg-emerald-50 border border-emerald-100 rounded-lg px-2.5 py-1.5 font-medium">
                <MapPin className="w-3 h-3 text-emerald-500 shrink-0" />
                Location pinned · {form.latitude.toFixed(4)}, {form.longitude.toFixed(4)}
                <a
                  href={`https://www.google.com/maps?q=${form.latitude},${form.longitude}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="ml-auto text-emerald-600 hover:text-emerald-700 underline underline-offset-2 shrink-0"
                >
                  Open in Maps ↗
                </a>
              </p>
            )}
          </div>

          {/* Times */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label><span className="flex items-center gap-1"><Clock className="w-3 h-3" />Arrival</span></Label>
              <div className="flex gap-1.5">
                <Input
                  type="date"
                  value={isoToDate(form.arrivalTime)}
                  onChange={(e) => set("arrivalTime", buildISO(e.target.value, isoToTime(form.arrivalTime)))}
                  className="flex-1 min-w-0"
                />
                <select
                  value={isoToTime(form.arrivalTime)}
                  onChange={(e) => set("arrivalTime", buildISO(isoToDate(form.arrivalTime), e.target.value))}
                  className={timeSelectClass}
                >
                  <option value="">–</option>
                  {TIME_OPTIONS.map((t) => <option key={t} value={t}>{formatTimeOption(t)}</option>)}
                </select>
              </div>
            </div>
            <div>
              <Label><span className="flex items-center gap-1"><Clock className="w-3 h-3" />Departure</span></Label>
              <div className="flex gap-1.5">
                <Input
                  type="date"
                  value={isoToDate(form.departureTime)}
                  onChange={(e) => set("departureTime", buildISO(e.target.value, isoToTime(form.departureTime)))}
                  className="flex-1 min-w-0"
                />
                <select
                  value={isoToTime(form.departureTime)}
                  onChange={(e) => set("departureTime", buildISO(isoToDate(form.departureTime), e.target.value))}
                  className={timeSelectClass}
                >
                  <option value="">–</option>
                  {TIME_OPTIONS.map((t) => <option key={t} value={t}>{formatTimeOption(t)}</option>)}
                </select>
              </div>
            </div>
          </div>

          {/* Transport-specific */}
          {isTransport && (
            <div className="rounded-xl border border-sky-100 bg-sky-50/60 p-4 space-y-3">
              <p className="text-xs font-semibold text-sky-700 flex items-center gap-1.5">
                ✈️ Flight Details
              </p>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <Label>Airline</Label>
                  <Input type="text" value={form.airline ?? ""} onChange={(e) => set("airline", e.target.value || undefined)} placeholder="e.g. Delta" className="bg-white" />
                </div>
                <div>
                  <Label>Flight #</Label>
                  <Input type="text" value={form.flightNumber ?? ""} onChange={(e) => set("flightNumber", e.target.value || undefined)} placeholder="e.g. DL234" className="bg-white" />
                </div>
                <div>
                  <Label>From (airport)</Label>
                  <Input type="text" value={form.departureAirport ?? ""} onChange={(e) => set("departureAirport", e.target.value || undefined)} placeholder="JFK" className="bg-white" />
                </div>
                <div>
                  <Label>To (airport)</Label>
                  <Input type="text" value={form.arrivalAirport ?? ""} onChange={(e) => set("arrivalAirport", e.target.value || undefined)} placeholder="CDG" className="bg-white" />
                </div>
              </div>
              <div>
                <Label>Confirmation code</Label>
                <Input type="text" value={form.confirmationCode ?? ""} onChange={(e) => set("confirmationCode", e.target.value || undefined)} placeholder="e.g. ABC123" className="bg-white" />
              </div>
            </div>
          )}

          {/* Accommodation-specific */}
          {isAccommodation && (
            <div className="rounded-xl border border-purple-100 bg-purple-50/60 p-4 space-y-3">
              <p className="text-xs font-semibold text-purple-700">🏨 Accommodation Details</p>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <Label>Confirmation code</Label>
                  <Input type="text" value={form.confirmationCode ?? ""} onChange={(e) => set("confirmationCode", e.target.value || undefined)} placeholder="e.g. HB123456" className="bg-white" />
                </div>
                <div>
                  <Label>Check-out date</Label>
                  <Input type="date" value={form.checkOutDate ?? ""} onChange={(e) => set("checkOutDate", e.target.value || undefined)} className="bg-white" />
                </div>
              </div>
            </div>
          )}

          {/* Rating */}
          <div>
            <Label>Rating</Label>
            <div className="flex items-center gap-1.5">
              {[1, 2, 3, 4, 5].map((n) => (
                <button key={n} type="button" onClick={() => set("rating", form.rating === n ? 0 : n)}
                  className="p-0.5 transition-transform hover:scale-[1.18] active:scale-90 select-none">
                  <Star className={cn("w-6 h-6 transition-all duration-100",
                    n <= form.rating ? "text-amber-400 fill-amber-400 drop-shadow-[0_0_4px_rgba(251,191,36,0.5)]" : "text-slate-200 hover:text-amber-300"
                  )} />
                </button>
              ))}
              {form.rating > 0 && (
                <button type="button" onClick={() => set("rating", 0)} className="ml-1 text-[11px] text-slate-400 hover:text-slate-600 transition-colors">
                  Clear
                </button>
              )}
            </div>
          </div>

          {/* Website / Phone */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label>Website</Label>
              <Input type="url" value={form.website ?? ""} onChange={(e) => set("website", e.target.value || undefined)} placeholder="https://…" />
            </div>
            <div>
              <Label>Phone</Label>
              <Input type="tel" value={form.phone ?? ""} onChange={(e) => set("phone", e.target.value || undefined)} placeholder="+1 234 567 8900" />
            </div>
          </div>

          {/* Notes */}
          <div>
            <Label>Notes</Label>
            <Textarea
              value={form.notes}
              onChange={(e) => set("notes", e.target.value)}
              onInput={(e) => { const el = e.currentTarget; el.style.height = "auto"; el.style.height = Math.min(el.scrollHeight, 200) + "px"; }}
              rows={3}
              placeholder="Any details, tips, or reminders…"
            />
          </div>

          {/* Todos */}
          <div>
            <Label>To-do list</Label>
            {form.todos.length > 0 && (
              <ul className="mb-2.5 space-y-1">
                {form.todos.map((todo) => (
                  <li key={todo.id} className="flex items-center gap-2.5 group py-1.5 px-2 rounded-lg hover:bg-slate-50">
                    <input
                      type="checkbox"
                      checked={todo.isCompleted}
                      onChange={() => toggleTodo(todo.id)}
                      className="rounded text-blue-600 border-slate-300 focus:ring-blue-500"
                    />
                    <span className={cn("flex-1 text-sm", todo.isCompleted && "line-through text-slate-400")}>
                      {todo.text}
                    </span>
                    <button type="button" onClick={() => deleteTodo(todo.id)} className="opacity-0 group-hover:opacity-100 text-slate-300 hover:text-red-500 transition-all">
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </li>
                ))}
              </ul>
            )}
            <div className="flex gap-2">
              <Input
                type="text"
                value={newTodo}
                onChange={(e) => setNewTodo(e.target.value)}
                onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); addTodo(); } }}
                placeholder="Add a to-do…"
              />
              <button type="button" onClick={addTodo} className="px-3 py-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-600 transition-colors shrink-0">
                <Plus className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Links */}
          <div>
            <Label>Links</Label>
            {form.links.length > 0 && (
              <ul className="mb-2.5 space-y-1">
                {form.links.map((link) => (
                  <li key={link.id} className="flex items-center gap-2.5 group py-1.5 px-2 rounded-lg hover:bg-slate-50">
                    <ExternalLink className="w-3.5 h-3.5 text-blue-400 shrink-0" />
                    <a href={link.url} target="_blank" rel="noopener noreferrer" className="flex-1 text-sm text-blue-500 hover:underline truncate">
                      {link.title}
                    </a>
                    <button type="button" onClick={() => deleteLink(link.id)} className="opacity-0 group-hover:opacity-100 text-slate-300 hover:text-red-500 transition-all">
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </li>
                ))}
              </ul>
            )}
            <div className="flex gap-2">
              <Input type="text" value={newLinkTitle} onChange={(e) => setNewLinkTitle(e.target.value)} placeholder="Label (optional)" className="w-32" />
              <Input
                type="url"
                value={newLinkUrl}
                onChange={(e) => setNewLinkUrl(e.target.value)}
                onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); addLink(); } }}
                placeholder="https://…"
              />
              <button type="button" onClick={addLink} className="px-3 py-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-600 transition-colors shrink-0">
                <Plus className="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="flex justify-end gap-2.5 px-6 py-4 border-t border-slate-100 bg-slate-50/50 rounded-b-2xl shrink-0">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2.5 rounded-xl text-sm font-medium text-slate-600 hover:bg-slate-100 transition-colors"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={handleSubmit as unknown as React.MouseEventHandler}
            className="px-5 py-2.5 rounded-xl text-sm font-semibold bg-blue-600 text-white hover:bg-blue-700 transition-colors shadow-sm"
          >
            {stop ? "Save changes" : "Add Stop"}
          </button>
        </div>
      </div>
    </div>
  );
}
