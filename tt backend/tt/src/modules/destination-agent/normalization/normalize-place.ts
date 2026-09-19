import type { PlaceDetailResult } from '../providers/places/places.provider.js';

export interface NormalizedPlace {
  id: string;
  name: string;
  category: string;
  location: { latitude: number; longitude: number };
  rating?: number;
  ratingCount?: number;
  priceLevel?: number;
  openingHours?: Array<{ day: number; open: string; close: string }>;
  websiteUrl?: string;
  phone?: string;
  popularitySignal?: number;
  photos: string[];
  source: { provider: string; retrievedAt: string };
}

const CATEGORY_MAP: Record<string, string> = {
  restaurant: 'FOOD',
  cafe: 'FOOD',
  bar: 'FOOD',
  meal_takeaway: 'FOOD',
  food: 'FOOD',
  museum: 'CULTURE',
  art_gallery: 'CULTURE',
  library: 'CULTURE',
  theater: 'CULTURE',
  park: 'NATURE',
  natural_feature: 'NATURE',
  campground: 'NATURE',
  zoo: 'NATURE',
  amusement_park: 'ADVENTURE',
  stadium: 'ADVENTURE',
  shopping_mall: 'SHOPPING',
  clothing_store: 'SHOPPING',
  grocery_store: 'SHOPPING',
  landmark: 'LANDMARK',
  point_of_interest: 'LANDMARK',
  lodging: 'ACCOMMODATION',
  hotel: 'ACCOMMODATION',
  transit_station: 'TRANSPORT',
  bus_station: 'TRANSPORT',
  airport: 'TRANSPORT',
};

function mapCategory(rawCategory: string): string {
  return CATEGORY_MAP[rawCategory.toLowerCase()] ?? 'LANDMARK';
}

function normalizeOpeningHours(
  hours?: Array<{ day: number; open: string; close: string }>
): Array<{ day: number; open: string; close: string }> | undefined {
  if (!hours) return undefined;

  return hours.map((h) => ({
    day: h.day,
    open: h.open.length === 5 ? h.open : '00:00',
    close: h.close.length === 5 ? h.close : '23:59',
  }));
}

export function normalizePlaces(places: PlaceDetailResult[]): NormalizedPlace[] {
  if (!places) return [];

  return places
    .filter((p) => p?.providerPlaceId && p?.name)
    .map((place) => ({
      id: place.providerPlaceId,
      name: place.name,
      category: mapCategory(place.category),
      location: place.location,
      rating: place.rating,
      ratingCount: place.ratingCount,
      priceLevel: place.priceLevel,
      openingHours: normalizeOpeningHours(place.openingHours),
      websiteUrl: place.websiteUrl,
      phone: place.phone,
      popularitySignal: place.popularitySignal,
      photos: place.photos ?? [],
      source: place.source,
    }));
}
