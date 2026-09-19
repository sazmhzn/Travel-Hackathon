import { GeneratedItinerarySchema, type GeneratedItinerary } from '../schemas/destination.schema.js';
import { buildItineraryPrompt, type ItineraryPromptInput } from './itinerary.prompt.js';

export type ItineraryGenerationInput = ItineraryPromptInput;

const GEMINI_API_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

interface GeminiRequest {
  contents: Array<{ parts: Array<{ text: string }> }>;
  generationConfig: { responseMimeType: string };
}

interface GeminiResponse {
  candidates?: Array<{
    content?: { parts?: Array<{ text?: string }> };
  }>;
  error?: { message: string; code: number };
}

export class GeminiService {
  static async generateItinerary(
    input: ItineraryGenerationInput,
  ): Promise<GeneratedItinerary> {
    const apiKey = process.env.GOOGLE_GEMINI_API_KEY;
    if (!apiKey) {
      throw new Error(
        'GOOGLE_GEMINI_API_KEY environment variable is not set. ' +
          'Please provide a valid Gemini API key to generate itineraries.',
      );
    }

    const prompt = buildItineraryPrompt(input);

    const body: GeminiRequest = {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { responseMimeType: 'application/json' },
    };

    const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(
        `Gemini API request failed with status ${response.status}: ${text}`,
      );
    }

    const data = (await response.json()) as GeminiResponse;

    if (data.error) {
      throw new Error(
        `Gemini API error: ${data.error.message} (code ${data.error.code})`,
      );
    }

    const jsonText = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!jsonText) {
      throw new Error(
        'Gemini API returned an empty response. No itinerary could be generated.',
      );
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(jsonText);
    } catch {
      throw new Error(
        'Gemini API returned invalid JSON. Could not parse itinerary.',
      );
    }

    const result = GeneratedItinerarySchema.safeParse(parsed);
    if (!result.success) {
      throw new Error(
        `Gemini response failed schema validation: ${result.error.message}`,
      );
    }

    return result.data;
  }
}
