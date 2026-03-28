"use client";

import { useState } from "react";
import dynamic from "next/dynamic";
import type { Day, Stop } from "@/lib/types";

const TripMap = dynamic(() => import("@/components/map/TripMap"), {
  ssr: false,
  loading: () => (
    <div className="h-full flex flex-col items-center justify-center gap-3 bg-[#f2f0eb]">
      <div className="w-5 h-5 border-2 border-slate-400 border-t-transparent rounded-full animate-spin opacity-40" />
    </div>
  ),
});

function dayLabel(day: Day): string {
  const prefix = `Day ${day.dayNumber}`;
  if (day.date && /^\d{4}-\d{2}-\d{2}$/.test(day.date.slice(0, 10))) {
    try {
      const d = new Date(day.date.slice(0, 10) + "T12:00:00");
      if (!isNaN(d.getTime())) {
        return `${prefix} · ${d.toLocaleDateString(undefined, { month: "short", day: "numeric" })}`;
      }
    } catch { /* fall through */ }
  }
  return day.location ? `${prefix} · ${day.location}` : prefix;
}

interface MapPanelProps {
  days: Day[];
  stops: Stop[];
  selectedStopId?: string | null;
  onSelectStop?: (id: string) => void;
}

export default function MapPanel({ days, stops, selectedStopId, onSelectStop }: MapPanelProps) {
  const [selectedDayId, setSelectedDayId] = useState<string | "all">("all");

  const visibleStops =
    selectedDayId === "all"
      ? stops
      : days.find((d) => d.id === selectedDayId)?.stops ?? [];

  const daysWithStops = days.filter((d) => d.stops.some((s) => s.latitude !== 0 || s.longitude !== 0));

  return (
    <div className="h-full w-full relative">
      {daysWithStops.length > 1 && (
        <div className="absolute top-2 left-1/2 -translate-x-1/2 z-[1000]">
          <select
            value={selectedDayId}
            onChange={(e) => setSelectedDayId(e.target.value)}
            className="text-xs font-medium bg-white border border-slate-200 rounded-full px-3 py-1.5 shadow-md text-slate-700 cursor-pointer focus:outline-none focus:ring-2 focus:ring-blue-400 appearance-none pr-7"
            style={{ backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%2394a3b8' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'/%3E%3C/svg%3E")`, backgroundRepeat: "no-repeat", backgroundPosition: "right 10px center" }}
          >
            <option value="all">All days</option>
            {daysWithStops.map((d) => (
              <option key={d.id} value={d.id}>
                {dayLabel(d)}
              </option>
            ))}
          </select>
        </div>
      )}
      <TripMap
        stops={visibleStops}
        selectedStopId={selectedStopId}
        onSelectStop={onSelectStop}
      />
    </div>
  );
}
