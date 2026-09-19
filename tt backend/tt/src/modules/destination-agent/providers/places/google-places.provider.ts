import type {
  PlacesProvider,
  PlaceResult,
  PlaceDetailResult,
} from "./places.provider.js";

interface GoogleNearbySearchRequest {
  includedPrimaryTypes?: string[];
  maxResultCount?: number;
  locationFilter?: {
    circle: {
      center: { latitude: number; longitude: number };
      radius: number;
    };
  };
  textQuery?: string;
}

interface GooglePlace {
  id: string;
  displayName?: { text: string; languageCode?: string };
  primaryType?: string;
  location?: { latitude: number; longitude: number };
  rating?: number;
  userRatingCount?: number;
  priceLevel?: string;
  photos?: Array<{ name: string }>;
  formattedAddress?: string;
  websiteUri?: string;
  nationalPhoneNumber?: string;
  regularOpeningHours?: {
    openDays?: Array<{
      day: string;
      open: { hour: number; minute: number };
      close: { hour: number; minute: number };
    }>;
  };
}

interface GoogleNearbySearchResponse {
  places?: GooglePlace[];
}

const GOOGLE_PRICE_LEVEL_MAP: Record<string, number> = {
  PRICE_LEVEL_FREE: 0,
  PRICE_LEVEL_INEXPENSIVE: 1,
  PRICE_LEVEL_MODERATE: 2,
  PRICE_LEVEL_EXPENSIVE: 3,
  PRICE_LEVEL_VERY_EXPENSIVE: 4,
};

const CATEGORY_TO_GOOGLE_TYPE: Record<string, string> = {
  food: "restaurant",
  restaurant: "restaurant",
  cafe: "cafe",
  coffee: "cafe",
  hotel: "lodging",
  lodging: "lodging",
  museum: "museum",
  park: "park",
  beach: "natural_feature",
  shopping: "shopping_mall",
  temple: "hindu_temple",
  religious: "place_of_worship",
  activity: "tourist_attraction",
  attraction: "tourist_attraction",
  nightlife: "bar",
  bar: "bar",
  transport: "transit_station",
};

export class GooglePlacesProvider implements PlacesProvider {
  private readonly apiKey: string | undefined;
  private readonly baseUrl = "https://places.googleapis.com/v1";

  constructor() {
    this.apiKey = process.env.GOOGLE_PLACES_API_KEY;
  }

  private get isAvailable(): boolean {
    return Boolean(this.apiKey);
  }

  async searchNearby(input: {
    latitude: number;
    longitude: number;
    radius: number;
    categories: string[];
    query?: string;
  }): Promise<PlaceResult[]> {
    if (!this.isAvailable) {
      console.warn(
        "[GooglePlacesProvider] GOOGLE_PLACES_API_KEY not set, returning empty results"
      );
      return [];
    }

    try {
      const googleTypes = input.categories
        .map((c) => CATEGORY_TO_GOOGLE_TYPE[c.toLowerCase()])
        .filter(Boolean);

      const body: GoogleNearbySearchRequest = {
        locationFilter: {
          circle: {
            center: { latitude: input.latitude, longitude: input.longitude },
            radius: input.radius,
          },
        },
        maxResultCount: 20,
      };

      if (googleTypes.length > 0) {
        body.includedPrimaryTypes = googleTypes;
      }

      if (input.query) {
        body.textQuery = input.query;
      }

      const response = await fetch(
        `${this.baseUrl}/places:searchNearby`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": this.apiKey!,
            "X-Goog-FieldMask":
              "places.id,places.displayName,places.primaryType,places.location,places.rating,places.userRatingCount,places.priceLevel,places.photos",
          },
          body: JSON.stringify(body),
        }
      );

      if (!response.ok) {
        console.warn(
          `[GooglePlacesProvider] searchNearby failed: ${response.status} ${response.statusText}`
        );
        return [];
      }

      const data = (await response.json()) as GoogleNearbySearchResponse;
      if (!data.places) {
        return [];
      }

      return data.places.map((place) => this.mapPlace(place));
    } catch (error) {
      console.warn("[GooglePlacesProvider] searchNearby error:", error);
      return [];
    }
  }

  async getDetails(placeId: string): Promise<PlaceDetailResult> {
    if (!this.isAvailable) {
      console.warn(
        "[GooglePlacesProvider] GOOGLE_PLACES_API_KEY not set, returning empty details"
      );
      return this.emptyDetail(placeId);
    }

    try {
      const response = await fetch(
        `${this.baseUrl}/places/${encodeURIComponent(placeId)}`,
        {
          headers: {
            "X-Goog-Api-Key": this.apiKey!,
            "X-Goog-FieldMask":
              "id,displayName,primaryType,location,rating,userRatingCount,priceLevel,photos,formattedAddress,websiteUri,nationalPhoneNumber,regularOpeningHours",
          },
        }
      );

      if (!response.ok) {
        console.warn(
          `[GooglePlacesProvider] getDetails failed: ${response.status} ${response.statusText}`
        );
        return this.emptyDetail(placeId);
      }

      const place = (await response.json()) as GooglePlace;

      const base = this.mapPlace(place);

      return {
        ...base,
        address: place.formattedAddress,
        websiteUrl: place.websiteUri ?? undefined,
        phone: place.nationalPhoneNumber ?? undefined,
        openingHours: place.regularOpeningHours?.openDays?.map((d) => ({
          day: this.dayOfWeekToNumber(d.day),
          open: `${String(d.open.hour).padStart(2, "0")}:${String(d.open.minute).padStart(2, "0")}`,
          close: `${String(d.close.hour).padStart(2, "0")}:${String(d.close.minute).padStart(2, "0")}`,
        })),
      };
    } catch (error) {
      console.warn("[GooglePlacesProvider] getDetails error:", error);
      return this.emptyDetail(placeId);
    }
  }

  private mapPlace(place: GooglePlace): PlaceResult {
    return {
      providerPlaceId: place.id,
      name: place.displayName?.text ?? "Unknown",
      category: place.primaryType ?? "unknown",
      location: {
        latitude: place.location?.latitude ?? 0,
        longitude: place.location?.longitude ?? 0,
      },
      rating: place.rating,
      ratingCount: place.userRatingCount,
      priceLevel: place.priceLevel
        ? GOOGLE_PRICE_LEVEL_MAP[place.priceLevel]
        : undefined,
      photos: place.photos?.map((p) => p.name) ?? [],
      source: { provider: "google-places", retrievedAt: new Date().toISOString() },
    };
  }

  private emptyDetail(placeId: string): PlaceDetailResult {
    return {
      providerPlaceId: placeId,
      name: "Unknown",
      category: "unknown",
      location: { latitude: 0, longitude: 0 },
      photos: [],
      source: { provider: "google-places", retrievedAt: new Date().toISOString() },
    };
  }

  private dayOfWeekToNumber(day: string): number {
    const map: Record<string, number> = {
      MONDAY: 1,
      TUESDAY: 2,
      WEDNESDAY: 3,
      THURSDAY: 4,
      FRIDAY: 5,
      SATURDAY: 6,
      SUNDAY: 0,
    };
    return map[day.toUpperCase()] ?? 0;
  }
}
