# Travly

## What is this?
iOS travel planner app built with Swift/SwiftUI. Plan trips, track your itinerary on the go, and automatically match photos from your camera roll to trip stops using GPS metadata.

## Architecture
- **TripCore** (`Packages/TripCore/`) — Pure Swift package with all business logic, models, and services. No UI dependencies. Tests run fast with `swift test`.
- **Travly** — SwiftUI iOS app target that depends on TripCore.
- **TravlyTests** — App-level unit tests.

## Validation Loop
After every code change, run:
```bash
./Scripts/validate.sh
```
This runs 4 steps:
1. TripCore package build
2. TripCore tests (fast, no simulator)
3. Full app build (xcodebuild, needs simulator)
4. App tests (xcodebuild test)

For fast iteration on business logic only:
```bash
./Scripts/test-logic.sh
```

## Key Commands
```bash
# Fast: logic tests only (no simulator)
cd Packages/TripCore && swift test

# Full app build
xcodebuild build -scheme Travly -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet

# Full app tests
xcodebuild test -scheme Travly -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:TravlyTests -quiet

# Regenerate Xcode project after changing project.yml
xcodegen generate
```

## Project Structure
```
Packages/TripCore/          ← Pure logic package (models, services, tests)
Travly/                     ← SwiftUI app (views, view models, platform services)
TravlyTests/                ← App-level tests
Scripts/                    ← Validation scripts
project.yml                 ← XcodeGen project spec
```

## Rules
- Keep business logic in TripCore, not in the app target
- Every new service or model gets tests in TripCore
- Run validate.sh after every change before considering work done
- Use `public` access control on TripCore types that the app needs
- iOS 17+ minimum deployment target
- Swift 6 strict concurrency
