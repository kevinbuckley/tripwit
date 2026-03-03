/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * Parses .tripwit JSON files (exported from the iOS app) into the web Trip type.
 * Handles both v1 (pre-booking-fields) and v2 (with booking fields) schemas.
 */
import type { Trip, Day, Stop, Booking, Expense, TripList } from "./types";
import { newId, nowISO } from "./types";

export function parseTripwitFile(json: unknown, userId: string): Trip {
  const raw = json as any;

  const days: Day[] = (raw.days ?? []).map((d: any): Day => ({
    id: d.id ?? newId(),
    dayNumber: d.dayNumber ?? 1,
    date: d.date ?? nowISO(),
    notes: d.notes ?? "",
    location: d.location ?? "",
    locationLatitude: d.locationLatitude ?? 0,
    locationLongitude: d.locationLongitude ?? 0,
    stops: (d.stops ?? []).map((s: any): Stop => ({
      id: s.id ?? newId(),
      name: s.name ?? "",
      categoryRaw: s.categoryRaw ?? "other",
      sortOrder: s.sortOrder ?? 0,
      notes: s.notes ?? "",
      latitude: s.latitude ?? 0,
      longitude: s.longitude ?? 0,
      address: s.address,
      phone: s.phone,
      website: s.website,
      arrivalTime: s.arrivalTime,
      departureTime: s.departureTime,
      isVisited: s.isVisited ?? false,
      visitedAt: s.visitedAt,
      rating: s.rating ?? 0,
      confirmationCode: s.confirmationCode,
      checkOutDate: s.checkOutDate,
      airline: s.airline,
      flightNumber: s.flightNumber,
      departureAirport: s.departureAirport,
      arrivalAirport: s.arrivalAirport,
      todos: (s.todos ?? []).map((t: any) => ({
        id: t.id ?? newId(),
        text: t.text ?? "",
        isCompleted: t.isCompleted ?? false,
        sortOrder: t.sortOrder ?? 0,
      })),
      links: (s.links ?? []).map((l: any) => ({
        id: l.id ?? newId(),
        title: l.title ?? "",
        url: l.url ?? "",
        sortOrder: l.sortOrder ?? 0,
      })),
      comments: (s.comments ?? []).map((c: any) => ({
        id: c.id ?? newId(),
        text: c.text ?? "",
        createdAt: c.createdAt ?? nowISO(),
      })),
    })),
  }));

  const bookings: Booking[] = (raw.bookings ?? []).map((b: any): Booking => ({
    id: b.id ?? newId(),
    typeRaw: b.typeRaw ?? "other",
    title: b.title ?? "",
    confirmationCode: b.confirmationCode ?? "",
    notes: b.notes ?? "",
    sortOrder: b.sortOrder ?? 0,
    airline: b.airline,
    flightNumber: b.flightNumber,
    departureAirport: b.departureAirport,
    arrivalAirport: b.arrivalAirport,
    departureTime: b.departureTime,
    arrivalTime: b.arrivalTime,
    hotelName: b.hotelName,
    hotelAddress: b.hotelAddress,
    checkInDate: b.checkInDate,
    checkOutDate: b.checkOutDate,
  }));

  const expenses: Expense[] = (raw.expenses ?? []).map((e: any): Expense => ({
    id: e.id ?? newId(),
    title: e.title ?? "",
    amount: e.amount ?? 0,
    currencyCode: e.currencyCode ?? "USD",
    categoryRaw: e.categoryRaw ?? "other",
    notes: e.notes ?? "",
    sortOrder: e.sortOrder ?? 0,
    createdAt: e.createdAt ?? nowISO(),
    dateIncurred: e.dateIncurred ?? nowISO(),
  }));

  const lists: TripList[] = (raw.lists ?? []).map((l: any): TripList => ({
    id: l.id ?? newId(),
    name: l.name ?? "",
    icon: l.icon ?? "📋",
    sortOrder: l.sortOrder ?? 0,
    items: (l.items ?? []).map((i: any) => ({
      id: i.id ?? newId(),
      text: i.text ?? "",
      isChecked: i.isChecked ?? false,
      sortOrder: i.sortOrder ?? 0,
    })),
  }));

  const now = nowISO();
  return {
    id: newId(),
    userId,
    isPublic: false,
    name: raw.name ?? "Imported Trip",
    destination: raw.destination ?? "",
    statusRaw: raw.statusRaw ?? "planning",
    notes: raw.notes ?? "",
    hasCustomDates: raw.hasCustomDates ?? false,
    budgetAmount: raw.budgetAmount ?? 0,
    budgetCurrencyCode: raw.budgetCurrencyCode ?? "USD",
    startDate: raw.startDate ?? now,
    endDate: raw.endDate ?? now,
    createdAt: now,
    updatedAt: now,
    days,
    bookings,
    lists,
    expenses,
  };
}
