import JSZip from 'jszip';
import { PackageFile } from '../types';
import { DEFAULT_PACKAGE_FILES } from '../data/packageFiles';
import { PRECOMPILED_ZIP_BASE64 } from '../data/precompiledZip';

/**
 * Converts a base64 string to a binary Blob
 */
function base64ToBlob(base64: string, mimeType: string = 'application/zip'): Blob {
  const binaryString = window.atob(base64);
  const len = binaryString.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return new Blob([bytes], { type: mimeType });
}

function triggerDownload(blob: Blob, fileName: string) {
  const url = window.URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = fileName;
  document.body.appendChild(anchor);
  anchor.click();
  document.body.removeChild(anchor);

  setTimeout(() => {
    window.URL.revokeObjectURL(url);
  }, 60000);
}

/**
 * Downloads the Windows-compatible ZIP package
 * - Prioritizes fresh server generation (/api/download-zip)
 * - In-browser DOS-compatible JSZip generation fallback
 * - 100% offline static precompiled ZIP fallback
 */
export async function generateAndDownloadZip(files?: PackageFile[]): Promise<{ fileName: string; sizeKb: number; fileCount: number }> {
  const fileName = 'NguyeensAI-Gemini.zip';
  const targetFiles = (files && files.length > 0) ? files : DEFAULT_PACKAGE_FILES;

  // 1. Try server download endpoint first (always has exact disk files)
  try {
    const serverResp = await fetch('/api/download-zip');
    if (serverResp.ok) {
      const blob = await serverResp.blob();
      if (blob.size > 1000) {
        triggerDownload(blob, fileName);
        return {
          fileName,
          sizeKb: Math.round((blob.size / 1024) * 10) / 10,
          fileCount: targetFiles.length,
        };
      }
    }
  } catch (err) {
    console.info('Server zip download skipped, using client generation:', err);
  }

  // 2. Client-side JSZip generation (works offline and on static hosts)
  try {
    const zip = new JSZip();

    for (const file of targetFiles) {
      const normalizedPath = file.path.replace(/\\/g, '/');
      zip.file(normalizedPath, file.content, {
        date: new Date('2026-03-25T12:00:00Z'),
      });
    }

    const blob = await zip.generateAsync({
      type: 'blob',
      mimeType: 'application/zip',
      compression: 'DEFLATE',
      compressionOptions: { level: 9 },
      platform: 'DOS',
    });

    triggerDownload(blob, fileName);

    return {
      fileName,
      sizeKb: Math.round((blob.size / 1024) * 10) / 10,
      fileCount: targetFiles.length,
    };
  } catch (err) {
    console.warn('JSZip generation fallback to precompiled binary:', err);
  }

  // 3. Ultra-resilient offline pre-compiled fallback
  const fallbackBlob = base64ToBlob(PRECOMPILED_ZIP_BASE64, 'application/zip');
  triggerDownload(fallbackBlob, fileName);

  return {
    fileName,
    sizeKb: Math.round((fallbackBlob.size / 1024) * 10) / 10,
    fileCount: targetFiles.length,
  };
}
