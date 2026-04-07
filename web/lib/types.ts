// ─── Enums (match iOS TripCore exactly) ─────────────────────────────────────

export type TripStatus = "planning" | "active" | "completed";
export type StopCategory =
  | "accommodation"
  | "restaurant"
  | "attraction"
  | "transport"
  | "activity"
  | "entertainment"
  | "shopping"
  | "other";
export type BookingType = "flight" | "hotel" | "car_rental" | "other";
export type StopBookingStatus = "none" | "need_to_book" | "booked";
export type ExpenseCategory =
  | "accommodation"
  | "food"
  | "transport"
  | "activity"
  | "shopping"
  | "other";

// ─── Sub-models ──────────────────────────────────────────────────────────────

export interface StopTodo {
  id: string;
  text: string;
  isCompleted: boolean;
  sortOrder: number;
}

export interface StopLink {
  id: string;
  title: string;
  url: string;
  sortOrder: number;
}

export interface StopComment {
  id: string;
  text: string;
  createdAt: string; // ISO 8601
}

export interface Expense {
  id: string;
  title: string;
  amount: number;
  currencyCode: string;
  categoryRaw: ExpenseCategory;
  notes: string;
  sortOrder: number;
  createdAt: string; // ISO 8601
  dateIncurred: string; // ISO 8601
}

export interface TripListItem {
  id: string;
  text: string;
  isChecked: boolean;
  sortOrder: number;
}

export interface TripList {
  id: string;
  name: string;
  icon: string;
  sortOrder: number;
  items: TripListItem[];
}

export interface Booking {
  id: string;
  typeRaw: BookingType;
  title: string;
  confirmationCode: string;
  notes: string;
  sortOrder: number;
  // Flight
  airline?: string;
  flightNumber?: string;
  departureAirport?: string;
  arrivalAirport?: string;
  departureTime?: string;
  arrivalTime?: string;
  // Hotel
  hotelName?: string;
  hotelAddress?: string;
  checkInDate?: string;
  checkOutDate?: string;
}

// ─── Stop ────────────────────────────────────────────────────────────────────

export interface Stop {
  id: string;
  name: string;
  categoryRaw: StopCategory;
  sortOrder: number;
  notes: string;
  latitude: number;
  longitude: number;
  address?: string;
  phone?: string;
  website?: string;
  arrivalTime?: string;
  departureTime?: string;
  isVisited: boolean;
  visitedAt?: string;
  bookingStatus?: StopBookingStatus; // default "none"
  rating: number; // 0–5
  // Booking fields (accommodation / transport)
  confirmationCode?: string;
  checkOutDate?: string;
  airline?: string;
  flightNumber?: string;
  departureAirport?: string;
  arrivalAirport?: string;
  // Nested
  todos: StopTodo[];
  links: StopLink[];
  comments: StopComment[];
}

// ─── Day ─────────────────────────────────────────────────────────────────────

export interface Day {
  id: string;
  dayNumber: number;
  date: string; // ISO 8601 date (YYYY-MM-DD)
  notes: string;
  location: string;
  locationLatitude: number;
  locationLongitude: number;
  stops: Stop[];
}

// ─── Trip ─────────────────────────────────────────────────────────────────────

export interface Trip {
  id: string;
  userId: string;
  isPublic: boolean;
  name: string;
  destination: string;
  statusRaw: TripStatus;
  notes: string;
  hasCustomDates: boolean;
  budgetAmount: number;
  budgetCurrencyCode: string;
  startDate: string; // ISO 8601
  endDate: string; // ISO 8601
  createdAt: string; // ISO 8601
  updatedAt: string; // ISO 8601
  days: Day[];
  bookings: Booking[];
  lists: TripList[];
  expenses: Expense[];
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

export function newId(): string {
  return crypto.randomUUID();
}

export function nowISO(): string {
  return new Date().toISOString();
}

export const CATEGORY_LABELS: Record<StopCategory, string> = {
  accommodation: "Accommodation",
  restaurant: "Restaurant",
  attraction: "Attraction",
  transport: "Transport",
  activity: "Activity",
  entertainment: "Entertainment",
  shopping: "Shopping",
  other: "Other",
};

export const CATEGORY_COLORS: Record<StopCategory, string> = {
  accommodation: "#9333ea", // purple
  restaurant: "#f97316",   // orange
  attraction: "#eab308",   // yellow
  transport: "#3b82f6",    // blue
  activity: "#22c55e",     // green
  entertainment: "#ec4899", // pink
  shopping: "#f43f5e",     // rose
  other: "#6b7280",        // gray
};
