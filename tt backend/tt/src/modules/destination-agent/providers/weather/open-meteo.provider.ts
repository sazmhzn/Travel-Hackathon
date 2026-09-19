import type {
  WeatherProvider,
  WeatherResult,
  SunTimesResult,
} from "./weather.provider.js";

const WMO_WEATHER_CODES: Record<number, string> = {
  0: "Clear sky",
  1: "Mainly clear",
  2: "Partly cloudy",
  3: "Overcast",
  45: "Fog",
  48: "Depositing rime fog",
  51: "Light drizzle",
  53: "Moderate drizzle",
  55: "Dense drizzle",
  56: "Light freezing drizzle",
  57: "Dense freezing drizzle",
  61: "Slight rain",
  63: "Moderate rain",
  65: "Heavy rain",
  66: "Light freezing rain",
  67: "Heavy freezing rain",
  71: "Slight snow fall",
  73: "Moderate snow fall",
  75: "Heavy snow fall",
  77: "Snow grains",
  80: "Slight rain showers",
  81: "Moderate rain showers",
  82: "Violent rain showers",
  85: "Slight snow showers",
  86: "Heavy snow showers",
  95: "Thunderstorm",
  96: "Thunderstorm with slight hail",
  99: "Thunderstorm with heavy hail",
};

export class OpenMeteoWeatherProvider implements WeatherProvider {
  private readonly baseUrl = "https://api.open-meteo.com/v1/forecast";

  async getWeather(input: {
    latitude: number;
    longitude: number;
    startDate: string;
    endDate: string;
  }): Promise<WeatherResult> {
    try {
      const params = new URLSearchParams({
        latitude: String(input.latitude),
        longitude: String(input.longitude),
        daily: [
          "temperature_2m_max",
          "temperature_2m_min",
          "precipitation_probability_max",
          "wind_speed_10m_max",
          "weather_code",
        ].join(","),
        start_date: input.startDate,
        end_date: input.endDate,
      });

      const response = await fetch(`${this.baseUrl}?${params.toString()}`);

      if (!response.ok) {
        console.warn(
          `[OpenMeteoWeatherProvider] getWeather failed: ${response.status} ${response.statusText}`
        );
        return { daily: [], source: this.source() };
      }

      const data = (await response.json()) as {
        daily?: {
          time: string[];
          temperature_2m_max: number[];
          temperature_2m_min: number[];
          precipitation_probability_max: number[];
          wind_speed_10m_max: number[];
          weather_code: number[];
        };
      };

      const daily = data.daily;
      if (!daily) {
        return { daily: [], source: this.source() };
      }

      return {
        daily: daily.time.map((date, i) => ({
          date,
          temperatureMin: daily.temperature_2m_min[i],
          temperatureMax: daily.temperature_2m_max[i],
          precipitationProbability: daily.precipitation_probability_max[i],
          windSpeed: daily.wind_speed_10m_max[i],
          weatherCondition: WMO_WEATHER_CODES[daily.weather_code[i]],
        })),
        source: this.source(),
      };
    } catch (error) {
      console.warn("[OpenMeteoWeatherProvider] getWeather error:", error);
      return { daily: [], source: this.source() };
    }
  }

  async getSunTimes(input: {
    latitude: number;
    longitude: number;
    date: string;
  }): Promise<SunTimesResult> {
    try {
      const params = new URLSearchParams({
        latitude: String(input.latitude),
        longitude: String(input.longitude),
        daily: "sunrise,sunset",
        start_date: input.date,
        end_date: input.date,
        timezone: "auto",
      });

      const response = await fetch(`${this.baseUrl}?${params.toString()}`);

      if (!response.ok) {
        console.warn(
          `[OpenMeteoWeatherProvider] getSunTimes failed: ${response.status} ${response.statusText}`
        );
        return { sunrise: "", sunset: "", source: this.source() };
      }

      const data = (await response.json()) as {
        daily?: {
          sunrise: string[];
          sunset: string[];
        };
      };

      const daily = data.daily;
      if (!daily || !daily.sunrise[0] || !daily.sunset[0]) {
        return { sunrise: "", sunset: "", source: this.source() };
      }

      return {
        sunrise: daily.sunrise[0],
        sunset: daily.sunset[0],
        source: this.source(),
      };
    } catch (error) {
      console.warn("[OpenMeteoWeatherProvider] getSunTimes error:", error);
      return { sunrise: "", sunset: "", source: this.source() };
    }
  }

  private source() {
    return { provider: "open-meteo", retrievedAt: new Date().toISOString() };
  }
}
