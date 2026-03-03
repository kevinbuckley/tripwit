import { initializeApp, getApps } from "firebase/app";
import { getAuth, GoogleAuthProvider } from "firebase/auth";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

// Guard: only initialize when env vars are present (avoids build-time crash)
const isConfigured = !!process.env.NEXT_PUBLIC_FIREBASE_API_KEY;
const app = isConfigured
  ? (getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0])
  : null;

export const auth = app ? getAuth(app) : ({} as ReturnType<typeof getAuth>);
export const db = app ? getFirestore(app) : ({} as ReturnType<typeof getFirestore>);
export const googleProvider = new GoogleAuthProvider();
