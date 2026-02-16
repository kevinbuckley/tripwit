# Travly

An iOS travel planning app that spans the full trip lifecycle: **Plan → Experience → Remember**.

Plan dozens of future trips with detailed itineraries, use the app while traveling to track your journey, and automatically match photos from your camera roll to locations using GPS metadata.

<p align="center">
  <img src="screenshots/6.7/screenshot_5.png" width="180" alt="Welcome screen" />
  &nbsp;&nbsp;
  <img src="screenshots/6.7/screenshot_1.png" width="180" alt="Trip list" />
  &nbsp;&nbsp;
  <img src="screenshots/6.7/screenshot_2.png" width="180" alt="Trip detail with itinerary" />
  &nbsp;&nbsp;
  <img src="screenshots/6.7/screenshot_3.png" width="180" alt="Interactive map view" />
</p>

## Features

### Trip Management
- Create and manage multiple trips with destinations, dates, and notes
- Trips organized by status: **Active**, **Upcoming**, and **Past**
- Auto-generated day-by-day itinerary based on trip dates
- Start and complete trips with one tap

### Itinerary Planning
- Add stops to each day with location search powered by MapKit
- Six stop categories: Accommodation, Restaurant, Attraction, Transport, Activity, Other
- Drag to reorder stops within a day
- Set arrival and departure times for each stop
- Add notes to trips, days, and individual stops

### Bookings
- Track flights, hotels, and car rentals with confirmation codes
- All booking details in one place

### Map View
- Full-screen map showing all stops for any trip
- Color-coded pins by stop category
- Quick trip switcher to jump between trips

### Weather & Travel Times
- Weather forecasts for your destination
- Driving and walking time estimates between stops

### Photo Matching
- Automatically scan your camera roll
- Match photos to stops using GPS coordinates and timestamps

### Share
- Export trip as a clean PDF itinerary

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Data | SwiftData (local persistence) |
| Maps | MapKit |
| Architecture | MVVM with @Observable |
| Min Target | iOS 17.0 |
| Swift | 6.2 (strict concurrency) |

## Project Structure

```
Travly/
├── Packages/TripCore/          ← Pure Swift package (models, services, tests)
│   ├── Sources/TripCore/
│   │   ├── Models/             ← Trip, Day, Stop, MatchedPhoto, Coordinate
│   │   └── Services/           ← PhotoMatcher, GeoUtils, ItineraryEngine
│   └── Tests/TripCoreTests/    ← Unit tests
├── Travly/                     ← SwiftUI app
│   ├── Data/                   ← SwiftData entities + DataManager
│   ├── Views/                  ← All screens
│   └── Views/Components/       ← Reusable UI components
├── TravlyTests/                ← App-level tests
└── Scripts/                    ← CLI validation scripts
```

## Building

Requires Xcode 26+ and macOS 15+.

```bash
# Full validation (build + all tests)
./Scripts/validate.sh

# Fast logic tests only (no simulator needed)
./Scripts/test-logic.sh

# Build for simulator
xcodebuild build -scheme Travly \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet

# Regenerate Xcode project after changing project.yml
xcodegen generate
```

## License

Private — All rights reserved.
