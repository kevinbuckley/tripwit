"use client";

import { useState } from "react";
import { Plus, Plane, MapPin, Trash2, Upload } from "lucide-react";
import type { Trip } from "@/lib/types";
import { cn } from "@/components/ui/cn";
import { parseTripwitFile } from "@/lib/tripwit-parser";

interface TripsSidebarProps {
  trips: Trip[];
  selectedTripId: string | null;
  userId: string;
  onSelectTrip: (id: string) => void;
  onCreateTrip: () => void;
  onDeleteTrip: (id: string) => void;
  onImportTrip: (trip: Trip) => void;
}

const STATUS_COLORS: Record<string, string> = {
  planning: "bg-blue-100 text-blue-700",
  active: "bg-green-100 text-green-700",
  completed: "bg-slate-100 text-slate-600",
};

export default function TripsSidebar({
  trips,
  selectedTripId,
  userId,
  onSelectTrip,
  onCreateTrip,
  onDeleteTrip,
  onImportTrip,
}: TripsSidebarProps) {
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null);
  const [importError, setImportError] = useState<string | null>(null);

  async function handleImport(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const text = await file.text();
      const json = JSON.parse(text);
      const trip = parseTripwitFile(json, userId);
      onImportTrip(trip);
      setImportError(null);
    } catch {
      setImportError("Could not read .tripwit file.");
    }
    e.target.value = "";
  }

  return (
    <aside className="w-60 shrink-0 border-r border-slate-200 bg-white flex flex-col h-full">
      {/* Header */}
      <div className="px-3 py-3 border-b border-slate-100 flex items-center justify-between">
        <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
          My Trips
        </span>
        <div className="flex gap-1">
          {/* Import .tripwit */}
          <label
            title="Import .tripwit file"
            className="p-1 rounded hover:bg-slate-100 cursor-pointer text-slate-400 hover:text-slate-700 transition-colors"
          >
            <Upload className="w-4 h-4" />
            <input
              type="file"
              accept=".tripwit,.json"
              className="hidden"
              onChange={handleImport}
            />
          </label>
          <button
            onClick={onCreateTrip}
            title="New trip"
            className="p-1 rounded hover:bg-slate-100 text-slate-400 hover:text-slate-700 transition-colors"
          >
            <Plus className="w-4 h-4" />
          </button>
        </div>
      </div>

      {importError && (
        <div className="mx-3 mt-2 px-2 py-1.5 bg-red-50 text-red-600 text-xs rounded">
          {importError}
        </div>
      )}

      {/* Trip list */}
      <div className="flex-1 overflow-y-auto">
        {trips.length === 0 && (
          <div className="px-4 py-8 text-center text-sm text-slate-400">
            <Plane className="w-8 h-8 mx-auto mb-2 opacity-40" />
            No trips yet.
            <br />
            Create one to get started!
          </div>
        )}
        {trips.map((trip) => (
          <div
            key={trip.id}
            className={cn(
              "group flex items-start gap-2 px-3 py-2.5 cursor-pointer border-b border-slate-100 hover:bg-slate-50 transition-colors",
              selectedTripId === trip.id && "bg-blue-50 hover:bg-blue-50"
            )}
            onClick={() => {
              setConfirmDelete(null);
              onSelectTrip(trip.id);
            }}
          >
            <MapPin
              className="w-4 h-4 mt-0.5 shrink-0 text-slate-400"
            />
            <div className="flex-1 min-w-0">
              <div
                className={cn(
                  "text-sm font-medium truncate",
                  selectedTripId === trip.id ? "text-blue-700" : "text-slate-800"
                )}
              >
                {trip.name}
              </div>
              {trip.destination && (
                <div className="text-xs text-slate-400 truncate">{trip.destination}</div>
              )}
              <div className="mt-1">
                <span
                  className={cn(
                    "text-xs px-1.5 py-0.5 rounded-full font-medium",
                    STATUS_COLORS[trip.statusRaw]
                  )}
                >
                  {trip.statusRaw}
                </span>
              </div>
            </div>
            {/* Delete */}
            {confirmDelete === trip.id ? (
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onDeleteTrip(trip.id);
                  setConfirmDelete(null);
                }}
                className="text-xs text-red-600 shrink-0 mt-0.5"
              >
                Confirm
              </button>
            ) : (
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  setConfirmDelete(trip.id);
                }}
                className="opacity-0 group-hover:opacity-100 p-0.5 rounded hover:bg-red-50 text-slate-300 hover:text-red-500 transition-all"
              >
                <Trash2 className="w-3.5 h-3.5" />
              </button>
            )}
          </div>
        ))}
      </div>
    </aside>
  );
}
