import React, { useState, useRef } from 'react';
import { Terminal, Play, Loader2, Monitor, Image as ImageIcon, X, Upload } from 'lucide-react';

export const InteractiveTest: React.FC = () => {
  const [prompt, setPrompt] = useState('Open Notepad and write a short poem about autumn in Seattle.');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<string | null>(null);
  const [imageBase64, setImageBase64] = useState<string | null>(null);
  const [imageName, setImageName] = useState<string | null>(null);
  const [imageMime, setImageMime] = useState<string>('image/jpeg');
  const fileInputRef = useRef<HTMLInputElement>(null);

  const samplePrompts = [
    'Open Notepad and type a welcoming note for Nguyeen\'s AI Gemini.',
    'Open Microsoft Edge and search for today\'s weather forecast.',
    'Look at the attached image and click on the primary blue action button.',
    'Open File Explorer, navigate to Downloads, and count existing files.',
  ];

  const handleImageUpload = (file: File) => {
    if (!file.type.startsWith('image/')) {
      alert('Please select an image file (PNG, JPG, WebP).');
      return;
    }
    setImageName(file.name);
    setImageMime(file.type);
    const reader = new FileReader();
    reader.onload = (e) => {
      const b64 = e.target?.result as string;
      setImageBase64(b64);
    };
    reader.readAsDataURL(file);
  };

  const handleRemoveImage = () => {
    setImageBase64(null);
    setImageName(null);
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const handleRunSimulation = async () => {
    if (!prompt.trim()) return;
    setLoading(true);
    setResult(null);

    try {
      const res = await fetch('/api/test-gemini-vision', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          prompt: prompt.trim(),
          imageBase64: imageBase64 || undefined,
          imageMime: imageMime || undefined,
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.error || 'Error occurred while executing Gemini vision simulation');
      }
      setResult(data.result);
    } catch (err: any) {
      setResult('Connection Error: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="border-2 border-[#285430] bg-[#071009] p-6 rounded-lg shadow-lg">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 border border-[#79ee87] bg-[#030704] flex items-center justify-center text-[#79ee87]">
            <Monitor className="w-5 h-5" />
          </div>
          <div>
            <h3 className="text-base font-bold text-[#a6ffae] tracking-tight">
              Interactive Gemini Vision Action Simulator
            </h3>
            <p className="text-xs text-[#78a17d]">
              Test task planning and image visual reasoning with Gemini 3.8 / 3.5 Flash Vision
            </p>
          </div>
        </div>
      </div>

      <div className="space-y-4">
        <div>
          <label className="block text-xs font-mono uppercase text-[#78a17d] mb-1.5">
            Command Prompt &amp; Image Attachment
          </label>
          <div className="flex flex-col sm:flex-row gap-2">
            <input
              type="text"
              value={prompt}
              onChange={(e) => setPrompt(e.target.value)}
              placeholder="Enter task description for Gemini (e.g., Click the Send button in the image)..."
              className="flex-1 bg-[#020503] border-2 border-[#285430] text-[#79ee87] px-3.5 py-2 text-sm font-mono focus:border-[#79ee87] focus:outline-none placeholder-[#37523b]"
            />
            
            <input
              type="file"
              ref={fileInputRef}
              accept="image/*"
              className="hidden"
              onChange={(e) => {
                if (e.target.files?.[0]) handleImageUpload(e.target.files[0]);
              }}
            />

            <button
              type="button"
              onClick={() => fileInputRef.current?.click()}
              className="px-3.5 py-2 border border-[#285430] hover:border-[#79ee87] text-[#a6ffae] font-bold text-xs uppercase flex items-center justify-center gap-1.5 transition-colors shrink-0"
              title="Attach an image screenshot or reference image"
            >
              <ImageIcon className="w-4 h-4 text-[#79ee87]" />
              <span>{imageBase64 ? 'Change Image' : 'Attach Image'}</span>
            </button>

            <button
              onClick={handleRunSimulation}
              disabled={loading}
              className="px-5 py-2 bg-[#79ee87] hover:bg-[#a6ffae] text-[#071009] font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors shrink-0"
            >
              {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Play className="w-4 h-4" />}
              <span>Simulate</span>
            </button>
          </div>
        </div>

        {/* Attached image preview pill */}
        {imageBase64 && (
          <div className="flex items-center gap-3 p-2 bg-[#040c06] border border-[#79ee87] rounded text-xs font-mono">
            <img
              src={imageBase64}
              alt="Attached preview"
              className="w-12 h-12 object-cover border border-[#285430] rounded"
            />
            <div className="flex-1 min-w-0">
              <span className="font-bold text-[#a6ffae] block truncate">{imageName || 'Attached Image'}</span>
              <span className="text-[10px] text-[#78a17d]">
                Image attached to prompt • Gemini will analyze visual coordinates and layout
              </span>
            </div>
            <button
              onClick={handleRemoveImage}
              className="p-1.5 hover:bg-[#ff766d]/20 text-[#ff766d] border border-transparent hover:border-[#ff766d] rounded transition-colors"
              title="Remove attached image"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        )}

        <div className="flex flex-wrap items-center gap-1.5">
          <span className="text-[11px] text-[#78a17d] self-center mr-1">Quick examples:</span>
          {samplePrompts.map((p, idx) => (
            <button
              key={idx}
              onClick={() => setPrompt(p)}
              className="text-[11px] font-mono px-2 py-1 bg-[#040a05] border border-[#285430] text-[#78a17d] hover:text-[#a6ffae] hover:border-[#79ee87] transition-colors text-left"
            >
              {p.slice(0, 36)}...
            </button>
          ))}
        </div>

        {result && (
          <div className="mt-4 p-4 border border-[#285430] bg-[#020503] rounded">
            <div className="flex items-center gap-2 text-xs font-mono text-[#a6ffae] mb-2">
              <Terminal className="w-4 h-4 text-[#79ee87]" />
              <span className="font-bold">Gemini Vision Action Plan:</span>
            </div>
            <div className="text-xs font-mono text-[#79ee87] leading-relaxed whitespace-pre-wrap">
              {result}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
