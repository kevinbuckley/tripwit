export interface NominatimResult {
  place_id: number;
  display_name: string;
  lat: string;
  lon: string;
  address?: {
    road?: string;
    city?: string;
    town?: string;
    village?: string;
    country?: string;
  };
}

let lastRequestTime = 0;

/** Search Nominatim (OSM). Rate-limited to 1 req/s per ToS. */
export async function searchPlaces(query: string): Promise<NominatimResult[]> {
  if (!query.trim()) return [];

  // Enforce 1 req/s
  const now = Date.now();
  const elapsed = now - lastRequestTime;
  if (elapsed < 1000) {
    await new Promise((r) => setTimeout(r, 1000 - elapsed));
  }
  lastRequestTime = Date.now();

  const url = new URL("https://nominatim.openstreetmap.org/search");
  url.searchParams.set("q", query);
  url.searchParams.set("format", "json");
  url.searchParams.set("limit", "5");
  url.searchParams.set("addressdetails", "1");

  const res = await fetch(url.toString(), {
    headers: {
      "User-Agent": "TripWit-Web/1.0 (https://tripwit.app)",
      "Accept-Language": "en",
    },
  });

  if (!res.ok) return [];
  return res.json();
}
