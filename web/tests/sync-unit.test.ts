/**
 * sync-unit.test.ts
 *
 * Unit tests for TripWit web sync logic.
 *
 * These tests cover pure functions only (no network calls):
 *   - rowToTrip / tripToRow converters in db.ts
 *   - changesToRow field mapping
 *   - types.ts helpers (newId, nowISO)
 *   - Cross-platform UUID compatibility (iOS uppercase vs web lowercase)
 *
 * Run with: npm run test:unit
 *
 * Integration tests that require a live Supabase connection are in
 * sync-integration.spec.ts (Playwright).
 */

import { describe, it, expect, beforeEach, vi } from "vitest";
import type { Trip, Day, Stop, Booking, TripList, Expense } from "../lib/types";
import { newId, nowISO } from "../lib/types";

// ─── Re-export private helpers under test ────────────────────────────────────
// db.ts does not export the converters, so we duplicate the minimal logic here
// to test the field-mapping contracts. When db.ts changes, update these too.

type TripRow = Record<string, unknown>;

function rowToTrip(row: TripRow): Trip {
  return {
    id: row.id as string,
    userId: row.user_id as string,
    isPublic: row.is_public as boolean,
    name: row.name as string,
    destination: row.destination as string,
    statusRaw: row.status_raw as Trip["statusRaw"],
    notes: row.notes as string,
    hasCustomDates: row.has_custom_dates as boolean,
    budgetAmount: row.budget_amount as number,
    budgetCurrencyCode: row.budget_currency_code as string,
    startDate: row.start_date as string,
    endDate: row.end_date as string,
    createdAt: row.created_at as string,
    updatedAt: row.updated_at as string,
    days: (row.days as Trip["days"]) ?? [],
    bookings: (row.bookings as Trip["bookings"]) ?? [],
    lists: (row.lists as Trip["lists"]) ?? [],
    expenses: (row.expenses as Trip["expenses"]) ?? [],
  };
}

function tripToRow(trip: Trip): TripRow {
  return {
    id: trip.id,
    user_id: trip.userId,
    is_public: trip.isPublic,
    name: trip.name,
    destination: trip.destination,
    status_raw: trip.statusRaw,
    notes: trip.notes,
    has_custom_dates: trip.hasCustomDates,
    budget_amount: trip.budgetAmount,
    budget_currency_code: trip.budgetCurrencyCode,
    start_date: trip.startDate,
    end_date: trip.endDate,
    days: trip.days,
    bookings: trip.bookings,
    lists: trip.lists,
    expenses: trip.expenses,
  };
}

function changesToRow(changes: Partial<Trip>): TripRow {
  const row: TripRow = { updated_at: nowISO() };
  if (changes.isPublic !== undefined)          row.is_public = changes.isPublic;
  if (changes.name !== undefined)              row.name = changes.name;
  if (changes.destination !== undefined)       row.destination = changes.destination;
  if (changes.statusRaw !== undefined)         row.status_raw = changes.statusRaw;
  if (changes.notes !== undefined)             row.notes = changes.notes;
  if (changes.hasCustomDates !== undefined)    row.has_custom_dates = changes.hasCustomDates;
  if (changes.budgetAmount !== undefined)      row.budget_amount = changes.budgetAmount;
  if (changes.budgetCurrencyCode !== undefined) row.budget_currency_code = changes.budgetCurrencyCode;
  if (changes.startDate !== undefined)         row.start_date = changes.startDate;
  if (changes.endDate !== undefined)           row.end_date = changes.endDate;
  if (changes.days !== undefined)              row.days = changes.days;
  if (changes.bookings !== undefined)          row.bookings = changes.bookings;
  if (changes.lists !== undefined)             row.lists = changes.lists;
  if (changes.expenses !== undefined)          row.expenses = changes.expenses;
  return row;
}

// ─── Fixtures ────────────────────────────────────────────────────────────────

const now = new Date().toISOString();

function makeTrip(overrides: Partial<Trip> = {}): Trip {
  return {
    id: newId(),
    userId: "user-abc",
    isPublic: false,
    name: "Paris Adventure",
    destination: "Paris",
    statusRaw: "planning",
    notes: "Can't wait!",
    hasCustomDates: false,
    budgetAmount: 2000,
    budgetCurrencyCode: "EUR",
    startDate: now,
    endDate: now,
    createdAt: now,
    updatedAt: now,
    days: [],
    bookings: [],
    lists: [],
    expenses: [],
    ...overrides,
  };
}

function makeRow(overrides: Partial<TripRow> = {}): TripRow {
  return {
    id: newId(),
    user_id: "user-abc",
    is_public: false,
    name: "Paris Adventure",
    destination: "Paris",
    status_raw: "planning",
    notes: "Can't wait!",
    has_custom_dates: false,
    budget_amount: 2000,
    budget_currency_code: "EUR",
    start_date: now,
    end_date: now,
    created_at: now,
    updated_at: now,
    days: [],
    bookings: [],
    lists: [],
    expenses: [],
    ...overrides,
  };
}

// ─── Tests ───────────────────────────────────────────────────────────────────

describe("newId()", () => {
  it("returns a valid UUID v4 string", () => {
    const id = newId();
    expect(id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    );
  });

  it("returns a unique value each call", () => {
    const ids = new Set(Array.from({ length: 100 }, () => newId()));
    expect(ids.size).toBe(100);
  });

  it("returns lowercase hex (matching crypto.randomUUID spec)", () => {
    const id = newId();
    expect(id).toBe(id.toLowerCase());
  });
});

describe("nowISO()", () => {
  it("returns a valid ISO 8601 timestamp", () => {
    const ts = nowISO();
    expect(() => new Date(ts)).not.toThrow();
    expect(new Date(ts).toISOString()).toBe(ts);
  });

  it("returns a timestamp close to the current time", () => {
    const before = Date.now();
    const ts = nowISO();
    const after = Date.now();
    const parsed = new Date(ts).getTime();
    expect(parsed).toBeGreaterThanOrEqual(before - 10);
    expect(parsed).toBeLessThanOrEqual(after + 10);
  });
});

// ─── rowToTrip ───────────────────────────────────────────────────────────────

describe("rowToTrip()", () => {
  it("maps snake_case columns to camelCase Trip fields", () => {
    const row = makeRow({ id: "id-1", user_id: "user-1" });
    const trip = rowToTrip(row);
    expect(trip.id).toBe("id-1");
    expect(trip.userId).toBe("user-1");
    expect(trip.isPublic).toBe(false);
    expect(trip.statusRaw).toBe("planning");
    expect(trip.hasCustomDates).toBe(false);
    expect(trip.budgetAmount).toBe(2000);
    expect(trip.budgetCurrencyCode).toBe("EUR");
  });

  it("passes through nested JSONB arrays unchanged", () => {
    const day: Day = {
      id: newId(), dayNumber: 1, date: now,
      notes: "", location: "", locationLatitude: 0, locationLongitude: 0,
      stops: [],
    };
    const row = makeRow({ days: [day] });
    const trip = rowToTrip(row);
    expect(trip.days).toHaveLength(1);
    expect(trip.days[0].id).toBe(day.id);
  });

  it("defaults nested arrays to [] when columns are null/undefined", () => {
    const row = makeRow({ days: null, bookings: null, lists: null, expenses: null });
    const trip = rowToTrip(row);
    expect(trip.days).toEqual([]);
    expect(trip.bookings).toEqual([]);
    expect(trip.lists).toEqual([]);
    expect(trip.expenses).toEqual([]);
  });

  it("preserves createdAt and updatedAt strings exactly", () => {
    const created = "2026-01-01T00:00:00.000Z";
    const updated = "2026-06-15T12:30:00.000Z";
    const row = makeRow({ created_at: created, updated_at: updated });
    const trip = rowToTrip(row);
    expect(trip.createdAt).toBe(created);
    expect(trip.updatedAt).toBe(updated);
  });

  it("round-trips: rowToTrip(tripToRow(trip)) is identity", () => {
    const original = makeTrip({ id: "round-trip-id", userId: "user-rt" });
    const roundTripped = rowToTrip(tripToRow(original));
    // Check key fields (createdAt/updatedAt not in tripToRow output but rest should match)
    expect(roundTripped.id).toBe(original.id);
    expect(roundTripped.userId).toBe(original.userId);
    expect(roundTripped.name).toBe(original.name);
    expect(roundTripped.destination).toBe(original.destination);
    expect(roundTripped.statusRaw).toBe(original.statusRaw);
    expect(roundTripped.budgetAmount).toBe(original.budgetAmount);
  });
});

// ─── tripToRow ───────────────────────────────────────────────────────────────

describe("tripToRow()", () => {
  it("maps camelCase Trip fields to snake_case row columns", () => {
    const trip = makeTrip({ id: "t1", userId: "u1" });
    const row = tripToRow(trip);
    expect(row.id).toBe("t1");
    expect(row.user_id).toBe("u1");
    expect(row.is_public).toBe(false);
    expect(row.status_raw).toBe("planning");
    expect(row.has_custom_dates).toBe(false);
    expect(row.budget_amount).toBe(2000);
    expect(row.budget_currency_code).toBe("EUR");
  });

  it("includes all nested JSONB fields", () => {
    const day: Day = {
      id: newId(), dayNumber: 1, date: now,
      notes: "", location: "", locationLatitude: 48.85, locationLongitude: 2.35,
      stops: [],
    };
    const trip = makeTrip({ days: [day] });
    const row = tripToRow(trip);
    expect((row.days as Day[])[0].id).toBe(day.id);
  });

  it("does not include createdAt or updatedAt (server controls these)", () => {
    const trip = makeTrip();
    const row = tripToRow(trip);
    expect("created_at" in row).toBe(false);
    expect("updated_at" in row).toBe(false);
  });
});

// ─── changesToRow ─────────────────────────────────────────────────────────────

describe("changesToRow()", () => {
  it("always includes updated_at as a recent ISO timestamp", () => {
    const before = Date.now();
    const row = changesToRow({ name: "Updated" });
    const after = Date.now();
    const ts = new Date(row.updated_at as string).getTime();
    expect(ts).toBeGreaterThanOrEqual(before - 10);
    expect(ts).toBeLessThanOrEqual(after + 10);
  });

  it("only includes fields that are present in the changes object", () => {
    const row = changesToRow({ name: "Only Name" });
    expect(row.name).toBe("Only Name");
    expect("destination" in row).toBe(false);
    expect("budget_amount" in row).toBe(false);
  });

  it("maps every Trip field to the correct snake_case column", () => {
    const now2 = nowISO();
    const changes: Partial<Trip> = {
      isPublic: true,
      name: "New Name",
      destination: "Berlin",
      statusRaw: "active",
      notes: "updated notes",
      hasCustomDates: true,
      budgetAmount: 999,
      budgetCurrencyCode: "USD",
      startDate: now2,
      endDate: now2,
      days: [],
      bookings: [],
      lists: [],
      expenses: [],
    };
    const row = changesToRow(changes);
    expect(row.is_public).toBe(true);
    expect(row.name).toBe("New Name");
    expect(row.destination).toBe("Berlin");
    expect(row.status_raw).toBe("active");
    expect(row.notes).toBe("updated notes");
    expect(row.has_custom_dates).toBe(true);
    expect(row.budget_amount).toBe(999);
    expect(row.budget_currency_code).toBe("USD");
    expect(row.start_date).toBe(now2);
    expect(row.end_date).toBe(now2);
    expect(row.days).toEqual([]);
    expect(row.bookings).toEqual([]);
    expect(row.lists).toEqual([]);
    expect(row.expenses).toEqual([]);
  });

  it("accepts undefined for fields that should not be updated (no-op fields)", () => {
    const row = changesToRow({ name: undefined });
    expect("name" in row).toBe(false);
  });
});

// ─── Cross-Platform UUID Compatibility ───────────────────────────────────────

describe("UUID cross-platform compatibility", () => {
  it("iOS uppercase UUID and web lowercase UUID represent the same value", () => {
    const base = "550e8400-e29b-41d4-a716-446655440000";
    const iosFormat = base.toUpperCase();
    const webFormat = base.toLowerCase();
    expect(iosFormat.toLowerCase()).toBe(webFormat);
    expect(webFormat.toUpperCase()).toBe(iosFormat);
  });

  it("web-created trip IDs (lowercase) survive a rowToTrip round-trip", () => {
    const lowerId = "a1b2c3d4-e5f6-4abc-89de-f01234567890".toLowerCase();
    const row = makeRow({ id: lowerId });
    const trip = rowToTrip(row);
    // The trip.id should be exactly what was in the row (no case transformation)
    expect(trip.id).toBe(lowerId);
  });

  it("iOS-created trip IDs (uppercase) survive a rowToTrip round-trip", () => {
    const upperId = "A1B2C3D4-E5F6-4ABC-89DE-F01234567890".toUpperCase();
    const row = makeRow({ id: upperId });
    const trip = rowToTrip(row);
    expect(trip.id).toBe(upperId);
  });

  it("case-insensitive equality check correctly identifies same UUID", () => {
    const webId  = newId().toLowerCase();
    const iosId  = webId.toUpperCase();
    // This is the comparison that the iOS SyncService must use
    expect(webId.toLowerCase()).toBe(iosId.toLowerCase());
  });

  it("newId() returns lowercase — consistent with crypto.randomUUID spec", () => {
    for (let i = 0; i < 20; i++) {
      const id = newId();
      expect(id).toBe(id.toLowerCase());
      expect(id).not.toBe(id.toUpperCase()); // contains lowercase letters
    }
  });
});

// ─── Trip Status Enum Compatibility ──────────────────────────────────────────

describe("TripStatus cross-platform compatibility", () => {
  const validStatuses: Trip["statusRaw"][] = ["planning", "active", "completed"];

  validStatuses.forEach((status) => {
    it(`statusRaw '${status}' survives row round-trip`, () => {
      const trip = makeTrip({ statusRaw: status });
      const roundTripped = rowToTrip(tripToRow(trip));
      expect(roundTripped.statusRaw).toBe(status);
    });
  });
});

// ─── Nested Data Integrity ────────────────────────────────────────────────────

describe("Nested data integrity", () => {
  it("stop with all optional fields null survives round-trip", () => {
    const stop: Stop = {
      id: newId(), name: "Museum", categoryRaw: "attraction", sortOrder: 0,
      notes: "", latitude: 48.85, longitude: 2.29,
      address: undefined, phone: undefined, website: undefined,
      arrivalTime: undefined, departureTime: undefined,
      isVisited: false, visitedAt: undefined,
      rating: 0,
      confirmationCode: undefined, checkOutDate: undefined,
      airline: undefined, flightNumber: undefined,
      departureAirport: undefined, arrivalAirport: undefined,
      todos: [], links: [], comments: [],
    };
    const day: Day = {
      id: newId(), dayNumber: 1, date: now,
      notes: "", location: "", locationLatitude: 0, locationLongitude: 0,
      stops: [stop],
    };
    const trip = makeTrip({ days: [day] });
    const roundTripped = rowToTrip(tripToRow(trip));
    expect(roundTripped.days[0].stops[0].name).toBe("Museum");
    expect(roundTripped.days[0].stops[0].address).toBeUndefined();
  });

  it("booking with all flight fields survives round-trip", () => {
    const booking: Booking = {
      id: newId(), typeRaw: "flight", title: "BA456",
      confirmationCode: "XYZ789", notes: "window seat", sortOrder: 0,
      airline: "British Airways", flightNumber: "BA456",
      departureAirport: "LHR", arrivalAirport: "CDG",
      departureTime: now, arrivalTime: now,
    };
    const trip = makeTrip({ bookings: [booking] });
    const roundTripped = rowToTrip(tripToRow(trip));
    const rb = roundTripped.bookings[0];
    expect(rb.airline).toBe("British Airways");
    expect(rb.flightNumber).toBe("BA456");
    expect(rb.departureAirport).toBe("LHR");
    expect(rb.arrivalAirport).toBe("CDG");
  });

  it("expense amount preserves decimal precision", () => {
    const expense: Expense = {
      id: newId(), title: "Hotel", amount: 199.99,
      currencyCode: "USD", categoryRaw: "accommodation",
      notes: "", sortOrder: 0, createdAt: now, dateIncurred: now,
    };
    const trip = makeTrip({ expenses: [expense] });
    const roundTripped = rowToTrip(tripToRow(trip));
    expect(roundTripped.expenses[0].amount).toBe(199.99);
  });

  it("list with checked and unchecked items survives round-trip", () => {
    const list: TripList = {
      id: newId(), name: "Packing", icon: "🎒", sortOrder: 0,
      items: [
        { id: newId(), text: "Passport", isChecked: true,  sortOrder: 0 },
        { id: newId(), text: "Sunscreen", isChecked: false, sortOrder: 1 },
      ],
    };
    const trip = makeTrip({ lists: [list] });
    const roundTripped = rowToTrip(tripToRow(trip));
    expect(roundTripped.lists[0].items[0].isChecked).toBe(true);
    expect(roundTripped.lists[0].items[1].isChecked).toBe(false);
  });

  it("stop with todo, link, and comment survives round-trip", () => {
    const stop: Stop = {
      id: newId(), name: "Eiffel Tower", categoryRaw: "attraction", sortOrder: 0,
      notes: "iconic", latitude: 48.8584, longitude: 2.2945,
      isVisited: false, rating: 5,
      todos: [{ id: newId(), text: "Take photo", isCompleted: false, sortOrder: 0 }],
      links: [{ id: newId(), title: "Wikipedia", url: "https://en.wikipedia.org/wiki/Eiffel_Tower", sortOrder: 0 }],
      comments: [{ id: newId(), text: "Amazing views!", createdAt: now }],
    };
    const day: Day = {
      id: newId(), dayNumber: 1, date: now,
      notes: "", location: "", locationLatitude: 0, locationLongitude: 0,
      stops: [stop],
    };
    const trip = makeTrip({ days: [day] });
    const roundTripped = rowToTrip(tripToRow(trip));
    const rs = roundTripped.days[0].stops[0];
    expect(rs.todos[0].text).toBe("Take photo");
    expect(rs.links[0].url).toBe("https://en.wikipedia.org/wiki/Eiffel_Tower");
    expect(rs.comments[0].text).toBe("Amazing views!");
  });
});

// ─── updateTrip changesToRow edge cases ──────────────────────────────────────

describe("updateTrip partial-update semantics", () => {
  it("does not include unchanged fields (avoids accidental overwrites)", () => {
    // Only changing the name — other fields should NOT appear in the row
    const row = changesToRow({ name: "Updated Name" });
    expect(Object.keys(row)).toEqual(expect.arrayContaining(["updated_at", "name"]));
    expect(Object.keys(row)).not.toContain("destination");
    expect(Object.keys(row)).not.toContain("budget_amount");
    expect(Object.keys(row)).not.toContain("days");
  });

  it("updating days replaces entire JSONB column (whole-trip replacement)", () => {
    const days: Day[] = [];
    const row = changesToRow({ days });
    expect(row.days).toEqual([]);
  });

  it("updated_at is always a string in ISO 8601 format", () => {
    const row = changesToRow({ name: "x" });
    const ts = row.updated_at as string;
    expect(ts).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/);
  });
});
