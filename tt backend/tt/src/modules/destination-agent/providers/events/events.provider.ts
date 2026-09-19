export interface EventsProvider {
  searchEvents(input: {
    destination: string;
    startDate: string;
    endDate: string;
    latitude?: number;
    longitude?: number;
  }): Promise<EventResult[]>;
}

export interface EventResult {
  name: string;
  description?: string;
  category: string;
  startDate: string;
  endDate?: string;
  location?: string;
  latitude?: number;
  longitude?: number;
  url?: string;
  price?: string;
  source: { provider: string; retrievedAt: string };
}

export class ManualEventsProvider implements EventsProvider {
  async searchEvents(_input?: {
    destination: string;
    startDate: string;
    endDate: string;
    latitude?: number;
    longitude?: number;
  }): Promise<EventResult[]> {
    return [];
  }
}
