import type { NormalizedPlace, WeatherData, Preferences } from '../schemas/destination.schema.js';
import type { RouteResult } from '../providers/routes/routes.provider.js';
import type { ElevationResult } from '../providers/elevation/google-elevation.provider.js';
import type { EventResult } from '../providers/events/events.provider.js';
import type { SafetyInformation } from '../providers/safety/safety.provider.js';
import type { TransportOperatorResult } from '../providers/transport/local-transport.provider.js';
import type { TourismInformation } from '../providers/tourism/tourism.provider.js';
import type { ScoredCandidate } from '../scoring/destination-scoring.service.js';

type TransportOption = TransportOperatorResult;

export interface ItineraryPromptInput {
  destination: string;
  tripDates: { startDate: string; endDate: string };
  preferences: Preferences;
  weather: WeatherData[];
  places: NormalizedPlace[];
  routes: Map<string, RouteResult>;
  elevation?: ElevationResult;
  events: EventResult[];
  safety: SafetyInformation;
  transport: TransportOption[];
  tourism: TourismInformation;
  scoredCandidates: ScoredCandidate[];
}

function formatWeather(weather: WeatherData[]): string {
  if (weather.length === 0) return 'No weather data available.';
  return weather
    .map(
      (w) =>
        `  - ${w.date}: ${w.weatherCondition ?? 'N/A'}, ${w.temperatureMin}°C–${w.temperatureMax}°C, ` +
        `precipitation ${w.precipitationProbability}%, wind ${w.windSpeed} km/h`,
    )
    .join('\n');
}

function formatPlaces(places: NormalizedPlace[]): string {
  if (places.length === 0) return 'No places data available.';
  return places
    .map(
      (p) =>
        `  - [${p.id}] ${p.name} (${p.category}) at (${p.location.latitude}, ${p.location.longitude})` +
        `${p.rating != null ? `, rating ${p.rating}/5` : ''}` +
        `${p.priceLevel != null ? `, price level ${p.priceLevel}` : ''}` +
        `${p.openingHours ? `, hours: ${JSON.stringify(p.openingHours)}` : ''}`,
    )
    .join('\n');
}

function formatRoutes(routes: Map<string, RouteResult>): string {
  if (routes.size === 0) return 'No route data available.';
  return Array.from(routes.entries())
    .map(
      ([key, r]) =>
        `  - ${key}: ${r.distanceMeters}m, ${Math.round(r.durationSeconds / 60)}min by ${r.mode}` +
        `${r.elevationGainMeters != null ? `, elevation gain ${r.elevationGainMeters}m` : ''}`,
    )
    .join('\n');
}

function formatEvents(events: EventResult[]): string {
  if (events.length === 0) return 'No events found during the trip dates.';
  return events
    .map(
      (e) =>
        `  - ${e.name} (${e.category}): ${e.startDate}–${e.endDate ?? 'N/A'}` +
        `${e.description ? ` — ${e.description}` : ''}` +
        `${e.location ? ` at ${e.location}` : ''}`,
    )
    .join('\n');
}

function formatTransport(transport: TransportOperatorResult[]): string {
  if (transport.length === 0) return 'No local transport data available.';
  return transport
    .map(
      (t) =>
        `  - ${t.name} (${t.type}): ${t.origin} → ${t.destination}` +
        `${t.priceRange ? `, price: ${t.priceRange}` : ''}` +
        `${t.estimatedDurationMinutes != null ? `, ~${t.estimatedDurationMinutes}min` : ''}` +
        `${t.phone ? `, phone: ${t.phone}` : ''}`,
    )
    .join('\n');
}

function formatScoredCandidates(candidates: ScoredCandidate[]): string {
  if (candidates.length === 0) return 'No scored candidates.';
  return candidates
    .slice(0, 15)
    .map(
      (c, i) =>
        `  ${i + 1}. ${c.place.name} (${c.place.category}) — score ${c.score.toFixed(3)}` +
        ` [interest=${c.breakdown.interestMatch.toFixed(2)}, route=${c.breakdown.routeFit.toFixed(2)}, ` +
        `weather=${c.breakdown.weatherFit.toFixed(2)}, hours=${c.breakdown.openingHoursFit.toFixed(2)}, ` +
        `pop=${c.breakdown.popularity.toFixed(2)}]`,
    )
    .join('\n');
}

export function buildItineraryPrompt(input: ItineraryPromptInput): string {
  const {
    destination,
    tripDates,
    preferences,
    weather,
    places,
    routes,
    elevation,
    events,
    safety,
    transport,
    tourism,
    scoredCandidates,
  } = input;

  const start = new Date(tripDates.startDate);
  const end = new Date(tripDates.endDate);
  const dayCount =
    Math.round((end.getTime() - start.getTime()) / 86_400_000) + 1;

  const systemPrompt = `You are an itinerary synthesis engine. You generate detailed, practical travel itineraries based EXCLUSIVELY on the supplied data.

RULES:
1. Use ONLY the supplied data. Never invent places, prices, opening hours, weather, events, transport options, travel times, crowd levels, or safety information.
2. If information for a field is unavailable, return null for that field.
3. Every itinerary item MUST reference a supplied place by its placeId.
4. Every factual claim in the itinerary MUST be traceable to the supplied source data.
5. You MAY generate explanations, descriptions, titles, and itinerary structure.
6. You MAY reorder and group places logically for a good travel experience.
7. Respect the user's travel style: FAST means more items per day, SLOW means fewer items with more time at each.
8. Respect the user's budget when selecting places and transport.
9. Consider weather conditions when scheduling outdoor activities.
10. Check opening hours to ensure places are open on the scheduled day.
11. Use the scoredCandidates list to prioritize higher-rated places, but you may override if contextual reasoning justifies it.
12. Return the output as valid JSON matching the GeneratedItinerary schema.`;

  const userPrompt = `Generate a ${dayCount}-day travel itinerary for ${destination}.

## DESTINATION
${destination}

## DATES
Start: ${tripDates.startDate}
End: ${tripDates.endDate}
Total days: ${dayCount}

## USER PREFERENCES
- Interests: ${preferences.interests.join(', ')}
- Budget: ${preferences.budget}
- Transport modes: ${preferences.transport.join(', ')}
- Travel style: ${preferences.travelStyle}

## WEATHER
${formatWeather(weather)}

## PLACES (ranked by relevance score)
${formatPlaces(places)}

## SCORED CANDIDATES (prioritized)
${formatScoredCandidates(scoredCandidates)}

## ROUTES
${formatRoutes(routes)}

## ELEVATION
${elevation ? `${elevation.elevationMeters}m above sea level at destination center` : 'Elevation data not available.'}

## EVENTS
${formatEvents(events)}

## SAFETY
- Overall safety level: ${safety.safetyLevel}
${safety.alerts.length > 0 ? `- Alerts:\n${safety.alerts.map((a) => `  - [${a.severity}] ${a.message}`).join('\n')}` : '- No active alerts'}
${safety.recommendations.length > 0 ? `- Recommendations:\n${safety.recommendations.map((r) => `  - ${r}`).join('\n')}` : ''}

## TRANSPORT
${formatTransport(transport)}

## TOURISM
- Overview: ${tourism.overview}
- Best time to visit: ${tourism.bestTimeToVisit}
- Highlights: ${tourism.highlights.join(', ')}
- Tips: ${tourism.tips.join(', ')}

Respond with a JSON object matching the GeneratedItinerary schema.`;

  return `${systemPrompt}\n\n${userPrompt}`;
}
