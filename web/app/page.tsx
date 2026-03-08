import Link from "next/link";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "TripWit — Plan Your Perfect Trip",
  description:
    "TripWit is a free travel planner for desktop. Organize your itinerary day-by-day, pin stops on a map, and share your trips with friends.",
};

const features = [
  {
    icon: "🗺️",
    title: "Interactive Map",
    desc: "Every stop pinned on a live map with color-coded categories. See your whole trip at a glance.",
    accent: "from-blue-500 to-cyan-400",
  },
  {
    icon: "📅",
    title: "Day-by-Day Itinerary",
    desc: "Organize stops by day with arrival times, notes, websites, and visited checkmarks.",
    accent: "from-violet-500 to-purple-400",
  },
  {
    icon: "🎫",
    title: "Bookings & Expenses",
    desc: "Track flights, hotels, and car rentals. Log expenses and stay within your budget.",
    accent: "from-emerald-500 to-teal-400",
  },
  {
    icon: "📋",
    title: "Packing Lists",
    desc: "Create custom lists for anything — packing, groceries, must-see spots.",
    accent: "from-orange-500 to-amber-400",
  },
  {
    icon: "📲",
    title: "iOS + Web",
    desc: "Use TripWit on iPhone and import your .tripwit files to the web — your data travels with you.",
    accent: "from-pink-500 to-rose-400",
  },
  {
    icon: "🔒",
    title: "Secure & Synced",
    desc: "Sign in with Google. Your trips are stored securely and accessible from any device.",
    accent: "from-slate-500 to-slate-400",
  },
];

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-white font-sans antialiased">
      {/* Nav */}
      <nav className="fixed top-0 left-0 right-0 z-50 border-b border-white/10 bg-[#0c111d]/90 backdrop-blur-md">
        <div className="max-w-6xl mx-auto px-6 h-14 flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <div className="w-7 h-7 rounded-lg bg-blue-600 flex items-center justify-center shadow-sm">
              <span className="text-white text-sm">✈</span>
            </div>
            <span className="text-white font-semibold text-[15px] tracking-tight">TripWit</span>
          </div>
          <Link
            href="/app"
            className="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-500 transition-colors shadow-sm"
          >
            Open App
          </Link>
        </div>
      </nav>

      {/* Hero */}
      <section className="relative bg-[#0c111d] pt-32 pb-24 px-6 overflow-hidden">
        {/* Background glow */}
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[400px] bg-blue-600/20 rounded-full blur-[100px]" />
          <div className="absolute top-1/4 right-1/4 w-[300px] h-[300px] bg-violet-600/10 rounded-full blur-[80px]" />
        </div>

        <div className="relative max-w-3xl mx-auto text-center">
          {/* Badge */}
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-blue-500/15 border border-blue-500/25 text-blue-400 text-xs font-semibold mb-8 tracking-wide">
            <span className="w-1.5 h-1.5 rounded-full bg-blue-400 animate-pulse" />
            Free travel planner for web &amp; iOS
          </div>

          <h1 className="text-5xl sm:text-6xl font-bold text-white leading-[1.1] tracking-tight mb-6">
            Plan trips that
            <br />
            <span className="bg-gradient-to-r from-blue-400 to-cyan-400 bg-clip-text text-transparent">
              actually happen
            </span>
          </h1>

          <p className="text-lg text-slate-400 max-w-xl mx-auto leading-relaxed mb-10">
            TripWit is a desktop travel planner that brings your itinerary, map, bookings, and budget
            together in one beautiful workspace.
          </p>

          <div className="flex flex-col sm:flex-row gap-3 justify-center items-center">
            <Link
              href="/app"
              className="inline-flex items-center gap-2 px-8 py-3.5 bg-blue-600 text-white rounded-xl font-semibold text-base hover:bg-blue-500 transition-all shadow-[0_0_20px_rgba(59,130,246,0.4)] hover:shadow-[0_0_28px_rgba(59,130,246,0.5)]"
            >
              Start Planning — Free
              <span className="text-blue-300">→</span>
            </Link>
            <span className="text-xs text-slate-500">No credit card required</span>
          </div>
        </div>
      </section>

      {/* Feature grid */}
      <section className="bg-slate-50 py-20 px-6">
        <div className="max-w-5xl mx-auto">
          <div className="text-center mb-14">
            <h2 className="text-3xl font-bold text-slate-900 tracking-tight mb-3">
              Everything in one place
            </h2>
            <p className="text-slate-500 text-base max-w-md mx-auto">
              Stop juggling spreadsheets and notes apps. TripWit gives you a proper home for every trip detail.
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-5">
            {features.map((f) => (
              <div
                key={f.title}
                className="bg-white rounded-2xl p-6 border border-slate-100 shadow-[0_1px_3px_rgba(0,0,0,0.07)] hover:shadow-[0_8px_24px_rgba(0,0,0,0.09)] transition-shadow group"
              >
                <div className={`w-11 h-11 rounded-xl bg-gradient-to-br ${f.accent} flex items-center justify-center text-xl mb-4 shadow-sm group-hover:scale-105 transition-transform`}>
                  {f.icon}
                </div>
                <h3 className="font-semibold text-slate-900 mb-1.5">{f.title}</h3>
                <p className="text-sm text-slate-500 leading-relaxed">{f.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Social proof strip */}
      <section className="bg-white border-y border-slate-100 py-8 px-6">
        <div className="max-w-4xl mx-auto flex flex-wrap justify-center gap-x-10 gap-y-4 text-sm text-slate-500">
          {[
            { stat: "Free", label: "forever — no subscriptions" },
            { stat: "iOS + Web", label: "your trips travel with you" },
            { stat: "Offline", label: ".tripwit file export" },
            { stat: "Private", label: "your data stays yours" },
          ].map((item) => (
            <div key={item.stat} className="flex items-center gap-2">
              <span className="font-bold text-slate-900">{item.stat}</span>
              <span>{item.label}</span>
            </div>
          ))}
        </div>
      </section>

      {/* CTA */}
      <section className="bg-[#0c111d] py-20 px-6 text-center relative overflow-hidden">
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-[500px] h-[300px] bg-blue-600/15 rounded-full blur-[80px]" />
        </div>
        <div className="relative max-w-xl mx-auto">
          <h2 className="text-3xl font-bold text-white mb-3 tracking-tight">
            Ready for your next adventure?
          </h2>
          <p className="text-slate-400 mb-8">
            Join travelers who plan smarter with TripWit. It&apos;s free, fast, and beautifully simple.
          </p>
          <Link
            href="/app"
            className="inline-flex items-center gap-2 px-8 py-3.5 bg-blue-600 text-white rounded-xl font-semibold text-base hover:bg-blue-500 transition-all shadow-[0_0_20px_rgba(59,130,246,0.35)] hover:shadow-[0_0_28px_rgba(59,130,246,0.5)]"
          >
            Open TripWit
            <span className="text-blue-300">→</span>
          </Link>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-[#080d18] py-6 px-6 border-t border-white/5">
        <div className="max-w-6xl mx-auto flex items-center justify-between text-xs text-slate-600">
          <div className="flex items-center gap-2">
            <div className="w-5 h-5 rounded-md bg-blue-600 flex items-center justify-center">
              <span className="text-white text-[10px]">✈</span>
            </div>
            <span className="text-slate-500 font-medium">TripWit</span>
          </div>
          <span>Map data © OpenStreetMap contributors · © CARTO</span>
        </div>
      </footer>
    </div>
  );
}
