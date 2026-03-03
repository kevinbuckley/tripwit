# TripWit Monorepo

## Structure
```
iosapp/    ← Swift/SwiftUI iOS app
web/       ← Next.js web app (Vercel)
```

---

# iOS App (`iosapp/`)

## What is it?
iOS travel planner app built with Swift/SwiftUI. Plan trips, track your itinerary on the go, and automatically match photos from your camera roll to trip stops using GPS metadata.

## Architecture
- **TripCore** (`iosapp/Packages/TripCore/`) — Pure Swift package with all business logic, models, and services. No UI dependencies. Tests run fast with `swift test`.
- **TripWit** — SwiftUI iOS app target that depends on TripCore.
- **TripWitTests** — App-level unit tests.

## Validation Loop
After every iOS code change, run from `iosapp/`:
```bash
./iosapp/Scripts/validate.sh
```
This runs 4 steps:
1. TripCore package build
2. TripCore tests (fast, no simulator)
3. Full app build (xcodebuild, needs simulator)
4. App tests (xcodebuild test)

For fast iteration on business logic only:
```bash
./iosapp/Scripts/test-logic.sh
```

## Key Commands (run from repo root)
```bash
# Fast: logic tests only (no simulator)
cd iosapp/Packages/TripCore && swift test

# Full app build
xcodebuild build -project iosapp/TripWit.xcodeproj -scheme TripWit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet

# Full app tests
xcodebuild test -project iosapp/TripWit.xcodeproj -scheme TripWit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:TripWitTests -quiet

# Regenerate Xcode project after changing iosapp/project.yml
cd iosapp && xcodegen generate
```

## iOS Project Structure
```
iosapp/Packages/TripCore/   ← Pure logic package (models, services, tests)
iosapp/TripWit/             ← SwiftUI app (views, view models, platform services)
iosapp/TripWitTests/        ← App-level tests
iosapp/Scripts/             ← Validation scripts
iosapp/project.yml          ← XcodeGen project spec
```

## iOS Rules
- Keep business logic in TripCore, not in the app target
- Every new service or model gets tests in TripCore
- Run validate.sh after every change before considering work done
- Use `public` access control on TripCore types that the app needs
- iOS 17+ minimum deployment target
- Swift 6 strict concurrency
- **Never upload to TestFlight unless explicitly asked**

## File Format Rules (.tripwit)
- `.tripwit` files (JSON via `TripTransfer`) must always be **forwards compatible**
- Never remove fields from `TripTransfer` structs — only add new optional fields with defaults
- New fields must have defaults so old files still decode correctly (`var foo: String = ""`)
- Bump `TripTransfer.currentSchemaVersion` when making structural changes
- Date encoding is `iso8601` — do not change

## Data Safety Rules
- **Never destroy or migrate away existing Core Data stores** — users' trips live in `Private.sqlite` and `Shared.sqlite` in Application Support
- Do not change the `NSPersistentCloudKitContainer(name:)` value — it determines the store filename; changing it orphans existing data
- Do not change the CloudKit container identifier (`iCloud.com.kevinbuckley.travelplanner`) — it is linked to the App Store app
- Any Core Data model changes must be additive (new optional attributes only) — no renames, no deletes, no type changes
- If a migration is ever needed, use lightweight migration and test it explicitly before shipping

## iOS Deployment (run from `iosapp/`)
- **Archive:** `xcodebuild -project TripWit.xcodeproj -scheme TripWit -configuration Release -destination 'generic/platform=iOS' -archivePath build/TripWit.xcarchive archive`
- **TestFlight upload:** `xcodebuild -exportArchive -archivePath build/TripWit.xcarchive -exportOptionsPlist build/ExportOptions.plist -exportPath build/TripWitExport`
- **Device deploy (no TestFlight):** `xcodebuild -destination 'platform=iOS,id=<UDID>'` — find UDID with `xcrun xctrace list devices`
- Build number lives in `iosapp/project.yml` → `CURRENT_PROJECT_VERSION` — increment for every TestFlight upload

## App Icon
- Single 1024×1024 PNG at `iosapp/TripWit/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
- No rounded corners, no transparency — iOS applies rounding automatically

## iMessage / CloudKit Sharing
- **Do not use UICloudSharingController for new shares** — documented iOS spinner bug in Messages
- New shares: pre-create `CKShare` via `container.share([trip], to: nil)`, wrap URL as `tripwit://share?url=<encoded>`, send via `MFMessageComposeViewController` directly
- Existing shares: `UICloudSharingController` is fine for participant management only
- CKError 10/2007 "Permission Failure": Developer Portal → App ID → iCloud → uncheck/re-check container → save → regenerate provisioning profiles in Xcode

---

# Web App (`web/`)

## What is it?
Desktop-first Next.js web app on Vercel. Google login, Firebase Firestore, Leaflet/OpenStreetMap maps, Google AdSense.

## Tech Stack
- **Framework:** Next.js 15 (App Router)
- **Auth:** Firebase Auth (Google provider)
- **Database:** Firebase Firestore (free Spark plan)
- **Maps:** Leaflet + react-leaflet + OpenStreetMap
- **Geocoding:** Nominatim (free, OSM-based)
- **Ads:** Google AdSense
- **Styling:** Tailwind CSS
- **Language:** TypeScript
- **Deploy:** Vercel

## Key Commands (run from `web/`)
```bash
npm run dev       # local dev server
npm run build     # production build (run before every deploy)
npm run lint      # ESLint
```

## Web Rules
- Run `npm run build` after every change to catch TypeScript errors
- All Firebase config goes in `web/.env.local` (never commit secrets)
- Leaflet map component must be imported with `dynamic({ ssr: false })` — it cannot SSR
- Ad units only render for logged-in users in `/app`; always render on public `/trip/[id]` pages
- Nominatim: max 1 req/second, include `User-Agent` header, show OSM attribution
- **Never commit `.env.local`**

## Web Project Structure
```
web/app/           ← Next.js App Router pages
web/components/    ← React components
web/lib/           ← Firebase, Firestore service, types, utilities
web/contexts/      ← React contexts (Auth)
web/hooks/         ← Custom hooks
```

## Environment Variables (web/.env.local)
```
NEXT_PUBLIC_FIREBASE_API_KEY=
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=
NEXT_PUBLIC_FIREBASE_PROJECT_ID=
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=
NEXT_PUBLIC_FIREBASE_APP_ID=
```
