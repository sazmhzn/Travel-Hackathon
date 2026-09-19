export interface ElevationProvider {
  getElevation(input: {
    latitude: number;
    longitude: number;
  }): Promise<ElevationResult>;
}

export interface ElevationResult {
  elevationMeters: number;
  source: { provider: string; retrievedAt: string };
}

export class OpenMeteoElevationProvider implements ElevationProvider {
  private readonly baseUrl = "https://api.open-meteo.com/v1/elevation";

  async getElevation(input: {
    latitude: number;
    longitude: number;
  }): Promise<ElevationResult> {
    try {
      const params = new URLSearchParams({
        latitude: String(input.latitude),
        longitude: String(input.longitude),
      });

      const response = await fetch(`${this.baseUrl}?${params.toString()}`);

      if (!response.ok) {
        console.warn(
          `[OpenMeteoElevationProvider] getElevation failed: ${response.status} ${response.statusText}`
        );
        return { elevationMeters: 0, source: this.source() };
      }

      const data = (await response.json()) as {
        elevation?: number[];
      };

      const elevation = data.elevation?.[0];
      if (elevation === undefined || elevation === null) {
        return { elevationMeters: 0, source: this.source() };
      }

      return {
        elevationMeters: elevation,
        source: this.source(),
      };
    } catch (error) {
      console.warn("[OpenMeteoElevationProvider] getElevation error:", error);
      return { elevationMeters: 0, source: this.source() };
    }
  }

  private source() {
    return { provider: "open-meteo", retrievedAt: new Date().toISOString() };
  }
}
