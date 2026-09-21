import express from 'express';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { GoogleGenAI } from '@google/genai';
import { createServer as createViteServer } from 'vite';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function startServer() {
  const app = express();
  const PORT = 3000;

  app.use(express.json({ limit: '20mb' }));

  // Health check endpoint
  app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', time: new Date().toISOString() });
  });

  // Download ZIP file endpoint
  app.get('/api/download-zip', (req, res) => {
    const zipPath = path.join(process.cwd(), 'public', 'NguyeensAI-Gemini.zip');
    if (!fs.existsSync(zipPath)) {
      return res.status(404).json({ error: 'ZIP package not yet generated. Please try again shortly.' });
    }
    res.download(zipPath, 'NguyeensAI-Gemini.zip', (err) => {
      if (err) {
        console.error('Error downloading zip:', err);
      }
    });
  });

  // Verification endpoint for Gemini API Key
  app.post('/api/verify-gemini-key', async (req, res) => {
    try {
      const userProvidedKey = req.body.apiKey ? String(req.body.apiKey).trim() : '';
      const keyToTest = userProvidedKey || process.env.GEMINI_API_KEY;

      if (!keyToTest) {
        return res.status(400).json({
          valid: false,
          error: 'No API key provided for testing. Please enter your API key or configure GEMINI_API_KEY.',
        });
      }

      // Check key format
      const startsWithGooglePrefix = keyToTest.startsWith('AIzaSy') || keyToTest.startsWith('AIza');
      
      const startTime = Date.now();
      const ai = new GoogleGenAI({
        apiKey: keyToTest,
        httpOptions: {
          headers: {
            'User-Agent': 'aistudio-build',
          },
        },
      });

      // Try gemini-3.5-flash first (most stable, high quota, immune to 503 overload), with resilient fallbacks
      let response;
      let usedModel = 'gemini-3.5-flash';
      const candidateModels = ['gemini-3.5-flash', 'gemini-3.5-flash-lite', 'gemini-flash-lite-latest', 'gemini-3.7-flash', 'gemini-3.8-flash', 'gemini-flash-latest'];
      let lastErr: any = null;

      for (const modelName of candidateModels) {
        try {
          response = await ai.models.generateContent({
            model: modelName,
            contents: 'Ping test. Reply with exactly one word: "PONG".',
          });
          usedModel = modelName;
          lastErr = null;
          break;
        } catch (callErr: any) {
          lastErr = callErr;
          if (callErr.message?.includes('503') || callErr.message?.includes('404') || callErr.message?.includes('429')) {
            continue;
          }
          throw callErr;
        }
      }

      if (!response) {
        throw lastErr || new Error('No response received from Gemini API.');
      }

      const latencyMs = Date.now() - startTime;
      const reply = response.text ? response.text.trim() : '';

      return res.json({
        valid: true,
        message: 'Google Gemini API key is valid and working reliably!',
        latencyMs,
        reply,
        model: usedModel,
        keyPrefix: keyToTest.slice(0, 6) + '...' + keyToTest.slice(-4),
        formatWarning: !startsWithGooglePrefix
          ? 'Note: This key does not start with AIza..., but was successfully verified by Google.'
          : undefined,
      });
    } catch (err: any) {
      console.error('Gemini Key Verification Error:', err);
      let userFriendlyError = err.message || 'Unknown error occurred while connecting to Gemini API';
      
      if (userFriendlyError.includes('400') || userFriendlyError.includes('API_KEY_INVALID') || userFriendlyError.includes('key not valid')) {
        userFriendlyError = 'Invalid API key (HTTP 400). Please check your key from Google AI Studio (starts with AIzaSy...).';
      } else if (userFriendlyError.includes('403') || userFriendlyError.includes('PERMISSION_DENIED')) {
        userFriendlyError = 'API key does not have permission for Generative Language API (HTTP 403). Check Google Cloud / Google AI Studio permissions.';
      } else if (userFriendlyError.includes('429') || userFriendlyError.includes('RESOURCE_EXHAUSTED')) {
        userFriendlyError = 'API key rate limit exceeded (HTTP 429). Please wait a moment or use an account with available quota.';
      }

      return res.status(400).json({
        valid: false,
        error: userFriendlyError,
      });
    }
  });

  // Package file contents endpoint for viewer and copy
  app.get('/api/package-files', (req, res) => {
    try {
      const baseDir = path.join(process.cwd(), 'nguyeens-ai-gemini');
      const files: Array<{ name: string; path: string; size: number; content: string; language: string; changes: string }> = [];

      const readFilesRecursively = (dir: string, relBase = '') => {
        if (!fs.existsSync(dir)) return;
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const entry of entries) {
          const fullPath = path.join(dir, entry.name);
          const relPath = relBase ? `${relBase}/${entry.name}` : entry.name;
          if (entry.isDirectory()) {
            readFilesRecursively(fullPath, relPath);
          } else {
            const stat = fs.statSync(fullPath);
            const content = fs.readFileSync(fullPath, 'utf8');
            let language = 'plaintext';
            if (entry.name.endsWith('.ps1')) language = 'powershell';
            else if (entry.name.endsWith('.html')) language = 'html';
            else if (entry.name.endsWith('.json')) language = 'json';
            else if (entry.name.endsWith('.bat')) language = 'bat';
            else if (entry.name.endsWith('.md') || entry.name.endsWith('.txt')) language = 'markdown';

            let changes = 'Updated for Google Gemini Vision API and optimized with UTF-8 BOM encoding for Windows PowerShell.';
            if (entry.name === 'cli.bat') {
              changes = 'Direct 1-click Command Prompt launch. Supports custom image prompts and Enter key execution.';
            } else if (entry.name === 'web.bat') {
              changes = 'Launches local Web control interface (http://127.0.0.1:8765/) with image prompt attachment support.';
            } else if (entry.name === 'NguyeensCLI.ps1') {
              changes = 'Interactive CLI controller: image path prompts, Enter key triggers, DPAPI key storage, and continuous 10 FPS loop.';
            } else if (entry.name === 'run.bat') {
              changes = 'Direct Command Prompt launcher, error-free and instant start.';
            } else if (entry.name === 'NguyeensAI.ps1') {
              changes = 'Local HTTP server for Web UI, multipart/image prompt handler, and DPAPI key management.';
            } else if (entry.name === 'worker.ps1') {
              changes = 'Continuous 10 FPS engine, Cubic Ease-Out physical mouse motion, 0-1000 optical normalized targeting, image prompt integration, and Ctrl+Fn+E emergency stop.';
            } else if (entry.name === 'index.html') {
              changes = 'Local web interface with drag-and-drop image prompt uploads, 10 FPS live monitor, and emergency stop.';
            } else if (entry.name === 'settings.json') {
              changes = 'Default configuration: gemini-3.5-flash, fps=10, step_delay_ms=100.';
            }

            files.push({
              name: entry.name,
              path: relPath,
              size: stat.size,
              content,
              language,
              changes,
            });
          }
        }
      };

      readFilesRecursively(baseDir);

      res.json({ files, zipDownloadUrl: '/api/download-zip' });
    } catch (err: any) {
      res.status(500).json({ error: err.message });
    }
  });

  // Test prompt execution via Gemini with image prompt support
  app.post('/api/test-gemini-vision', async (req, res) => {
    try {
      const { prompt, apiKey, imageBase64, imageMime } = req.body;
      const keyToUse = apiKey || process.env.GEMINI_API_KEY;
      if (!keyToUse) {
        return res.status(400).json({ error: 'No API Key configured.' });
      }

      const ai = new GoogleGenAI({
        apiKey: keyToUse,
        httpOptions: {
          headers: {
            'User-Agent': 'aistudio-build',
          },
        },
      });

      let response;
      const promptText = `You are a Windows computer automation assistant. For the user request: "${prompt || 'Open Notepad and type a note'}", analyze the task (and attached image if provided) and explain step-by-step how you would interact with Windows (Win key, app name, exact coordinates to click, text to type). Be concise, clear, and professional in English.`;
      
      const contentsParts: any[] = [{ text: promptText }];
      if (imageBase64) {
        const cleanBase64 = imageBase64.replace(/^data:image\/[a-zA-Z]+;base64,/, '');
        contentsParts.push({
          inlineData: {
            mimeType: imageMime || 'image/jpeg',
            data: cleanBase64,
          },
        });
      }

      const candidateModels = ['gemini-3.8-flash', 'gemini-3.5-flash', 'gemini-flash-latest'];
      let lastErr: any = null;

      for (const modelName of candidateModels) {
        try {
          response = await ai.models.generateContent({
            model: modelName,
            contents: contentsParts,
          });
          lastErr = null;
          break;
        } catch (callErr: any) {
          lastErr = callErr;
          if (callErr.message?.includes('503') || callErr.message?.includes('404') || callErr.message?.includes('429')) {
            continue;
          }
          throw callErr;
        }
      }

      if (!response) {
        throw lastErr || new Error('No response received from Gemini API.');
      }

      res.json({ result: response.text });
    } catch (err: any) {
      res.status(500).json({ error: err.message });
    }
  });

  // Vite middleware setup
  if (process.env.NODE_ENV !== 'production') {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), 'dist');
    app.use(express.static(distPath));
    app.get('*', (req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
  });
}

startServer();
