export interface RoutesProvider {
  getRoute(input: {
    origin: { latitude: number; longitude: number };
    destination: { latitude: number; longitude: number };
    mode: string;
  }): Promise<RouteResult | null>;
}

export interface RouteResult {
  distanceMeters: number;
  durationSeconds: number;
  mode: string;
  elevationGainMeters?: number;
  polyline?: string;
  source: { provider: string; retrievedAt: string };
}
