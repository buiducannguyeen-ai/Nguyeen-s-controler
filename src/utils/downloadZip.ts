import JSZip from 'jszip';
import { PackageFile } from '../types';
import { DEFAULT_PACKAGE_FILES } from '../data/packageFiles';

/**
 * Generates and triggers download of NguyeensAI-Gemini.zip directly in browser memory.
 * - 100% Client-side: Never makes network requests that can 404 on static hosts like Vercel.
 * - Windows DOS/FAT format: Avoids extraction errors in Windows Compressed Folders wizard.
 * - Always includes all 13 verified scripts, subdirectories, and tools.
 */
export async function generateAndDownloadZip(files?: PackageFile[]): Promise<{ fileName: string; sizeKb: number; fileCount: number }> {
  const targetFiles = (files && files.length > 0) ? files : DEFAULT_PACKAGE_FILES;
  
  const zip = new JSZip();

  // Create explicit directories for Windows Explorer
  zip.folder('data');
  zip.folder('web');

  for (const file of targetFiles) {
    // Normalize path to use forward slashes (standard zip specification)
    const normalizedPath = file.path.replace(/\\/g, '/');
    zip.file(normalizedPath, file.content, {
      date: new Date('2026-03-25T12:00:00Z'),
      createFolders: true,
    });
  }

  // Generate ZIP using DOS platform for flawless Windows Explorer native extraction
  const blob = await zip.generateAsync({
    type: 'blob',
    compression: 'DEFLATE',
    compressionOptions: { level: 6 },
    platform: 'DOS',
  });

  const fileName = 'NguyeensAI-Gemini.zip';
  const url = window.URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = fileName;
  document.body.appendChild(anchor);
  anchor.click();
  document.body.removeChild(anchor);

  // Keep blob URL active for 60 seconds so browser download manager finishes writing to disk
  setTimeout(() => {
    window.URL.revokeObjectURL(url);
  }, 60000);

  return {
    fileName,
    sizeKb: Math.round((blob.size / 1024) * 10) / 10,
    fileCount: targetFiles.length,
  };
}
