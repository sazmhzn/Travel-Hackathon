export interface TransportProvider {
  searchOperators(input: {
    origin: string;
    destination: string;
    latitude?: number;
    longitude?: number;
  }): Promise<TransportOperatorResult[]>;
}

export interface TransportOperatorResult {
  name: string;
  type: string;
  origin: string;
  destination: string;
  phone?: string;
  website?: string;
  bookingUrl?: string;
  priceRange?: string;
  estimatedPriceNpr?: number;
  estimatedDurationMinutes?: number;
  estimatedDistanceMeters?: number;
  source: { provider: string; retrievedAt: string };
}

export class ManualTransportProvider implements TransportProvider {
  async searchOperators(_input?: {
    origin: string;
    destination: string;
    latitude?: number;
    longitude?: number;
  }): Promise<TransportOperatorResult[]> {
    return [];
  }
}
