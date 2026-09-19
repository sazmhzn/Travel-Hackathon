import type { TransportOperatorResult } from '../providers/transport/local-transport.provider.js';

export interface NormalizedTransport {
  operatorName: string;
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

const TRANSPORT_TYPE_MAP: Record<string, string> = {
  local_bus: 'LOCAL_BUS',
  tourist_bus: 'TOURIST_BUS',
  taxi: 'TAXI',
  jeep: 'JEEP',
  shuttle: 'SHUTTLE',
  boat: 'BOAT',
  bus: 'LOCAL_BUS',
  private: 'TAXI',
  public: 'LOCAL_BUS',
};

function mapTransportType(rawType: string): string {
  return TRANSPORT_TYPE_MAP[rawType.toLowerCase()] ?? 'OTHER';
}

export function normalizeTransport(operators: TransportOperatorResult[]): NormalizedTransport[] {
  if (!operators) return [];

  return operators
    .filter(
      (op) => op?.name && op?.type && op?.origin && op?.destination
    )
    .map((op) => ({
      operatorName: op.name,
      type: mapTransportType(op.type),
      origin: op.origin,
      destination: op.destination,
      phone: op.phone,
      website: op.website,
      bookingUrl: op.bookingUrl,
      priceRange: op.priceRange,
      estimatedPriceNpr: op.estimatedPriceNpr,
      estimatedDurationMinutes: op.estimatedDurationMinutes,
      estimatedDistanceMeters: op.estimatedDistanceMeters,
      source: op.source,
    }));
}
