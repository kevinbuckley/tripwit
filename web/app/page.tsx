"use client";

import { useEffect, useState, useCallback, useRef } from "react";
import { useAuth } from "@/contexts/AuthContext";
import Header from "@/components/layout/Header";
import TripsSidebar from "@/components/layout/TripsSidebar";
import TripDetail from "@/components/layout/TripDetail";
import MapPanel from "@/components/layout/MapPanel";
import { getTrips, createTrip, updateTrip, deleteTrip, insertTrip } from "@/lib/db";
import type { Trip, Stop } from "@/lib/types";
import { newId, nowISO } from "@/lib/types";
import { Map, ChevronLeft, Check, Loader2, Maximize2, Minimize2 } from "lucide-react";

type MobilePanel = "sidebar" | "detail";

export default function AppPage() {
  const { user, loading, signIn, signInWithApple, signOut } = useAuth();

  const [trips, setTrips] = useState<Trip[]>([]);
  const [selectedTripId, setSelectedTripId] = useState<string | null>(null);
  const [selectedStopId, setSelectedStopId] = useState<string | null>(null);
  const [tripsLoading, setTripsLoading] = useState(true);
  const [saveStatus, setSaveStatus] = useState<"idle" | "saving" | "saved">("idle");
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [mapState, setMapState] = useState<"normal" | "collapsed" | "maximized">("normal");
  const [mobilePanel, setMobilePanel] = useState<MobilePanel>("sidebar");

  const userId = user?.id;
  useEffect(() => {
    if (!userId) return;
    setTripsLoading(true);
    getTrips(userId)
      .then((data) => {
        setTrips(data);
        setSelectedTripId((prev) => prev ?? data[0]?.id ?? null);
      })
      .finally(() => setTripsLoading(false));
  }, [userId]);

  const selectedTrip = trips.find((t) => t.id === selectedTripId) ?? null;
  const mapStops: Stop[] = selectedTrip
    ? selectedTrip.days
        .flatMap((d) => d.stops)
        .sort((a, b) => a.sortOrder - b.sortOrder)
    : [];

  const handleSelectTrip = useCallback((id: string) => {
    setSelectedTripId(id);
    setSelectedStopId(null);
    setMobilePanel("detail");
  }, []);

  const handleCreateTrip = useCallback(async () => {
    if (!user) return;
    try {
      const trip = await createTrip(user.id);
      setTrips((prev) => [trip, ...prev]);
      setSelectedTripId(trip.id);
      setMobilePanel("detail");
    } catch { /* silent */ }
  }, [user]);

  const handleDeleteTrip = useCallback(async (id: string) => {
    try {
      await deleteTrip(id);
      setTrips((prev) => {
        const remaining = prev.filter((t) => t.id !== id);
        setSelectedTripId((cur) => {
          if (cur !== id) return cur;
          return remaining[0]?.id ?? null;
        });
        return remaining;
      });
    } catch { /* silent */ }
  }, []);

  const handleImportTrip = useCallback(async (trip: Trip) => {
    if (!user) return;
    try {
      const tripWithUser = { ...trip, userId: user.id };
      await insertTrip(tripWithUser);
      setTrips((prev) => [tripWithUser, ...prev]);
      setSelectedTripId(trip.id);
      setMobilePanel("detail");
    } catch { /* silent */ }
  }, [user]);

  const handleDuplicateTrip = useCallback(async (trip: Trip) => {
    if (!user) return;
    const now = nowISO();
    const dupe: Trip = {
      ...JSON.parse(JSON.stringify(trip)),
      id: newId(),
      userId: user.id,
      name: `${trip.name} (copy)`,
      isPublic: false,
      createdAt: now,
      updatedAt: now,
    };
    dupe.days = dupe.days.map((d: Trip["days"][0]) => ({
      ...d, id: newId(),
      stops: d.stops.map((s: Stop) => ({
        ...s, id: newId(),
        todos: s.todos.map((t) => ({ ...t, id: newId() })),
        links: s.links.map((l) => ({ ...l, id: newId() })),
        comments: s.comments.map((c) => ({ ...c, id: newId() })),
      })),
    }));
    dupe.bookings = dupe.bookings.map((b: Trip["bookings"][0]) => ({ ...b, id: newId() }));
    dupe.expenses = dupe.expenses.map((e: Trip["expenses"][0]) => ({ ...e, id: newId() }));
    dupe.lists = dupe.lists.map((l: Trip["lists"][0]) => ({
      ...l, id: newId(), items: l.items.map((i) => ({ ...i, id: newId() })),
    }));
    await insertTrip(dupe);
    setTrips((prev) => [dupe, ...prev]);
    setSelectedTripId(dupe.id);
    setMobilePanel("detail");
  }, [user]);

  const handleUpdateTrip = useCallback(async (changes: Partial<Trip>) => {
    if (!selectedTripId) return;
    setTrips((prev) => prev.map((t) => (t.id === selectedTripId ? { ...t, ...changes } : t)));
    setSaveStatus("saving");
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(async () => {
      try {
        await updateTrip(selectedTripId, changes);
        setSaveStatus("saved");
        setTimeout(() => setSaveStatus("idle"), 1500);
      } catch { setSaveStatus("idle"); }
    }, 600);
  }, [selectedTripId]);

  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key === "n") { e.preventDefault(); handleCreateTrip(); }
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [handleCreateTrip]);

  // ── Auth loading ───────────────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="h-screen flex items-center justify-center bg-[#0c111d]">
        <div className="flex flex-col items-center gap-4">
          <img src="/icon-512.png" alt="TripWit" className="w-10 h-10 rounded-2xl object-cover shadow-lg" />
          <div className="w-5 h-5 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
        </div>
      </div>
    );
  }

  // ── Sign-in screen ────────────────────────────────────────────────────────
  if (!user) {
    return (
      <div className="h-screen flex flex-col bg-[#0c111d]">
        <nav className="px-6 h-14 flex items-center border-b border-white/6 shrink-0">
          <div className="flex items-center gap-2.5">
            <img src="/icon-512.png" alt="TripWit" className="w-7 h-7 rounded-xl object-cover shadow-sm" />
            <span className="text-white font-semibold text-[15px]">TripWit</span>
          </div>
        </nav>
        <div className="flex-1 flex flex-col items-center justify-center px-6 relative overflow-hidden">
          {/* Layered gradient orbs */}
          <div className="absolute inset-0 overflow-hidden pointer-events-none">
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[500px] bg-blue-600/12 rounded-full blur-[120px]" />
            <div className="absolute top-1/4 left-1/3 w-[300px] h-[250px] bg-indigo-500/8 rounded-full blur-[80px]" />
            <div className="absolute bottom-1/4 right-1/4 w-[250px] h-[200px] bg-blue-400/8 rounded-full blur-[80px]" />
            {/* Subtle dot grid */}
            <div className="absolute inset-0 opacity-[0.03]" style={{ backgroundImage: "radial-gradient(circle, white 1px, transparent 1px)", backgroundSize: "32px 32px" }} />
          </div>
          <div className="relative text-center max-w-sm">
            <img
              src="/icon-512.png"
              alt="TripWit"
              className="w-20 h-20 rounded-3xl object-cover mx-auto mb-7 shadow-[0_0_0_1px_rgba(255,255,255,0.08),0_8px_40px_rgba(59,130,246,0.45)] hover:shadow-[0_0_0_1px_rgba(255,255,255,0.12),0_12px_48px_rgba(59,130,246,0.55)] transition-shadow duration-500"
            />
            <h1 className="text-[28px] font-extrabold text-white mb-2.5 tracking-tight leading-tight">Welcome to TripWit</h1>
            <p className="text-slate-400 text-[14px] leading-relaxed mb-8 max-w-[280px] mx-auto">
              Your itineraries, bookings, and budget — all in one beautiful workspace.
            </p>
            <button
              onClick={signInWithApple}
              className="inline-flex items-center gap-3 w-full justify-center px-5 py-3.5 bg-white text-slate-800 rounded-xl font-semibold text-sm hover:bg-slate-50 active:scale-[0.98] transition-all shadow-[0_4px_20px_rgba(0,0,0,0.25)] hover:shadow-[0_6px_28px_rgba(59,130,246,0.22),0_4px_20px_rgba(0,0,0,0.2)] mb-3"
            >
              <svg className="w-4 h-4 shrink-0" viewBox="0 0 24 24" fill="currentColor">
                <path d="M17.05 20.28c-.98.95-2.05.88-3.08.4-1.09-.5-2.08-.48-3.24 0-1.44.62-2.2.44-3.06-.4C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"/>
              </svg>
              Continue with Apple
            </button>
            <button
              onClick={signIn}
              className="inline-flex items-center gap-3 w-full justify-center px-5 py-3.5 bg-white/10 text-white border border-white/10 rounded-xl font-semibold text-sm hover:bg-white/15 active:scale-[0.98] transition-all mb-6"
            >
              <svg className="w-4 h-4 shrink-0" viewBox="0 0 24 24">
                <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
                <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
              </svg>
              Continue with Google
            </button>
            {/* Feature chips */}
            <div className="flex flex-wrap justify-center gap-2 mb-5">
              {[
                { icon: "📍", label: "Day-by-day itinerary" },
                { icon: "✈️", label: "Flights & hotels" },
                { icon: "💰", label: "Budget tracking" },
                { icon: "🗺️", label: "Interactive map" },
              ].map(({ icon, label }) => (
                <span key={label} className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-full bg-white/5 border border-white/10 text-[12px] text-slate-400 hover:text-slate-300 hover:border-white/20 transition-colors">
                  <span>{icon}</span>
                  {label}
                </span>
              ))}
            </div>
            <p className="text-xs text-slate-600 mb-3">Free forever · No credit card required</p>
            <a
              href="https://apps.apple.com/us/app/tripwit/id6759219752"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full border border-white/10 bg-white/5 text-xs font-medium text-slate-400 hover:text-slate-200 hover:border-white/20 hover:bg-white/8 transition-all"
            >
              <svg className="w-3.5 h-3.5 text-slate-400" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>
              Also on iPhone
            </a>
          </div>
        </div>
      </div>
    );
  }

  // ── Trips loading — full skeleton ─────────────────────────────────────────
  if (tripsLoading) {
    return (
      <div className="h-screen flex overflow-hidden">
        {/* Skeleton sidebar */}
        <div className="hidden md:flex flex-col w-64 shrink-0 h-full bg-[#0c111d] border-r border-white/5">
          <div className="flex items-center gap-2.5 px-4 h-14 border-b border-white/5 shrink-0">
            <img src="/icon-512.png" alt="TripWit" className="w-7 h-7 rounded-xl object-cover shrink-0" />
            <span className="text-white font-semibold text-[15px] tracking-tight">TripWit</span>
          </div>
          <div className="flex items-center justify-between px-4 pt-5 pb-2 shrink-0">
            <span className="text-[10px] font-semibold text-slate-500 uppercase tracking-widest">My Trips</span>
          </div>
          <div className="flex-1 px-2 space-y-0.5 pt-1">
            {[78, 55, 88].map((w, i) => (
              <div key={i} className="rounded-xl px-3 py-2.5">
                <div className="flex items-start gap-2.5">
                  <div className="w-1.5 h-1.5 rounded-full mt-[5px] shrink-0 shimmer-dark" style={{ animationDelay: `${i * 0.15}s` }} />
                  <div className="flex-1 space-y-1.5">
                    <div className="h-3 rounded-md shimmer-dark" style={{ width: `${w}%`, animationDelay: `${i * 0.15}s` }} />
                    <div className="h-2 rounded shimmer-dark" style={{ width: `${Math.floor(w * 0.55)}%`, animationDelay: `${i * 0.15 + 0.1}s` }} />
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Skeleton detail panel */}
        <div className="flex flex-1 flex-col overflow-hidden">
          <div className="h-14 border-b border-slate-200/60 bg-white shrink-0" />
          <div className="flex flex-1 overflow-hidden bg-slate-50">
            <div className="flex-1 flex flex-col overflow-hidden">
              {/* Header card skeleton */}
              <div className="mx-4 mt-4 bg-white rounded-xl shadow-[0_1px_3px_rgba(0,0,0,0.06)] border border-slate-100 px-5 py-4 shrink-0 space-y-3">
                <div className="h-7 rounded-lg shimmer" style={{ width: "62%" }} />
                <div className="h-3.5 rounded shimmer" style={{ width: "38%" }} />
                <div className="flex gap-2 flex-wrap">
                  <div className="h-7 w-28 rounded-lg shimmer" />
                  <div className="h-7 w-32 rounded-lg shimmer" />
                  <div className="h-7 w-36 rounded-lg shimmer" />
                  <div className="h-7 w-20 rounded-lg shimmer" />
                </div>
              </div>
              {/* Tab bar skeleton */}
              <div className="flex gap-1 px-4 pt-3 pb-0 shrink-0">
                {[68, 80, 76, 56].map((w, i) => (
                  <div key={i} className="h-8 rounded-t-lg shimmer" style={{ width: w }} />
                ))}
              </div>
              {/* Day rows skeleton */}
              <div className="mx-4 bg-white border border-slate-100 rounded-b-xl shadow-[0_1px_3px_rgba(0,0,0,0.06)] overflow-hidden">
                {[65, 80, 50].map((w, i) => (
                  <div key={i} className="flex items-center gap-3 px-4 py-3.5 border-b border-slate-100">
                    <div className="w-7 h-7 rounded-full shimmer shrink-0" style={{ animationDelay: `${i * 0.12}s` }} />
                    <div className="flex-1 space-y-1.5">
                      <div className="h-3.5 rounded shimmer" style={{ width: `${w}%`, animationDelay: `${i * 0.12}s` }} />
                      <div className="h-2.5 rounded shimmer" style={{ width: "28%", animationDelay: `${i * 0.12 + 0.08}s` }} />
                    </div>
                    <div className="w-4 h-4 rounded shimmer shrink-0" />
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // ── Main app ───────────────────────────────────────────────────────────────
  return (
    <div className="h-screen flex overflow-hidden">

      {/* ── Mobile: sliding panel container ─────────────────────────────────── */}
      <div className={`md:hidden mobile-panels ${mobilePanel === "detail" ? "show-detail" : ""}`}>
        {/* Mobile sidebar panel */}
        <div className="mobile-panel flex flex-col bg-[#0c111d]">
          <TripsSidebar
            trips={trips}
            selectedTripId={selectedTripId}
            userId={user.id}
            user={user}
            onSelectTrip={handleSelectTrip}
            onCreateTrip={handleCreateTrip}
            onDeleteTrip={handleDeleteTrip}
            onImportTrip={handleImportTrip}
            onDuplicateTrip={handleDuplicateTrip}
            onSignOut={signOut}
          />
        </div>

        {/* Mobile detail panel */}
        <div className="mobile-panel flex flex-col overflow-hidden">
          {/* Mobile top bar */}
          <div className="flex items-center gap-2 px-3 h-14 border-b border-slate-200/60 bg-white shrink-0">
            <button
              onClick={() => setMobilePanel("sidebar")}
              className="flex items-center gap-1 p-1.5 -ml-1 rounded-lg text-slate-500 hover:text-slate-900 hover:bg-slate-100 transition-colors shrink-0"
              aria-label="Back to trips"
            >
              <ChevronLeft className="w-5 h-5" />
              <span className="text-sm font-medium">Trips</span>
            </button>
            <div className="flex-1 min-w-0 text-center">
              <span className="text-sm font-semibold text-slate-900 truncate block">
                {selectedTrip?.name ?? ""}
              </span>
            </div>
            <div className="w-16 shrink-0 flex justify-end">
              {saveStatus !== "idle" && (
                <div className={`save-status-enter inline-flex items-center gap-1 text-xs font-medium px-2 py-1 rounded-full transition-all ${
                  saveStatus === "saved" ? "bg-slate-900 text-white" : "bg-slate-100 text-slate-500"
                }`}>
                  {saveStatus === "saving" && <Loader2 className="w-3 h-3 animate-spin" />}
                  {saveStatus === "saved" && <Check className="w-3 h-3 text-emerald-400" />}
                </div>
              )}
            </div>
          </div>
          <div className="flex-1 overflow-hidden">
            {selectedTrip ? (
              <TripDetail
                trip={selectedTrip}
                showAds={true}
                onUpdateTrip={handleUpdateTrip}
                onSelectStop={setSelectedStopId}
                selectedStopId={selectedStopId}
              />
            ) : (
              <div className="flex-1 flex flex-col items-center justify-center text-center px-8 bg-slate-50 h-full">
                <div className="w-16 h-16 rounded-2xl bg-white border border-slate-200 shadow-card flex items-center justify-center text-3xl mb-4">🗺️</div>
                <h2 className="text-lg font-semibold text-slate-800 mb-1.5">Select a trip</h2>
                <p className="text-sm text-slate-400 max-w-xs leading-relaxed">Pick a trip from the sidebar to view and edit it.</p>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* ── Desktop: sidebar ─────────────────────────────────────────────────── */}
      <div className="hidden md:flex flex-col w-64 shrink-0 h-full">
        <TripsSidebar
          trips={trips}
          selectedTripId={selectedTripId}
          userId={user.id}
          user={user}
          onSelectTrip={handleSelectTrip}
          onCreateTrip={handleCreateTrip}
          onDeleteTrip={handleDeleteTrip}
          onImportTrip={handleImportTrip}
          onDuplicateTrip={handleDuplicateTrip}
          onSignOut={signOut}
        />
      </div>

      {/* ── Desktop: right panel ─────────────────────────────────────────────── */}
      <div className="hidden md:flex flex-1 flex-col overflow-hidden">

        {/* Desktop header (ads + save status) */}
        <Header showAds={true} saveStatus={saveStatus} />

        <div className="flex flex-1 overflow-hidden">
          {/* Center: Trip detail or empty state — hidden when map is maximized */}
          {mapState !== "maximized" && (selectedTrip ? (
            <TripDetail
              trip={selectedTrip}
              showAds={true}
              onUpdateTrip={handleUpdateTrip}
              onSelectStop={setSelectedStopId}
              selectedStopId={selectedStopId}
            />
          ) : (
            <div className="flex-1 flex flex-col items-center justify-center text-center px-8 bg-slate-50">
              <div className="w-16 h-16 rounded-2xl bg-white border border-slate-200 shadow-card flex items-center justify-center text-3xl mb-4">
                🗺️
              </div>
              <h2 className="text-lg font-semibold text-slate-800 mb-1.5">
                {trips.length === 0 ? "Plan your first adventure" : "Select a trip"}
              </h2>
              <p className="text-sm text-slate-400 max-w-xs mb-5 leading-relaxed">
                {trips.length === 0
                  ? "Create a trip to start building your itinerary with days, stops, bookings, and more."
                  : "Pick a trip from the sidebar to view and edit it."}
              </p>
              {trips.length === 0 && (
                <button
                  onClick={handleCreateTrip}
                  className="inline-flex items-center gap-2 px-5 py-2.5 bg-blue-600 text-white text-sm font-semibold rounded-xl hover:bg-blue-700 transition-colors shadow-sm"
                >
                  ✈️ Create Your First Trip
                </button>
              )}
            </div>
          ))}

          {/* Right: Map panel (collapsible / maximizable, hidden on mobile) */}
          <div className={`hidden md:flex${mapState === "maximized" ? " flex-1" : ""}`}>
            {mapState !== "collapsed" ? (
              <div className={`${mapState === "maximized" ? "flex-1 w-full" : "w-96 shrink-0"} border-l border-slate-200 flex flex-col bg-slate-100`}>
                {/* Map header bar */}
                <div className="flex items-center justify-between px-3 h-10 border-b border-slate-200 bg-white shrink-0">
                  <div className="flex items-center gap-1.5 text-[11px] font-semibold text-slate-500 uppercase tracking-wide">
                    <Map className="w-3 h-3" />
                    Map
                  </div>
                  <div className="flex items-center gap-0.5">
                    <button
                      onClick={() => setMapState(mapState === "maximized" ? "normal" : "maximized")}
                      title={mapState === "maximized" ? "Restore map" : "Maximize map"}
                      className="p-1.5 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors"
                    >
                      {mapState === "maximized"
                        ? <Minimize2 className="w-3.5 h-3.5" />
                        : <Maximize2 className="w-3.5 h-3.5" />}
                    </button>
                    <button
                      onClick={() => setMapState("collapsed")}
                      title="Hide map"
                      className="p-1.5 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors text-xs font-medium flex items-center gap-1"
                    >
                      <ChevronLeft className="w-3.5 h-3.5" />
                      Hide
                    </button>
                  </div>
                </div>
                <div className="flex-1 relative">
                  <MapPanel stops={mapStops} selectedStopId={selectedStopId} onSelectStop={setSelectedStopId} />
                </div>
              </div>
            ) : (
              <button
                onClick={() => setMapState("normal")}
                className="shrink-0 w-9 border-l border-slate-200 flex flex-col items-center justify-center gap-1.5 bg-slate-50 hover:bg-slate-100 transition-colors group"
                title="Show map"
              >
                <Map className="w-3.5 h-3.5 text-slate-400 group-hover:text-slate-600 transition-colors" />
                <span className="text-[10px] text-slate-400 group-hover:text-slate-600 font-medium transition-colors [writing-mode:vertical-lr] rotate-180 tracking-wide">
                  Map
                </span>
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
