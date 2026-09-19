import { createHash } from 'crypto';
import { OpenMeteoWeatherProvider } from './providers/weather/open-meteo.provider.js';
import { GooglePlacesProvider } from './providers/places/google-places.provider.js';
import { GoogleRoutesProvider } from './providers/routes/google-routes.provider.js';
import { OpenMeteoElevationProvider } from './providers/elevation/google-elevation.provider.js';
import { ManualTourismProvider } from './providers/tourism/tourism.provider.js';
import { ManualEventsProvider } from './providers/events/events.provider.js';
import { ManualSafetyProvider } from './providers/safety/safety.provider.js';
import { ManualTransportProvider } from './providers/transport/local-transport.provider.js';
import { normalizeWeather } from './normalization/normalize-weather.js';
import { normalizePlaces } from './normalization/normalize-place.js';
import { DestinationScoringService } from './scoring/destination-scoring.service.js';
import { GeminiService } from './ai/gemini.service.js';
import { DestinationCacheService } from './cache/destination-cache.service.js';
import { DestinationRepository } from './destination.repository.js';
import { logger } from '../../utils/logger.js';
import type { WeatherData, Preferences } from './schemas/destination.schema.js';
import type { RouteResult } from './providers/routes/routes.provider.js';

const REQUEST_VERSION = 1;

export interface OrchestratorInput {
  userId: string;
  destination: string;
  startDate: string;
  endDate: string;
  preferences: {
    interests: string[];
    budget: string;
    transport: string[];
    travelStyle: string;
  };
}

export interface OrchestratorResult {
  generationId: string;
  itinerary: any;
  destinationId: string;
  warnings: string[];
}

function computeRequestHash(input: OrchestratorInput): string {
  return createHash('sha256')
    .update(JSON.stringify({ ...input, version: REQUEST_VERSION }))
    .digest('hex');
}

export class DestinationOrchestrator {
  static async generate(input: OrchestratorInput): Promise<OrchestratorResult> {
    const warnings: string[] = [];
    const log = logger.child({ userId: input.userId, destination: input.destination });

    log.info('Starting destination generation');

    // 1. Find or create destination in DB
    const destination = await DestinationRepository.findOrCreateDestination(
      input.destination,
    );
    const destinationId: string = destination?.id ?? '';

    // 2. Resolve coordinates (V1: use stored coords or null)
    const latitude: number | null = destination?.latitude ?? null;
    const longitude: number | null = destination?.longitude ?? null;

    if (latitude === null || longitude === null) {
      warnings.push('Coordinates not available for this destination; location-dependent data may be limited.');
    }

    // 3. Check cache for existing generation with same request hash
    const requestHash = computeRequestHash(input);
    const cacheKey = `generation:${requestHash}`;
    const cached = await DestinationCacheService.get<OrchestratorResult>(cacheKey);
    if (cached) {
      log.info({ generationId: cached.generationId }, 'Returning cached generation');
      return cached;
    }

    // 4. Collect data in parallel (skip coordinate-dependent providers if no coords)
    log.info('Collecting provider data in parallel');
    const hasCoords = latitude !== null && longitude !== null;

    const settled = await Promise.allSettled([
      hasCoords
        ? new OpenMeteoWeatherProvider().getWeather({
            latitude: latitude!,
            longitude: longitude!,
            startDate: input.startDate,
            endDate: input.endDate,
          })
        : Promise.resolve(null),
      hasCoords
        ? new GooglePlacesProvider().searchNearby({
            latitude: latitude!,
            longitude: longitude!,
            radius: 10000,
            categories: input.preferences.interests,
          })
        : Promise.resolve([]),
      new ManualEventsProvider().searchEvents({
        destination: input.destination,
        startDate: input.startDate,
        endDate: input.endDate,
        latitude: latitude ?? undefined,
        longitude: longitude ?? undefined,
      }),
      new ManualTourismProvider().getDestinationInfo(input.destination),
      new ManualSafetyProvider().getSafetyInformation(input.destination),
      new ManualTransportProvider().searchOperators({
        origin: input.destination,
        destination: input.destination,
        latitude: latitude ?? undefined,
        longitude: longitude ?? undefined,
      }),
    ]);

    // 5 & 6. Process results — mark failures as unavailable, never throw
    const [weatherResult, placesResult, eventsResult, tourismResult, safetyResult, transportResult] = settled;

    const weatherData =
      weatherResult.status === 'fulfilled' && weatherResult.value
        ? normalizeWeather(weatherResult.value)
        : [];
    if (weatherResult.status === 'rejected') {
      const msg = `Weather provider failed: ${weatherResult.reason?.message ?? weatherResult.reason}`;
      log.warn({ err: weatherResult.reason }, msg);
      warnings.push(msg);
    }

    const rawPlaces = placesResult.status === 'fulfilled' ? placesResult.value : [];
    if (placesResult.status === 'rejected') {
      const msg = `Places provider failed: ${placesResult.reason?.message ?? placesResult.reason}`;
      log.warn({ err: placesResult.reason }, msg);
      warnings.push(msg);
    }

    const eventsData = eventsResult.status === 'fulfilled' ? eventsResult.value : [];
    if (eventsResult.status === 'rejected') {
      const msg = `Events provider failed: ${eventsResult.reason?.message ?? eventsResult.reason}`;
      log.warn({ err: eventsResult.reason }, msg);
      warnings.push(msg);
    }

    const tourismData = tourismResult.status === 'fulfilled'
      ? tourismResult.value
      : { destination: input.destination, overview: '', bestTimeToVisit: '', highlights: [], tips: [], source: { provider: 'fallback', retrievedAt: new Date().toISOString() } };
    if (tourismResult.status === 'rejected') {
      const msg = `Tourism provider failed: ${tourismResult.reason?.message ?? tourismResult.reason}`;
      log.warn({ err: tourismResult.reason }, msg);
      warnings.push(msg);
    }

    const safetyData = safetyResult.status === 'fulfilled'
      ? safetyResult.value
      : { destination: input.destination, safetyLevel: 'safe' as const, alerts: [], recommendations: [], source: { provider: 'fallback', retrievedAt: new Date().toISOString() } };
    if (safetyResult.status === 'rejected') {
      const msg = `Safety provider failed: ${safetyResult.reason?.message ?? safetyResult.reason}`;
      log.warn({ err: safetyResult.reason }, msg);
      warnings.push(msg);
    }

    const transportData = transportResult.status === 'fulfilled' ? transportResult.value : [];
    if (transportResult.status === 'rejected') {
      const msg = `Transport provider failed: ${transportResult.reason?.message ?? transportResult.reason}`;
      log.warn({ err: transportResult.reason }, msg);
      warnings.push(msg);
    }

    // Fetch full details for each place and normalize
    log.info({ count: rawPlaces.length }, 'Fetching place details');
    const placesProvider = new GooglePlacesProvider();
    const detailedPlaces = await Promise.allSettled(
      rawPlaces.map((p) => placesProvider.getDetails(p.providerPlaceId)),
    );
    const placeDetails = detailedPlaces
      .filter((r): r is PromiseFulfilledResult<any> => r.status === 'fulfilled')
      .map((r) => r.value);
    const failedDetails = detailedPlaces.filter((r) => r.status === 'rejected');
    if (failedDetails.length > 0) {
      warnings.push(`${failedDetails.length} place detail fetches failed`);
    }

    let normalizedPlaces = normalizePlaces(placeDetails);

    // Cache normalized data
    if (weatherData.length > 0) {
      await DestinationCacheService.setWeather(input.destination, input.startDate, weatherData);
    }
    if (normalizedPlaces.length > 0) {
      await DestinationCacheService.setPlaces(input.destination, normalizedPlaces);
    }

    // 7. Get routes between top places (limit to top 10)
    const topPlaces = normalizedPlaces.slice(0, 10);
    log.info({ count: topPlaces.length }, 'Computing routes between top places');

    const routesProvider = new GoogleRoutesProvider();
    const routeMap = new Map<string, RouteResult>();

    if (hasCoords && topPlaces.length > 1) {
      const routePromises: Promise<void>[] = [];
      for (let i = 0; i < topPlaces.length; i++) {
        for (let j = i + 1; j < topPlaces.length; j++) {
          const origin = topPlaces[i];
          const dest = topPlaces[j];
          const routeKey = `${origin.id}->${dest.id}`;

          const cachedRoute = await DestinationCacheService.getRoute(origin.id, dest.id, 'drive');
          if (cachedRoute) {
            routeMap.set(routeKey, cachedRoute as RouteResult);
            continue;
          }

          routePromises.push(
            routesProvider
              .getRoute({
                origin: origin.location,
                destination: dest.location,
                mode: 'drive',
              })
              .then(async (route) => {
                if (route) {
                  routeMap.set(routeKey, route);
                  await DestinationCacheService.setRoute(origin.id, dest.id, 'drive', route);
                }
              })
              .catch(() => {
                // Route failures are non-fatal
              }),
          );
        }
      }
      await Promise.allSettled(routePromises);
    }

    // 8. Get elevation for top places
    log.info('Fetching elevation data');
    const elevationProvider = new OpenMeteoElevationProvider();
    let primaryElevation = null;
    if (hasCoords && topPlaces.length > 0) {
      const firstPlace = topPlaces[0];
      const cachedElevation = await DestinationCacheService.getElevation(
        firstPlace.location.latitude,
        firstPlace.location.longitude,
      );
      if (cachedElevation) {
        primaryElevation = cachedElevation;
      } else {
        const elevResult = await elevationProvider.getElevation({
          latitude: firstPlace.location.latitude,
          longitude: firstPlace.location.longitude,
        });
        primaryElevation = elevResult;
        await DestinationCacheService.setElevation(
          firstPlace.location.latitude,
          firstPlace.location.longitude,
          elevResult,
        );
      }
    }

    // 9. Score candidates
    log.info('Scoring candidates');
    const scoredCandidates = DestinationScoringService.calculateScores({
      places: normalizedPlaces as any,
      weather: weatherData as any,
      routes: routeMap,
      preferences: input.preferences as any,
      tripDates: { startDate: input.startDate, endDate: input.endDate },
    });

    // Filter by preferences
    const filteredCandidates = DestinationScoringService.filterByPreferences(scoredCandidates, input.preferences as any);
    const filteredPlaces = filteredCandidates.map(c => c.place);

    // 10. Generate itinerary via Gemini
    log.info('Generating itinerary with AI');
    const itinerary = await GeminiService.generateItinerary({
      destination: input.destination,
      tripDates: { startDate: input.startDate, endDate: input.endDate },
      preferences: input.preferences as any,
      weather: weatherData as any,
      places: filteredPlaces as any,
      routes: routeMap,
      elevation: primaryElevation ?? undefined,
      events: eventsData as any,
      safety: safetyData as any,
      transport: transportData as any,
      tourism: tourismData as any,
      scoredCandidates: filteredCandidates as any,
    });

    // 11. Validate result with business rules
    log.info('Validating generated itinerary');
    const normalizedPlaceMap = new Map(filteredPlaces.map((p) => [p.id, p]));

    for (const day of itinerary.days) {
      for (const item of day.items) {
        // Check that referenced placeIds exist in collected data
        if (item.placeId && !normalizedPlaceMap.has(item.placeId)) {
          warnings.push(
            `Itinerary item "${item.title}" references unknown placeId "${item.placeId}"`,
          );
        }

        // Check that start_time is not before place opening hours
        if (item.placeId) {
          const place = normalizedPlaceMap.get(item.placeId);
          if (place?.openingHours && place.openingHours.length > 0) {
            const dayOfWeek = new Date(day.date).getDay();
            const hoursForDay = place.openingHours.find((h) => h.day === dayOfWeek);
            if (hoursForDay) {
              const [openHour, openMin] = hoursForDay.open.split(':').map(Number);
              const [itemHour, itemMin] = item.startTime.split(':').map(Number);
              const openMinutes = openHour * 60 + openMin;
              const itemMinutes = itemHour * 60 + itemMin;
              if (itemMinutes < openMinutes) {
                warnings.push(
                  `Itinerary item "${item.title}" starts at ${item.startTime} but ${place.name} opens at ${hoursForDay.open}`,
                );
              }
            }
          }
        }
      }
    }

    // 12. Save itinerary to DB via repository
    log.info('Saving itinerary to database');
    const generation = await DestinationRepository.saveItineraryGeneration(
      input.userId,
      destinationId,
      requestHash,
      { destination: input.destination, startDate: input.startDate, endDate: input.endDate, preferences: input.preferences },
      'gemini-2.0-flash',
      'v1',
    );

    await DestinationRepository.updateItineraryGeneration(generation.id, {
      status: 'COMPLETED',
      resultJson: itinerary,
      completedAt: new Date().toISOString(),
    });

    // Save itinerary items
    const items: any[] = [];
    for (const day of itinerary.days) {
      for (const item of day.items) {
        items.push({
          dayNumber: day.day,
          sequence: item.sequence,
          placeId: item.placeId ?? null,
          title: item.title,
          description: item.description ?? null,
          startTime: item.startTime,
          endTime: item.endTime,
          durationMinutes: item.durationMinutes,
          transportMode: item.transportMode ?? null,
          travelMinutes: item.travelMinutes ?? null,
          reason: item.reason,
        });
      }
    }
    await DestinationRepository.saveItineraryItems(generation.id, items);

    // 13. Save snapshot IDs for provenance
    const snapshotIds: string[] = [];
    const snapDataTypes = ['weather', 'places', 'events', 'safety', 'transport', 'tourism'];
    for (const dataType of snapDataTypes) {
      try {
        const snap = await DestinationRepository.saveDataSnapshot(
          destinationId,
          dataType,
          'multi-provider',
          { requestHash },
          { generatedAt: new Date().toISOString() },
        );
        snapshotIds.push(snap.id);
      } catch {
        // Snapshot save failures are non-fatal
      }
    }

    if (snapshotIds.length > 0) {
      await DestinationRepository.updateItineraryGeneration(generation.id, {
        sourceSnapshotIds: snapshotIds,
      });
    }

    // 14. Return result
    const result: OrchestratorResult = {
      generationId: generation.id,
      itinerary,
      destinationId,
      warnings,
    };

    // Cache the result (TTL: 1 hour)
    await DestinationCacheService.set(cacheKey, result, 3600);

    log.info(
      { generationId: generation.id, warnings: warnings.length },
      'Destination generation completed',
    );

    return result;
  }
}
