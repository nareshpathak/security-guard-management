"use client";

import React, { useState, useRef } from "react";
import { Upload, X, FileText, Image as ImageIcon, CheckCircle2, AlertCircle } from "lucide-react";

export interface FileItem {
  id: string;
  file: File;
  previewUrl?: string;
  progress: number;
  status: "idle" | "uploading" | "success" | "error";
  errorMessage?: string;
  url?: string;
}

interface FileUploadProps {
  accept?: string;
  multiple?: boolean;
  maxSizeMb?: number;
  onUpload?: (files: FileItem[]) => Promise<void> | void;
  onChange?: (files: File[]) => void;
  label?: string;
  description?: string;
}

export function FileUpload({
  accept = "image/*,.pdf,.doc,.docx,.xls,.xlsx",
  multiple = true,
  onUpload,
  onChange,
  label = "Upload files or drag and drop",
  description = "PNG, JPG, PDF, DOCX up to 10MB",
}: FileUploadProps) {
  const [files, setFiles] = useState<FileItem[]>([]);
  const [isDragging, setIsDragging] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleFiles = (selectedFiles: FileList | File[]) => {
    const newItems: FileItem[] = Array.from(selectedFiles).map((file) => {
      const isImage = file.type.startsWith("image/");
      return {
        id: `${file.name}-${Date.now()}-${Math.random().toString(36).substring(2, 7)}`,
        file,
        previewUrl: isImage ? URL.createObjectURL(file) : undefined,
        progress: 0,
        status: "idle",
      };
    });

    const updated = multiple ? [...files, ...newItems] : newItems;
    setFiles(updated);
    if (onChange) onChange(updated.map((f) => f.file));

    if (onUpload) {
      onUpload(newItems);
    }
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      handleFiles(e.dataTransfer.files);
    }
  };

  const removeFile = (id: string) => {
    const updated = files.filter((f) => f.id !== id);
    setFiles(updated);
    if (onChange) onChange(updated.map((f) => f.file));
  };

  const formatSize = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  return (
    <div className="space-y-4">
      <div
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onClick={() => inputRef.current?.click()}
        className={`group relative flex cursor-pointer flex-col items-center justify-center rounded-xl border-2 border-dashed p-6 text-center transition-all ${
          isDragging
            ? "border-[var(--diti-primary)] bg-[var(--diti-primary-subtle)]"
            : "border-[var(--diti-border)] bg-[var(--diti-surface)] hover:border-[var(--diti-border-strong)] hover:bg-[var(--diti-surface-sunken)]"
        }`}
      >
        <input
          ref={inputRef}
          type="file"
          accept={accept}
          multiple={multiple}
          onChange={(e) => e.target.files && handleFiles(e.target.files)}
          className="hidden"
        />

        <div className="mb-3 flex size-12 items-center justify-center rounded-full bg-[var(--diti-primary-subtle)] text-[var(--diti-primary)] transition-transform group-hover:scale-110">
          <Upload className="size-6" />
        </div>

        <p className="text-sm font-semibold text-[var(--diti-text)]">{label}</p>
        <p className="mt-1 text-xs text-[var(--diti-muted)]">{description}</p>
      </div>

      {files.length > 0 && (
        <div className="space-y-2">
          {files.map((item) => (
            <div
              key={item.id}
              className="flex items-center justify-between gap-3 rounded-lg border border-[var(--diti-border)] bg-[var(--diti-surface)] p-3 text-sm"
            >
              <div className="flex items-center gap-3 overflow-hidden">
                {item.previewUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={item.previewUrl}
                    alt={item.file.name}
                    className="size-10 rounded-md object-cover"
                  />
                ) : (
                  <div className="flex size-10 items-center justify-center rounded-md bg-[var(--diti-surface-sunken)] text-[var(--diti-muted)]">
                    {item.file.type.startsWith("image/") ? (
                      <ImageIcon className="size-5" />
                    ) : (
                      <FileText className="size-5" />
                    )}
                  </div>
                )}
                <div className="min-w-0">
                  <p className="truncate font-medium text-[var(--diti-text)]">{item.file.name}</p>
                  <p className="text-xs text-[var(--diti-muted)]">{formatSize(item.file.size)}</p>
                </div>
              </div>

              <div className="flex items-center gap-2">
                {item.status === "success" && (
                  <CheckCircle2 className="size-5 text-[var(--diti-success)]" />
                )}
                {item.status === "error" && (
                  <AlertCircle className="size-5 text-[var(--diti-danger)]" />
                )}
                <button
                  type="button"
                  onClick={(e) => {
                    e.stopPropagation();
                    removeFile(item.id);
                  }}
                  className="rounded-md p-1 text-[var(--diti-muted)] hover:bg-[var(--diti-surface-sunken)] hover:text-[var(--diti-text)]"
                >
                  <X className="size-4" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
