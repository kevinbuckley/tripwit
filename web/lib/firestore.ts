import {
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  serverTimestamp,
  Timestamp,
} from "firebase/firestore";
import { db } from "./firebase";
import type { Trip } from "./types";
import { newId, nowISO } from "./types";

// ─── Converters ──────────────────────────────────────────────────────────────

function tripToFirestore(trip: Trip): object {
  return {
    ...trip,
    startDate: trip.startDate ? Timestamp.fromDate(new Date(trip.startDate)) : null,
    endDate: trip.endDate ? Timestamp.fromDate(new Date(trip.endDate)) : null,
    createdAt: trip.createdAt ? Timestamp.fromDate(new Date(trip.createdAt)) : serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

function tripFromFirestore(data: Record<string, unknown>, id: string): Trip {
  return {
    ...(data as unknown as Trip),
    id,
    startDate: data.startDate instanceof Timestamp ? data.startDate.toDate().toISOString() : (data.startDate as string) ?? "",
    endDate: data.endDate instanceof Timestamp ? data.endDate.toDate().toISOString() : (data.endDate as string) ?? "",
    createdAt: data.createdAt instanceof Timestamp ? data.createdAt.toDate().toISOString() : (data.createdAt as string) ?? "",
    updatedAt: data.updatedAt instanceof Timestamp ? data.updatedAt.toDate().toISOString() : (data.updatedAt as string) ?? "",
    days: (data.days as Trip["days"]) ?? [],
    bookings: (data.bookings as Trip["bookings"]) ?? [],
    lists: (data.lists as Trip["lists"]) ?? [],
    expenses: (data.expenses as Trip["expenses"]) ?? [],
  };
}

// ─── User profile ─────────────────────────────────────────────────────────────

export async function upsertUserProfile(
  uid: string,
  profile: { email: string | null; displayName: string | null; photoURL: string | null }
) {
  const ref = doc(db, "users", uid);
  await setDoc(ref, { ...profile, updatedAt: serverTimestamp() }, { merge: true });
}

// ─── Trips ────────────────────────────────────────────────────────────────────

export async function getTrips(userId: string): Promise<Trip[]> {
  const q = query(
    collection(db, "trips"),
    where("userId", "==", userId),
    orderBy("updatedAt", "desc")
  );
  const snap = await getDocs(q);
  return snap.docs.map((d) => tripFromFirestore(d.data() as Record<string, unknown>, d.id));
}

export async function getTrip(tripId: string): Promise<Trip | null> {
  const snap = await getDoc(doc(db, "trips", tripId));
  if (!snap.exists()) return null;
  return tripFromFirestore(snap.data() as Record<string, unknown>, snap.id);
}

export async function createTrip(userId: string, partial: Partial<Trip> = {}): Promise<Trip> {
  const id = newId();
  const now = nowISO();
  const trip: Trip = {
    id,
    userId,
    isPublic: false,
    name: "New Trip",
    destination: "",
    statusRaw: "planning",
    notes: "",
    hasCustomDates: false,
    budgetAmount: 0,
    budgetCurrencyCode: "USD",
    startDate: now,
    endDate: now,
    createdAt: now,
    updatedAt: now,
    days: [],
    bookings: [],
    lists: [],
    expenses: [],
    ...partial,
  };
  await setDoc(doc(db, "trips", id), tripToFirestore(trip));
  return trip;
}

export async function updateTrip(tripId: string, changes: Partial<Trip>): Promise<void> {
  const ref = doc(db, "trips", tripId);
  const payload: Record<string, unknown> = { ...changes, updatedAt: serverTimestamp() };
  if (changes.startDate) payload.startDate = Timestamp.fromDate(new Date(changes.startDate));
  if (changes.endDate) payload.endDate = Timestamp.fromDate(new Date(changes.endDate));
  await updateDoc(ref, payload);
}

export async function deleteTrip(tripId: string): Promise<void> {
  await deleteDoc(doc(db, "trips", tripId));
}

export async function setTripPublic(tripId: string, isPublic: boolean): Promise<void> {
  await updateDoc(doc(db, "trips", tripId), { isPublic, updatedAt: serverTimestamp() });
}
