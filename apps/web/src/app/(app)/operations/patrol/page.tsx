"use client";
export const dynamic = "force-dynamic";

import { useQuery } from "@tanstack/react-query";
import { useSearchParams } from "next/navigation";
import { useState } from "react";
import { Button, Input, Label, Select } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Modal } from "@/components/modal";
import { GenericReportPrintTemplate, PrintModal } from "@/components/print-template";
import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";
import { cell, useListQueryState } from "@/lib/list-query";
import { dateTime, isoDate } from "@/lib/format";

type Tab = "logs" | "checkpoints" | "missed";

export default function PatrolPage() {
  const { has } = useAuth();
  const params = useSearchParams();
  const q = useListQueryState();
  const tab = (params.get("tab") as Tab) ?? "logs";

  const [checkpointModal, setCheckpointModal] = useState(false);
  const [showPrintModal, setShowPrintModal] = useState(false);

  const [cpForm, setCpForm] = useState({
    unitId: "",
    name: "",
    location: "",
    maxDistanceMeters: "50",
    requirePhoto: false,
    remark: "",
  });

  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  const unitsQuery = useQuery({
    queryKey: ["units-dropdown"],
    queryFn: () => getApi().get<Row[]>("/api/v2/units"),
    staleTime: 5 * 60 * 1000,
  });

  const cpCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/patrol/checkpoints",
    invalidate: ["patrol-checkpoints", "patrol-logs"],
    successMessage: "Patrol QR checkpoint created successfully",
    onDone: () => {
      setCheckpointModal(false);
      setCpForm({
        unitId: "",
        name: "",
        location: "",
        maxDistanceMeters: "50",
        requirePhoto: false,
        remark: "",
      });
    },
  });

  const units = unitsQuery.data?.data ?? [];

  const tabs: { id: Tab; label: string }[] = [
    { id: "logs", label: "Scan Logs" },
    { id: "checkpoints", label: "QR Checkpoints" },
    { id: "missed", label: "Missed Patrol Rounds" },
  ];

  const switcher = (
    <div className="flex items-center gap-2">
      {tabs.map((t) => (
        <Button
          key={t.id}
          size="sm"
          variant={tab === t.id ? "primary" : "outline"}
          onClick={() => q.setParams({ tab: t.id === "logs" ? undefined : t.id, page: 1 })}
        >
          {t.label}
        </Button>
      ))}
      <Button variant="outline" size="sm" onClick={() => setShowPrintModal(true)}>
        Print Report
      </Button>
      {has(Perm.patrolEdit) && tab === "checkpoints" ? (
        <Button variant="primary" size="sm" onClick={() => setCheckpointModal(true)}>
          + Add Checkpoint
        </Button>
      ) : null}
    </div>
  );

  return (
    <div>
      {tab === "checkpoints" ? (
        <ResourceList
          title="Patrol & QR Checkpoint Master"
          description="Configured QR checkpoints, geofence radius boundaries, and photo rules."
          actions={switcher}
          path="/api/v2/patrol/checkpoints"
          queryKey="patrol-checkpoints"
          rowKey={(r, i) => String(r.QrID ?? i)}
          emptyTitle="No checkpoints configured"
          emptyDescription="Checkpoints are QR codes fixed at client sites scanned by guards."
          columns={[
            { id: "unit", header: "Unit Site", cell: (r) => cell(r, "UnitName") },
            { id: "name", header: "Checkpoint Name", cell: (r) => cell(r, "QrName", "CheckpointName") },
            {
              id: "code",
              header: "QR Code",
              hideOnMobile: true,
              cell: (r) => <span className="tabular text-muted font-mono">{cell(r, "QrCode")}</span>,
            },
            {
              id: "radius",
              header: "Geofence Radius",
              className: "text-right",
              hideOnMobile: true,
              cell: (r) => <span className="tabular font-medium">{cell(r, "MaxDistanceMeters")} m</span>,
            },
            {
              id: "photo",
              header: "Photo Rule",
              cell: (r) => <Status value={r.RequirePhoto ? "Required" : "Optional"} />,
            },
            {
              id: "active",
              header: "Status",
              cell: (r) => <Status value={r.IsActive ? "Active" : "Inactive"} />,
            },
          ]}
        />
      ) : tab === "missed" ? (
        <ResourceList
          title="Missed Patrol Rounds Audit"
          description="Scheduled patrol rounds that were due and never scanned by guards."
          actions={switcher}
          path="/api/v2/patrol/missed"
          queryKey="patrol-missed"
          rowKey={(r, i) => String(r.RoundID ?? i)}
          emptyTitle="No missed patrol rounds"
          emptyDescription="All scheduled patrol rounds in this period were scanned on time."
          columns={[
            { id: "unit", header: "Unit Site", cell: (r) => cell(r, "UnitName") },
            { id: "round", header: "Patrol Round", cell: (r) => cell(r, "RoundName", "RoundNo") },
            {
              id: "due",
              header: "Was Scheduled Due",
              cell: (r) => <span className="tabular">{dateTime(r.DueAt ?? r.StartTime)}</span>,
            },
            {
              id: "missed",
              header: "Checkpoints Missed",
              className: "text-right",
              cell: (r) => (
                <span className="tabular font-bold text-danger">
                  {cell(r, "MissedCount", "MissedCheckpoints")} Missed
                </span>
              ),
            },
          ]}
        />
      ) : (
        <ResourceList
          title="Patrol Scan History & Geofence Logs"
          description="Real-time record of all QR scans. Out-of-range scans beyond geofence radius are highlighted."
          actions={switcher}
          path="/api/v2/patrol/logs"
          queryKey="patrol-logs"
          params={{ from: q.from ?? isoDate(thirtyDaysAgo), to: q.to }}
          rowKey={(r, i) => String(r.ScanID ?? r.LogID ?? i)}
          emptyTitle="No scan logs found"
          emptyDescription="Scans submitted by mobile guards will appear here in real-time."
          columns={[
            {
              id: "when",
              header: "Scanned Time",
              cell: (r) => <span className="tabular font-medium">{dateTime(r.Scantime ?? r.ScanTime)}</span>,
            },
            { id: "unit", header: "Unit Site", cell: (r) => cell(r, "UnitName") },
            {
              id: "checkpoint",
              header: "QR Checkpoint",
              cell: (r) => (
                <div>
                  <div className="font-medium text-text">{cell(r, "QrName", "CheckpointName")}</div>
                  <div className="text-xs text-muted">Round: {cell(r, "RoundNo")}</div>
                </div>
              ),
            },
            { id: "guard", header: "Guard", hideOnMobile: true, cell: (r) => cell(r, "EmpFullName") },
            {
              id: "distance",
              header: "GPS Distance",
              className: "text-right",
              cell: (r) => {
                const metres = Number(r.DistanceMeters ?? 0);
                const inRange = r.IsWithinRange === true || r.IsWithinRange === 1;
                return (
                  <span className={inRange ? "tabular text-muted" : "tabular font-bold text-danger"}>
                    {metres} m
                  </span>
                );
              },
            },
            {
              id: "range",
              header: "Geofence Check",
              cell: (r) => (
                <Status value={r.IsWithinRange === true || r.IsWithinRange === 1 ? "In Geofence Range" : "OUT OF RANGE"} />
              ),
            },
          ]}
        />
      )}

      {/* Add Checkpoint Modal */}
      <Modal
        open={checkpointModal}
        onOpenChange={setCheckpointModal}
        title="Add Master QR Checkpoint"
        description="Create a new physical QR scan checkpoint at client unit."
        footer={
          <Button
            loading={cpCmd.isPending}
            disabled={!cpForm.unitId || !cpForm.name}
            onClick={() =>
              cpCmd.mutate({
                unitId: Number(cpForm.unitId),
                name: cpForm.name,
                location: cpForm.location || undefined,
                maxDistanceMeters: Number(cpForm.maxDistanceMeters),
                requirePhoto: cpForm.requirePhoto,
                remark: cpForm.remark || undefined,
              })
            }
          >
            Create Checkpoint
          </Button>
        }
      >
        <div>
          <Label required>Unit Site</Label>
          <Select
            value={cpForm.unitId}
            onChange={(e) => setCpForm((f) => ({ ...f, unitId: e.target.value }))}
          >
            <option value="">Select Unit Site...</option>
            {units.map((u, i) => (
              <option key={String(u.UnitID ?? u.Id ?? i)} value={String(u.UnitID ?? u.Id ?? "")}>
                {String(u.UnitName ?? u.Name ?? "")}
              </option>
            ))}
          </Select>
        </div>
        <div>
          <Label required>Checkpoint Name</Label>
          <Input
            placeholder="e.g. Main Gate North Tower / Server Room Entrance"
            value={cpForm.name}
            onChange={(e) => setCpForm((f) => ({ ...f, name: e.target.value }))}
          />
        </div>
        <div>
          <Label>Specific Location Description</Label>
          <Input
            placeholder="e.g. Ground Floor East Wing Column #4"
            value={cpForm.location}
            onChange={(e) => setCpForm((f) => ({ ...f, location: e.target.value }))}
          />
        </div>
        <div>
          <Label required>Max Geofence Distance (Meters)</Label>
          <Input
            type="number"
            placeholder="50"
            value={cpForm.maxDistanceMeters}
            onChange={(e) => setCpForm((f) => ({ ...f, maxDistanceMeters: e.target.value }))}
          />
        </div>
        <div className="flex items-center gap-2 pt-2">
          <input
            type="checkbox"
            id="requirePhoto"
            checked={cpForm.requirePhoto}
            onChange={(e) => setCpForm((f) => ({ ...f, requirePhoto: e.target.checked }))}
            className="size-4 rounded border-[var(--diti-border)] text-blue-600 focus:ring-blue-500"
          />
          <Label htmlFor="requirePhoto" className="!mb-0 cursor-pointer">
            Mandatory Guard Photo Verification on Scan
          </Label>
        </div>
      </Modal>

      {/* Printable Patrol Compliance Report */}
      <PrintModal
        open={showPrintModal}
        onClose={() => setShowPrintModal(false)}
        title="SECURITY PATROL & GEOFENCE COMPLIANCE REPORT"
      >
        <GenericReportPrintTemplate
          title="SECURITY PATROL & GEOFENCE COMPLIANCE REPORT"
          columns={[
            { key: "Scantime", label: "Scan Time" },
            { key: "UnitName", label: "Unit Site" },
            { key: "QrName", label: "Checkpoint Name" },
            { key: "EmpFullName", label: "Guard" },
            { key: "DistanceMeters", label: "Distance (m)", align: "right" },
          ]}
          rows={[]}
        />
      </PrintModal>
    </div>
  );
}
