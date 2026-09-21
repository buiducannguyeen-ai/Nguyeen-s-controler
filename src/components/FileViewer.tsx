import React, { useState } from 'react';
import { FileCode, Copy, Check, Info, FileText, Download } from 'lucide-react';
import { PackageFile } from '../types';

interface FileViewerProps {
  files: PackageFile[];
}

export const FileViewer: React.FC<FileViewerProps> = ({ files }) => {
  const [selectedPath, setSelectedPath] = useState<string>(files[0]?.path || '');
  const [copied, setCopied] = useState(false);

  const currentFile = files.find((f) => f.path === selectedPath) || files[0];

  const handleCopy = () => {
    if (!currentFile) return;
    navigator.clipboard.writeText(currentFile.content);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="border-2 border-[#285430] bg-[#071009] rounded-lg overflow-hidden flex flex-col h-full shadow-lg">
      <div className="bg-[#0b170e] border-b-2 border-[#285430] px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <FileCode className="w-5 h-5 text-[#79ee87]" />
          <h3 className="font-bold text-[#a6ffae] text-sm tracking-wide uppercase">
            Package Files Optimized for Gemini Vision API
          </h3>
        </div>
        <span className="text-xs text-[#78a17d] font-mono">
          {files.length} files in ZIP package
        </span>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-12 flex-1 min-h-[480px]">
        {/* Sidebar list */}
        <div className="md:col-span-4 border-b-2 md:border-b-0 md:border-r-2 border-[#285430] bg-[#040a05] p-2 space-y-1 overflow-y-auto max-h-[500px]">
          {files.map((file) => {
            const isSelected = file.path === selectedPath;
            return (
              <button
                key={file.path}
                onClick={() => setSelectedPath(file.path)}
                className={`w-full text-left px-3 py-2.5 rounded transition-all text-xs font-mono flex items-center justify-between gap-2 ${
                  isSelected
                    ? 'bg-[#102817] text-[#a6ffae] border border-[#79ee87] font-bold'
                    : 'text-[#78a17d] hover:bg-[#071009] hover:text-[#79ee87]'
                }`}
              >
                <div className="flex items-center gap-2 truncate">
                  <FileText className="w-3.5 h-3.5 shrink-0 opacity-70" />
                  <span className="truncate">{file.path}</span>
                </div>
                <span className="text-[10px] opacity-60 shrink-0">
                  {Math.round(file.size / 102) / 10} KB
                </span>
              </button>
            );
          })}
        </div>

        {/* Content viewer */}
        <div className="md:col-span-8 flex flex-col bg-[#020503] min-w-0">
          {currentFile && (
            <>
              {/* File details bar */}
              <div className="p-3 border-b border-[#1b3b22] bg-[#050e07] flex flex-wrap items-center justify-between gap-2 text-xs">
                <div className="space-y-1">
                  <div className="font-mono text-[#a6ffae] font-bold flex items-center gap-2">
                    <span>{currentFile.path}</span>
                    <span className="px-1.5 py-0.5 border border-[#285430] text-[10px] uppercase text-[#78a17d]">
                      {currentFile.language}
                    </span>
                  </div>
                  <p className="text-[11px] text-[#78a17d] flex items-center gap-1.5">
                    <Info className="w-3.5 h-3.5 text-[#79ee87] shrink-0" />
                    <span>{currentFile.changes}</span>
                  </p>
                </div>

                <div className="flex items-center gap-2">
                  <button
                    onClick={() => {
                      if (!currentFile) return;
                      const blob = new Blob([currentFile.content], { type: 'text/plain;charset=utf-8' });
                      const url = URL.createObjectURL(blob);
                      const a = document.createElement('a');
                      a.href = url;
                      a.download = currentFile.name;
                      document.body.appendChild(a);
                      a.click();
                      URL.revokeObjectURL(url);
                      document.body.removeChild(a);
                    }}
                    className="px-3 py-1.5 border border-[#285430] text-[#76c9a1] hover:border-[#79ee87] hover:text-[#a6ffae] text-xs font-mono flex items-center gap-1.5 transition-colors"
                    title={`Download ${currentFile.name} individually`}
                  >
                    <Download className="w-3.5 h-3.5" />
                    <span>Save file</span>
                  </button>

                  <button
                    onClick={handleCopy}
                    className="px-3 py-1.5 border border-[#79ee87] text-[#79ee87] hover:bg-[#79ee87] hover:text-[#071009] text-xs font-mono flex items-center gap-1.5 transition-colors font-bold"
                  >
                    {copied ? (
                      <>
                        <Check className="w-3.5 h-3.5" />
                        <span>Copied!</span>
                      </>
                    ) : (
                      <>
                        <Copy className="w-3.5 h-3.5" />
                        <span>Copy Code</span>
                      </>
                    )}
                  </button>
                </div>
              </div>

              {/* Code display */}
              <div className="flex-1 p-4 overflow-auto max-h-[460px] bg-[#010302]">
                <pre className="text-xs font-mono text-[#79ee87] leading-relaxed select-all whitespace-pre">
                  <code>{currentFile.content}</code>
                </pre>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
};
