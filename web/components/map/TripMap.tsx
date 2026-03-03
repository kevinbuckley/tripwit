"use client";

import { useEffect } from "react";
import { MapContainer, TileLayer, Marker, Popup, useMap } from "react-leaflet";
import L from "leaflet";
import type { Stop } from "@/lib/types";
import { CATEGORY_COLORS } from "@/lib/types";

// Fix Leaflet default marker icon (webpack breaks the default URL resolution)
delete (L.Icon.Default.prototype as unknown as Record<string, unknown>)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

function makeIcon(color: string) {
  return L.divIcon({
    className: "",
    html: `<div style="
      width:24px;height:24px;border-radius:50% 50% 50% 0;
      background:${color};border:2px solid white;
      box-shadow:0 1px 4px rgba(0,0,0,.4);
      transform:rotate(-45deg);
    "></div>`,
    iconSize: [24, 24],
    iconAnchor: [12, 24],
    popupAnchor: [0, -26],
  });
}

interface FlyToProps {
  stops: Stop[];
}

function FlyToStops({ stops }: FlyToProps) {
  const map = useMap();
  useEffect(() => {
    const located = stops.filter((s) => s.latitude !== 0 || s.longitude !== 0);
    if (located.length === 0) return;
    if (located.length === 1) {
      map.flyTo([located[0].latitude, located[0].longitude], 14, { animate: true, duration: 0.8 });
    } else {
      const bounds = L.latLngBounds(located.map((s) => [s.latitude, s.longitude]));
      map.flyToBounds(bounds, { padding: [40, 40], animate: true, duration: 0.8 });
    }
  }, [stops, map]);
  return null;
}

interface TripMapProps {
  stops: Stop[];
  selectedStopId?: string | null;
  onSelectStop?: (id: string) => void;
}

export default function TripMap({ stops, selectedStopId, onSelectStop }: TripMapProps) {
  const located = stops.filter((s) => s.latitude !== 0 || s.longitude !== 0);
  const center: [number, number] = located.length > 0
    ? [located[0].latitude, located[0].longitude]
    : [20, 0];

  return (
    <MapContainer
      center={center}
      zoom={located.length > 0 ? 12 : 2}
      style={{ height: "100%", width: "100%" }}
      scrollWheelZoom={true}
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <FlyToStops stops={located} />
      {located.map((stop, i) => (
        <Marker
          key={stop.id}
          position={[stop.latitude, stop.longitude]}
          icon={makeIcon(CATEGORY_COLORS[stop.categoryRaw])}
          eventHandlers={{ click: () => onSelectStop?.(stop.id) }}
          zIndexOffset={selectedStopId === stop.id ? 1000 : 0}
        >
          <Popup>
            <div className="text-sm">
              <div className="font-semibold">{i + 1}. {stop.name}</div>
              {stop.address && <div className="text-slate-500 text-xs mt-0.5">{stop.address}</div>}
            </div>
          </Popup>
        </Marker>
      ))}
    </MapContainer>
  );
}
