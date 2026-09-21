export interface PackageFile {
  name: string;
  path: string;
  size: number;
  content: string;
  language: string;
  changes?: string;
  description?: string;
}

export interface VerificationResult {
  valid: boolean;
  message?: string;
  latencyMs?: number;
  reply?: string;
  model?: string;
  keyPrefix?: string;
  formatWarning?: string;
  error?: string;
}
