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

export interface LocationBias {
  lat: number;
  lon: number;
}

/**
 * Search Nominatim (OSM). Rate-limited to 1 req/s per ToS.
 * When `bias` is provided, results are soft-biased toward that location
 * (viewbox hint, bounded=0 so results outside the box still appear).
 *
 * Options:
 *  - bounded: if true, only return results within the viewbox (default false)
 *  - radiusKm: viewbox radius in km (default ~500km / delta=5)
 */
export async function searchPlaces(
  query: string,
  bias?: LocationBias,
  options?: { bounded?: boolean; radiusKm?: number },
): Promise<NominatimResult[]> {
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

  if (bias) {
    // Convert radiusKm to degrees (~111 km per degree)
    const delta = options?.radiusKm ? options.radiusKm / 111 : 5;
    const viewbox = [
      (bias.lon - delta).toFixed(4),
      (bias.lat + delta).toFixed(4),
      (bias.lon + delta).toFixed(4),
      (bias.lat - delta).toFixed(4),
    ].join(",");
    url.searchParams.set("viewbox", viewbox);
    url.searchParams.set("bounded", options?.bounded ? "1" : "0");
  }

  const res = await fetch(url.toString(), {
    headers: {
      "User-Agent": "TripWit-Web/1.0 (https://tripwit.app)",
      "Accept-Language": "en",
    },
  });

  if (!res.ok) return [];
  return res.json();
}
