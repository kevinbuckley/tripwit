"use client";

import dynamic from "next/dynamic";
import type { Stop } from "@/lib/types";

const TripMap = dynamic(() => import("@/components/map/TripMap"), {
  ssr: false,
  loading: () => (
    <div className="h-full flex items-center justify-center bg-slate-100 text-slate-400 text-sm">
      Loading map…
    </div>
  ),
});

interface MapPanelProps {
  stops: Stop[];
  selectedStopId?: string | null;
  onSelectStop?: (id: string) => void;
}

export default function MapPanel({ stops, selectedStopId, onSelectStop }: MapPanelProps) {
  return (
    <div className="h-full w-full">
      <TripMap
        stops={stops}
        selectedStopId={selectedStopId}
        onSelectStop={onSelectStop}
      />
    </div>
  );
}
