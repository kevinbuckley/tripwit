export const dynamic = "force-dynamic";

import { notFound } from "next/navigation";
import { getDoc, doc } from "firebase/firestore";
import Link from "next/link";
import { db } from "@/lib/firebase";
import type { Trip, Stop } from "@/lib/types";
import { CATEGORY_LABELS, CATEGORY_COLORS } from "@/lib/types";
import type { Metadata } from "next";
import AdUnit from "@/components/ads/AdUnit";

interface Props {
  params: Promise<{ id: string }>;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  if (!process.env.NEXT_PUBLIC_FIREBASE_API_KEY) {
    return { title: "TripWit — Trip" };
  }
  const { id } = await params;
  try {
    const snap = await getDoc(doc(db, "trips", id));
    if (!snap.exists()) return { title: "Trip not found" };
    const trip = snap.data() as Trip;
    return {
      title: `${trip.name} — TripWit`,
      description: `Explore ${trip.name}${trip.destination ? ` in ${trip.destination}` : ""} on TripWit.`,
    };
  } catch {
    return { title: "TripWit — Trip" };
  }
}

export default async function PublicTripPage({ params }: Props) {
  const { id } = await params;
  const snap = await getDoc(doc(db, "trips", id));

  if (!snap.exists()) notFound();
  const trip = snap.data() as Trip;
  if (!trip.isPublic) notFound();

  const sortedDays = [...trip.days].sort((a, b) => a.dayNumber - b.dayNumber);

  return (
    <div className="min-h-screen bg-slate-50">
      {/* Header */}
      <header className="bg-white border-b border-slate-200 px-4 py-3 flex items-center justify-between">
        <Link href="/" className="text-lg font-bold text-slate-800">✈ TripWit</Link>
        <Link
          href="/app"
          className="text-sm text-blue-600 hover:underline"
        >
          Plan your own trip →
        </Link>
      </header>

      {/* Ad banner */}
      <div className="flex justify-center py-3 bg-white border-b border-slate-100">
        <AdUnit slot="PUBLIC_TRIP_TOP_SLOT" format="horizontal" style={{ width: 728, height: 90 }} />
      </div>

      <main className="max-w-2xl mx-auto px-4 py-8">
        {/* Trip header */}
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-slate-800">{trip.name}</h1>
          {trip.destination && (
            <p className="text-slate-500 mt-1">{trip.destination}</p>
          )}
          {trip.startDate && trip.endDate && (
            <p className="text-sm text-slate-400 mt-1">
              {new Date(trip.startDate).toLocaleDateString()} –{" "}
              {new Date(trip.endDate).toLocaleDateString()}
            </p>
          )}
        </div>

        {/* Days */}
        {sortedDays.map((day) => {
          const stops = [...day.stops].sort((a, b) => a.sortOrder - b.sortOrder);
          return (
            <div key={day.id} className="mb-6">
              <div className="flex items-baseline gap-2 mb-3">
                <h2 className="text-lg font-semibold text-slate-700">
                  Day {day.dayNumber}
                </h2>
                {day.date && (
                  <span className="text-sm text-slate-400">
                    {new Date(day.date + "T12:00:00").toLocaleDateString(undefined, {
                      weekday: "short",
                      month: "short",
                      day: "numeric",
                    })}
                  </span>
                )}
                {day.location && (
                  <span className="text-sm text-slate-400">· {day.location}</span>
                )}
              </div>

              <div className="space-y-2">
                {stops.map((stop: Stop) => (
                  <div
                    key={stop.id}
                    className="bg-white rounded-xl border border-slate-200 px-4 py-3 flex items-start gap-3"
                  >
                    <div
                      className="w-3 h-3 rounded-full mt-1.5 shrink-0"
                      style={{ backgroundColor: CATEGORY_COLORS[stop.categoryRaw] }}
                    />
                    <div>
                      <div className="font-medium text-slate-800">{stop.name}</div>
                      <div className="text-xs text-slate-400 mt-0.5">
                        {CATEGORY_LABELS[stop.categoryRaw]}
                        {stop.address && ` · ${stop.address.split(",").slice(0, 2).join(",")}`}
                      </div>
                      {stop.notes && (
                        <p className="text-sm text-slate-600 mt-1">{stop.notes}</p>
                      )}
                      {stop.website && (
                        <a
                          href={stop.website}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-xs text-blue-500 hover:underline mt-1 block"
                        >
                          Visit website →
                        </a>
                      )}
                    </div>
                  </div>
                ))}
                {stops.length === 0 && (
                  <p className="text-sm text-slate-400 italic">No stops added yet.</p>
                )}
              </div>
            </div>
          );
        })}

        {/* Bottom ad */}
        <div className="flex justify-center mt-8">
          <AdUnit slot="PUBLIC_TRIP_BOTTOM_SLOT" format="rectangle" style={{ width: 336, height: 280 }} />
        </div>

        <div className="mt-8 text-center text-sm text-slate-400">
          Planned with{" "}
          <Link href="/" className="text-blue-500 hover:underline">TripWit</Link>
        </div>
      </main>
    </div>
  );
}
