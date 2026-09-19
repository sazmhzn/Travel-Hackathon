import type { NormalizedPlace, WeatherData } from '../schemas/destination.schema.js';
import type { RouteResult } from '../providers/routes/routes.provider.js';

export interface ScoringInput {
  places: NormalizedPlace[];
  weather: WeatherData[];
  routes: Map<string, RouteResult>;
  preferences: {
    interests: string[];
    budget: string;
    transport: string[];
    travelStyle: string;
  };
  tripDates: { startDate: string; endDate: string };
}

export interface ScoredCandidate {
  place: NormalizedPlace;
  score: number;
  breakdown: {
    interestMatch: number;
    routeFit: number;
    weatherFit: number;
    openingHoursFit: number;
    popularity: number;
  };
}

function haversineMeters(
  a: { latitude: number; longitude: number },
  b: { latitude: number; longitude: number },
): number {
  const R = 6_371_000;
  const dLat = ((b.latitude - a.latitude) * Math.PI) / 180;
  const dLng = ((b.longitude - a.longitude) * Math.PI) / 180;
  const sinLat = Math.sin(dLat / 2);
  const sinLng = Math.sin(dLng / 2);
  const h =
    sinLat * sinLat +
    Math.cos((a.latitude * Math.PI) / 180) *
      Math.cos((b.latitude * Math.PI) / 180) *
      sinLng * sinLng;
  return R * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function normalize(value: number, min: number, max: number): number {
  if (max === min) return 0.5;
  return clamp((value - min) / (max - min), 0, 1);
}

const OUTDOOR_CATEGORIES = new Set(['NATURE', 'ADVENTURE']);

const INTEREST_TO_CATEGORIES: Record<string, string[]> = {
  NATURE: ['NATURE', 'LANDMARK'],
  CULTURE: ['CULTURE', 'LANDMARK'],
  FOOD: ['FOOD'],
  ADVENTURE: ['ADVENTURE', 'NATURE'],
  SHOPPING: ['SHOPPING'],
  NIGHTLIFE: ['FOOD'],
  RELAXATION: ['NATURE', 'CULTURE'],
  PHOTOGRAPHY: ['NATURE', 'LANDMARK', 'CULTURE'],
};

function computeInterestMatch(
  place: NormalizedPlace,
  interests: string[],
): number {
  if (interests.length === 0) return 0.5;
  const matchedCategories = new Set<string>();
  for (const interest of interests) {
    const cats = INTEREST_TO_CATEGORIES[interest];
    if (cats) {
      for (const c of cats) matchedCategories.add(c);
    }
  }
  if (matchedCategories.size === 0) return 0.3;
  return matchedCategories.has(place.category) ? 1.0 : 0.4;
}

function computeRouteFit(
  place: NormalizedPlace,
  routes: Map<string, RouteResult>,
  center: { latitude: number; longitude: number },
  maxDistance: number,
): number {
  const distMeters = haversineMeters(center, place.location);
  const distScore = 1 - normalize(distMeters, 0, maxDistance);

  let routeTimeScore = 0.5;
  let routeCount = 0;
  for (const [key, route] of routes) {
    if (key.includes(place.id)) {
      const hours = route.durationSeconds / 3600;
      routeTimeScore = 1 - clamp(hours / 4, 0, 1);
      routeCount++;
      break;
    }
  }

  return routeCount > 0 ? distScore * 0.5 + routeTimeScore * 0.5 : distScore;
}

function computeWeatherFit(
  place: NormalizedPlace,
  weather: WeatherData[],
): number {
  if (!OUTDOOR_CATEGORIES.has(place.category)) return 1.0;
  if (weather.length === 0) return 0.5;
  const avgPrecip =
    weather.reduce((s, w) => s + w.precipitationProbability, 0) / weather.length;
  if (avgPrecip <= 30) return 1.0;
  if (avgPrecip <= 60) return 0.7;
  if (avgPrecip <= 80) return 0.4;
  return 0.15;
}

function computeOpeningHoursFit(
  place: NormalizedPlace,
  tripDates: { startDate: string; endDate: string },
): number {
  if (!place.openingHours || place.openingHours.length === 0) return 0.6;

  const start = new Date(tripDates.startDate);
  const end = new Date(tripDates.endDate);
  let openDays = 0;
  let totalDays = 0;

  const current = new Date(start);
  while (current <= end) {
    const dayOfWeek = current.getDay();
    totalDays++;
    const hasHours = place.openingHours.some((h) => h.day === dayOfWeek);
    if (hasHours) openDays++;
    current.setDate(current.getDate() + 1);
  }

  if (totalDays === 0) return 0.5;
  return openDays / totalDays;
}

function computePopularity(place: NormalizedPlace): number {
  const ratingScore = place.rating != null ? place.rating / 5 : 0.5;
  const popularityScore = place.popularitySignal ?? 0.5;
  return ratingScore * 0.6 + popularityScore * 0.4;
}

const WEIGHTS = {
  interestMatch: 0.30,
  routeFit: 0.15,
  weatherFit: 0.15,
  openingHoursFit: 0.10,
  popularity: 0.10,
} as const;

const TOTAL_WEIGHT =
  WEIGHTS.interestMatch +
  WEIGHTS.routeFit +
  WEIGHTS.weatherFit +
  WEIGHTS.openingHoursFit +
  WEIGHTS.popularity;

export class DestinationScoringService {
  static calculateScores(input: ScoringInput): ScoredCandidate[] {
    const { places, weather, routes, preferences, tripDates } = input;

    const center =
      places.length > 0
        ? {
            latitude:
              places.reduce((s, p) => s + p.location.latitude, 0) / places.length,
            longitude:
              places.reduce((s, p) => s + p.location.longitude, 0) / places.length,
          }
        : { latitude: 0, longitude: 0 };

    const distances = places.map((p) => haversineMeters(center, p.location));
    const maxDistance = Math.max(...distances, 1);

    const candidates: ScoredCandidate[] = places.map((place) => {
      const interestMatch = computeInterestMatch(place, preferences.interests);
      const routeFit = computeRouteFit(place, routes, center, maxDistance);
      const weatherFit = computeWeatherFit(place, weather);
      const openingHoursFit = computeOpeningHoursFit(place, tripDates);
      const popularity = computePopularity(place);

      const breakdown = { interestMatch, routeFit, weatherFit, openingHoursFit, popularity };
      const rawScore =
        WEIGHTS.interestMatch * interestMatch +
        WEIGHTS.routeFit * routeFit +
        WEIGHTS.weatherFit * weatherFit +
        WEIGHTS.openingHoursFit * openingHoursFit +
        WEIGHTS.popularity * popularity;

      return { place, score: rawScore / TOTAL_WEIGHT, breakdown };
    });

    candidates.sort((a, b) => b.score - a.score);
    return candidates;
  }

  static filterByPreferences(
    candidates: ScoredCandidate[],
    preferences: ScoringInput['preferences'],
  ): ScoredCandidate[] {
    const budgetMap: Record<string, number[]> = {
      BUDGET: [1, 2],
      MEDIUM: [2, 3],
      LUXURY: [3, 4],
    };
    const allowedLevels = budgetMap[preferences.budget] ?? [1, 2, 3, 4];

    return candidates.filter((c) => {
      if (c.place.priceLevel != null && !allowedLevels.includes(c.place.priceLevel)) {
        return false;
      }
      return true;
    });
  }
}
