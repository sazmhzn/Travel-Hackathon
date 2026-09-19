import { z } from 'zod';

// ============================================================================
// Source & Metadata
// ============================================================================

export const SourceMetadataSchema = z.object({
  provider: z.string(),
  providerId: z.string().optional(),
  url: z.string().url().optional(),
  retrievedAt: z.string().datetime(),
});

// ============================================================================
// Coordinates
// ============================================================================

export const CoordinatesSchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
});

// ============================================================================
// Opening Hours
// ============================================================================

export const OpeningHoursSchema = z.object({
  day: z.number().min(0).max(6),
  open: z.string().regex(/^\d{2}:\d{2}$/),
  close: z.string().regex(/^\d{2}:\d{2}$/),
});

// ============================================================================
// Place
// ============================================================================

export const PlaceCategorySchema = z.enum([
  'NATURE',
  'CULTURE',
  'FOOD',
  'ADVENTURE',
  'SHOPPING',
  'LANDMARK',
  'ACCOMMODATION',
  'TRANSPORT',
]);

export const NormalizedPlaceSchema = z.object({
  id: z.string(),
  name: z.string(),
  category: PlaceCategorySchema,
  location: CoordinatesSchema,
  rating: z.number().min(0).max(5).optional(),
  ratingCount: z.number().int().nonnegative().optional(),
  priceLevel: z.number().min(1).max(4).optional(),
  openingHours: z.array(OpeningHoursSchema).optional(),
  websiteUrl: z.string().url().optional(),
  phone: z.string().optional(),
  popularitySignal: z.number().min(0).max(1).optional(),
  photos: z.array(z.string().url()).optional(),
  source: SourceMetadataSchema,
});

// ============================================================================
// Weather
// ============================================================================

export const WeatherConditionSchema = z.enum([
  'CLEAR',
  'PARTLY_CLOUDY',
  'CLOUDY',
  'RAIN',
  'HEAVY_RAIN',
  'THUNDERSTORM',
  'SNOW',
  'FOG',
  'WINDY',
]);

export const WeatherDataSchema = z.object({
  date: z.string().datetime(),
  temperatureMin: z.number(),
  temperatureMax: z.number(),
  precipitationProbability: z.number().min(0).max(100),
  windSpeed: z.number().nonnegative(),
  weatherCondition: WeatherConditionSchema.optional(),
  sunrise: z.string().datetime().optional(),
  sunset: z.string().datetime().optional(),
  source: SourceMetadataSchema,
});

// ============================================================================
// Route
// ============================================================================

export const TransportModeSchema = z.enum([
  'DRIVE',
  'WALK',
  'BICYCLE',
  'TRANSIT',
]);

export const RouteDataSchema = z.object({
  originName: z.string(),
  destinationName: z.string(),
  distanceMeters: z.number().nonnegative(),
  durationSeconds: z.number().nonnegative(),
  mode: TransportModeSchema,
  elevationGainMeters: z.number().nonnegative().optional(),
  source: SourceMetadataSchema,
});

// ============================================================================
// Elevation
// ============================================================================

export const ElevationDataSchema = z.object({
  elevationMeters: z.number(),
  source: SourceMetadataSchema,
});

// ============================================================================
// Event
// ============================================================================

export const EventCategorySchema = z.enum([
  'FESTIVAL',
  'MARKET',
  'CONCERT',
  'EXHIBITION',
  'SPORTS',
  'CULTURAL',
  'RELIGIOUS',
  'OTHER',
]);

export const EventDataSchema = z.object({
  name: z.string(),
  description: z.string().optional(),
  startTime: z.string().datetime(),
  endTime: z.string().datetime(),
  location: CoordinatesSchema.optional(),
  url: z.string().url().optional(),
  category: EventCategorySchema,
  source: SourceMetadataSchema,
});

// ============================================================================
// Safety
// ============================================================================

export const SeverityLevelSchema = z.enum([
  'CRITICAL',
  'HIGH',
  'MEDIUM',
  'LOW',
]);

export const SafetyAlertSchema = z.object({
  title: z.string(),
  severity: SeverityLevelSchema,
  source: SourceMetadataSchema,
  publishedAt: z.string().datetime(),
});

export const SafetyLevelSchema = z.enum([
  'SAFE',
  'MODERATE',
  'RESTRICTED',
  'DANGEROUS',
]);

export const SafetyInformationSchema = z.object({
  alerts: z.array(SafetyAlertSchema),
  overallSafetyLevel: SafetyLevelSchema,
  source: SourceMetadataSchema,
});

// ============================================================================
// Tourism Information
// ============================================================================

export const TourismInformationSchema = z.object({
  title: z.string(),
  content: z.string(),
  highlights: z.array(z.string()),
  source: SourceMetadataSchema,
});

// ============================================================================
// Transport Option
// ============================================================================

export const TransportTypeSchema = z.enum([
  'LOCAL_BUS',
  'TOURIST_BUS',
  'TAXI',
  'JEEP',
  'SHUTTLE',
  'BOAT',
  'OTHER',
]);

export const TransportOptionSchema = z.object({
  operatorName: z.string(),
  type: TransportTypeSchema,
  origin: z.string(),
  destination: z.string(),
  phone: z.string().optional(),
  website: z.string().url().optional(),
  bookingUrl: z.string().url().optional(),
  priceRange: z.string().optional(),
  estimatedPriceNpr: z.number().nonnegative().optional(),
  estimatedDurationMinutes: z.number().nonnegative().optional(),
  estimatedDistanceMeters: z.number().nonnegative().optional(),
  source: SourceMetadataSchema,
});

// ============================================================================
// Destination Generation Request
// ============================================================================

export const InterestEnum = z.enum([
  'NATURE',
  'CULTURE',
  'FOOD',
  'ADVENTURE',
  'SHOPPING',
  'NIGHTLIFE',
  'RELAXATION',
  'PHOTOGRAPHY',
]);

export const BudgetLevelSchema = z.enum([
  'BUDGET',
  'MEDIUM',
  'LUXURY',
]);

export const TravelPreferenceTransportSchema = z.enum([
  'PUBLIC',
  'PRIVATE',
  'WALKING',
  'BICYCLE',
]);

export const TravelStyleSchema = z.enum([
  'FAST',
  'MODERATE',
  'SLOW',
]);

export const PreferencesSchema = z.object({
  interests: z.array(InterestEnum),
  budget: BudgetLevelSchema,
  transport: z.array(TravelPreferenceTransportSchema),
  travelStyle: TravelStyleSchema,
});

export const DestinationGenerationRequestSchema = z.object({
  destination: z.string().min(1),
  startDate: z.string().datetime(),
  endDate: z.string().datetime(),
  preferences: PreferencesSchema,
});

// ============================================================================
// Itinerary
// ============================================================================

export const ItineraryItemSchema = z.object({
  dayNumber: z.number().int().min(1),
  sequence: z.number().int().min(1),
  placeId: z.string().optional(),
  title: z.string(),
  description: z.string().optional(),
  startTime: z.string().regex(/^\d{2}:\d{2}$/),
  endTime: z.string().regex(/^\d{2}:\d{2}$/),
  durationMinutes: z.number().int().positive(),
  transportMode: z.string().optional(),
  travelMinutes: z.number().nonnegative().optional(),
  reason: z.string(),
});

export const DayPlanSchema = z.object({
  day: z.number().int().min(1),
  date: z.string(),
  items: z.array(ItineraryItemSchema),
});

export const GeneratedItinerarySchema = z.object({
  title: z.string(),
  summary: z.string(),
  days: z.array(DayPlanSchema),
  warnings: z.array(z.string()).optional(),
});

// ============================================================================
// Types
// ============================================================================

export type SourceMetadata = z.infer<typeof SourceMetadataSchema>;
export type Coordinates = z.infer<typeof CoordinatesSchema>;
export type OpeningHours = z.infer<typeof OpeningHoursSchema>;
export type PlaceCategory = z.infer<typeof PlaceCategorySchema>;
export type NormalizedPlace = z.infer<typeof NormalizedPlaceSchema>;
export type WeatherCondition = z.infer<typeof WeatherConditionSchema>;
export type WeatherData = z.infer<typeof WeatherDataSchema>;
export type TransportMode = z.infer<typeof TransportModeSchema>;
export type RouteData = z.infer<typeof RouteDataSchema>;
export type ElevationData = z.infer<typeof ElevationDataSchema>;
export type EventCategory = z.infer<typeof EventCategorySchema>;
export type EventData = z.infer<typeof EventDataSchema>;
export type SeverityLevel = z.infer<typeof SeverityLevelSchema>;
export type SafetyAlert = z.infer<typeof SafetyAlertSchema>;
export type SafetyLevel = z.infer<typeof SafetyLevelSchema>;
export type SafetyInformation = z.infer<typeof SafetyInformationSchema>;
export type TourismInformation = z.infer<typeof TourismInformationSchema>;
export type TransportType = z.infer<typeof TransportTypeSchema>;
export type TransportOption = z.infer<typeof TransportOptionSchema>;
export type Interest = z.infer<typeof InterestEnum>;
export type BudgetLevel = z.infer<typeof BudgetLevelSchema>;
export type TravelPreferenceTransport = z.infer<typeof TravelPreferenceTransportSchema>;
export type TravelStyle = z.infer<typeof TravelStyleSchema>;
export type Preferences = z.infer<typeof PreferencesSchema>;
export type DestinationGenerationRequest = z.infer<typeof DestinationGenerationRequestSchema>;
export type ItineraryItem = z.infer<typeof ItineraryItemSchema>;
export type DayPlan = z.infer<typeof DayPlanSchema>;
export type GeneratedItinerary = z.infer<typeof GeneratedItinerarySchema>;
