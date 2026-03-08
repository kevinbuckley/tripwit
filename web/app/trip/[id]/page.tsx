export const dynamic = "force-dynamic";

import { notFound } from "next/navigation";
import Link from "next/link";
import { createClient } from "@supabase/supabase-js";
import type { Trip, Stop, Booking } from "@/lib/types";
import { CATEGORY_LABELS, CATEGORY_COLORS } from "@/lib/types";
import type { Metadata } from "next";
import AdUnit from "@/components/ads/AdUnit";
import { BedDouble, Utensils, Star, Plane, Footprints, MapPin, type LucideIcon } from "lucide-react";

const CATEGORY_ICON_MAP: Record<string, LucideIcon> = {
  accommodation: BedDouble,
  restaurant: Utensils,
  attraction: Star,
  transport: Plane,
  activity: Footprints,
  other: MapPin,
};

interface Props {
  params: Promise<{ id: string }>;
}

function getServerSupabase() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) return null;
  return createClient(url, key);
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const supabase = getServerSupabase();
  if (!supabase) return { title: "TripWit — Trip" };
  const { id } = await params;
  try {
    const { data } = await supabase
      .from("trips")
      .select("name, destination")
      .eq("id", id)
      .eq("is_public", true)
      .single();
    if (!data) return { title: "Trip not found" };
    return {
      title: `${data.name} — TripWit`,
      description: `Explore ${data.name}${data.destination ? ` in ${data.destination}` : ""} on TripWit.`,
    };
  } catch {
    return { title: "TripWit — Trip" };
  }
}

const BOOKING_TYPE_ICONS: Record<string, string> = {
  flight: "✈️", hotel: "🏨", car_rental: "🚗", other: "📋",
};
const BOOKING_TYPE_LABELS: Record<string, string> = {
  flight: "Flight", hotel: "Hotel", car_rental: "Car rental", other: "Other",
};
const STATUS_CONFIG: Record<string, { label: string; color: string }> = {
  planning: { label: "Planning",   color: "bg-blue-100 text-blue-700" },
  active:   { label: "Active",     color: "bg-emerald-100 text-emerald-700" },
  completed:{ label: "Completed",  color: "bg-slate-100 text-slate-600" },
};

function formatDate(dateStr: string, opts?: Intl.DateTimeFormatOptions) {
  try {
    return new Date(dateStr + "T12:00:00").toLocaleDateString(undefined, opts);
  } catch { return ""; }
}

export default async function PublicTripPage({ params }: Props) {
  const { id } = await params;
  const supabase = getServerSupabase();
  if (!supabase) notFound();
  const { data } = await supabase
    .from("trips")
    .select("*")
    .eq("id", id)
    .eq("is_public", true)
    .single();

  if (!data) notFound();

  const trip: Trip = {
    id: data.id,
    userId: data.user_id,
    isPublic: data.is_public,
    name: data.name,
    destination: data.destination,
    statusRaw: data.status_raw,
    notes: data.notes,
    hasCustomDates: data.has_custom_dates,
    budgetAmount: data.budget_amount,
    budgetCurrencyCode: data.budget_currency_code,
    startDate: data.start_date,
    endDate: data.end_date,
    createdAt: data.created_at,
    updatedAt: data.updated_at,
    days: data.days ?? [],
    bookings: data.bookings ?? [],
    lists: data.lists ?? [],
    expenses: data.expenses ?? [],
  };

  const sortedDays = [...trip.days].sort((a, b) => a.dayNumber - b.dayNumber);
  const sortedBookings = [...trip.bookings].sort((a, b) => a.sortOrder - b.sortOrder);
  const statusCfg = STATUS_CONFIG[trip.statusRaw] ?? STATUS_CONFIG.planning;
  const totalStops = trip.days.reduce((c, d) => c + d.stops.length, 0);
  const visitedStops = trip.days.reduce((c, d) => c + d.stops.filter(s => s.isVisited).length, 0);

  return (
    <div className="min-h-screen bg-slate-50 font-sans antialiased">
      {/* Nav */}
      <nav className="fixed top-0 left-0 right-0 z-50 bg-[#0c111d]/95 backdrop-blur-md border-b border-white/8">
        <div className="max-w-3xl mx-auto px-5 h-14 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2">
            <div className="w-6 h-6 rounded-lg bg-blue-600 flex items-center justify-center shadow-sm">
              <span className="text-white text-xs">✈</span>
            </div>
            <span className="text-white font-semibold text-[14px]">TripWit</span>
          </Link>
          <Link
            href="/app"
            className="text-xs font-medium text-blue-400 hover:text-blue-300 transition-colors flex items-center gap-1"
          >
            Plan your own trip
            <span className="text-blue-500">→</span>
          </Link>
        </div>
      </nav>

      {/* Hero */}
      <div className="bg-[#0c111d] pt-14">
        <div className="max-w-3xl mx-auto px-5 pt-12 pb-10">
          <div className="flex items-start justify-between gap-4">
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-3">
                <span className={`text-xs font-semibold px-2.5 py-1 rounded-full ${statusCfg.color}`}>
                  {statusCfg.label}
                </span>
              </div>
              <h1 className="text-3xl sm:text-4xl font-bold text-white leading-tight tracking-tight">
                {trip.name}
              </h1>
              {trip.destination && (
                <p className="text-slate-400 mt-2 flex items-center gap-1.5">
                  <span>📍</span>
                  {trip.destination}
                </p>
              )}
              {trip.startDate && trip.endDate && (
                <p className="text-slate-500 text-sm mt-1.5">
                  {formatDate(trip.startDate, { month: "long", day: "numeric", year: "numeric" })}
                  {" – "}
                  {formatDate(trip.endDate, { month: "long", day: "numeric", year: "numeric" })}
                </p>
              )}
            </div>
          </div>

          {/* Stats strip */}
          <div className="flex items-center gap-6 mt-8 pt-6 border-t border-white/8">
            {sortedDays.length > 0 && (
              <div className="text-center">
                <div className="text-2xl font-bold text-white">{sortedDays.length}</div>
                <div className="text-xs text-slate-500 mt-0.5">day{sortedDays.length !== 1 ? "s" : ""}</div>
              </div>
            )}
            {totalStops > 0 && (
              <div className="text-center">
                <div className="text-2xl font-bold text-white">{totalStops}</div>
                <div className="text-xs text-slate-500 mt-0.5">stop{totalStops !== 1 ? "s" : ""}</div>
              </div>
            )}
            {sortedBookings.length > 0 && (
              <div className="text-center">
                <div className="text-2xl font-bold text-white">{sortedBookings.length}</div>
                <div className="text-xs text-slate-500 mt-0.5">booking{sortedBookings.length !== 1 ? "s" : ""}</div>
              </div>
            )}
            {trip.statusRaw !== "planning" && totalStops > 0 && (
              <div className="flex-1 ml-2">
                <div className="flex items-center justify-between mb-1">
                  <span className="text-[11px] text-slate-500">{visitedStops}/{totalStops} visited</span>
                  <span className="text-[11px] text-slate-500">{Math.round((visitedStops/totalStops)*100)}%</span>
                </div>
                <div className="h-1.5 bg-white/8 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-emerald-500 rounded-full"
                    style={{ width: `${Math.round((visitedStops/totalStops)*100)}%` }}
                  />
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Ad banner */}
      <div className="flex justify-center py-3 bg-white border-b border-slate-100">
        <AdUnit slot="PUBLIC_TRIP_TOP_SLOT" format="horizontal" style={{ width: 728, height: 90 }} />
      </div>

      <main className="max-w-3xl mx-auto px-5 py-8 space-y-8">
        {/* Notes */}
        {trip.notes && (
          <div className="bg-white rounded-2xl border border-slate-200 shadow-[0_1px_3px_rgba(0,0,0,0.06)] px-5 py-4">
            <p className="text-[11px] font-semibold text-slate-400 uppercase tracking-wide mb-2">Notes</p>
            <p className="text-slate-600 text-sm leading-relaxed">{trip.notes}</p>
          </div>
        )}

        {/* Bookings */}
        {sortedBookings.length > 0 && (
          <section>
            <h2 className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-3">Bookings</h2>
            <div className="space-y-2">
              {sortedBookings.map((b: Booking) => (
                <div key={b.id} className="bg-white rounded-2xl border border-slate-200 shadow-[0_1px_3px_rgba(0,0,0,0.06)] px-4 py-3.5 flex items-start gap-3.5">
                  <div className="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center text-lg shrink-0">
                    {BOOKING_TYPE_ICONS[b.typeRaw]}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="font-semibold text-slate-800 text-sm">{b.title}</div>
                    <div className="text-xs text-slate-400 mt-0.5">{BOOKING_TYPE_LABELS[b.typeRaw]}</div>
                    {b.confirmationCode && (
                      <div className="text-xs text-slate-500 mt-1">
                        Conf: <span className="font-mono font-semibold bg-slate-100 px-1.5 py-0.5 rounded">{b.confirmationCode}</span>
                      </div>
                    )}
                    {b.typeRaw === "flight" && (b.airline || b.flightNumber) && (
                      <div className="text-xs text-slate-500 mt-0.5">
                        {[b.airline, b.flightNumber].filter(Boolean).join(" ")}
                        {b.departureAirport && b.arrivalAirport && (
                          <span className="font-medium"> · {b.departureAirport} → {b.arrivalAirport}</span>
                        )}
                      </div>
                    )}
                    {b.typeRaw === "hotel" && b.hotelName && (
                      <div className="text-xs text-slate-600 font-medium mt-0.5">{b.hotelName}</div>
                    )}
                    {(b.checkInDate || b.checkOutDate) && (
                      <div className="text-xs text-slate-400 mt-0.5">
                        {b.checkInDate && formatDate(b.checkInDate, { month: "short", day: "numeric" })}
                        {b.checkInDate && b.checkOutDate && " → "}
                        {b.checkOutDate && formatDate(b.checkOutDate, { month: "short", day: "numeric" })}
                      </div>
                    )}
                    {b.notes && <p className="text-xs text-slate-400 italic mt-1">{b.notes}</p>}
                  </div>
                </div>
              ))}
            </div>
          </section>
        )}

        {/* Days */}
        {sortedDays.length > 0 && (
          <section>
            <h2 className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-3">Itinerary</h2>
            <div className="space-y-6">
              {sortedDays.map((day) => {
                const stops = [...day.stops].sort((a, b) => a.sortOrder - b.sortOrder);
                return (
                  <div key={day.id} className="bg-white rounded-2xl border border-slate-200 shadow-[0_1px_3px_rgba(0,0,0,0.06)] overflow-hidden">
                    {/* Day header */}
                    <div className="flex items-center gap-3.5 px-5 py-4 border-b border-slate-100 bg-slate-50/60">
                      <div className="w-8 h-8 rounded-xl bg-slate-900 flex items-center justify-center text-white text-xs font-bold shrink-0 shadow-sm">
                        {day.dayNumber}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 flex-wrap">
                          {day.location && (
                            <span className="font-semibold text-slate-800 text-sm">{day.location}</span>
                          )}
                          {day.date && (
                            <span className="text-xs text-slate-400">
                              {formatDate(day.date, { weekday: "short", month: "short", day: "numeric" })}
                            </span>
                          )}
                        </div>
                        {!day.location && (
                          <span className="text-sm font-semibold text-slate-700">Day {day.dayNumber}</span>
                        )}
                      </div>
                      <span className="text-xs text-slate-400 shrink-0">
                        {stops.length} stop{stops.length !== 1 ? "s" : ""}
                      </span>
                    </div>

                    {day.notes && (
                      <p className="text-sm text-slate-500 italic px-5 py-3 border-b border-slate-50">{day.notes}</p>
                    )}

                    {/* Stops */}
                    <div className="divide-y divide-slate-50">
                      {stops.map((stop: Stop, i: number) => (
                        <div key={stop.id} className="px-5 py-4 flex items-start gap-3.5 group">
                          {/* Color dot + connector line */}
                          <div className="relative flex flex-col items-center shrink-0">
                            <div
                              className="w-3 h-3 rounded-full mt-1 ring-2 ring-white shadow-sm"
                              style={{ backgroundColor: CATEGORY_COLORS[stop.categoryRaw] ?? "#94a3b8" }}
                            />
                            {i < stops.length - 1 && (
                              <div className="w-px bg-slate-100 flex-1 mt-1" style={{ minHeight: 24 }} />
                            )}
                          </div>

                          <div className="flex-1 min-w-0 pb-1">
                            <div className="flex items-start gap-2 flex-wrap">
                              <span className={`font-semibold text-sm ${stop.isVisited ? "line-through text-slate-400" : "text-slate-800"}`}>
                                {stop.name}
                              </span>
                              {stop.isVisited && (
                                <span className="inline-flex items-center gap-1 text-[10px] font-semibold text-emerald-600 bg-emerald-50 px-1.5 py-0.5 rounded-full">
                                  ✓ Visited
                                </span>
                              )}
                              {stop.rating > 0 && (
                                <span className="text-xs text-amber-400">
                                  {"★".repeat(stop.rating)}{"☆".repeat(5 - stop.rating)}
                                </span>
                              )}
                            </div>

                            <div className="text-xs text-slate-400 mt-0.5 flex items-center gap-1.5 flex-wrap">
                              {(() => {
                                const CatIcon = CATEGORY_ICON_MAP[stop.categoryRaw] ?? MapPin;
                                return (
                                  <span
                                    className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full text-[10px] font-semibold"
                                    style={{
                                      backgroundColor: `${CATEGORY_COLORS[stop.categoryRaw]}18`,
                                      color: CATEGORY_COLORS[stop.categoryRaw],
                                    }}
                                  >
                                    <CatIcon className="w-2.5 h-2.5 shrink-0" />
                                    {CATEGORY_LABELS[stop.categoryRaw]}
                                  </span>
                                );
                              })()}
                              {stop.arrivalTime && (
                                <span>
                                  {new Date(stop.arrivalTime).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                                </span>
                              )}
                              {stop.address && (
                                <span className="truncate max-w-[200px]">
                                  📍 {stop.address.split(",").slice(0, 2).join(",")}
                                </span>
                              )}
                            </div>

                            {stop.flightNumber && (
                              <div className="text-xs text-sky-600 mt-1 bg-sky-50 px-2 py-0.5 rounded-lg inline-block">
                                ✈️ {[stop.airline, stop.flightNumber].filter(Boolean).join(" ")}
                                {stop.departureAirport && stop.arrivalAirport && (
                                  <> · {stop.departureAirport} → {stop.arrivalAirport}</>
                                )}
                              </div>
                            )}

                            {stop.notes && (
                              <p className="text-sm text-slate-500 mt-1.5 leading-relaxed">{stop.notes}</p>
                            )}

                            {(stop.website || (stop.links && stop.links.length > 0)) && (
                              <div className="mt-2 flex flex-wrap gap-2">
                                {stop.website && (
                                  <a
                                    href={stop.website}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="text-xs text-blue-500 hover:text-blue-700 hover:underline transition-colors"
                                  >
                                    Visit website →
                                  </a>
                                )}
                                {stop.links?.map((link) => (
                                  <a
                                    key={link.id}
                                    href={link.url}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="text-xs text-blue-500 hover:text-blue-700 hover:underline transition-colors"
                                  >
                                    {link.title} →
                                  </a>
                                ))}
                              </div>
                            )}
                          </div>
                        </div>
                      ))}

                      {stops.length === 0 && (
                        <p className="text-sm text-slate-400 italic px-5 py-4">No stops planned.</p>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </section>
        )}

        {/* Bottom ad */}
        <div className="flex justify-center">
          <AdUnit slot="PUBLIC_TRIP_BOTTOM_SLOT" format="rectangle" style={{ width: 336, height: 280 }} />
        </div>

        {/* CTA */}
        <div className="rounded-2xl bg-[#0c111d] px-6 py-8 text-center">
          <div className="w-10 h-10 rounded-xl bg-blue-600 flex items-center justify-center mx-auto mb-3 shadow-sm">
            <span className="text-white">✈</span>
          </div>
          <h3 className="text-white font-semibold text-base mb-1">Plan your own adventure</h3>
          <p className="text-slate-400 text-sm mb-4">
            Create beautiful itineraries with TripWit — free, for web and iOS.
          </p>
          <Link
            href="/app"
            className="inline-flex items-center gap-1.5 px-5 py-2.5 bg-blue-600 text-white rounded-xl text-sm font-semibold hover:bg-blue-500 transition-colors shadow-sm"
          >
            Start planning free
            <span className="text-blue-300">→</span>
          </Link>
        </div>

        <p className="text-center text-xs text-slate-400 pb-4">
          Planned with{" "}
          <Link href="/" className="text-blue-400 hover:underline">TripWit</Link>
          {" "}· Map data © OpenStreetMap contributors
        </p>
      </main>
    </div>
  );
}
