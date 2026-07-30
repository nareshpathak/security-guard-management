"use client";

import React, { useState } from "react";
import { MapPin, Navigation, Compass, ZoomIn, ZoomOut } from "lucide-react";
import { Button, Card } from "@diti365/ui";

export interface MapMarker {
  id: string | number;
  title: string;
  subtitle?: string;
  lat: number;
  lng: number;
  status?: "active" | "alert" | "warning" | "offline";
  type?: "guard" | "site" | "checkpoint" | "incident";
  details?: Record<string, string>;
}

interface MapViewProps {
  markers?: MapMarker[];
  centerLat?: number;
  centerLng?: number;
  zoom?: number;
  height?: string;
  onMarkerClick?: (marker: MapMarker) => void;
  title?: string;
}

export function MapView({
  markers = [],
  zoom = 14,
  height = "h-[450px]",
  onMarkerClick,
  title = "Live Location Map",
}: MapViewProps) {
  const [selectedMarker, setSelectedMarker] = useState<MapMarker | null>(null);
  const [currentZoom, setCurrentZoom] = useState(zoom);

  const getMarkerColor = (status?: MapMarker["status"]) => {
    switch (status) {
      case "active":
        return "bg-[var(--diti-success)] text-white shadow-emerald-500/50";
      case "alert":
        return "bg-[var(--diti-danger)] text-white animate-pulse shadow-rose-500/50";
      case "warning":
        return "bg-[var(--diti-warning)] text-white shadow-amber-500/50";
      default:
        return "bg-[var(--diti-muted)] text-white shadow-slate-500/50";
    }
  };

  return (
    <Card className="relative overflow-hidden p-0">
      {/* Map Header Overlay */}
      <div className="absolute left-4 top-4 z-10 flex items-center gap-2 rounded-lg border border-[var(--diti-border)] bg-[var(--diti-surface)]/90 px-3 py-1.5 backdrop-blur-md shadow-sm">
        <Compass className="size-4 text-[var(--diti-primary)]" />
        <span className="text-xs font-semibold text-[var(--diti-text)]">{title}</span>
        <span className="rounded-full bg-[var(--diti-primary-subtle)] px-2 py-0.5 text-[10px] font-bold text-[var(--diti-primary)]">
          {markers.length} Pins · Zoom {currentZoom}x
        </span>
      </div>

      {/* Map Controls */}
      <div className="absolute right-4 top-4 z-10 flex flex-col gap-1 rounded-lg border border-[var(--diti-border)] bg-[var(--diti-surface)]/90 p-1 backdrop-blur-md shadow-sm">
        <button
          type="button"
          onClick={() => setCurrentZoom((z) => Math.min(z + 1, 18))}
          className="rounded p-1.5 text-[var(--diti-muted)] hover:bg-[var(--diti-surface-sunken)] hover:text-[var(--diti-text)]"
        >
          <ZoomIn className="size-4" />
        </button>
        <button
          type="button"
          onClick={() => setCurrentZoom((z) => Math.max(z - 1, 6))}
          className="rounded p-1.5 text-[var(--diti-muted)] hover:bg-[var(--diti-surface-sunken)] hover:text-[var(--diti-text)]"
        >
          <ZoomOut className="size-4" />
        </button>
      </div>

      {/* Interactive Vector Grid Canvas */}
      <div className={`relative w-full ${height} bg-[#1e293b] overflow-hidden`}>
        {/* SVG Grid Overlay */}
        <svg className="absolute inset-0 size-full opacity-20" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern id="map-grid" width="40" height="40" patternUnits="userSpaceOnUse">
              <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#94a3b8" strokeWidth="1" />
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#map-grid)" />
        </svg>

        {/* Map Route Connecting Lines */}
        {markers.length > 1 && (
          <svg className="absolute inset-0 size-full">
            <polyline
              points={markers
                .map((_, i) => {
                  const x = 150 + (i % 4) * 200;
                  const y = 100 + Math.floor(i / 4) * 120;
                  return `${x},${y}`;
                })
                .join(" ")}
              fill="none"
              stroke="#0b5fff"
              strokeWidth="2"
              strokeDasharray="6,6"
              className="opacity-60"
            />
          </svg>
        )}

        {/* Pins Render Engine */}
        {markers.map((m, i) => {
          // Spread coordinates across grid container for visual layout
          const leftPercent = 15 + ((i * 25) % 70);
          const topPercent = 20 + ((i * 30) % 60);

          return (
            <div
              key={m.id}
              style={{ left: `${leftPercent}%`, top: `${topPercent}%` }}
              onClick={() => {
                setSelectedMarker(m);
                if (onMarkerClick) onMarkerClick(m);
              }}
              className="group absolute -translate-x-1/2 -translate-y-1/2 cursor-pointer transition-transform hover:scale-125"
            >
              <div
                className={`flex size-8 items-center justify-center rounded-full shadow-lg ${getMarkerColor(
                  m.status,
                )}`}
              >
                <MapPin className="size-4" />
              </div>

              {/* Pin Tooltip */}
              <div className="absolute left-1/2 top-9 z-20 hidden -translate-x-1/2 rounded-md bg-[var(--diti-surface-raised)] px-2.5 py-1 text-xs shadow-md group-hover:block whitespace-nowrap border border-[var(--diti-border)]">
                <p className="font-semibold text-[var(--diti-text)]">{m.title}</p>
                {m.subtitle && <p className="text-[10px] text-[var(--diti-muted)]">{m.subtitle}</p>}
              </div>
            </div>
          );
        })}

        {markers.length === 0 && (
          <div className="flex h-full flex-col items-center justify-center text-slate-400">
            <Navigation className="mb-2 size-8 animate-bounce" />
            <p className="text-sm font-medium">No map coordinates active</p>
          </div>
        )}
      </div>

      {/* Selected Marker Detail Card */}
      {selectedMarker && (
        <div className="border-t border-[var(--diti-border)] bg-[var(--diti-surface)] p-4">
          <div className="flex items-start justify-between">
            <div>
              <h4 className="font-semibold text-[var(--diti-text)]">{selectedMarker.title}</h4>
              <p className="text-xs text-[var(--diti-muted)]">{selectedMarker.subtitle}</p>
            </div>
            <Button size="sm" variant="outline" onClick={() => setSelectedMarker(null)}>
              Close
            </Button>
          </div>
          {selectedMarker.details && (
            <div className="mt-3 grid grid-cols-2 gap-2 text-xs">
              {Object.entries(selectedMarker.details).map(([k, v]) => (
                <div key={k} className="rounded bg-[var(--diti-surface-sunken)] p-2">
                  <span className="text-[var(--diti-muted)]">{k}: </span>
                  <span className="font-medium text-[var(--diti-text)]">{v}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </Card>
  );
}
