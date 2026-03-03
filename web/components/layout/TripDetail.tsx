"use client";

import { useState } from "react";
import {
  Plus,
  Trash2,
  ChevronDown,
  ChevronUp,
  MapPin,
  Share2,
  Check,
  ExternalLink,
  Star,
} from "lucide-react";
import type { Trip, Day, Stop } from "@/lib/types";
import { CATEGORY_LABELS, CATEGORY_COLORS, newId, nowISO } from "@/lib/types";
import { cn } from "@/components/ui/cn";
import StopDialog from "@/components/stops/StopDialog";
import AdUnit from "@/components/ads/AdUnit";

interface TripDetailProps {
  trip: Trip;
  showAds?: boolean;
  onUpdateTrip: (changes: Partial<Trip>) => void;
  onSelectStop?: (stopId: string | null) => void;
  selectedStopId?: string | null;
}

export default function TripDetail({
  trip,
  showAds = false,
  onUpdateTrip,
  onSelectStop,
  selectedStopId,
}: TripDetailProps) {
  const [editingStop, setEditingStop] = useState<{ dayId: string; stop: Stop | null } | null>(null);
  const [expandedDays, setExpandedDays] = useState<Set<string>>(() => {
    // Expand the first day by default
    const s = new Set<string>();
    if (trip.days[0]) s.add(trip.days[0].id);
    return s;
  });
  const [copied, setCopied] = useState(false);

  // ─── Trip header edits ──────────────────────────────────────────────────────
  function updateField<K extends keyof Trip>(key: K, value: Trip[K]) {
    onUpdateTrip({ [key]: value });
  }

  // ─── Days ────────────────────────────────────────────────────────────────────
  function addDay() {
    const maxNum = trip.days.reduce((m, d) => Math.max(m, d.dayNumber), 0);
    const newDay: Day = {
      id: newId(),
      dayNumber: maxNum + 1,
      date: nowISO().slice(0, 10),
      notes: "",
      location: "",
      locationLatitude: 0,
      locationLongitude: 0,
      stops: [],
    };
    onUpdateTrip({ days: [...trip.days, newDay] });
    setExpandedDays((s) => new Set([...s, newDay.id]));
  }

  function deleteDay(dayId: string) {
    onUpdateTrip({ days: trip.days.filter((d) => d.id !== dayId) });
  }

  function toggleDay(dayId: string) {
    setExpandedDays((s) => {
      const next = new Set(s);
      if (next.has(dayId)) next.delete(dayId);
      else next.add(dayId);
      return next;
    });
  }

  function updateDay(dayId: string, changes: Partial<Day>) {
    onUpdateTrip({
      days: trip.days.map((d) => (d.id === dayId ? { ...d, ...changes } : d)),
    });
  }

  // ─── Stops ───────────────────────────────────────────────────────────────────
  function saveStop(dayId: string, stop: Stop) {
    const day = trip.days.find((d) => d.id === dayId);
    if (!day) return;
    const exists = day.stops.find((s) => s.id === stop.id);
    const newStops = exists
      ? day.stops.map((s) => (s.id === stop.id ? stop : s))
      : [...day.stops, { ...stop, sortOrder: day.stops.length }];
    updateDay(dayId, { stops: newStops });
    setEditingStop(null);
  }

  function deleteStop(dayId: string, stopId: string) {
    const day = trip.days.find((d) => d.id === dayId);
    if (!day) return;
    updateDay(dayId, { stops: day.stops.filter((s) => s.id !== stopId) });
  }

  function toggleVisited(dayId: string, stop: Stop) {
    const updated = {
      ...stop,
      isVisited: !stop.isVisited,
      visitedAt: !stop.isVisited ? nowISO() : undefined,
    };
    saveStop(dayId, updated);
  }

  // ─── Sharing ─────────────────────────────────────────────────────────────────
  async function toggleShare() {
    const newPublic = !trip.isPublic;
    onUpdateTrip({ isPublic: newPublic });
    if (newPublic && typeof window !== "undefined") {
      const url = `${window.location.origin}/trip/${trip.id}`;
      await navigator.clipboard.writeText(url).catch(() => {});
      setCopied(true);
      setTimeout(() => setCopied(false), 2500);
    }
  }

  const sortedDays = [...trip.days].sort((a, b) => a.dayNumber - b.dayNumber);

  return (
    <div className="flex-1 overflow-y-auto bg-white">
      {/* Trip header */}
      <div className="px-5 py-4 border-b border-slate-100 space-y-3">
        <input
          type="text"
          value={trip.name}
          onChange={(e) => updateField("name", e.target.value)}
          placeholder="Trip name"
          className="w-full text-xl font-bold text-slate-800 placeholder-slate-300 border-0 outline-none bg-transparent"
        />
        <input
          type="text"
          value={trip.destination}
          onChange={(e) => updateField("destination", e.target.value)}
          placeholder="Destination"
          className="w-full text-sm text-slate-500 placeholder-slate-300 border-0 outline-none bg-transparent"
        />
        <div className="flex items-center gap-3 flex-wrap">
          <div className="flex items-center gap-1 text-xs text-slate-500">
            <span>From</span>
            <input
              type="date"
              value={trip.startDate?.slice(0, 10) ?? ""}
              onChange={(e) => updateField("startDate", e.target.value)}
              className="border border-slate-200 rounded px-2 py-0.5 text-xs focus:outline-none focus:ring-1 focus:ring-blue-400"
            />
            <span>to</span>
            <input
              type="date"
              value={trip.endDate?.slice(0, 10) ?? ""}
              onChange={(e) => updateField("endDate", e.target.value)}
              className="border border-slate-200 rounded px-2 py-0.5 text-xs focus:outline-none focus:ring-1 focus:ring-blue-400"
            />
          </div>

          <select
            value={trip.statusRaw}
            onChange={(e) => updateField("statusRaw", e.target.value as Trip["statusRaw"])}
            className="text-xs border border-slate-200 rounded px-2 py-0.5 focus:outline-none focus:ring-1 focus:ring-blue-400"
          >
            <option value="planning">Planning</option>
            <option value="active">Active</option>
            <option value="completed">Completed</option>
          </select>

          <button
            onClick={toggleShare}
            className={cn(
              "flex items-center gap-1 text-xs px-2 py-0.5 rounded border transition-colors",
              trip.isPublic
                ? "border-green-400 text-green-700 bg-green-50"
                : "border-slate-200 text-slate-500 hover:border-blue-400"
            )}
          >
            {copied ? (
              <><Check className="w-3 h-3" /> Link copied!</>
            ) : trip.isPublic ? (
              <><Share2 className="w-3 h-3" /> Shared</>
            ) : (
              <><Share2 className="w-3 h-3" /> Share</>
            )}
          </button>
        </div>
      </div>

      {/* Days */}
      {sortedDays.map((day, dayIdx) => (
        <div key={day.id}>
          {/* Ad between days */}
          {showAds && dayIdx > 0 && (
            <div className="px-5 py-2 flex justify-center">
              <AdUnit slot="BETWEEN_DAYS_SLOT" format="horizontal" style={{ width: 468, height: 60 }} />
            </div>
          )}

          {/* Day header */}
          <div
            className="flex items-center gap-2 px-5 py-3 cursor-pointer hover:bg-slate-50 border-b border-slate-100 group"
            onClick={() => toggleDay(day.id)}
          >
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <span className="text-sm font-semibold text-slate-700">
                  Day {day.dayNumber}
                </span>
                {day.date && (
                  <input
                    type="date"
                    value={day.date}
                    onClick={(e) => e.stopPropagation()}
                    onChange={(e) => updateDay(day.id, { date: e.target.value })}
                    className="text-xs text-slate-400 border-0 outline-none bg-transparent cursor-pointer"
                  />
                )}
              </div>
              {day.location && (
                <div className="text-xs text-slate-400 flex items-center gap-1 mt-0.5">
                  <MapPin className="w-3 h-3" />
                  {day.location}
                </div>
              )}
            </div>
            <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  deleteDay(day.id);
                }}
                className="p-1 rounded hover:bg-red-50 text-slate-300 hover:text-red-500 transition-colors"
              >
                <Trash2 className="w-3.5 h-3.5" />
              </button>
            </div>
            {expandedDays.has(day.id) ? (
              <ChevronUp className="w-4 h-4 text-slate-400" />
            ) : (
              <ChevronDown className="w-4 h-4 text-slate-400" />
            )}
          </div>

          {/* Stops */}
          {expandedDays.has(day.id) && (
            <div className="pb-2">
              {day.stops
                .slice()
                .sort((a, b) => a.sortOrder - b.sortOrder)
                .map((stop) => (
                  <div
                    key={stop.id}
                    className={cn(
                      "group flex items-start gap-3 px-5 py-3 border-b border-slate-50 hover:bg-slate-50 cursor-pointer transition-colors",
                      selectedStopId === stop.id && "bg-blue-50 hover:bg-blue-50"
                    )}
                    onClick={() => onSelectStop?.(stop.id)}
                  >
                    {/* Category dot */}
                    <div
                      className="w-3 h-3 rounded-full mt-1 shrink-0"
                      style={{ backgroundColor: CATEGORY_COLORS[stop.categoryRaw] }}
                    />
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-1">
                        <span
                          className={cn(
                            "text-sm font-medium",
                            stop.isVisited ? "line-through text-slate-400" : "text-slate-800"
                          )}
                        >
                          {stop.name}
                        </span>
                        {stop.isVisited && (
                          <Check className="w-3.5 h-3.5 text-green-500" />
                        )}
                      </div>
                      <div className="text-xs text-slate-400 mt-0.5">
                        {CATEGORY_LABELS[stop.categoryRaw]}
                        {stop.address && ` · ${stop.address.split(",")[0]}`}
                      </div>
                      {stop.arrivalTime && (
                        <div className="text-xs text-slate-400">
                          {new Date(stop.arrivalTime).toLocaleTimeString([], {
                            hour: "2-digit",
                            minute: "2-digit",
                          })}
                        </div>
                      )}
                      {stop.rating > 0 && (
                        <div className="flex items-center gap-0.5 mt-0.5">
                          {[1, 2, 3, 4, 5].map((n) => (
                            <Star
                              key={n}
                              className={cn(
                                "w-3 h-3",
                                n <= stop.rating ? "text-yellow-400 fill-yellow-400" : "text-slate-200"
                              )}
                            />
                          ))}
                        </div>
                      )}
                      {stop.website && (
                        <a
                          href={stop.website}
                          target="_blank"
                          rel="noopener noreferrer"
                          onClick={(e) => e.stopPropagation()}
                          className="text-xs text-blue-500 hover:underline flex items-center gap-0.5 mt-0.5"
                        >
                          <ExternalLink className="w-3 h-3" />
                          Website
                        </a>
                      )}
                    </div>
                    {/* Actions */}
                    <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          toggleVisited(day.id, stop);
                        }}
                        className="p-1 rounded hover:bg-green-50 text-slate-300 hover:text-green-600 transition-colors"
                        title={stop.isVisited ? "Mark unvisited" : "Mark visited"}
                      >
                        <Check className="w-3.5 h-3.5" />
                      </button>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setEditingStop({ dayId: day.id, stop });
                        }}
                        className="p-1 rounded hover:bg-slate-200 text-slate-300 hover:text-slate-600 transition-colors text-xs"
                        title="Edit stop"
                      >
                        ✏️
                      </button>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          deleteStop(day.id, stop.id);
                        }}
                        className="p-1 rounded hover:bg-red-50 text-slate-300 hover:text-red-500 transition-colors"
                        title="Delete stop"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                ))}

              {/* Add stop button */}
              <button
                onClick={() => setEditingStop({ dayId: day.id, stop: null })}
                className="flex items-center gap-2 px-5 py-2.5 w-full text-sm text-blue-500 hover:bg-blue-50 transition-colors"
              >
                <Plus className="w-4 h-4" />
                Add stop
              </button>
            </div>
          )}
        </div>
      ))}

      {/* Add day */}
      <button
        onClick={addDay}
        className="flex items-center gap-2 px-5 py-3 w-full text-sm text-slate-500 hover:bg-slate-50 transition-colors border-t border-slate-100"
      >
        <Plus className="w-4 h-4" />
        Add day
      </button>

      {/* Stop edit dialog */}
      {editingStop && (
        <StopDialog
          stop={editingStop.stop}
          onSave={(stop) => saveStop(editingStop.dayId, stop)}
          onClose={() => setEditingStop(null)}
        />
      )}
    </div>
  );
}
