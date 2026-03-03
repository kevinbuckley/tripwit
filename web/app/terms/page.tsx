import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Terms of Service — TripWit",
};

export default function TermsPage() {
  return (
    <div className="min-h-screen bg-white">
      <nav className="px-6 py-4 border-b border-slate-100 flex items-center justify-between">
        <Link href="/" className="text-xl font-bold text-slate-800">✈ TripWit</Link>
      </nav>
      <main className="max-w-2xl mx-auto px-6 py-12 prose prose-slate">
        <h1>Terms of Service</h1>
        <p><em>Last updated: March 2026</em></p>

        <h2>1. Acceptance of Terms</h2>
        <p>
          By using TripWit, you agree to these Terms of Service. If you do not
          agree, please do not use the service.
        </p>

        <h2>2. Description of Service</h2>
        <p>
          TripWit is a web-based travel planning tool that allows users to
          create, organize, and share travel itineraries.
        </p>

        <h2>3. User Accounts</h2>
        <p>
          You must sign in with a Google account to create and save trips. You
          are responsible for maintaining the security of your account.
        </p>

        <h2>4. User Content</h2>
        <p>
          You retain ownership of trip data you create. By making a trip public,
          you grant TripWit a license to display that content to users who access
          the shared link.
        </p>

        <h2>5. Prohibited Uses</h2>
        <p>You agree not to:</p>
        <ul>
          <li>Use the service for any unlawful purpose.</li>
          <li>Attempt to access other users&apos; private data.</li>
          <li>Abuse or interfere with the service infrastructure.</li>
        </ul>

        <h2>6. Disclaimer of Warranties</h2>
        <p>
          TripWit is provided &quot;as is&quot; without warranty of any kind.
          We do not guarantee that the service will be uninterrupted or error-free.
        </p>

        <h2>7. Limitation of Liability</h2>
        <p>
          TripWit shall not be liable for any indirect, incidental, or
          consequential damages arising from your use of the service.
        </p>

        <h2>8. Changes to Terms</h2>
        <p>
          We may update these terms at any time. Continued use of the service
          after changes constitutes acceptance of the new terms.
        </p>

        <h2>9. Contact</h2>
        <p>
          For questions about these terms:{" "}
          <a href="mailto:legal@tripwit.app">legal@tripwit.app</a>
        </p>
      </main>
    </div>
  );
}
