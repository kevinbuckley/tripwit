"use client";

import Image from "next/image";
import { useAuth } from "@/contexts/AuthContext";
import AdUnit from "@/components/ads/AdUnit";
import { Check, Loader2, LogOut } from "lucide-react";

interface HeaderProps {
  showAds?: boolean;
  saveStatus?: "idle" | "saving" | "saved";
}

export default function Header({ showAds = false, saveStatus = "idle" }: HeaderProps) {
  const { user, signIn, signOut } = useAuth();

  return (
    <header className="flex items-center gap-4 px-4 h-14 shrink-0 bg-white border-b border-slate-200/80 shadow-[0_1px_3px_rgba(0,0,0,0.06)]">

      {/* Save status indicator */}
      {user && saveStatus !== "idle" && (
        <div className="flex items-center gap-1.5 text-xs shrink-0">
          {saveStatus === "saving" && (
            <>
              <Loader2 className="w-3 h-3 text-slate-400 animate-spin" />
              <span className="text-slate-400">Saving</span>
            </>
          )}
          {saveStatus === "saved" && (
            <>
              <Check className="w-3 h-3 text-emerald-500" />
              <span className="text-emerald-600 font-medium">Saved</span>
            </>
          )}
        </div>
      )}

      {showAds && user && (
        <div className="flex-1 flex justify-center">
          <AdUnit slot="LEADERBOARD_SLOT" format="horizontal" style={{ width: 728, height: 90 }} />
        </div>
      )}

      {(!showAds || !user) && <div className="flex-1" />}

      {user ? (
        <div className="flex items-center gap-2.5 shrink-0">
          {user.user_metadata?.avatar_url && (
            <Image
              src={user.user_metadata.avatar_url as string}
              alt={user.user_metadata?.full_name ?? ""}
              width={28}
              height={28}
              className="rounded-full ring-2 ring-slate-100"
            />
          )}
          <span className="text-sm text-slate-600 font-medium hidden lg:block">
            {user.user_metadata?.full_name ?? user.email}
          </span>
          <button
            onClick={signOut}
            className="flex items-center gap-1.5 text-xs text-slate-400 hover:text-slate-700 transition-colors px-2 py-1.5 rounded-md hover:bg-slate-100"
            title="Sign out"
          >
            <LogOut className="w-3.5 h-3.5" />
            <span className="hidden md:inline">Sign out</span>
          </button>
        </div>
      ) : (
        <button
          onClick={signIn}
          className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors shrink-0 shadow-sm"
        >
          <svg className="w-4 h-4" viewBox="0 0 24 24">
            <path fill="currentColor" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
            <path fill="currentColor" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
            <path fill="currentColor" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
            <path fill="currentColor" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
          </svg>
          Sign in with Google
        </button>
      )}
    </header>
  );
}
