"use client";

import { useEffect, useRef } from "react";

interface AdUnitProps {
  slot: string;
  format?: "auto" | "horizontal" | "rectangle" | "vertical";
  className?: string;
  style?: React.CSSProperties;
}

declare global {
  interface Window {
    adsbygoogle: unknown[];
  }
}

export default function AdUnit({
  slot,
  format = "auto",
  className = "",
  style,
}: AdUnitProps) {
  const clientId = process.env.NEXT_PUBLIC_ADSENSE_CLIENT_ID;
  const pushed = useRef(false);

  useEffect(() => {
    if (!clientId || pushed.current) return;
    pushed.current = true;
    try {
      (window.adsbygoogle = window.adsbygoogle || []).push({});
    } catch {
      // AdSense not loaded in dev
    }
  }, [clientId]);

  if (!clientId) return null;

  return (
    <ins
      className={`adsbygoogle ${className}`}
      style={{ display: "block", ...style }}
      data-ad-client={clientId}
      data-ad-slot={slot}
      data-ad-format={format}
      data-full-width-responsive="true"
    />
  );
}
