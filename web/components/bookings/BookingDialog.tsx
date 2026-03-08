"use client";

import { useState, useEffect } from "react";
import { X } from "lucide-react";
import type { Booking, BookingType } from "@/lib/types";
import { newId } from "@/lib/types";
import { cn } from "@/components/ui/cn";

interface BookingDialogProps {
  booking?: Booking | null;
  onSave: (booking: Booking) => void;
  onClose: () => void;
}

const BOOKING_TYPES: { value: BookingType; label: string; icon: string }[] = [
  { value: "flight", label: "Flight", icon: "✈️" },
  { value: "hotel", label: "Hotel", icon: "🏨" },
  { value: "car_rental", label: "Car rental", icon: "🚗" },
  { value: "other", label: "Other", icon: "📋" },
];

function emptyBooking(): Booking {
  return { id: newId(), typeRaw: "flight", title: "", confirmationCode: "", notes: "", sortOrder: 0 };
}

const Label = ({ children }: { children: React.ReactNode }) => (
  <label className="block text-[11px] font-semibold text-slate-500 uppercase tracking-wide mb-1.5">
    {children}
  </label>
);

const Input = (props: React.InputHTMLAttributes<HTMLInputElement>) => (
  <input
    {...props}
    className={cn(
      "w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2.5 text-sm text-slate-800 placeholder-slate-400",
      "focus:outline-none focus:border-blue-400 focus:bg-white focus:ring-3 focus:ring-blue-100 transition-all",
      props.className
    )}
  />
);

export default function BookingDialog({ booking, onSave, onClose }: BookingDialogProps) {
  const [form, setForm] = useState<Booking>(() => booking ?? emptyBooking());

  function set<K extends keyof Booking>(key: K, value: Booking[K]) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  useEffect(() => {
    const handler = (e: KeyboardEvent) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [onClose]);

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.title.trim()) return;
    onSave({ ...form, id: form.id || newId() });
  }

  const isFlight = form.typeRaw === "flight";
  const isHotel = form.typeRaw === "hotel";

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div className="bg-white rounded-2xl shadow-[0_25px_50px_-12px_rgba(0,0,0,0.35)] w-full max-w-md max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100 shrink-0">
          <h2 className="font-semibold text-slate-900 text-[15px]">
            {booking ? "Edit Booking" : "Add Booking"}
          </h2>
          <button onClick={onClose} className="w-8 h-8 flex items-center justify-center rounded-xl text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors">
            <X className="w-4 h-4" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="overflow-y-auto flex-1">
          <div className="px-6 py-5 space-y-5">
            {/* Type selector */}
            <div>
              <Label>Type</Label>
              <div className="grid grid-cols-4 gap-1.5">
                {BOOKING_TYPES.map((t) => (
                  <button
                    key={t.value}
                    type="button"
                    onClick={() => set("typeRaw", t.value)}
                    className={cn(
                      "flex flex-col items-center gap-1 py-2.5 rounded-xl text-xs font-medium border transition-all",
                      form.typeRaw === t.value
                        ? "bg-blue-600 text-white border-blue-600 shadow-sm"
                        : "bg-slate-50 text-slate-600 border-slate-200 hover:border-slate-300"
                    )}
                  >
                    <span className="text-base">{t.icon}</span>
                    {t.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Title */}
            <div>
              <Label>Title *</Label>
              <Input
                type="text"
                value={form.title}
                onChange={(e) => set("title", e.target.value)}
                required
                autoFocus
                placeholder={isFlight ? "e.g. JFK → CDG" : isHotel ? "e.g. Hotel Le Marais" : "Title"}
              />
            </div>

            {/* Confirmation code */}
            <div>
              <Label>Confirmation code</Label>
              <Input
                type="text"
                value={form.confirmationCode}
                onChange={(e) => set("confirmationCode", e.target.value)}
                placeholder="e.g. ABC123"
                className="font-mono"
              />
            </div>

            {/* Flight details */}
            {isFlight && (
              <div className="rounded-xl border border-sky-100 bg-sky-50/60 p-4 space-y-3">
                <p className="text-xs font-semibold text-sky-700">✈️ Flight Details</p>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <Label>Airline</Label>
                    <Input type="text" value={form.airline ?? ""} onChange={(e) => set("airline", e.target.value || undefined)} placeholder="e.g. Delta" className="bg-white" />
                  </div>
                  <div>
                    <Label>Flight #</Label>
                    <Input type="text" value={form.flightNumber ?? ""} onChange={(e) => set("flightNumber", e.target.value || undefined)} placeholder="DL234" className="bg-white" />
                  </div>
                  <div>
                    <Label>From</Label>
                    <Input type="text" value={form.departureAirport ?? ""} onChange={(e) => set("departureAirport", e.target.value || undefined)} placeholder="JFK" className="bg-white" />
                  </div>
                  <div>
                    <Label>To</Label>
                    <Input type="text" value={form.arrivalAirport ?? ""} onChange={(e) => set("arrivalAirport", e.target.value || undefined)} placeholder="CDG" className="bg-white" />
                  </div>
                  <div>
                    <Label>Departure</Label>
                    <Input type="datetime-local" value={form.departureTime?.slice(0, 16) ?? ""} onChange={(e) => set("departureTime", e.target.value ? new Date(e.target.value).toISOString() : undefined)} className="bg-white" />
                  </div>
                  <div>
                    <Label>Arrival</Label>
                    <Input type="datetime-local" value={form.arrivalTime?.slice(0, 16) ?? ""} onChange={(e) => set("arrivalTime", e.target.value ? new Date(e.target.value).toISOString() : undefined)} className="bg-white" />
                  </div>
                </div>
              </div>
            )}

            {/* Hotel details */}
            {isHotel && (
              <div className="rounded-xl border border-purple-100 bg-purple-50/60 p-4 space-y-3">
                <p className="text-xs font-semibold text-purple-700">🏨 Hotel Details</p>
                <div>
                  <Label>Hotel name</Label>
                  <Input type="text" value={form.hotelName ?? ""} onChange={(e) => set("hotelName", e.target.value || undefined)} placeholder="e.g. Le Marais Hotel" className="bg-white" />
                </div>
                <div>
                  <Label>Address</Label>
                  <Input type="text" value={form.hotelAddress ?? ""} onChange={(e) => set("hotelAddress", e.target.value || undefined)} placeholder="Street address" className="bg-white" />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <Label>Check-in</Label>
                    <Input type="date" value={form.checkInDate ?? ""} onChange={(e) => set("checkInDate", e.target.value || undefined)} className="bg-white" />
                  </div>
                  <div>
                    <Label>Check-out</Label>
                    <Input type="date" value={form.checkOutDate ?? ""} onChange={(e) => set("checkOutDate", e.target.value || undefined)} className="bg-white" />
                  </div>
                </div>
              </div>
            )}

            {/* Notes */}
            <div>
              <Label>Notes</Label>
              <textarea
                value={form.notes}
                onChange={(e) => set("notes", e.target.value)}
                rows={2}
                placeholder="Any details…"
                className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3.5 py-2.5 text-sm text-slate-800 placeholder-slate-400 resize-none focus:outline-none focus:border-blue-400 focus:bg-white focus:ring-3 focus:ring-blue-100 transition-all"
              />
            </div>
          </div>

          <div className="flex justify-end gap-2.5 px-6 py-4 border-t border-slate-100 bg-slate-50/50 rounded-b-2xl shrink-0">
            <button type="button" onClick={onClose} className="px-4 py-2.5 rounded-xl text-sm font-medium text-slate-600 hover:bg-slate-100 transition-colors">
              Cancel
            </button>
            <button type="submit" className="px-5 py-2.5 rounded-xl text-sm font-semibold bg-blue-600 text-white hover:bg-blue-700 transition-colors shadow-sm">
              {booking ? "Save changes" : "Add Booking"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
