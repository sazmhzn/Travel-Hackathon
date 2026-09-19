export interface WeatherProvider {
  getWeather(input: {
    latitude: number;
    longitude: number;
    startDate: string;
    endDate: string;
  }): Promise<WeatherResult>;
  getSunTimes(input: {
    latitude: number;
    longitude: number;
    date: string;
  }): Promise<SunTimesResult>;
}

export interface WeatherResult {
  daily: Array<{
    date: string;
    temperatureMin: number;
    temperatureMax: number;
    precipitationProbability: number;
    windSpeed: number;
    weatherCondition?: string;
  }>;
  source: { provider: string; retrievedAt: string };
}

export interface SunTimesResult {
  sunrise: string;
  sunset: string;
  source: { provider: string; retrievedAt: string };
}
