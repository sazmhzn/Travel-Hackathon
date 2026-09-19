export interface TourismProvider {
  getDestinationInfo(destination: string): Promise<TourismInformation>;
}

export interface TourismInformation {
  destination: string;
  overview: string;
  bestTimeToVisit: string;
  averageDailyBudget?: number;
  currency?: string;
  language?: string;
  highlights: string[];
  tips: string[];
  source: { provider: string; retrievedAt: string };
}

export class ManualTourismProvider implements TourismProvider {
  async getDestinationInfo(destination: string): Promise<TourismInformation> {
    return {
      destination,
      overview: "",
      bestTimeToVisit: "",
      highlights: [],
      tips: [],
      source: { provider: "manual", retrievedAt: new Date().toISOString() },
    };
  }
}
