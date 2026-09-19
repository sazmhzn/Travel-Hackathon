import type { WeatherResult } from '../providers/weather/weather.provider.js';

export interface NormalizedWeatherDay {
  date: string;
  temperatureMin: number;
  temperatureMax: number;
  precipitationProbability: number;
  windSpeed: number;
  weatherCondition?: string;
  sunrise?: string;
  sunset?: string;
  source: { provider: string; retrievedAt: string };
}

const WMO_CODE_MAP: Record<number, string> = {
  0: 'CLEAR',
  1: 'CLEAR',
  2: 'PARTLY_CLOUDY',
  3: 'CLOUDY',
  45: 'FOG',
  48: 'FOG',
  51: 'RAIN',
  53: 'RAIN',
  55: 'RAIN',
  61: 'RAIN',
  63: 'HEAVY_RAIN',
  65: 'HEAVY_RAIN',
  71: 'SNOW',
  73: 'SNOW',
  75: 'SNOW',
  80: 'RAIN',
  81: 'HEAVY_RAIN',
  82: 'HEAVY_RAIN',
  95: 'THUNDERSTORM',
  96: 'THUNDERSTORM',
  99: 'THUNDERSTORM',
};

function mapWeatherCode(code?: string): string | undefined {
  if (!code) return undefined;
  const num = parseInt(code, 10);
  if (isNaN(num)) return undefined;
  return WMO_CODE_MAP[num];
}

export function normalizeWeather(data: WeatherResult | null | undefined): NormalizedWeatherDay[] {
  if (!data?.daily) return [];

  return data.daily.map((day) => ({
    date: day.date,
    temperatureMin: day.temperatureMin,
    temperatureMax: day.temperatureMax,
    precipitationProbability: day.precipitationProbability,
    windSpeed: day.windSpeed,
    weatherCondition: mapWeatherCode(day.weatherCondition),
    source: data.source,
  }));
}
