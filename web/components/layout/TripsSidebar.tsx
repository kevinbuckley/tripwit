"use client";

import { useState, useCallback, useEffect } from "react";
import { Plus, Trash2, Upload, Download, Copy, MapPin, LogOut, Smartphone, CalendarDays, Sparkles, Camera } from "lucide-react";
import Image from "next/image";
import type { Trip } from "@/lib/types";
import type { User } from "@supabase/supabase-js";
import { cn } from "@/components/ui/cn";
import { parseTripwitFile } from "@/lib/tripwit-parser";
import { downloadTripwit } from "@/lib/tripwit-exporter";

type TripTab = "upcoming" | "wishlist" | "memories";

function categorizeTripTab(trip: Trip): TripTab {
  const now = new Date();
  const todayStr = now.toISOString().slice(0, 10);

  // If no meaningful dates, it's a wishlist trip
  if (!trip.hasCustomDates || !trip.startDate || !trip.endDate) return "wishlist";

  const endStr = trip.endDate.slice(0, 10);
  // Past trips → memories
  if (endStr < todayStr) return "memories";

  // Future or current trips → upcoming
  return "upcoming";
}

interface TripsSidebarProps {
  trips: Trip[];
  selectedTripId: string | null;
  userId: string;
  user?: User | null;
  onSelectTrip: (id: string) => void;
  onCreateTrip: () => void;
  onDeleteTrip: (id: string) => void;
  onImportTrip: (trip: Trip) => void;
  onDuplicateTrip?: (trip: Trip) => void;
  onSignOut?: () => void;
}

const STATUS_DOT: Record<string, string> = {
  planning: "bg-blue-400",
  active:   "bg-emerald-400",
  completed:"bg-slate-500",
};

const STATUS_DOT_PULSE: Record<string, boolean> = {
  planning: false,
  active:   true,
  completed:false,
};

function formatTripDates(start: string, end: string): string {
  if (!start) return "";
  try {
    const s0 = start.slice(0, 10);
    const e0 = (end || start).slice(0, 10);
    const s = new Date(s0 + "T12:00:00");
    const e = new Date(e0 + "T12:00:00");
    if (isNaN(s.getTime())) return "";
    const opts: Intl.DateTimeFormatOptions = { month: "short", day: "numeric" };
    if (s0 === e0) return s.toLocaleDateString(undefined, opts);
    return `${s.toLocaleDateString(undefined, opts)} – ${e.toLocaleDateString(undefined, opts)}`;
  } catch { return ""; }
}

const IconBtn = ({ onClick, title, children }: { onClick?: () => void; title: string; children: React.ReactNode }) => (
  <button
    onClick={onClick}
    title={title}
    className="w-7 h-7 flex items-center justify-center rounded-lg text-slate-400 hover:text-slate-200 hover:bg-white/8 transition-colors"
  >
    {children}
  </button>
);

export default function TripsSidebar({
  trips, selectedTripId, userId, user, onSelectTrip, onCreateTrip, onDeleteTrip, onImportTrip, onDuplicateTrip, onSignOut,
}: TripsSidebarProps) {
  const [activeTab, setActiveTab] = useState<TripTab>("upcoming");
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null);
  const [importError, setImportError] = useState<string | null>(null);
  const [dragOver, setDragOver] = useState(false);

  // Auto-switch tab when the selected trip is in a different category
  useEffect(() => {
    if (!selectedTripId) return;
    const selected = trips.find((t) => t.id === selectedTripId);
    if (!selected) return;
    const tab = categorizeTripTab(selected);
    setActiveTab(tab);
  }, [selectedTripId, trips]);

  const tabCounts = { upcoming: 0, wishlist: 0, memories: 0 };
  const filteredTrips: Trip[] = [];
  for (const t of trips) {
    const tab = categorizeTripTab(t);
    tabCounts[tab]++;
    if (tab === activeTab) filteredTrips.push(t);
  }

  async function importFile(file: File) {
    try {
      const text = await file.text();
      const trip = parseTripwitFile(JSON.parse(text), userId);
      onImportTrip(trip);
      setImportError(null);
    } catch {
      setImportError("Couldn't read .tripwit file.");
      setTimeout(() => setImportError(null), 3000);
    }
  }

  async function handleImport(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (file) await importFile(file);
    e.target.value = "";
  }

  const handleDragOver = useCallback((e: React.DragEvent) => { e.preventDefault(); setDragOver(true); }, []);
  const handleDragLeave = useCallback((e: React.DragEvent) => { e.preventDefault(); setDragOver(false); }, []);
  const handleDrop = useCallback(
    async (e: React.DragEvent) => {
      e.preventDefault();
      setDragOver(false);
      const file = e.dataTransfer.files?.[0];
      if (file && (file.name.endsWith(".tripwit") || file.name.endsWith(".json"))) {
        await importFile(file);
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [userId, onImportTrip]
  );

  const selectedTrip = trips.find((t) => t.id === selectedTripId);

  return (
    <aside
      className="w-full flex flex-col h-full select-none bg-[#0c111d] border-r border-white/5"
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      {/* ── Logo header ─────────────────────────────── */}
      <div className="flex items-center gap-2.5 px-4 h-14 border-b border-white/5 shrink-0">
        <img src="/icon-512.png" alt="TripWit" className="w-7 h-7 rounded-xl object-cover shadow-sm shrink-0" />
        <span className="text-white font-semibold text-[15px] tracking-tight">TripWit</span>
      </div>

      {/* ── Section header + actions ─────────────────── */}
      <div className="flex items-center justify-between px-4 pt-5 pb-2 shrink-0">
        <div className="flex items-center gap-2">
          <span className="text-[10px] font-semibold text-slate-500 uppercase tracking-widest">
            My Trips
          </span>
          {trips.length > 0 && (
            <span className="text-[10px] font-bold text-slate-500 bg-white/8 px-1.5 py-0.5 rounded-full tabular-nums">
              {trips.length}
            </span>
          )}
        </div>
        <div className="flex items-center gap-0.5">
          {selectedTrip && (
            <IconBtn onClick={() => downloadTripwit(selectedTrip)} title="Export .tripwit">
              <Download className="w-3.5 h-3.5" />
            </IconBtn>
          )}
          {selectedTrip && onDuplicateTrip && (
            <IconBtn onClick={() => onDuplicateTrip(selectedTrip)} title="Duplicate trip">
              <Copy className="w-3.5 h-3.5" />
            </IconBtn>
          )}
          <label title="Import .tripwit" className="w-7 h-7 flex items-center justify-center rounded-lg text-slate-400 hover:text-slate-200 hover:bg-white/8 transition-colors cursor-pointer">
            <Upload className="w-3.5 h-3.5" />
            <input type="file" accept=".tripwit,.json" className="hidden" onChange={handleImport} />
          </label>
          <button
            onClick={onCreateTrip}
            title="New trip (⌘N)"
            className="w-7 h-7 flex items-center justify-center rounded-lg bg-blue-600 text-white hover:bg-blue-500 transition-colors shadow-sm"
          >
            <Plus className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {/* ── Trip category tabs ─────────────────────── */}
      <div className="flex items-center gap-0.5 px-3 pb-2 shrink-0">
        {([
          { key: "upcoming" as const, label: "Upcoming", icon: CalendarDays },
          { key: "wishlist" as const, label: "Wishlist", icon: Sparkles },
          { key: "memories" as const, label: "Memories", icon: Camera },
        ]).map((t) => (
          <button
            key={t.key}
            onClick={() => setActiveTab(t.key)}
            className={cn(
              "flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[11px] font-semibold transition-all",
              activeTab === t.key
                ? "bg-white/10 text-white"
                : "text-slate-500 hover:text-slate-300 hover:bg-white/5"
            )}
          >
            <t.icon className="w-3 h-3" />
            {t.label}
            {tabCounts[t.key] > 0 && (
              <span className={cn(
                "text-[9px] font-bold px-1.5 py-0.5 rounded-full tabular-nums",
                activeTab === t.key ? "bg-white/15 text-white" : "bg-white/8 text-slate-500"
              )}>
                {tabCounts[t.key]}
              </span>
            )}
          </button>
        ))}
      </div>

      {importError && (
        <div className="mx-3 mb-2 px-3 py-2 bg-red-500/15 text-red-400 text-xs rounded-xl border border-red-500/20">
          {importError}
        </div>
      )}

      {dragOver && (
        <div className="mx-3 mb-2 px-4 py-5 border border-dashed border-blue-500/40 rounded-xl bg-blue-500/8 text-center">
          <Upload className="w-5 h-5 mx-auto mb-1 text-blue-400" />
          <p className="text-xs text-blue-400 font-medium">Drop to import</p>
        </div>
      )}

      {/* ── Trip list ─────────────────────────────────── */}
      <div className="flex-1 overflow-y-auto sidebar-scroll px-2 pb-2">
        {trips.length === 0 && !dragOver && (
          <div className="flex flex-col items-center justify-center py-12 text-center px-4">
            <div className="w-12 h-12 rounded-xl bg-white/5 flex items-center justify-center mb-3">
              <span className="text-2xl">🗺️</span>
            </div>
            <p className="text-sm font-medium text-slate-300 mb-1">No trips yet</p>
            <p className="text-xs text-slate-500 mb-4 leading-relaxed">
              Create your first trip or drop a .tripwit file here.
            </p>
            <button
              onClick={onCreateTrip}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-blue-600 text-white text-xs font-medium rounded-lg hover:bg-blue-500 transition-colors"
            >
              <Plus className="w-3.5 h-3.5" />
              New Trip
            </button>
          </div>
        )}

        {trips.length > 0 && filteredTrips.length === 0 && !dragOver && (
          <div className="flex flex-col items-center justify-center py-8 text-center px-4">
            <p className="text-xs text-slate-500">
              No {activeTab === "upcoming" ? "upcoming" : activeTab === "wishlist" ? "wishlist" : "past"} trips
            </p>
          </div>
        )}

        {filteredTrips.map((trip) => {
          const isSelected = selectedTripId === trip.id;
          const stopCount = trip.days.reduce((c, d) => c + d.stops.length, 0);
          const visitedCount = trip.days.reduce((c, d) => c + d.stops.filter((s) => s.isVisited).length, 0);
          const progressPct = stopCount > 0 ? Math.round((visitedCount / stopCount) * 100) : 0;

          return (
            <div
              key={trip.id}
              className={cn(
                "group relative rounded-xl px-3 py-2.5 cursor-pointer mb-0.5 transition-all duration-150",
                isSelected
                  ? "bg-white/8 border border-white/8"
                  : "hover:bg-white/4 border border-transparent"
              )}
              onClick={() => { setConfirmDelete(null); onSelectTrip(trip.id); }}
            >
              {isSelected && (
                <div className="absolute left-0 top-2.5 bottom-2.5 w-0.5 bg-blue-500 rounded-r-full" />
              )}
              <div className="flex items-start gap-2.5">
                <div className={cn(
                  "w-1.5 h-1.5 rounded-full mt-[5px] shrink-0",
                  STATUS_DOT[trip.statusRaw] ?? "bg-slate-500",
                  STATUS_DOT_PULSE[trip.statusRaw] && "status-pulse"
                )} />
                <div className="flex-1 min-w-0">
                  <div className={cn(
                    "text-[13px] font-medium leading-snug truncate",
                    isSelected ? "text-white" : "text-slate-300 group-hover:text-slate-200"
                  )}>
                    {trip.name}
                  </div>
                  {trip.destination && (
                    <div className="flex items-center gap-1 mt-0.5">
                      <MapPin className="w-2.5 h-2.5 text-slate-600 shrink-0" />
                      <span className="text-[11px] text-slate-500 truncate">{trip.destination}</span>
                    </div>
                  )}
                  <div className="flex items-center gap-2 mt-1">
                    {trip.startDate && (
                      <span className="text-[10px] text-slate-600">
                        {formatTripDates(trip.startDate, trip.endDate)}
                      </span>
                    )}
                    {stopCount > 0 && trip.statusRaw === "active" ? (
                      <span className="text-[10px] text-emerald-500 font-medium">
                        {trip.startDate && "· "}{visitedCount}/{stopCount} visited
                      </span>
                    ) : stopCount > 0 ? (
                      <span className="text-[10px] text-slate-600">
                        {trip.startDate && "· "}{stopCount} stop{stopCount !== 1 ? "s" : ""}
                      </span>
                    ) : null}
                  </div>
                  {trip.statusRaw === "active" && stopCount > 0 && (
                    <div className="mt-2 h-[2px] bg-white/8 rounded-full overflow-hidden">
                      <div className="h-full rounded-full transition-all duration-500"
                        style={{ width: `${progressPct}%`, background: "linear-gradient(90deg, #34d399, #14b8a6)" }} />
                    </div>
                  )}
                </div>

                {confirmDelete === trip.id ? (
                  <div className="flex flex-col gap-1 shrink-0 pt-0.5">
                    <button
                      onClick={(e) => { e.stopPropagation(); onDeleteTrip(trip.id); setConfirmDelete(null); }}
                      className="text-[10px] text-red-400 hover:text-red-300 font-semibold"
                    >Delete</button>
                    <button
                      onClick={(e) => { e.stopPropagation(); setConfirmDelete(null); }}
                      className="text-[10px] text-slate-500 hover:text-slate-400"
                    >Cancel</button>
                  </div>
                ) : (
                  <button
                    onClick={(e) => { e.stopPropagation(); setConfirmDelete(trip.id); }}
                    className="opacity-0 group-hover:opacity-100 p-1 rounded-md hover:bg-white/8 text-slate-600 hover:text-red-400 transition-all"
                  >
                    <Trash2 className="w-3 h-3" />
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* ── iPhone app promo ──────────────────────────── */}
      <a
        href="https://apps.apple.com/us/app/tripwit/id6759219752"
        target="_blank"
        rel="noopener noreferrer"
        className="flex items-center gap-2.5 px-4 py-2.5 border-t border-white/5 group shrink-0"
      >
        <Smartphone className="w-3.5 h-3.5 text-slate-600 group-hover:text-slate-400 transition-colors shrink-0" />
        <span className="text-[11px] font-medium text-slate-600 group-hover:text-slate-400 transition-colors">
          Get TripWit for iPhone
        </span>
      </a>

      {/* ── User footer ───────────────────────────────── */}
      {user && (
        <div className="relative z-[1101] shrink-0 border-t border-white/5 px-3 py-3 bg-[#0c111d]">
          <div className="flex items-center gap-2.5 group">
            {user.user_metadata?.avatar_url ? (
              <Image
                src={user.user_metadata.avatar_url as string}
                alt=""
                width={28}
                height={28}
                className="rounded-full ring-1 ring-white/10 shrink-0"
              />
            ) : (
              <div className="w-7 h-7 rounded-full bg-blue-600 flex items-center justify-center text-white text-xs font-bold shrink-0">
                {(user.user_metadata?.full_name as string | undefined)?.charAt(0) ?? user.email?.charAt(0) ?? "?"}
              </div>
            )}
            <div className="flex-1 min-w-0">
              <div className="text-[12px] font-medium text-slate-300 truncate leading-tight">
                {(user.user_metadata?.full_name as string | undefined) ?? user.email}
              </div>
              <div className="text-[10px] text-slate-500 truncate">{user.email}</div>
            </div>
            {onSignOut && (
              <button
                onClick={onSignOut}
                title="Sign out"
                className="p-1.5 rounded-lg text-slate-600 hover:text-slate-300 hover:bg-white/8 transition-colors shrink-0"
              >
                <LogOut className="w-3.5 h-3.5" />
              </button>
            )}
          </div>
        </div>
      )}
    </aside>
  );
}
