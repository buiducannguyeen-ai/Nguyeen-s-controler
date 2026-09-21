import React, { useState, useEffect } from 'react';
import { FileCode, Copy, Check, Info, FileText, Download, Search, CheckCircle } from 'lucide-react';
import { PackageFile } from '../types';
import { DEFAULT_PACKAGE_FILES } from '../data/packageFiles';

interface FileViewerProps {
  files: PackageFile[];
  selectedFilePath?: string;
  onSelectFile?: (path: string) => void;
  onDownloadZip?: () => void;
}

export const FileViewer: React.FC<FileViewerProps> = ({
  files,
  selectedFilePath,
  onSelectFile,
  onDownloadZip,
}) => {
  const effectiveFiles = (files && files.length > 0) ? files : DEFAULT_PACKAGE_FILES;
  const [selectedPath, setSelectedPath] = useState<string>(selectedFilePath || effectiveFiles[0]?.path || '');
  const [copied, setCopied] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  // Synchronize when files change or parent requests a specific file
  useEffect(() => {
    if (selectedFilePath && effectiveFiles.some((f) => f.path === selectedFilePath)) {
      setSelectedPath(selectedFilePath);
    } else if (effectiveFiles.length > 0 && (!selectedPath || !effectiveFiles.some((f) => f.path === selectedPath))) {
      setSelectedPath(effectiveFiles[0].path);
    }
  }, [effectiveFiles, selectedFilePath, selectedPath]);

  const handleSelect = (path: string) => {
    setSelectedPath(path);
    if (onSelectFile) onSelectFile(path);
  };

  const filteredFiles = effectiveFiles.filter(
    (f) =>
      f.path.toLowerCase().includes(searchQuery.toLowerCase()) ||
      f.name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const currentFile = effectiveFiles.find((f) => f.path === selectedPath) || effectiveFiles[0];

  const handleCopy = () => {
    if (!currentFile) return;
    navigator.clipboard.writeText(currentFile.content);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownloadFile = () => {
    if (!currentFile) return;
    const blob = new Blob([currentFile.content], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = currentFile.name;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(() => URL.revokeObjectURL(url), 60000);
  };

  return (
    <div id="file-viewer-section" className="border-2 border-[#285430] bg-[#071009] rounded-lg overflow-hidden flex flex-col h-full shadow-lg">
      <div className="bg-[#0b170e] border-b-2 border-[#285430] px-4 py-3 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <FileCode className="w-5 h-5 text-[#79ee87]" />
          <div>
            <h3 className="font-bold text-[#a6ffae] text-sm tracking-wide uppercase">
              Package Source Code Files ({effectiveFiles.length} Total)
            </h3>
            <p className="text-[11px] text-[#78a17d]">
              Full verified scripts &amp; tools ready for Windows automation
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          {onDownloadZip && (
            <button
              onClick={onDownloadZip}
              className="px-3 py-1.5 bg-[#79ee87] hover:bg-[#a6ffae] text-[#071009] font-black text-xs uppercase tracking-wider flex items-center gap-1.5 shadow-[2px_2px_0_#102817] transition-all"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Download Full ZIP</span>
            </button>
          )}
        </div>
      </div>

      {/* Search and filter bar */}
      <div className="p-2.5 bg-[#040b05] border-b border-[#285430] flex items-center justify-between gap-2">
        <div className="relative flex-1 max-w-sm">
          <Search className="w-3.5 h-3.5 text-[#78a17d] absolute left-2.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search files (e.g. run.bat, worker.ps1)..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-[#020503] border border-[#285430] pl-8 pr-3 py-1.5 text-xs text-[#a6ffae] placeholder-[#527257] outline-none focus:border-[#79ee87]"
          />
        </div>
        <div className="text-[11px] text-[#78a17d] font-mono hidden sm:block">
          Showing {filteredFiles.length} of {effectiveFiles.length} files
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-12 flex-1 min-h-[520px]">
        {/* Sidebar list */}
        <div className="md:col-span-4 border-b-2 md:border-b-0 md:border-r-2 border-[#285430] bg-[#040a05] p-2 space-y-1 overflow-y-auto max-h-[540px]">
          {filteredFiles.length === 0 ? (
            <div className="p-4 text-center text-xs text-[#78a17d]">
              No files match "{searchQuery}"
            </div>
          ) : (
            filteredFiles.map((file) => {
              const isSelected = file.path === selectedPath;
              return (
                <button
                  key={file.path}
                  onClick={() => handleSelect(file.path)}
                  className={`w-full text-left px-3 py-2.5 rounded transition-all text-xs font-mono flex items-center justify-between gap-2 ${
                    isSelected
                      ? 'bg-[#102817] text-[#a6ffae] border border-[#79ee87] font-bold shadow-[inset_2px_0_0_#79ee87]'
                      : 'text-[#78a17d] hover:bg-[#071009] hover:text-[#79ee87]'
                  }`}
                >
                  <div className="flex items-center gap-2 truncate">
                    <FileText className={`w-3.5 h-3.5 shrink-0 ${isSelected ? 'text-[#79ee87]' : 'opacity-70'}`} />
                    <span className="truncate">{file.path}</span>
                  </div>
                  <span className="text-[10px] opacity-60 shrink-0">
                    {Math.round((file.size / 1024) * 10) / 10} KB
                  </span>
                </button>
              );
            })
          )}
        </div>

        {/* Content viewer */}
        <div className="md:col-span-8 flex flex-col bg-[#020503] min-w-0">
          {currentFile ? (
            <>
              {/* File details bar */}
              <div className="p-3 border-b border-[#1b3b22] bg-[#050e07] flex flex-wrap items-center justify-between gap-2 text-xs">
                <div className="space-y-1">
                  <div className="font-mono text-[#a6ffae] font-bold flex items-center gap-2">
                    <span className="text-sm">{currentFile.path}</span>
                    <span className="px-1.5 py-0.5 border border-[#285430] text-[10px] uppercase text-[#78a17d]">
                      {currentFile.language}
                    </span>
                    <span className="text-[11px] text-[#78a17d]">
                      ({currentFile.size} bytes)
                    </span>
                  </div>
                  <p className="text-[11px] text-[#78a17d] flex items-center gap-1.5">
                    <Info className="w-3.5 h-3.5 text-[#79ee87] shrink-0" />
                    <span>{currentFile.changes}</span>
                  </p>
                </div>

                <div className="flex items-center gap-2">
                  <button
                    onClick={handleDownloadFile}
                    className="px-3 py-1.5 border border-[#285430] text-[#76c9a1] hover:border-[#79ee87] hover:text-[#a6ffae] text-xs font-mono flex items-center gap-1.5 transition-colors"
                    title={`Download ${currentFile.name} individually`}
                  >
                    <Download className="w-3.5 h-3.5" />
                    <span>Download file</span>
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
              <div className="flex-1 p-4 overflow-auto max-h-[500px] bg-[#010302]">
                <pre className="text-xs font-mono text-[#79ee87] leading-relaxed select-all whitespace-pre">
                  <code>{currentFile.content}</code>
                </pre>
              </div>
            </>
          ) : (
            <div className="p-8 text-center text-sm text-[#78a17d]">
              Select a file on the left to inspect its contents.
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
