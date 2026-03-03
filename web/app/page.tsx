import Link from "next/link";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "TripWit — Plan Your Perfect Trip",
  description:
    "TripWit is a free travel planner for desktop. Organize your itinerary day-by-day, pin stops on a map, and share your trips with friends.",
};

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-white">
      {/* Nav */}
      <nav className="px-6 py-4 flex items-center justify-between border-b border-slate-100">
        <span className="text-xl font-bold text-slate-800">✈ TripWit</span>
        <Link
          href="/app"
          className="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors"
        >
          Open App
        </Link>
      </nav>

      {/* Hero */}
      <section className="max-w-4xl mx-auto px-6 py-20 text-center">
        <h1 className="text-5xl font-extrabold text-slate-900 leading-tight">
          Plan trips that
          <br />
          <span className="text-blue-600">actually happen</span>
        </h1>
        <p className="mt-6 text-lg text-slate-500 max-w-xl mx-auto">
          TripWit is a free desktop travel planner. Organize your itinerary
          day-by-day, pin stops on an interactive map, and share your trips
          with friends — all in one place.
        </p>
        <div className="mt-8 flex flex-col sm:flex-row gap-3 justify-center">
          <Link
            href="/app"
            className="px-8 py-3 bg-blue-600 text-white rounded-xl font-semibold text-base hover:bg-blue-700 transition-colors shadow-md"
          >
            Start Planning — It&apos;s Free
          </Link>
        </div>
      </section>

      {/* Features */}
      <section className="bg-slate-50 py-16">
        <div className="max-w-4xl mx-auto px-6">
          <h2 className="text-2xl font-bold text-slate-800 text-center mb-10">
            Everything you need to plan a great trip
          </h2>
          <div className="grid md:grid-cols-3 gap-6">
            {[
              {
                icon: "🗺",
                title: "Interactive Map",
                desc: "Pin every stop on a live map. See your whole trip at a glance with color-coded categories.",
              },
              {
                icon: "📅",
                title: "Day-by-Day Itinerary",
                desc: "Organize stops by day, add arrival times, notes, websites, and mark stops as visited.",
              },
              {
                icon: "🔗",
                title: "Shareable Trips",
                desc: "Share a public link to your trip so friends and family can follow along.",
              },
              {
                icon: "📲",
                title: "Import from iOS",
                desc: "Already using TripWit on iPhone? Import your .tripwit files directly.",
              },
              {
                icon: "🔒",
                title: "Sign in with Google",
                desc: "Your trips are stored securely and sync across all your devices.",
              },
              {
                icon: "🆓",
                title: "Free to Use",
                desc: "TripWit is completely free. No subscriptions, no paywalls.",
              },
            ].map((f) => (
              <div key={f.title} className="bg-white rounded-xl p-5 border border-slate-200">
                <div className="text-2xl mb-2">{f.icon}</div>
                <h3 className="font-semibold text-slate-800 mb-1">{f.title}</h3>
                <p className="text-sm text-slate-500">{f.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-16 text-center px-6">
        <h2 className="text-2xl font-bold text-slate-800 mb-4">
          Ready to plan your next adventure?
        </h2>
        <Link
          href="/app"
          className="inline-block px-8 py-3 bg-blue-600 text-white rounded-xl font-semibold hover:bg-blue-700 transition-colors"
        >
          Open TripWit
        </Link>
      </section>

      {/* Footer */}
      <footer className="border-t border-slate-100 px-6 py-6 text-center text-sm text-slate-400">
        <div className="flex justify-center gap-6 mb-2">
          <Link href="/privacy" className="hover:text-slate-600 transition-colors">Privacy Policy</Link>
          <Link href="/terms" className="hover:text-slate-600 transition-colors">Terms of Service</Link>
        </div>
        <p>© {new Date().getFullYear()} TripWit. All rights reserved.</p>
      </footer>
    </div>
  );
}
