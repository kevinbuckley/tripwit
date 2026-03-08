"use client";

import { useState } from "react";
import { Plus, Trash2, Pencil, Plane, BedDouble, Car, ClipboardList, type LucideIcon } from "lucide-react";
import type { Booking, Trip } from "@/lib/types";
import BookingDialog from "./BookingDialog";

interface BookingsPanelProps {
  trip: Trip;
  onUpdateTrip: (changes: Partial<Trip>) => void;
}

// Matches iOS SF Symbols: airplane / bed.double.fill / car.fill / list.clipboard
const TYPE_ICON_MAP: Record<string, LucideIcon> = {
  flight: Plane,
  hotel: BedDouble,
  car_rental: Car,
  other: ClipboardList,
};

const TYPE_LABELS: Record<string, string> = {
  flight: "Flight",
  hotel: "Hotel",
  car_rental: "Car rental",
  other: "Other",
};

const TYPE_COLORS: Record<string, string> = {
  flight: "bg-sky-50 border-sky-100 text-sky-700",
  hotel: "bg-purple-50 border-purple-100 text-purple-700",
  car_rental: "bg-amber-50 border-amber-100 text-amber-700",
  other: "bg-slate-50 border-slate-100 text-slate-600",
};

export default function BookingsPanel({ trip, onUpdateTrip }: BookingsPanelProps) {
  const [editing, setEditing] = useState<Booking | null | "new">(null);

  const bookings = [...trip.bookings].sort((a, b) => a.sortOrder - b.sortOrder);

  function saveBooking(booking: Booking) {
    const exists = trip.bookings.find((b) => b.id === booking.id);
    const updated = exists
      ? trip.bookings.map((b) => (b.id === booking.id ? booking : b))
      : [...trip.bookings, { ...booking, sortOrder: trip.bookings.length }];
    onUpdateTrip({ bookings: updated });
    setEditing(null);
  }

  function deleteBooking(id: string) {
    onUpdateTrip({ bookings: trip.bookings.filter((b) => b.id !== id) });
  }

  return (
    <div className="flex-1 overflow-y-auto tab-content">
      <div className="px-5 py-4 space-y-3">
        {bookings.length === 0 && (
          <div className="text-center py-12">
            <div className="w-12 h-12 rounded-2xl bg-slate-100 flex items-center justify-center mx-auto mb-3 text-2xl">
              🎫
            </div>
            <p className="text-sm font-medium text-slate-600 mb-1">No bookings yet</p>
            <p className="text-xs text-slate-400">Add flights, hotels, and car rentals to keep everything in one place.</p>
          </div>
        )}

        {bookings.map((b) => (
          <div
            key={b.id}
            className="rounded-xl border border-slate-200 bg-white shadow-[0_1px_3px_rgba(0,0,0,0.06)] group hover:shadow-[0_4px_12px_rgba(0,0,0,0.08)] transition-shadow"
          >
            <div className="flex items-start gap-3 p-4">
              {/* Icon + type badge */}
              <div className="shrink-0">
                <div className={`w-10 h-10 rounded-xl flex items-center justify-center border ${TYPE_COLORS[b.typeRaw]}`}>
                  {(() => { const Icon = TYPE_ICON_MAP[b.typeRaw] ?? ClipboardList; return <Icon className="w-5 h-5" />; })()}
                </div>
              </div>

              <div className="flex-1 min-w-0">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <div className="font-semibold text-slate-800 text-sm leading-tight">{b.title}</div>
                    <span className={`inline-block mt-1 text-[10px] font-semibold px-2 py-0.5 rounded-full border ${TYPE_COLORS[b.typeRaw]}`}>
                      {TYPE_LABELS[b.typeRaw]}
                    </span>
                  </div>
                  <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity shrink-0">
                    <button
                      onClick={() => setEditing(b)}
                      className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-700 transition-colors"
                    >
                      <Pencil className="w-3.5 h-3.5" />
                    </button>
                    <button
                      onClick={() => deleteBooking(b.id)}
                      className="p-1.5 rounded-lg hover:bg-red-50 text-slate-400 hover:text-red-500 transition-colors"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>

                <div className="mt-2 space-y-1">
                  {b.confirmationCode && (
                    <div className="flex items-center gap-1.5">
                      <span className="text-[10px] font-medium text-slate-400 uppercase tracking-wide">Conf.</span>
                      <span className="text-xs font-mono font-semibold text-slate-700 bg-slate-100 px-1.5 py-0.5 rounded">
                        {b.confirmationCode}
                      </span>
                    </div>
                  )}

                  {b.typeRaw === "flight" && (
                    <>
                      {(b.airline || b.flightNumber) && (
                        <div className="text-xs text-slate-500">
                          {[b.airline, b.flightNumber].filter(Boolean).join(" ")}
                          {b.departureAirport && b.arrivalAirport && (
                            <span className="font-medium text-slate-600"> · {b.departureAirport} → {b.arrivalAirport}</span>
                          )}
                        </div>
                      )}
                      {b.departureTime && (
                        <div className="text-xs text-slate-400">
                          {new Date(b.departureTime).toLocaleString([], { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" })}
                          {b.arrivalTime && (
                            <> → {new Date(b.arrivalTime).toLocaleString([], { hour: "2-digit", minute: "2-digit" })}</>
                          )}
                        </div>
                      )}
                    </>
                  )}

                  {b.typeRaw === "hotel" && (
                    <>
                      {b.hotelName && <div className="text-xs font-medium text-slate-600">{b.hotelName}</div>}
                      {b.hotelAddress && <div className="text-xs text-slate-400">{b.hotelAddress}</div>}
                      {(b.checkInDate || b.checkOutDate) && (
                        <div className="text-xs text-slate-400">
                          {b.checkInDate && new Date(b.checkInDate + "T12:00:00").toLocaleDateString(undefined, { month: "short", day: "numeric" })}
                          {b.checkInDate && b.checkOutDate && " → "}
                          {b.checkOutDate && new Date(b.checkOutDate + "T12:00:00").toLocaleDateString(undefined, { month: "short", day: "numeric" })}
                        </div>
                      )}
                    </>
                  )}

                  {b.notes && (
                    <div className="text-xs text-slate-500 italic leading-relaxed">{b.notes}</div>
                  )}
                </div>
              </div>
            </div>
          </div>
        ))}

        <button
          onClick={() => setEditing("new")}
          className="flex items-center gap-2 w-full px-4 py-3 rounded-xl border-2 border-dashed border-slate-200 text-sm text-slate-400 hover:border-blue-400 hover:text-blue-500 transition-colors"
        >
          <Plus className="w-4 h-4" />
          Add booking
        </button>
      </div>

      {editing !== null && (
        <BookingDialog
          booking={editing === "new" ? null : editing}
          onSave={saveBooking}
          onClose={() => setEditing(null)}
        />
      )}
    </div>
  );
}
