export interface SafetyProvider {
  getSafetyInformation(destination: string): Promise<SafetyInformation>;
}

export interface SafetyInformation {
  destination: string;
  safetyLevel: "safe" | "caution" | "warning";
  alerts: SafetyAlert[];
  recommendations: string[];
  emergencyNumbers?: Record<string, string>;
  source: { provider: string; retrievedAt: string };
}

export interface SafetyAlert {
  type: string;
  message: string;
  severity: "low" | "medium" | "high";
}

export class ManualSafetyProvider implements SafetyProvider {
  async getSafetyInformation(destination: string): Promise<SafetyInformation> {
    return {
      destination,
      safetyLevel: "safe",
      alerts: [],
      recommendations: [],
      source: { provider: "manual", retrievedAt: new Date().toISOString() },
    };
  }
}
