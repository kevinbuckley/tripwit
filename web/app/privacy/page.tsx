import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Privacy Policy — TripWit",
};

export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-white">
      <nav className="px-6 py-4 border-b border-slate-100 flex items-center justify-between">
        <Link href="/" className="text-xl font-bold text-slate-800">✈ TripWit</Link>
      </nav>
      <main className="max-w-2xl mx-auto px-6 py-12 prose prose-slate">
        <h1>Privacy Policy</h1>
        <p><em>Last updated: March 2026</em></p>

        <h2>1. Information We Collect</h2>
        <p>
          When you sign in with Google, we receive your name, email address, and
          profile photo from Google. We store this information in our database to
          identify your account.
        </p>
        <p>
          Trip data you create (itineraries, stops, notes) is stored in our
          database under your account.
        </p>

        <h2>2. How We Use Your Information</h2>
        <ul>
          <li>To provide and improve the TripWit service.</li>
          <li>To associate trips with your account.</li>
          <li>To display your name and photo in the app interface.</li>
        </ul>

        <h2>3. Data Sharing</h2>
        <p>
          We do not sell your personal information. We do not share your data
          with third parties except as necessary to operate the service (e.g.,
          Google Firebase for data storage and authentication).
        </p>
        <p>
          If you make a trip public, the trip content will be visible to anyone
          with the link.
        </p>

        <h2>4. Cookies and Advertising</h2>
        <p>
          TripWit uses Google AdSense to display advertisements. Google may use
          cookies to serve ads based on your prior visits to this website or
          other websites. You can opt out of personalized advertising by visiting{" "}
          <a href="https://www.google.com/settings/ads" target="_blank" rel="noopener noreferrer">
            Google Ads Settings
          </a>
          .
        </p>

        <h2>5. Data Retention</h2>
        <p>
          Your data is retained as long as your account exists. You may delete
          your trips at any time from within the app. To request full account
          deletion, contact us at the email below.
        </p>

        <h2>6. Security</h2>
        <p>
          We use Firebase security rules to ensure that only you can access your
          private trip data. Public trips are readable by anyone with the link.
        </p>

        <h2>7. Children&apos;s Privacy</h2>
        <p>
          TripWit is not directed at children under 13. We do not knowingly
          collect personal information from children under 13.
        </p>

        <h2>8. Changes to This Policy</h2>
        <p>
          We may update this policy from time to time. We will notify you of
          significant changes by updating the date above.
        </p>

        <h2>9. Contact</h2>
        <p>
          For privacy questions, contact us at:{" "}
          <a href="mailto:privacy@tripwit.app">privacy@tripwit.app</a>
        </p>
      </main>
    </div>
  );
}
