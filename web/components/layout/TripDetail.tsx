"use client";

import { useState, useEffect, useRef } from "react";
import {
  Plus, Trash2, ChevronDown, ChevronUp, MapPin, Share2, Check,
  ExternalLink, Star, DollarSign, FileText, Calendar, GripVertical, Pencil,
  Clock, Plane, BedDouble, Utensils, Footprints, RotateCcw,
  ChevronsUpDown, Bookmark, List, type LucideIcon,
} from "lucide-react";
import type { Trip, Day, Stop } from "@/lib/types";
import { CATEGORY_LABELS, CATEGORY_COLORS, newId, nowISO } from "@/lib/types";
import { cn } from "@/components/ui/cn";
import StopDialog from "@/components/stops/StopDialog";
import BookingsPanel from "@/components/bookings/BookingsPanel";
import ExpensesPanel from "@/components/expenses/ExpensesPanel";
import ListsPanel from "@/components/lists/ListsPanel";
import AdUnit from "@/components/ads/AdUnit";

type Tab = "days" | "bookings" | "expenses" | "lists";

interface TripDetailProps {
  trip: Trip;
  showAds?: boolean;
  onUpdateTrip: (changes: Partial<Trip>) => void;
  onSelectStop?: (stopId: string | null) => void;
  selectedStopId?: string | null;
}

const CURRENCIES = ["USD","EUR","GBP","JPY","CAD","AUD","CHF","MXN","BRL","CNY","KRW","THB","INR","SGD","NZD"];

// Matches iOS SF Symbols: bed.double.fill / fork.knife / star.fill / airplane / figure.run / mappin
const CATEGORY_ICON_MAP: Record<string, LucideIcon> = {
  accommodation: BedDouble,
  restaurant: Utensils,
  attraction: Star,
  transport: Plane,
  activity: Footprints,
  other: MapPin,
};

const STATUS_CONFIG: Record<string, { label: string; className: string }> = {
  planning: { label: "📝 Planning", className: "bg-blue-50 text-blue-700 border-blue-200" },
  active:   { label: "🧭 Active",   className: "bg-emerald-50 text-emerald-700 border-emerald-200" },
  completed:{ label: "✅ Done",     className: "bg-slate-100 text-slate-600 border-slate-200" },
};

type UndoItem =
  | { type: "stop"; stop: Stop; dayId: string; index: number }
  | { type: "day"; day: Day; index: number };

function formatDayDate(dateStr: string | null | undefined): string {
  if (!dateStr) return "";
  const clean = String(dateStr).slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(clean)) return "";
  try {
    const d = new Date(clean + "T12:00:00");
    if (isNaN(d.getTime())) return "";
    return d.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" });
  } catch { return ""; }
}

/** Returns display date for a day: either its own date or derived from trip start */
function getEffectiveDate(day: Day, tripStartDate: string | null | undefined): string {
  if (day.date && /^\d{4}-\d{2}-\d{2}$/.test(day.date.slice(0, 10))) {
    return formatDayDate(day.date);
  }
  if (tripStartDate) {
    try {
      const d = new Date(tripStartDate.slice(0, 10) + "T12:00:00");
      if (!isNaN(d.getTime())) {
        d.setDate(d.getDate() + (day.dayNumber - 1));
        return d.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" });
      }
    } catch { /* fall through */ }
  }
  return "";
}

function daysBetween(start: string, end: string): number {
  try {
    const diff = new Date(end.slice(0,10) + "T00:00:00").getTime() - new Date(start.slice(0,10) + "T00:00:00").getTime();
    return Math.max(0, Math.round(diff / 86400000)) + 1;
  } catch { return 0; }
}

function addDaysToDate(dateStr: string, n: number): string {
  const d = new Date(dateStr.slice(0, 10) + "T12:00:00");
  d.setDate(d.getDate() + n);
  return d.toISOString().slice(0, 10);
}

/** Show city/location part of an address, skipping leading street numbers */
function addressCity(address: string | undefined): string {
  if (!address) return "";
  const parts = address.split(",").map((p) => p.trim());
  // Skip first part if it looks like a pure number or is the same as stop name
  const city = parts.find((p, i) => i > 0 && !/^\d+$/.test(p));
  return city || parts[0] || "";
}

export default function TripDetail({
  trip, showAds = false, onUpdateTrip, onSelectStop, selectedStopId,
}: TripDetailProps) {
  const [tab, setTab] = useState<Tab>("days");
  const [editingStop, setEditingStop] = useState<{ dayId: string; stop: Stop | null } | null>(null);
  const [expandedDays, setExpandedDays] = useState<Set<string>>(() =>
    new Set(trip.days[0] ? [trip.days[0].id] : [])
  );
  const [copied, setCopied] = useState(false);
  const [showNotes, setShowNotes] = useState(!!trip.notes);
  const [showBudget, setShowBudget] = useState(trip.budgetAmount > 0);
  const [editingDayLocation, setEditingDayLocation] = useState<string | null>(null);
  const [dragState, setDragState] = useState<{ dayId: string; stopId: string } | null>(null);
  const [daysLimitWarning, setDaysLimitWarning] = useState(false);
  const [undoItem, setUndoItem] = useState<UndoItem | null>(null);
  const undoTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape" && editingStop) { setEditingStop(null); e.stopPropagation(); }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [editingStop]);

  useEffect(() => {
    setExpandedDays((prev) => {
      if (prev.size === 0 && trip.days[0]) return new Set([trip.days[0].id]);
      return prev;
    });
  }, [trip.id, trip.days]);

  // Clear undo on trip change
  useEffect(() => {
    setUndoItem(null);
    if (undoTimerRef.current) clearTimeout(undoTimerRef.current);
  }, [trip.id]);

  function scheduleUndo(item: UndoItem) {
    if (undoTimerRef.current) clearTimeout(undoTimerRef.current);
    setUndoItem(item);
    undoTimerRef.current = setTimeout(() => setUndoItem(null), 5000);
  }

  function handleUndo() {
    if (!undoItem) return;
    if (undoTimerRef.current) clearTimeout(undoTimerRef.current);
    if (undoItem.type === "stop") {
      const day = trip.days.find((d) => d.id === undoItem.dayId);
      if (day) {
        const stops = [...day.stops];
        stops.splice(undoItem.index, 0, undoItem.stop);
        updateDay(undoItem.dayId, { stops: stops.map((s, i) => ({ ...s, sortOrder: i })) });
      }
    } else if (undoItem.type === "day") {
      const days = [...trip.days];
      days.splice(undoItem.index, 0, undoItem.day);
      onUpdateTrip({ days: days.map((d, i) => ({ ...d, dayNumber: i + 1 })) });
      setExpandedDays((s) => new Set([...s, undoItem.day.id]));
    }
    setUndoItem(null);
  }

  function updateField<K extends keyof Trip>(key: K, value: Trip[K]) {
    onUpdateTrip({ [key]: value });
  }

  function addDay() {
    const maxNum = trip.days.reduce((m, d) => Math.max(m, d.dayNumber), 0);
    const lastDay = [...trip.days].sort((a,b) => a.dayNumber - b.dayNumber).pop();
    const nextDate = lastDay?.date ? addDaysToDate(lastDay.date, 1) : nowISO().slice(0, 10);
    const newDay: Day = { id: newId(), dayNumber: maxNum + 1, date: nextDate, notes: "", location: "", locationLatitude: 0, locationLongitude: 0, stops: [] };
    onUpdateTrip({ days: [...trip.days, newDay] });
    setExpandedDays((s) => new Set([...s, newDay.id]));
  }

  function generateDaysFromDates() {
    if (!trip.startDate || !trip.endDate) return;
    const count = daysBetween(trip.startDate, trip.endDate);
    if (count <= 0) return;
    if (count > 60) {
      setDaysLimitWarning(true);
      setTimeout(() => setDaysLimitWarning(false), 4000);
      return;
    }
    const existingByDate = new Map(trip.days.map((d) => [d.date, d]));
    const newDays: Day[] = Array.from({ length: count }, (_, i) => {
      const date = addDaysToDate(trip.startDate, i);
      const existing = existingByDate.get(date);
      return existing ? { ...existing, dayNumber: i + 1 } : {
        id: newId(), dayNumber: i + 1, date, notes: "", location: "", locationLatitude: 0, locationLongitude: 0, stops: [],
      };
    });
    onUpdateTrip({ days: newDays, hasCustomDates: true });
    if (newDays[0]) setExpandedDays(new Set([newDays[0].id]));
  }

  function deleteDay(dayId: string) {
    const idx = trip.days.findIndex((d) => d.id === dayId);
    const day = trip.days[idx];
    if (!day) return;
    onUpdateTrip({ days: trip.days.filter((d) => d.id !== dayId) });
    scheduleUndo({ type: "day", day, index: idx });
  }

  function toggleDay(dayId: string) {
    setExpandedDays((s) => { const n = new Set(s); if (n.has(dayId)) n.delete(dayId); else n.add(dayId); return n; });
  }

  function expandAllDays() {
    setExpandedDays(new Set(trip.days.map((d) => d.id)));
  }

  function collapseAllDays() {
    setExpandedDays(new Set());
  }

  function updateDay(dayId: string, changes: Partial<Day>) {
    onUpdateTrip({ days: trip.days.map((d) => d.id === dayId ? { ...d, ...changes } : d) });
  }

  function saveStop(dayId: string, stop: Stop) {
    const day = trip.days.find((d) => d.id === dayId);
    if (!day) return;
    const exists = day.stops.find((s) => s.id === stop.id);
    const newStops = exists ? day.stops.map((s) => s.id === stop.id ? stop : s) : [...day.stops, { ...stop, sortOrder: day.stops.length }];
    updateDay(dayId, { stops: newStops });
    setEditingStop(null);
  }

  function deleteStop(dayId: string, stopId: string) {
    const day = trip.days.find((d) => d.id === dayId);
    if (!day) return;
    const idx = day.stops.findIndex((s) => s.id === stopId);
    const stop = day.stops[idx];
    if (!stop) return;
    updateDay(dayId, { stops: day.stops.filter((s) => s.id !== stopId) });
    scheduleUndo({ type: "stop", stop, dayId, index: idx });
  }

  function toggleVisited(dayId: string, stop: Stop) {
    saveStop(dayId, { ...stop, isVisited: !stop.isVisited, visitedAt: !stop.isVisited ? nowISO() : undefined });
  }

  function handleDragStart(dayId: string, stopId: string) { setDragState({ dayId, stopId }); }
  function handleDragOver(e: React.DragEvent, dayId: string, targetStopId: string) {
    e.preventDefault();
    if (!dragState || dragState.dayId !== dayId || dragState.stopId === targetStopId) return;
    const day = trip.days.find((d) => d.id === dayId);
    if (!day) return;
    const stops = [...day.stops];
    const fromIdx = stops.findIndex((s) => s.id === dragState.stopId);
    const toIdx = stops.findIndex((s) => s.id === targetStopId);
    if (fromIdx === -1 || toIdx === -1) return;
    const [moved] = stops.splice(fromIdx, 1);
    stops.splice(toIdx, 0, moved);
    updateDay(dayId, { stops: stops.map((s, i) => ({ ...s, sortOrder: i })) });
  }
  function handleDragEnd() { setDragState(null); }

  async function toggleShare() {
    const newPublic = !trip.isPublic;
    onUpdateTrip({ isPublic: newPublic });
    if (newPublic && typeof window !== "undefined") {
      await navigator.clipboard.writeText(`${window.location.origin}/trip/${trip.id}`).catch(() => {});
      setCopied(true);
      setTimeout(() => setCopied(false), 2500);
    }
  }

  /** Best-effort location bias for place search in StopDialog.
   *  Priority: day's own pin → stop in that day → any stop in the trip. */
  function getLocationBias(dayId: string): { lat: number; lon: number } | undefined {
    const day = trip.days.find((d) => d.id === dayId);
    if (!day) return undefined;
    if (day.locationLatitude !== 0 || day.locationLongitude !== 0) {
      return { lat: day.locationLatitude, lon: day.locationLongitude };
    }
    const stopInDay = day.stops.find((s) => s.latitude !== 0 || s.longitude !== 0);
    if (stopInDay) return { lat: stopInDay.latitude, lon: stopInDay.longitude };
    for (const d of trip.days) {
      const s = d.stops.find((s) => s.latitude !== 0 || s.longitude !== 0);
      if (s) return { lat: s.latitude, lon: s.longitude };
    }
    return undefined;
  }

  const sortedDays = [...trip.days].sort((a, b) => a.dayNumber - b.dayNumber);
  const totalStops = trip.days.reduce((c, d) => c + d.stops.length, 0);
  const visitedStops = trip.days.reduce((c, d) => c + d.stops.filter((s) => s.isVisited).length, 0);

  const TABS: { key: Tab; label: string; count?: number; icon: LucideIcon }[] = [
    { key: "days",     label: "Days",     count: trip.days.length,              icon: Calendar  },
    { key: "bookings", label: "Bookings", count: trip.bookings.length || undefined, icon: Bookmark  },
    { key: "expenses", label: "Expenses", count: trip.expenses.length || undefined, icon: DollarSign},
    { key: "lists",    label: "Lists",    count: trip.lists.length || undefined, icon: List      },
  ];

  return (
    <div className="flex-1 flex flex-col overflow-hidden bg-slate-50 relative">
      {/* ── Trip header card ─────────────────────────────────────────────────── */}
      <div className="mx-4 mt-4 mb-0 bg-white rounded-xl shadow-card border border-slate-100 px-5 py-4 shrink-0 space-y-3">
        <input
          type="text"
          value={trip.name}
          onChange={(e) => updateField("name", e.target.value)}
          placeholder="Trip name"
          className="trip-title w-full text-[22px] font-extrabold text-slate-900 placeholder-slate-300 border-0 outline-none bg-transparent leading-tight"
        />
        <div className="flex items-center gap-1.5 group">
          <MapPin className="w-3.5 h-3.5 text-slate-300 shrink-0" />
          <input
            type="text"
            value={trip.destination}
            onChange={(e) => updateField("destination", e.target.value)}
            placeholder="Add destination…"
            className="flex-1 text-sm text-slate-600 placeholder-slate-300 border-0 outline-none bg-transparent hover:text-slate-700 focus:text-slate-800 transition-colors"
          />
        </div>

        {/* Controls row */}
        <div className="flex items-center gap-2 flex-wrap">
          <div className="flex items-center gap-1.5 text-xs text-slate-500">
            <Calendar className="w-3.5 h-3.5 text-slate-400" />
            <input type="date" value={trip.startDate?.slice(0,10) ?? ""}
              onChange={(e) => updateField("startDate", e.target.value)}
              className="border border-slate-200 rounded-lg px-2 py-1 text-xs bg-white focus:border-blue-400"
            />
            <span className="text-slate-300">→</span>
            <input type="date" value={trip.endDate?.slice(0,10) ?? ""}
              onChange={(e) => updateField("endDate", e.target.value)}
              className="border border-slate-200 rounded-lg px-2 py-1 text-xs bg-white focus:border-blue-400"
            />
          </div>

          {trip.startDate && trip.endDate && daysBetween(trip.startDate, trip.endDate) > 0 && (
            <button onClick={generateDaysFromDates}
              className="flex items-center gap-1 text-xs px-2 py-1 rounded-lg border border-slate-200 text-slate-500 hover:border-blue-300 hover:text-blue-600 transition-colors bg-white"
            >
              <Calendar className="w-3 h-3" />
              {trip.days.length === 0 ? "Generate days" : "Sync days"}
            </button>
          )}
          {daysLimitWarning && (
            <span className="text-[11px] text-amber-600 bg-amber-50 border border-amber-200 px-2 py-1 rounded-lg font-medium">
              Max 60 days
            </span>
          )}

          {/* Status segmented control */}
          <div className="flex items-center rounded-lg border border-slate-200 bg-slate-50 p-0.5 gap-0.5 shrink-0">
            {(["planning", "active", "completed"] as const).map((s) => (
              <button key={s} onClick={() => updateField("statusRaw", s)}
                className={cn(
                  "px-2.5 py-[3px] text-[11px] font-semibold rounded-md transition-all whitespace-nowrap",
                  trip.statusRaw === s
                    ? s === "planning" ? "bg-white text-blue-700 shadow-sm"
                    : s === "active"   ? "bg-white text-emerald-700 shadow-sm"
                    :                    "bg-white text-slate-500 shadow-sm"
                    : "text-slate-400 hover:text-slate-600"
                )}
              >
                {STATUS_CONFIG[s].label}
              </button>
            ))}
          </div>

          <button onClick={toggleShare}
            className={cn("flex items-center gap-1 text-xs px-2.5 py-1 rounded-lg border font-medium transition-colors",
              trip.isPublic ? "border-emerald-300 text-emerald-700 bg-emerald-50" : "border-slate-200 text-slate-500 hover:border-blue-300 hover:text-blue-600 bg-white"
            )}
          >
            {copied ? <><Check className="w-3 h-3" /> Copied!</> : trip.isPublic ? <><Share2 className="w-3 h-3" /> Shared</> : <><Share2 className="w-3 h-3" /> Share</>}
          </button>

          <button onClick={() => setShowBudget(!showBudget)}
            className={cn("flex items-center gap-1 text-xs px-2.5 py-1 rounded-lg border transition-colors font-medium",
              showBudget ? "border-blue-300 text-blue-700 bg-blue-50" : "border-slate-200 text-slate-500 hover:border-blue-300 bg-white"
            )}
          >
            <DollarSign className="w-3 h-3" /> Budget
          </button>

          <button onClick={() => setShowNotes(!showNotes)}
            className={cn("flex items-center gap-1 text-xs px-2.5 py-1 rounded-lg border transition-colors font-medium",
              showNotes ? "border-blue-300 text-blue-700 bg-blue-50" : "border-slate-200 text-slate-500 hover:border-blue-300 bg-white"
            )}
          >
            <FileText className="w-3 h-3" /> Notes
          </button>
        </div>

        {/* Progress bar */}
        {totalStops > 0 && (trip.statusRaw === "active" || trip.statusRaw === "completed") && (
          <div className="flex items-center gap-2">
            <div className="flex-1 h-1.5 bg-slate-100 rounded-full overflow-hidden">
              <div className="h-full rounded-full transition-all duration-500"
                style={{ width: `${Math.round((visitedStops / totalStops) * 100)}%`, background: "linear-gradient(90deg, #34d399, #14b8a6)" }} />
            </div>
            <span className="text-[11px] text-slate-400 shrink-0 font-medium">
              {visitedStops}/{totalStops} visited
            </span>
          </div>
        )}

        {/* Budget — animated expand */}
        <div className={cn("overflow-hidden transition-all duration-200 ease-in-out", showBudget ? "max-h-16 opacity-100" : "max-h-0 opacity-0 !mt-0")}>
          <div className="flex items-center gap-2 pt-1">
            <DollarSign className="w-4 h-4 text-slate-400 shrink-0" />
            <input type="number" min="0" step="0.01" value={trip.budgetAmount || ""}
              onChange={(e) => updateField("budgetAmount", parseFloat(e.target.value) || 0)}
              placeholder="Budget amount"
              className="border border-slate-200 rounded-lg px-2 py-1.5 text-sm w-28 bg-white focus:border-blue-400"
            />
            <select value={trip.budgetCurrencyCode || "USD"}
              onChange={(e) => updateField("budgetCurrencyCode", e.target.value)}
              className="text-sm border border-slate-200 rounded-lg px-2 py-1.5 bg-white focus:border-blue-400"
            >
              {CURRENCIES.map((c) => <option key={c} value={c}>{c}</option>)}
            </select>
          </div>
        </div>

        {/* Notes — animated expand */}
        <div className={cn("overflow-hidden transition-all duration-200 ease-in-out", showNotes ? "max-h-48 opacity-100" : "max-h-0 opacity-0 !mt-0")}>
          <textarea value={trip.notes} onChange={(e) => updateField("notes", e.target.value)}
            onInput={(e) => { const el = e.currentTarget; el.style.height = "auto"; el.style.height = Math.min(el.scrollHeight, 160) + "px"; }}
            placeholder="Trip notes…" rows={2}
            className="w-full text-sm text-slate-600 placeholder-slate-300 border border-slate-200 rounded-lg px-3 py-2 resize-none bg-white focus:border-blue-400"
          />
        </div>
      </div>

      {/* ── Tab bar ─────────────────────────────────────────────────────────── */}
      <div className="flex gap-1 px-4 pt-3 pb-0 shrink-0 items-end">
        {TABS.map((t) => (
          <button key={t.key} onClick={() => setTab(t.key)}
            className={cn(
              "flex items-center gap-1.5 px-3.5 py-2 text-xs font-semibold rounded-t-lg transition-colors border-b-2",
              tab === t.key
                ? "bg-white text-slate-900 border-b-blue-600 shadow-card border-x border-t border-slate-100"
                : "text-slate-500 hover:text-slate-700 border-b-transparent hover:bg-white/60"
            )}
          >
            <t.icon className={cn("w-3 h-3 shrink-0", tab === t.key ? "text-blue-500" : "text-slate-400")} />
            {t.label}
            {t.count !== undefined && t.count > 0 && (
              <span className={cn("px-1.5 py-0.5 rounded-full text-[10px] font-bold",
                tab === t.key ? "bg-blue-100 text-blue-700" : "bg-slate-200 text-slate-500"
              )}>
                {t.count}
              </span>
            )}
          </button>
        ))}
        {/* Expand/collapse all — only shown on days tab */}
        {tab === "days" && sortedDays.length > 1 && (
          <button
            onClick={() => expandedDays.size === sortedDays.length ? collapseAllDays() : expandAllDays()}
            title={expandedDays.size === sortedDays.length ? "Collapse all" : "Expand all"}
            className="ml-auto mb-0.5 flex items-center gap-1 text-[11px] text-slate-400 hover:text-blue-600 transition-colors px-2 py-1 rounded-lg hover:bg-blue-50"
          >
            <ChevronsUpDown className="w-3 h-3" />
            {expandedDays.size === sortedDays.length ? "Collapse all" : "Expand all"}
          </button>
        )}
        {/* Tab bar line */}
        <div className="flex-1 border-b-2 border-b-slate-100" />
      </div>

      {/* ── Tab content ────────────────────────────────────────────────────── */}
      {tab === "bookings" && <BookingsPanel trip={trip} onUpdateTrip={onUpdateTrip} />}
      {tab === "expenses" && <ExpensesPanel trip={trip} onUpdateTrip={onUpdateTrip} />}
      {tab === "lists" && <ListsPanel trip={trip} onUpdateTrip={onUpdateTrip} />}

      {/* ── Days tab ─────────────────────────────────────────────────────────── */}
      {tab === "days" && (
        <div className="flex-1 overflow-y-auto bg-white border-x border-b border-slate-100 shadow-card rounded-b-xl mx-4 tab-content">
          {sortedDays.length === 0 && (
            <div className="flex flex-col items-center justify-center py-16 px-8 text-center">
              <div className="w-14 h-14 rounded-2xl bg-blue-50 flex items-center justify-center mb-4">
                <Calendar className="w-7 h-7 text-blue-500" />
              </div>
              <p className="text-base font-semibold text-slate-700 mb-1">No days planned yet</p>
              <p className="text-sm text-slate-400 max-w-xs mb-5 leading-relaxed">
                {trip.startDate && trip.endDate
                  ? "Click \"Generate days\" above to auto-create days from your dates."
                  : "Set your trip dates above to auto-generate days, or add them manually."}
              </p>
              <button onClick={addDay}
                className="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white text-sm font-semibold rounded-lg hover:bg-blue-700 transition-colors shadow-sm"
              >
                <Plus className="w-4 h-4" /> Add First Day
              </button>
            </div>
          )}

          {sortedDays.map((day, dayIdx) => {
            const isExpanded = expandedDays.has(day.id);
            const sortedStops = [...day.stops].sort((a, b) => a.sortOrder - b.sortOrder);
            const displayDate = getEffectiveDate(day, trip.startDate);

            // Mini category icons for collapsed preview
            const stopCategories = sortedStops.map((s) => s.categoryRaw);
            const uniqueCategories = [...new Set(stopCategories)].slice(0, 5);

            return (
              <div key={day.id}>
                {showAds && dayIdx > 0 && dayIdx % 3 === 0 && (
                  <div className="px-5 py-2 flex justify-center">
                    <AdUnit slot="BETWEEN_DAYS_SLOT" format="horizontal" style={{ width: 468, height: 60 }} />
                  </div>
                )}

                {/* ── Day header ────────────────────────────────────────────── */}
                <div
                  className={cn(
                    "day-row flex items-center gap-3 px-4 py-3.5 cursor-pointer hover:bg-slate-50/80 group border-b border-slate-100 transition-colors",
                    isExpanded && "bg-slate-50/50"
                  )}
                  onClick={() => toggleDay(day.id)}
                >
                  {/* Day number circle */}
                  <div className={cn(
                    "day-circle w-7 h-7 rounded-full text-[11px] font-bold flex items-center justify-center shrink-0 shadow-sm",
                    isExpanded
                      ? "text-white"
                      : "bg-slate-100 text-slate-600 group-hover:text-white"
                  )}
                  style={isExpanded ? { background: "linear-gradient(135deg, #1e293b, #0f172a)" } : undefined}
                  onMouseEnter={(e) => { if (!isExpanded) e.currentTarget.style.background = "linear-gradient(135deg, #334155, #1e293b)"; }}
                  onMouseLeave={(e) => { if (!isExpanded) e.currentTarget.style.background = ""; }}
                  >
                    {day.dayNumber}
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      {editingDayLocation === day.id ? (
                        <input autoFocus type="text" value={day.location}
                          onClick={(e) => e.stopPropagation()}
                          onChange={(e) => updateDay(day.id, { location: e.target.value })}
                          onBlur={() => setEditingDayLocation(null)}
                          onKeyDown={(e) => { if (e.key === "Enter") setEditingDayLocation(null); }}
                          placeholder="Day location…"
                          className="text-sm font-semibold text-slate-900 border-0 outline-none bg-transparent"
                        />
                      ) : (
                        <span
                          className="text-sm font-semibold text-slate-900 cursor-text hover:text-blue-600 transition-colors"
                          onClick={(e) => { e.stopPropagation(); setEditingDayLocation(day.id); }}
                        >
                          {day.location || `Day ${day.dayNumber}`}
                        </span>
                      )}
                      {displayDate && (
                        <span className="text-[10px] text-slate-500 bg-slate-100 px-2 py-0.5 rounded-full font-medium shrink-0">{displayDate}</span>
                      )}
                      {!isExpanded && day.stops.length > 0 && (
                        <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-slate-100 text-slate-500 font-medium">
                          {day.stops.length} stop{day.stops.length !== 1 ? "s" : ""}
                        </span>
                      )}
                    </div>
                    {/* Collapsed summary: location placeholder or mini category icons */}
                    {!isExpanded && (
                      <div className="flex items-center gap-2 mt-0.5">
                        {!editingDayLocation && !day.location && (
                          <div className="flex items-center gap-1">
                            <MapPin className="w-3 h-3 text-slate-300" />
                            <span className="text-xs text-slate-300 cursor-text"
                              onClick={(e) => { e.stopPropagation(); setEditingDayLocation(day.id); }}>
                              Add location…
                            </span>
                          </div>
                        )}
                        {uniqueCategories.length > 0 && (
                          <div className="flex items-center gap-1">
                            {uniqueCategories.map((cat) => {
                              const CatIcon = CATEGORY_ICON_MAP[cat] ?? MapPin;
                              return (
                                <span key={cat} className="w-4 h-4 rounded-full flex items-center justify-center"
                                  style={{ backgroundColor: `${CATEGORY_COLORS[cat]}22` }}>
                                  <CatIcon className="w-2 h-2" style={{ color: CATEGORY_COLORS[cat] }} />
                                </span>
                              );
                            })}
                          </div>
                        )}
                      </div>
                    )}
                    {isExpanded && !editingDayLocation && !day.location && (
                      <div className="flex items-center gap-1 mt-0.5">
                        <MapPin className="w-3 h-3 text-slate-300" />
                        <span className="text-xs text-slate-300 cursor-text"
                          onClick={(e) => { e.stopPropagation(); setEditingDayLocation(day.id); }}>
                          Add location…
                        </span>
                      </div>
                    )}
                  </div>

                  {/* Date picker + delete (hidden until hover) */}
                  <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <input type="date" value={day.date?.slice(0, 10) ?? ""}
                      onClick={(e) => e.stopPropagation()}
                      onChange={(e) => updateDay(day.id, { date: e.target.value })}
                      className="text-xs border border-slate-200 rounded px-1.5 py-0.5 bg-white cursor-pointer w-[6.5rem]"
                    />
                    <button onClick={(e) => { e.stopPropagation(); deleteDay(day.id); }}
                      className="p-1 rounded-md hover:bg-red-50 text-slate-300 hover:text-red-500 transition-colors"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>

                  {isExpanded
                    ? <ChevronUp className="w-4 h-4 text-slate-300 shrink-0" />
                    : <ChevronDown className="w-4 h-4 text-slate-300 shrink-0" />
                  }
                </div>

                {/* ── Stops ─────────────────────────────────────────────────── */}
                {isExpanded && (
                  <div className="py-2 px-3 space-y-1.5 day-stops-enter">
                    {sortedStops.length === 0 && (
                      <p className="text-xs text-slate-300 text-center py-2 italic">No stops added yet</p>
                    )}
                    {sortedStops.map((stop, stopIdx) => (
                      <div
                        key={stop.id}
                        draggable
                        onDragStart={() => handleDragStart(day.id, stop.id)}
                        onDragOver={(e) => handleDragOver(e, day.id, stop.id)}
                        onDragEnd={handleDragEnd}
                        onClick={() => onSelectStop?.(stop.id)}
                        className={cn(
                          "group flex items-stretch rounded-xl border cursor-pointer transition-all overflow-hidden",
                          dragState?.stopId === stop.id
                            ? "border-blue-400 ring-2 ring-blue-300/40 shadow-[0_0_0_2px_rgba(59,130,246,0.12)] opacity-60"
                            : selectedStopId === stop.id
                            ? "border-blue-300 bg-blue-50/60 shadow-[0_0_0_2px_rgba(59,130,246,0.15)]"
                            : stop.isVisited
                            ? "border-emerald-100 bg-emerald-50/30 hover:border-emerald-200"
                            : "border-slate-100 bg-white shadow-card hover:shadow-card-hover hover:border-slate-200"
                        )}
                      >
                        {/* Category accent bar — w-1.5 for better visibility */}
                        <div className="w-1.5 shrink-0 rounded-l-xl transition-all"
                          style={{ backgroundColor: stop.isVisited ? `${CATEGORY_COLORS[stop.categoryRaw]}66` : CATEGORY_COLORS[stop.categoryRaw] }} />

                        {/* Drag handle */}
                        <div className="flex items-center px-1.5 opacity-0 group-hover:opacity-100 transition-opacity cursor-grab active:cursor-grabbing">
                          <GripVertical className="w-3 h-3 text-slate-300" />
                        </div>

                        {/* Stop order number */}
                        <div className="text-[10px] font-bold text-slate-200 w-4 text-center shrink-0 select-none self-start pt-3 group-hover:text-slate-300 transition-colors">
                          {stopIdx + 1}
                        </div>

                        {/* Content */}
                        <div className="flex-1 flex items-start gap-3 px-3 py-2.5 min-w-0">
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-1.5">
                              <span className={cn(
                                "text-sm font-semibold leading-snug",
                                stop.isVisited ? "text-slate-400" : "text-slate-900"
                              )}>
                                {stop.name}
                              </span>
                              {stop.isVisited && (
                                <span className="inline-flex items-center gap-0.5 text-[10px] font-semibold text-emerald-600 bg-emerald-50 px-1.5 py-0.5 rounded-full shrink-0">
                                  <Check className="w-2.5 h-2.5" /> Visited
                                </span>
                              )}
                            </div>

                            <div className="flex items-center gap-1.5 mt-0.5 flex-wrap">
                              {(() => {
                                const CatIcon = CATEGORY_ICON_MAP[stop.categoryRaw] ?? MapPin;
                                return (
                                  <span className="inline-flex items-center gap-1 text-[11px] font-medium px-1.5 py-0.5 rounded-full"
                                    style={{ backgroundColor: `${CATEGORY_COLORS[stop.categoryRaw]}18`, color: CATEGORY_COLORS[stop.categoryRaw] }}>
                                    <CatIcon className="w-2.5 h-2.5 shrink-0" />
                                    {CATEGORY_LABELS[stop.categoryRaw]}
                                  </span>
                                );
                              })()}
                              {stop.address && (() => {
                                const city = addressCity(stop.address);
                                return city ? <span className="text-[11px] text-slate-400 truncate max-w-[140px]">{city}</span> : null;
                              })()}
                            </div>

                            <div className="flex items-center gap-2.5 mt-1 flex-wrap">
                              {stop.arrivalTime && (
                                <span className="text-[11px] text-slate-500 flex items-center gap-1">
                                  <Clock className="w-3 h-3 shrink-0" />
                                  {new Date(stop.arrivalTime).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                                  {stop.departureTime && ` – ${new Date(stop.departureTime).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`}
                                </span>
                              )}
                              {stop.flightNumber && (
                                <span className="text-[11px] text-blue-600 flex items-center gap-1">
                                  <Plane className="w-3 h-3 shrink-0" />
                                  {[stop.airline, stop.flightNumber].filter(Boolean).join(" ")}
                                  {stop.departureAirport && stop.arrivalAirport && ` ${stop.departureAirport}→${stop.arrivalAirport}`}
                                </span>
                              )}
                              {stop.rating > 0 && (
                                <span className="flex items-center gap-0.5">
                                  {[1,2,3,4,5].map((n) => (
                                    <Star key={n} className={cn("w-2.5 h-2.5",
                                      n <= stop.rating ? "text-amber-400 fill-amber-400" : "text-slate-200"
                                    )} />
                                  ))}
                                </span>
                              )}
                              {stop.todos.length > 0 && (
                                <span className="text-[11px] text-slate-400 flex items-center gap-0.5">
                                  <Check className="w-2.5 h-2.5 text-emerald-400" />
                                  {stop.todos.filter((t) => t.isCompleted).length}/{stop.todos.length}
                                </span>
                              )}
                              {stop.website && (
                                <a href={stop.website} target="_blank" rel="noopener noreferrer"
                                  onClick={(e) => e.stopPropagation()}
                                  className="text-[11px] text-blue-500 hover:underline flex items-center gap-0.5"
                                >
                                  <ExternalLink className="w-2.5 h-2.5" /> Website
                                </a>
                              )}
                            </div>
                          </div>

                          {/* Stop actions — visited always visible; edit/delete appear on hover */}
                          <div className="flex items-center gap-0.5 shrink-0">
                            <button onClick={(e) => { e.stopPropagation(); toggleVisited(day.id, stop); }}
                              className={cn("w-7 h-7 rounded-lg flex items-center justify-center transition-colors",
                                stop.isVisited ? "bg-emerald-50 text-emerald-600" : "text-slate-300 hover:bg-emerald-50 hover:text-emerald-600"
                              )}
                              title={stop.isVisited ? "Mark unvisited" : "Mark visited"}
                            >
                              <Check className="w-3.5 h-3.5" />
                            </button>
                            <button onClick={(e) => { e.stopPropagation(); setEditingStop({ dayId: day.id, stop }); }}
                              className="w-7 h-7 rounded-lg flex items-center justify-center text-slate-300 hover:bg-slate-100 hover:text-slate-600 transition-all opacity-0 group-hover:opacity-100"
                              title="Edit stop"
                            >
                              <Pencil className="w-3.5 h-3.5" />
                            </button>
                            <button onClick={(e) => { e.stopPropagation(); deleteStop(day.id, stop.id); }}
                              className="w-7 h-7 rounded-lg flex items-center justify-center text-slate-300 hover:bg-red-50 hover:text-red-500 transition-all opacity-0 group-hover:opacity-100"
                              title="Delete stop"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          </div>
                        </div>
                      </div>
                    ))}

                    {/* Add stop — dashed card style */}
                    <button onClick={() => setEditingStop({ dayId: day.id, stop: null })}
                      className="group flex items-center gap-2 w-full px-3 py-2.5 rounded-xl text-sm text-slate-400 hover:text-blue-500 transition-all border border-dashed border-transparent hover:border-blue-200 hover:bg-blue-50/30 mt-0.5"
                    >
                      <div className="w-5 h-5 rounded-full border border-slate-300 group-hover:border-blue-400 group-hover:bg-blue-50 flex items-center justify-center transition-all shrink-0">
                        <Plus className="w-3 h-3" />
                      </div>
                      Add stop
                    </button>
                  </div>
                )}
              </div>
            );
          })}

          {/* Add day — clean text button */}
          {sortedDays.length > 0 && (
            <button onClick={addDay}
              className="flex items-center gap-2 px-4 py-3.5 w-full text-sm text-slate-400 hover:text-blue-500 hover:bg-blue-50/40 transition-all border-t border-slate-100 group"
            >
              <div className="w-5 h-5 rounded-full border border-slate-300 group-hover:border-blue-400 flex items-center justify-center transition-colors shrink-0">
                <Plus className="w-3 h-3" />
              </div>
              Add day
            </button>
          )}
        </div>
      )}

      {/* ── Undo toast ────────────────────────────────────────────────────────── */}
      {undoItem && (
        <div className="absolute bottom-4 left-1/2 -translate-x-1/2 z-50 flex flex-col overflow-hidden rounded-xl shadow-[0_8px_24px_rgba(0,0,0,0.3)] bg-slate-900" style={{ minWidth: 220 }}>
          <div className="flex items-center gap-3 px-4 py-2.5">
            <span className="text-sm text-slate-300 whitespace-nowrap">
              {undoItem.type === "stop" ? `"${undoItem.stop.name}" deleted` : `Day ${undoItem.day.dayNumber} deleted`}
            </span>
            <button
              onClick={handleUndo}
              className="flex items-center gap-1 text-blue-400 hover:text-blue-300 font-semibold text-sm transition-colors shrink-0"
            >
              <RotateCcw className="w-3.5 h-3.5" />
              Undo
            </button>
          </div>
          {/* Progress bar — depletes over 5s */}
          <div className="h-0.5 bg-white/10">
            <div key={undoItem.type + (undoItem.type === "stop" ? undoItem.stop.id : undoItem.day.id)} className="undo-progress h-full bg-blue-500/70 rounded-full" />
          </div>
        </div>
      )}

      {editingStop && (
        <StopDialog
          stop={editingStop.stop}
          locationBias={getLocationBias(editingStop.dayId)}
          onSave={(stop) => saveStop(editingStop.dayId, stop)}
          onClose={() => setEditingStop(null)}
        />
      )}
    </div>
  );
}
