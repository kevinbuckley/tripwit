"use client";

import { useState, useCallback } from "react";
import { Plus, Trash2, Upload, Download, Copy, MapPin } from "lucide-react";
import type { Trip } from "@/lib/types";
import { cn } from "@/components/ui/cn";
import { parseTripwitFile } from "@/lib/tripwit-parser";
import { downloadTripwit } from "@/lib/tripwit-exporter";

interface TripsSidebarProps {
  trips: Trip[];
  selectedTripId: string | null;
  userId: string;
  onSelectTrip: (id: string) => void;
  onCreateTrip: () => void;
  onDeleteTrip: (id: string) => void;
  onImportTrip: (trip: Trip) => void;
  onDuplicateTrip?: (trip: Trip) => void;
}

const STATUS_DOT: Record<string, string> = {
  planning: "bg-blue-400",
  active: "bg-emerald-400",
  completed: "bg-slate-500",
};

function formatTripDates(start: string, end: string): string {
  if (!start) return "";
  try {
    const s = new Date(start + "T12:00:00");
    const e = new Date(end + "T12:00:00");
    const opts: Intl.DateTimeFormatOptions = { month: "short", day: "numeric" };
    if (start === end) return s.toLocaleDateString(undefined, opts);
    return `${s.toLocaleDateString(undefined, opts)} – ${e.toLocaleDateString(undefined, opts)}`;
  } catch {
    return "";
  }
}

const IconBtn = ({
  onClick,
  title,
  children,
}: {
  onClick?: () => void;
  title: string;
  children: React.ReactNode;
}) => (
  <button
    onClick={onClick}
    title={title}
    className="w-7 h-7 flex items-center justify-center rounded-md text-slate-400 hover:text-slate-200 hover:bg-white/8 transition-colors"
  >
    {children}
  </button>
);

export default function TripsSidebar({
  trips,
  selectedTripId,
  userId,
  onSelectTrip,
  onCreateTrip,
  onDeleteTrip,
  onImportTrip,
  onDuplicateTrip,
}: TripsSidebarProps) {
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null);
  const [importError, setImportError] = useState<string | null>(null);
  const [dragOver, setDragOver] = useState(false);

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

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(true);
  }, []);

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
  }, []);

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
      className={cn(
        "w-64 shrink-0 flex flex-col h-full transition-colors select-none",
        "bg-[#0c111d] border-r border-white/5"
      )}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      {/* Logo */}
      <div className="flex items-center gap-2.5 px-4 h-14 border-b border-white/5 shrink-0">
        <div className="w-7 h-7 rounded-lg bg-blue-600 flex items-center justify-center shadow-sm shrink-0">
          <span className="text-white text-sm">✈</span>
        </div>
        <span className="text-white font-semibold text-[15px] tracking-tight">TripWit</span>
      </div>

      {/* Section header + actions */}
      <div className="flex items-center justify-between px-4 pt-5 pb-2 shrink-0">
        <span className="text-[10px] font-semibold text-slate-500 uppercase tracking-widest">
          My Trips
        </span>
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
          <label title="Import .tripwit" className="w-7 h-7 flex items-center justify-center rounded-md text-slate-400 hover:text-slate-200 hover:bg-white/8 transition-colors cursor-pointer">
            <Upload className="w-3.5 h-3.5" />
            <input type="file" accept=".tripwit,.json" className="hidden" onChange={handleImport} />
          </label>
          <button
            onClick={onCreateTrip}
            title="New trip (⌘N)"
            className="w-7 h-7 flex items-center justify-center rounded-md bg-blue-600 text-white hover:bg-blue-500 transition-colors shadow-sm"
          >
            <Plus className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {/* Error message */}
      {importError && (
        <div className="mx-3 mb-2 px-3 py-2 bg-red-500/15 text-red-400 text-xs rounded-lg border border-red-500/20">
          {importError}
        </div>
      )}

      {/* Drag-over overlay */}
      {dragOver && (
        <div className="mx-3 mb-2 px-4 py-5 border border-dashed border-blue-500/50 rounded-xl bg-blue-500/10 text-center">
          <Upload className="w-5 h-5 mx-auto mb-1 text-blue-400" />
          <p className="text-xs text-blue-400 font-medium">Drop to import</p>
        </div>
      )}

      {/* Trip list */}
      <div className="flex-1 overflow-y-auto sidebar-scroll px-2 pb-4">
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

        {trips.map((trip) => {
          const isSelected = selectedTripId === trip.id;
          const stopCount = trip.days.reduce((c, d) => c + d.stops.length, 0);

          return (
            <div
              key={trip.id}
              className={cn(
                "group relative rounded-xl px-3 py-2.5 cursor-pointer mb-1 transition-all",
                isSelected
                  ? "bg-white/8 border border-white/8"
                  : "hover:bg-white/4 border border-transparent"
              )}
              onClick={() => { setConfirmDelete(null); onSelectTrip(trip.id); }}
            >
              {/* Selected accent line */}
              {isSelected && (
                <div className="absolute left-0 top-2.5 bottom-2.5 w-0.5 bg-blue-500 rounded-r-full" />
              )}

              <div className="flex items-start gap-2.5">
                {/* Status dot */}
                <div className={cn("w-2 h-2 rounded-full mt-1.5 shrink-0", STATUS_DOT[trip.statusRaw] ?? "bg-slate-500")} />

                <div className="flex-1 min-w-0">
                  <div className={cn(
                    "text-[13px] font-medium leading-snug truncate",
                    isSelected ? "text-white" : "text-slate-300"
                  )}>
                    {trip.name}
                  </div>
                  {trip.destination && (
                    <div className="flex items-center gap-1 mt-0.5">
                      <MapPin className="w-2.5 h-2.5 text-slate-500 shrink-0" />
                      <span className="text-[11px] text-slate-500 truncate">{trip.destination}</span>
                    </div>
                  )}
                  <div className="flex items-center gap-2 mt-1.5">
                    {trip.startDate && (
                      <span className="text-[10px] text-slate-500">
                        {formatTripDates(trip.startDate, trip.endDate)}
                      </span>
                    )}
                    {stopCount > 0 && (
                      <span className="text-[10px] text-slate-600">
                        · {stopCount} stop{stopCount !== 1 ? "s" : ""}
                      </span>
                    )}
                  </div>
                </div>

                {/* Delete */}
                {confirmDelete === trip.id ? (
                  <div className="flex flex-col gap-1 shrink-0 pt-0.5">
                    <button
                      onClick={(e) => { e.stopPropagation(); onDeleteTrip(trip.id); setConfirmDelete(null); }}
                      className="text-[10px] text-red-400 hover:text-red-300 font-medium"
                    >
                      Delete
                    </button>
                    <button
                      onClick={(e) => { e.stopPropagation(); setConfirmDelete(null); }}
                      className="text-[10px] text-slate-500 hover:text-slate-400"
                    >
                      Cancel
                    </button>
                  </div>
                ) : (
                  <button
                    onClick={(e) => { e.stopPropagation(); setConfirmDelete(trip.id); }}
                    className="opacity-0 group-hover:opacity-100 p-1 rounded-md hover:bg-white/8 text-slate-500 hover:text-red-400 transition-all"
                  >
                    <Trash2 className="w-3 h-3" />
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Bottom spacer */}
      <div className="shrink-0 h-4" />
    </aside>
  );
}
