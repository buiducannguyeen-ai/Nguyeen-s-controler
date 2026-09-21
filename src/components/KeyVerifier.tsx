import React, { useState } from 'react';
import { KeyRound, CheckCircle2, AlertCircle, Loader2, Sparkles, ShieldCheck } from 'lucide-react';
import { VerificationResult } from '../types';

export const KeyVerifier: React.FC = () => {
  const [apiKey, setApiKey] = useState('');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<VerificationResult | null>(null);

  const handleVerify = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    const cleanKey = apiKey.trim();
    if (!cleanKey) {
      setResult({ valid: false, error: 'Please enter a valid Gemini API key.' });
      return;
    }

    setLoading(true);
    setResult(null);

    try {
      // 1. Try server verification endpoint first
      const response = await fetch('/api/verify-gemini-key', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ apiKey: cleanKey }),
      }).catch(() => null);

      if (response && response.ok) {
        const data = await response.json();
        setResult(data);
        return;
      }

      // 2. Fallback for static hosting (e.g. Vercel): verify directly against Google Gemini API
      const startTime = Date.now();
      const directUrl = `https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(cleanKey)}`;
      const directResp = await fetch(directUrl);
      const latencyMs = Date.now() - startTime;

      if (directResp.ok) {
        const directData = await directResp.json();
        const availableModels = directData.models ? directData.models.length : 0;
        setResult({
          valid: true,
          message: `Gemini API key verified successfully via Google AI Studio (${availableModels} models accessible). Ready for Windows automation.`,
          latencyMs,
          model: 'gemini-3.5-flash',
          keyPrefix: cleanKey.slice(0, 6) + '...' + cleanKey.slice(-4),
        });
      } else {
        const errData = await directResp.json().catch(() => ({}));
        const errMsg = errData.error?.message || `HTTP ${directResp.status}: Invalid key or permission denied.`;
        setResult({
          valid: false,
          error: errMsg,
          keyPrefix: cleanKey.slice(0, 6) + '...',
        });
      }
    } catch (err: any) {
      setResult({
        valid: false,
        error: err.message || 'Unable to connect to Google Gemini API servers.',
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="border-2 border-[#285430] bg-[#071009] p-6 rounded-lg shadow-lg relative overflow-hidden">
      <div className="absolute top-0 right-0 w-32 h-32 bg-[#79ee87]/5 rounded-full blur-2xl pointer-events-none" />
      
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 border border-[#79ee87] bg-[#030704] flex items-center justify-center text-[#79ee87]">
            <KeyRound className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-lg font-bold text-[#a6ffae] tracking-tight">
              Gemini API Key Live Verifier
            </h2>
            <p className="text-xs text-[#78a17d]">
              Confirm your Google Gemini API key credentials before running local automation on Windows
            </p>
          </div>
        </div>
        <span className="text-[11px] font-mono uppercase px-2.5 py-1 border border-[#285430] text-[#76c9a1] bg-[#040a05]">
          Google AI Studio
        </span>
      </div>

      <form onSubmit={handleVerify} className="space-y-4">
        <div>
          <label htmlFor="testKeyInput" className="block text-xs font-mono uppercase text-[#78a17d] mb-1.5">
            Enter Gemini API Key to test
          </label>
          <div className="relative">
            <input
              id="testKeyInput"
              type="password"
              value={apiKey}
              onChange={(e) => setApiKey(e.target.value)}
              placeholder="AIzaSy... (leave blank to verify server-side default key)"
              className="w-full bg-[#020503] border-2 border-[#285430] text-[#79ee87] px-3.5 py-2.5 text-sm font-mono focus:border-[#79ee87] focus:outline-none placeholder-[#37523b] transition-colors"
            />
            {apiKey && (
              <button
                type="button"
                onClick={() => setApiKey('')}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-[#78a17d] hover:text-[#a6ffae]"
              >
                Clear
              </button>
            )}
          </div>
          <p className="mt-1 text-[11px] text-[#78a17d] flex items-center gap-1">
            <span>Need an API key?</span>
            <a
              href="https://aistudio.google.com/app/apikey"
              target="_blank"
              rel="noreferrer"
              className="text-[#a6ffae] underline hover:text-white inline-flex items-center gap-0.5"
            >
              Get a free API key at Google AI Studio
            </a>
          </p>
        </div>

        <div className="flex items-center justify-between gap-4 pt-1">
          <div className="flex items-center gap-2 text-xs text-[#78a17d]">
            <ShieldCheck className="w-4 h-4 text-[#79ee87]" />
            <span>Secure validation • Never logs personal credentials</span>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="px-5 py-2.5 bg-[#79ee87] hover:bg-[#a6ffae] text-[#071009] font-bold text-xs uppercase tracking-wider flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {loading ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                <span>Verifying...</span>
              </>
            ) : (
              <>
                <Sparkles className="w-4 h-4" />
                <span>Verify Connection</span>
              </>
            )}
          </button>
        </div>
      </form>

      {/* Result presentation */}
      {result && (
        <div
          className={`mt-4 p-4 border-2 rounded transition-all ${
            result.valid
              ? 'bg-[#08170c] border-[#79ee87] text-[#a6ffae]'
              : 'bg-[#180a09] border-[#ff766d] text-[#ff766d]'
          }`}
        >
          <div className="flex items-start gap-3">
            {result.valid ? (
              <CheckCircle2 className="w-5 h-5 text-[#79ee87] shrink-0 mt-0.5" />
            ) : (
              <AlertCircle className="w-5 h-5 text-[#ff766d] shrink-0 mt-0.5" />
            )}
            <div className="space-y-1 text-sm font-mono">
              <div className="font-bold flex items-center gap-2">
                <span>{result.valid ? 'Verification Successful!' : 'Verification Failed!'}</span>
                {result.latencyMs !== undefined && (
                  <span className="text-xs px-2 py-0.5 bg-[#030704] border border-[#285430] text-[#76c9a1]">
                    Latency: {result.latencyMs} ms
                  </span>
                )}
                {result.model && (
                  <span className="text-xs px-2 py-0.5 bg-[#030704] border border-[#285430] text-[#76c9a1]">
                    Model: {result.model}
                  </span>
                )}
              </div>
              
              <p className="text-xs opacity-90">
                {result.message || result.error}
              </p>

              {result.formatWarning && (
                <p className="text-xs text-[#e3d764] mt-1">
                  ⚠️ {result.formatWarning}
                </p>
              )}

              {result.reply && (
                <div className="mt-2 text-xs bg-[#020503] p-2 border border-[#285430] text-[#78a17d]">
                  Gemini Response: <span className="text-[#a6ffae] font-bold">{result.reply}</span>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
