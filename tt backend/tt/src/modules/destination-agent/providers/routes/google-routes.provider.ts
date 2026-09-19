import type {
  RoutesProvider,
  RouteResult,
} from "./routes.provider.js";

interface GoogleRoutesRequest {
  origin: {
    location: { latitude: number; longitude: number };
  };
  destination: {
    location: { latitude: number; longitude: number };
  };
  travelMode: string;
  computeAlternativeRoutes: boolean;
}

interface GoogleRoutesResponse {
  routes?: Array<{
    distanceMeters?: number;
    duration?: string;
    polyline?: { encodedPolyline?: string };
    legs?: Array<{
      distanceMeters?: number;
      duration?: string;
    }>;
  }>;
}

const MODE_TO_TRAVEL_MODE: Record<string, string> = {
  drive: "DRIVE",
  driving: "DRIVE",
  walk: "WALK",
  walking: "WALK",
  bicycle: "BICYCLE",
  biking: "BICYCLE",
  bicycling: "BICYCLE",
  two_wheeler: "TWO_WHEELER",
  motorcycle: "TWO_WHEELER",
};

function parseGoogleDuration(duration: string): number {
  const match = duration.match(/^(\d+)s$/);
  if (match) {
    return parseInt(match[1], 10);
  }
  let totalSeconds = 0;
  const hoursMatch = duration.match(/(\d+)h/);
  const minutesMatch = duration.match(/(\d+)m/);
  const secondsMatch = duration.match(/(\d+)s/);
  if (hoursMatch) totalSeconds += parseInt(hoursMatch[1], 10) * 3600;
  if (minutesMatch) totalSeconds += parseInt(minutesMatch[1], 10) * 60;
  if (secondsMatch) totalSeconds += parseInt(secondsMatch[1], 10);
  return totalSeconds;
}

export class GoogleRoutesProvider implements RoutesProvider {
  private readonly apiKey: string | undefined;
  private readonly baseUrl =
    "https://routes.googleapis.com/directions/v2:computeRoutes";

  constructor() {
    this.apiKey = process.env.GOOGLE_ROUTES_API_KEY;
  }

  async getRoute(input: {
    origin: { latitude: number; longitude: number };
    destination: { latitude: number; longitude: number };
    mode: string;
  }): Promise<RouteResult | null> {
    if (!this.apiKey) {
      console.warn(
        "[GoogleRoutesProvider] GOOGLE_ROUTES_API_KEY not set, returning null"
      );
      return null;
    }

    try {
      const travelMode = MODE_TO_TRAVEL_MODE[input.mode.toLowerCase()] ?? "DRIVE";

      const body: GoogleRoutesRequest = {
        origin: {
          location: { latitude: input.origin.latitude, longitude: input.origin.longitude },
        },
        destination: {
          location: {
            latitude: input.destination.latitude,
            longitude: input.destination.longitude,
          },
        },
        travelMode,
        computeAlternativeRoutes: false,
      };

      const response = await fetch(this.baseUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": this.apiKey,
          "X-Goog-FieldMask": "routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline",
        },
        body: JSON.stringify(body),
      });

      if (!response.ok) {
        console.warn(
          `[GoogleRoutesProvider] getRoute failed: ${response.status} ${response.statusText}`
        );
        return null;
      }

      const data = (await response.json()) as GoogleRoutesResponse;
      const route = data.routes?.[0];

      if (!route) {
        return null;
      }

      return {
        distanceMeters: route.distanceMeters ?? 0,
        durationSeconds: route.duration
          ? parseGoogleDuration(route.duration)
          : 0,
        mode: input.mode,
        polyline: route.polyline?.encodedPolyline,
        source: { provider: "google-routes", retrievedAt: new Date().toISOString() },
      };
    } catch (error) {
      console.warn("[GoogleRoutesProvider] getRoute error:", error);
      return null;
    }
  }
}
