import React, { useState, useEffect, useRef } from 'react';
import {
  Download,
  ShieldCheck,
  Cpu,
  Terminal,
  FileArchive,
  ArrowRight,
  ExternalLink,
  CheckCircle2,
  AlertTriangle,
  Settings,
  Flame,
  Zap,
  Loader2,
  Image as ImageIcon,
  X,
  Play,
  FileText,
} from 'lucide-react';
import { KeyVerifier } from './components/KeyVerifier';
import { FileViewer } from './components/FileViewer';
import { InteractiveTest } from './components/InteractiveTest';
import { PackageFile } from './types';
import { DEFAULT_PACKAGE_FILES } from './data/packageFiles';
import { generateAndDownloadZip } from './utils/downloadZip';

export default function App() {
  const [files, setFiles] = useState<PackageFile[]>(DEFAULT_PACKAGE_FILES);
  const [loading, setLoading] = useState(false);
  const [downloading, setDownloading] = useState(false);
  const [downloadSuccess, setDownloadSuccess] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'files' | 'test' | 'guide' | 'compare'>('files');
  const [selectedFilePath, setSelectedFilePath] = useState<string>('run.bat');

  useEffect(() => {
    // Attempt to sync from backend if Express server is running, otherwise DEFAULT_PACKAGE_FILES is active
    fetch('/api/package-files')
      .then((res) => {
        if (!res.ok) return null;
        return res.json();
      })
      .then((data) => {
        if (data && data.files && data.files.length > 0) {
          setFiles(data.files);
          if (!selectedFilePath) {
            setSelectedFilePath(data.files[0].path);
          }
        }
      })
      .catch(() => {
        // Static hosting like Vercel uses DEFAULT_PACKAGE_FILES seamlessly
      })
      .finally(() => setLoading(false));
  }, []);

  const openFile = (path: string) => {
    setSelectedFilePath(path);
    setActiveTab('files');
    setTimeout(() => {
      document.getElementById('file-viewer-section')?.scrollIntoView({ behavior: 'smooth' });
    }, 50);
  };

  // 100% Client-side in-memory ZIP package download: works seamlessly on Vercel, Cloud Run, and offline
  const handleDownload = async () => {
    try {
      setDownloading(true);
      setDownloadSuccess(null);

      const result = await generateAndDownloadZip(files);
      setDownloadSuccess(
        `Generated and downloaded package ${result.fileName} (${result.sizeKb} KB, ${result.fileCount} files). Extract the archive and double-click run.bat!`
      );
    } catch (err: any) {
      console.warn('In-browser zip generation fallback to direct static file:', err);
      try {
        const a = document.createElement('a');
        a.href = '/NguyeensAI-Gemini.zip';
        a.download = 'NguyeensAI-Gemini.zip';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
      } catch (staticErr: any) {
        alert('Could not generate ZIP file: ' + (err.message || staticErr.message));
      }
    } finally {
      setDownloading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#030704] text-[#79ee87] font-mono selection:bg-[#79ee87] selection:text-[#030704]">
      {/* Top Navigation Bar */}
      <header className="border-b-2 border-[#285430] bg-[#061008] px-4 md:px-8 py-4 sticky top-0 z-50 backdrop-blur-md">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-4">
            <img
              src="/logo.svg"
              alt="Nguyen's AI — Gemini Powered"
              className="h-10 w-auto object-contain select-none shrink-0"
            />
            <div className="hidden sm:block">
              <p className="text-xs text-[#78a17d]">
                Windows Desktop Autonomous Agent Powered by Google Gemini Vision API
              </p>
            </div>
          </div>

          {/* Single clean download button in the header */}
          <div>
            <button
              onClick={handleDownload}
              disabled={downloading}
              className="px-5 py-2.5 bg-[#79ee87] hover:bg-[#a6ffae] text-[#071009] font-black text-xs uppercase tracking-wider flex items-center gap-2 shadow-[4px_4px_0_#102817] transition-all hover:translate-x-0.5 hover:translate-y-0.5 active:translate-x-1 active:translate-y-1 disabled:opacity-50"
            >
              {downloading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Download className="w-4 h-4" />}
              <span>{downloading ? 'Downloading...' : 'Download ZIP Package'}</span>
            </button>
          </div>
        </div>
      </header>

      {/* Main Container */}
      <main className="max-w-7xl mx-auto px-4 md:px-8 py-8 space-y-8">
        {downloadSuccess && (
          <div className="p-3 bg-[#08170c] border-2 border-[#79ee87] text-[#a6ffae] text-xs flex items-center justify-between gap-2 rounded">
            <div className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-[#79ee87] shrink-0" />
              <span>{downloadSuccess}</span>
            </div>
            <button
              onClick={() => setDownloadSuccess(null)}
              className="text-[#78a17d] hover:text-[#a6ffae] text-xs"
            >
              ✕
            </button>
          </div>
        )}

        {/* Hero Section */}
        <section className="border-2 border-[#285430] bg-[#071009] p-6 md:p-8 rounded-lg relative overflow-hidden">
          <div className="absolute -top-10 -right-10 w-64 h-64 bg-[#79ee87]/5 rounded-full blur-3xl pointer-events-none" />
          
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
            <div className="lg:col-span-7 space-y-4">
              <div className="inline-flex items-center gap-2 px-3 py-1 border border-[#285430] bg-[#040a05] text-[#76c9a1] text-xs">
                <Zap className="w-3.5 h-3.5 text-[#79ee87]" />
                <span>Multimodal Vision &amp; Real Hardware Mouse Targeting</span>
              </div>

              <h1 className="text-2xl md:text-3xl font-extrabold text-[#a6ffae] leading-tight">
                Autonomous Windows Automation with Google Gemini Vision
              </h1>

              <p className="text-sm text-[#78a17d] leading-relaxed">
                Control your Windows PC using natural language and image prompt attachments. Powered by <span className="text-[#a6ffae] font-bold">gemini-3.5-flash</span> and <span className="text-[#a6ffae] font-bold">gemini-3.8-flash</span> with laser-precise 0–1000 optical screen coordinate mapping, smooth cubic cursor motion, DPAPI encrypted credentials, and instant emergency stop (<code className="text-[#a6ffae]">Ctrl + Fn + E</code>).
              </p>

              <div className="flex flex-wrap items-center gap-4 pt-2">
                {/* Single primary download button */}
                <button
                  onClick={handleDownload}
                  disabled={downloading}
                  className="px-6 py-3 bg-[#79ee87] hover:bg-[#a6ffae] text-[#071009] font-black text-sm uppercase tracking-wider flex items-center gap-2.5 shadow-[4px_4px_0_#102817] transition-all hover:translate-x-0.5 hover:translate-y-0.5 active:translate-x-1 active:translate-y-1 disabled:opacity-50"
                >
                  {downloading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Download className="w-4 h-4" />}
                  <span>Download ZIP Package</span>
                </button>

                <button
                  onClick={() => openFile('run.bat')}
                  className="px-5 py-3 border-2 border-[#79ee87] bg-[#102817] hover:bg-[#163820] text-[#a6ffae] text-sm uppercase tracking-wider font-bold flex items-center gap-2 transition-colors"
                >
                  <FileArchive className="w-4 h-4 text-[#79ee87]" />
                  <span>View All Files ({files.length})</span>
                </button>

                <button
                  onClick={() => setActiveTab('test')}
                  className="px-4 py-3 border border-[#285430] hover:border-[#79ee87] text-[#78a17d] hover:text-[#a6ffae] text-xs uppercase tracking-wider font-mono transition-colors"
                >
                  Test Image Prompt →
                </button>
              </div>

              {/* Quick file jump pills */}
              <div className="pt-2">
                <span className="text-[10px] text-[#78a17d] uppercase tracking-wider block mb-1.5 font-mono">
                  Quick View Package Files:
                </span>
                <div className="flex flex-wrap gap-1.5 font-mono text-xs">
                  {['run.bat', 'web.bat', 'worker.ps1', 'data/memory.json', 'NguyeensCLI.ps1', 'NguyeensAI.ps1', 'web/index.html', 'README.md'].map((fileName) => (
                    <button
                      key={fileName}
                      onClick={() => openFile(fileName)}
                      className="px-2.5 py-1 border border-[#285430] bg-[#020503] hover:border-[#79ee87] hover:bg-[#07150a] text-[#a6ffae] text-[11px] rounded flex items-center gap-1 transition-all"
                    >
                      <FileText className="w-3 h-3 text-[#79ee87]" />
                      <span>{fileName}</span>
                    </button>
                  ))}
                </div>
              </div>

              <div className="text-[11px] text-[#78a17d] flex flex-wrap items-center gap-2 pt-1 font-mono">
                <span className="text-[#79ee87]">✓ Verified ZIP package (~39 KB)</span>
                <span>• All {files.length} scripts &amp; tools inside (run.bat, web.bat, worker.ps1, data/memory.json, etc.)</span>
                <span>•</span>
                <button
                  type="button"
                  onClick={handleDownload}
                  disabled={downloading}
                  className="text-[#a6ffae] underline underline-offset-2 hover:text-[#79ee87] cursor-pointer"
                >
                  Download complete package ({files.length} files)
                </button>
              </div>
            </div>

            {/* Quick Specs Bento */}
            <div className="lg:col-span-5 grid grid-cols-2 gap-3 font-mono text-xs">
              <div className="p-3.5 bg-[#030704] border border-[#285430] space-y-1">
                <span className="text-[#78a17d] block text-[10px] uppercase">Reading Priority</span>
                <span className="font-bold text-[#a6ffae] flex items-center gap-1.5 text-[11px]">
                  <Zap className="w-3.5 h-3.5 text-[#79ee87]" />
                  Memory-First (Top Priority)
                </span>
              </div>

              <div className="p-3.5 bg-[#030704] border border-[#285430] space-y-1">
                <span className="text-[#78a17d] block text-[10px] uppercase">Keyboard Output</span>
                <span className="font-bold text-[#a6ffae] flex items-center gap-1.5">
                  <Cpu className="w-3.5 h-3.5 text-[#79ee87]" />
                  Vietnamese (Unicode)
                </span>
              </div>

              <div className="p-3.5 bg-[#030704] border border-[#285430] space-y-1">
                <span className="text-[#78a17d] block text-[10px] uppercase">Laser Mouse Accuracy</span>
                <span className="font-bold text-[#a6ffae]">DPI Scaled 125%-200%</span>
              </div>

              <div className="p-3.5 bg-[#030704] border border-[#285430] space-y-1">
                <span className="text-[#78a17d] block text-[10px] uppercase">Emergency Stop</span>
                <span className="font-bold text-[#a6ffae]">Ctrl + Fn + E</span>
              </div>
            </div>
          </div>
        </section>

        {/* Gemini API Key Live Verifier Section */}
        <KeyVerifier />

        {/* Tab Navigation */}
        <div className="border-b-2 border-[#285430] flex gap-2 overflow-x-auto pb-0">
          <button
            onClick={() => setActiveTab('files')}
            className={`px-4 py-2.5 text-xs font-bold uppercase tracking-wider flex items-center gap-2 border-t-2 border-x-2 transition-all ${
              activeTab === 'files'
                ? 'bg-[#071009] border-[#79ee87] text-[#a6ffae] -mb-[2px] pb-[12px]'
                : 'border-transparent text-[#78a17d] hover:text-[#79ee87]'
            }`}
          >
            <FileArchive className="w-4 h-4 text-[#79ee87]" />
            <span>Source Code Files</span>
            <span className="px-1.5 py-0.5 bg-[#102817] border border-[#285430] text-[#a6ffae] text-[10px] rounded">
              {files.length}
            </span>
          </button>

          <button
            onClick={() => setActiveTab('test')}
            className={`px-4 py-2.5 text-xs font-bold uppercase tracking-wider flex items-center gap-2 border-t-2 border-x-2 transition-all ${
              activeTab === 'test'
                ? 'bg-[#071009] border-[#79ee87] text-[#a6ffae] -mb-[2px] pb-[12px]'
                : 'border-transparent text-[#78a17d] hover:text-[#79ee87]'
            }`}
          >
            <ImageIcon className="w-4 h-4" />
            <span>Image Prompt &amp; Simulation</span>
          </button>

          <button
            onClick={() => setActiveTab('guide')}
            className={`px-4 py-2.5 text-xs font-bold uppercase tracking-wider flex items-center gap-2 border-t-2 border-x-2 transition-all ${
              activeTab === 'guide'
                ? 'bg-[#071009] border-[#79ee87] text-[#a6ffae] -mb-[2px] pb-[12px]'
                : 'border-transparent text-[#78a17d] hover:text-[#79ee87]'
            }`}
          >
            <Terminal className="w-4 h-4" />
            <span>Setup &amp; Usage Guide</span>
          </button>

          <button
            onClick={() => setActiveTab('compare')}
            className={`px-4 py-2.5 text-xs font-bold uppercase tracking-wider flex items-center gap-2 border-t-2 border-x-2 transition-all ${
              activeTab === 'compare'
                ? 'bg-[#071009] border-[#79ee87] text-[#a6ffae] -mb-[2px] pb-[12px]'
                : 'border-transparent text-[#78a17d] hover:text-[#79ee87]'
            }`}
          >
            <Flame className="w-4 h-4" />
            <span>OpenAI vs Gemini Architecture</span>
          </button>
        </div>

        {/* Tab Contents */}
        {activeTab === 'files' && (
          <div>
            {loading && files.length === 0 ? (
              <div className="p-12 border-2 border-[#285430] bg-[#071009] rounded-lg text-center font-mono">
                <Loader2 className="w-6 h-6 animate-spin text-[#79ee87] mx-auto mb-2" />
                <span className="text-xs text-[#a6ffae]">Loading package files from server...</span>
              </div>
            ) : (
              <FileViewer
                files={files}
                selectedFilePath={selectedFilePath}
                onSelectFile={(path) => setSelectedFilePath(path)}
                onDownloadZip={handleDownload}
              />
            )}
          </div>
        )}

        {activeTab === 'test' && (
          <InteractiveTest />
        )}

        {activeTab === 'guide' && (
          <div className="border-2 border-[#285430] bg-[#071009] p-6 rounded-lg space-y-6">
            <h3 className="text-lg font-bold text-[#a6ffae]">
              4-Step Windows Quick Start Guide
            </h3>

            <div className="grid grid-cols-1 md:grid-cols-4 gap-4 text-xs font-mono">
              <div className="p-4 bg-[#030704] border border-[#285430] space-y-2">
                <div className="w-7 h-7 border border-[#79ee87] text-[#a6ffae] flex items-center justify-center font-bold">
                  1
                </div>
                <h4 className="font-bold text-[#a6ffae]">Extract ZIP</h4>
                <p className="text-[#78a17d]">
                  Click the single "Download ZIP Package" button and extract <code className="text-[#79ee87]">NguyeensAI-Gemini.zip</code> to any folder on your computer.
                </p>
              </div>

              <div className="p-4 bg-[#030704] border border-[#285430] space-y-2">
                <div className="w-7 h-7 border border-[#79ee87] text-[#a6ffae] flex items-center justify-center font-bold">
                  2
                </div>
                <h4 className="font-bold text-[#a6ffae]">Launch CLI or Web</h4>
                <p className="text-[#78a17d]">
                  • <strong>Command Prompt (Recommended):</strong> Double-click <code className="text-[#79ee87]">run.bat</code>.<br />
                  • <strong>Local Web GUI:</strong> Double-click <code className="text-[#79ee87]">web.bat</code> (runs at http://127.0.0.1:8765).
                </p>
              </div>

              <div className="p-4 bg-[#030704] border border-[#285430] space-y-2">
                <div className="w-7 h-7 border border-[#79ee87] text-[#a6ffae] flex items-center justify-center font-bold">
                  3
                </div>
                <h4 className="font-bold text-[#a6ffae]">Gemini API Key</h4>
                <p className="text-[#78a17d]">
                  Paste your <code className="text-[#79ee87]">AIzaSy...</code> key from Google AI Studio. It is securely encrypted using Windows DPAPI.
                </p>
              </div>

              <div className="p-4 bg-[#030704] border border-[#285430] space-y-2">
                <div className="w-7 h-7 border border-[#79ee87] text-[#a6ffae] flex items-center justify-center font-bold">
                  4
                </div>
                <h4 className="font-bold text-[#a6ffae]">Execute Tasks</h4>
                <p className="text-[#78a17d]">
                  Type your task directly in Command Prompt (or attach images when using the Web GUI). Press <strong>ENTER</strong>. Gemini analyzes your screen and glides the physical mouse directly to the targets.
                </p>
              </div>
            </div>

            <div className="p-4 bg-[#040a05] border border-[#285430] text-xs text-[#78a17d] space-y-1">
              <span className="font-bold text-[#a6ffae] block">Safety Protocols:</span>
              <p>• The agent halts automatically before sensitive interactions (passwords, payment cards, file deletions).</p>
              <p>• Text is typed directly via native Windows virtual key input without touching the system clipboard.</p>
              <p>• Press <code className="text-[#a6ffae]">Ctrl + Fn + E</code> anytime or move cursor to (0, 0) to trigger immediate emergency halt in 30ms.</p>
            </div>
          </div>
        )}

        {activeTab === 'compare' && (
          <div className="border-2 border-[#285430] bg-[#071009] p-6 rounded-lg space-y-6">
            <h3 className="text-lg font-bold text-[#a6ffae]">
              Architectural Enhancements: Legacy OpenAI vs Google Gemini Edition
            </h3>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs font-mono">
              {/* Legacy column */}
              <div className="p-4 bg-[#140807] border border-[#ff766d]/40 rounded space-y-3">
                <div className="flex items-center gap-2 text-[#ff766d] font-bold text-sm">
                  <AlertTriangle className="w-4 h-4" />
                  <span>Legacy Model (OpenAI API)</span>
                </div>
                <ul className="space-y-2 text-[#e3a09b]">
                  <li>• Required OpenAI proprietary keys (<code className="text-[#ff766d]">sk-...</code>).</li>
                  <li>• Endpoint: <code className="text-[#ff766d]">api.openai.com/v1/responses</code></li>
                  <li>• Restricted to limited beta models with strict rate limits.</li>
                  <li>• No direct in-browser API key validation tester.</li>
                  <li>• Lacked unified 0-1000 optical coordinate scaling.</li>
                </ul>
              </div>

              {/* Gemini column */}
              <div className="p-4 bg-[#08170c] border border-[#79ee87] rounded space-y-3">
                <div className="flex items-center gap-2 text-[#a6ffae] font-bold text-sm">
                  <CheckCircle2 className="w-4 h-4 text-[#79ee87]" />
                  <span>Modern Architecture (Google Gemini Edition)</span>
                </div>
                <ul className="space-y-2 text-[#a6ffae]">
                  <li>• Free Google AI Studio API key (<code className="text-[#79ee87]">AIzaSy...</code>).</li>
                  <li>• Official REST endpoint: <code className="text-[#79ee87]">generativelanguage.googleapis.com/v1beta</code></li>
                  <li>• Models: <code className="text-[#79ee87]">gemini-3.5-flash</code> &amp; <code className="text-[#79ee87]">gemini-3.8-flash</code> with resilient fallbacks.</li>
                  <li>• Standardized 0–1000 normalized vision grid with DPI-aware physical pixel mapping.</li>
                  <li>• Custom image prompt attachment support for multi-image visual guidance.</li>
                  <li>• Emergency stop trigger (<code className="text-[#79ee87]">Ctrl + Fn + E</code>) responding in under 30ms.</li>
                </ul>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* Footer */}
      <footer className="border-t-2 border-[#285430] bg-[#061008] px-4 md:px-8 py-6 text-xs text-[#78a17d]">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <span>Nguyeen's AI (Gemini Edition)</span>
            <span>•</span>
            <span>Fully Compatible with Google AI Studio</span>
          </div>

          <div className="flex items-center gap-4">
            <a
              href="https://aistudio.google.com/app/apikey"
              target="_blank"
              rel="noreferrer"
              className="text-[#a6ffae] hover:underline flex items-center gap-1"
            >
              <span>Get Gemini API Key</span>
              <ExternalLink className="w-3 h-3" />
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
