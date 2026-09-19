export interface PlacesProvider {
  searchNearby(input: {
    latitude: number;
    longitude: number;
    radius: number;
    categories: string[];
    query?: string;
  }): Promise<PlaceResult[]>;
  getDetails(placeId: string): Promise<PlaceDetailResult>;
}

export interface PlaceResult {
  providerPlaceId: string;
  name: string;
  category: string;
  location: { latitude: number; longitude: number };
  rating?: number;
  ratingCount?: number;
  priceLevel?: number;
  photos: string[];
  source: { provider: string; retrievedAt: string };
}

export interface PlaceDetailResult extends PlaceResult {
  address?: string;
  websiteUrl?: string;
  phone?: string;
  openingHours?: Array<{ day: number; open: string; close: string }>;
  popularitySignal?: number;
}
