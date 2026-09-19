import type { EventResult } from '../providers/events/events.provider.js';

export interface NormalizedEvent {
  name: string;
  description?: string;
  startTime: string;
  endTime?: string;
  location?: { latitude: number; longitude: number };
  url?: string;
  category: string;
  source: { provider: string; retrievedAt: string };
}

const EVENT_CATEGORY_MAP: Record<string, string> = {
  festival: 'FESTIVAL',
  market: 'MARKET',
  concert: 'CONCERT',
  exhibition: 'EXHIBITION',
  sports: 'SPORTS',
  cultural: 'CULTURAL',
  religious: 'RELIGIOUS',
};

function mapCategory(rawCategory: string): string {
  return EVENT_CATEGORY_MAP[rawCategory.toLowerCase()] ?? 'OTHER';
}

export function normalizeEvents(events: EventResult[]): NormalizedEvent[] {
  if (!events) return [];

  return events
    .filter((e) => e?.name && e?.startDate)
    .map((event) => ({
      name: event.name,
      description: event.description,
      startTime: event.startDate,
      endTime: event.endDate,
      location:
        event.latitude != null && event.longitude != null
          ? { latitude: event.latitude, longitude: event.longitude }
          : undefined,
      url: event.url,
      category: mapCategory(event.category),
      source: event.source,
    }));
}
