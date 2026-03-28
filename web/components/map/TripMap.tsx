"use client";

import { useEffect } from "react";
import { MapContainer, TileLayer, Marker, Popup, useMap } from "react-leaflet";
import L from "leaflet";
import type { Stop } from "@/lib/types";
import { CATEGORY_COLORS } from "@/lib/types";

// Fix Leaflet default marker icon
delete (L.Icon.Default.prototype as unknown as Record<string, unknown>)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

function makeIcon(color: string, label: string, isSelected: boolean) {
  return L.divIcon({
    className: "",
    html: `<div style="
      display:flex;align-items:center;justify-content:center;
      width:${isSelected ? 32 : 28}px;height:${isSelected ? 32 : 28}px;
      border-radius:50%;
      background:${color};
      border:${isSelected ? "3px" : "2px"} solid white;
      box-shadow:0 ${isSelected ? "4px 12px" : "2px 6px"} rgba(0,0,0,${isSelected ? ".35" : ".22"});
      color:white;font-size:11px;font-weight:700;font-family:system-ui,sans-serif;
      transition:all .2s;
    ">${label}</div>`,
    iconSize: [isSelected ? 32 : 28, isSelected ? 32 : 28],
    iconAnchor: [isSelected ? 16 : 14, isSelected ? 16 : 14],
    popupAnchor: [0, isSelected ? -18 : -16],
  });
}

/** Watches the map container with ResizeObserver and calls invalidateSize so
 *  Leaflet re-renders correctly whenever the panel is resized (e.g. maximize). */
function AutoInvalidate() {
  const map = useMap();
  useEffect(() => {
    const container = map.getContainer();
    const observer = new ResizeObserver(() => { map.invalidateSize(); });
    observer.observe(container);
    return () => observer.disconnect();
  }, [map]);
  return null;
}

interface FlyToProps { stops: Stop[]; }
function FlyToStops({ stops }: FlyToProps) {
  const map = useMap();
  useEffect(() => {
    const located = stops.filter((s) => s.latitude !== 0 || s.longitude !== 0);
    if (located.length === 0) return;
    if (located.length === 1) {
      map.flyTo([located[0].latitude, located[0].longitude], 14, { animate: true, duration: 0.8 });
    } else {
      const bounds = L.latLngBounds(located.map((s) => [s.latitude, s.longitude]));
      map.flyToBounds(bounds, { padding: [48, 48], animate: true, duration: 0.8 });
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
      zoomControl={false}
    >
      {/* CartoDB Positron — clean, premium light basemap */}
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>'
        url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png"
        subdomains="abcd"
        maxZoom={19}
      />
      <AutoInvalidate />
      <FlyToStops stops={located} />
      {located.map((stop, i) => (
        <Marker
          key={stop.id}
          position={[stop.latitude, stop.longitude]}
          icon={makeIcon(
            CATEGORY_COLORS[stop.categoryRaw] ?? "#64748b",
            String(i + 1),
            selectedStopId === stop.id
          )}
          eventHandlers={{ click: () => onSelectStop?.(stop.id) }}
          zIndexOffset={selectedStopId === stop.id ? 1000 : 0}
        >
          <Popup>
            <div style={{ fontFamily: "system-ui, sans-serif", minWidth: 140 }}>
              <div style={{ fontWeight: 600, fontSize: 13, color: "#1e293b" }}>
                {i + 1}. {stop.name}
              </div>
              {stop.address && (
                <div style={{ fontSize: 11, color: "#94a3b8", marginTop: 2, lineHeight: 1.4 }}>
                  {stop.address.split(",").slice(0, 3).join(",")}
                </div>
              )}
              <a
                href={`https://www.google.com/maps?q=${stop.latitude},${stop.longitude}`}
                target="_blank"
                rel="noopener noreferrer"
                style={{ fontSize: 11, color: "#3b82f6", marginTop: 4, display: "inline-block" }}
              >
                Open in Google Maps ↗
              </a>
            </div>
          </Popup>
        </Marker>
      ))}
    </MapContainer>
  );
}
