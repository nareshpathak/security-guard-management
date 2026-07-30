"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Card, DataTable, EmptyState, Input, Label, PageHeader, Select, Skeleton, StatCard } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { useCommand } from "@/lib/use-command";
import { cell } from "@/lib/list-query";
import { count, isoDate, percent } from "@/lib/format";
import { GenericReportPrintTemplate, PrintModal } from "@/components/print-template";

export default function PatrolRoundsPage() {
  const router = useRouter();
  const [creating, setCreating] = useState(false);
  const [showPrintModal, setShowPrintModal] = useState(false);
  const [from, setFrom] = useState(() => {
    const d = new Date();
    d.setDate(d.getDate() - 7);
    return isoDate(d);
  });

  const summary = useQuery({
    queryKey: ["patrol-summary", from],
    queryFn: () => getApi().get<Row[]>("/api/v2/patrol/summary", { from, to: isoDate(new Date()) }),
  });

  const units = useQuery({
    queryKey: ["units-for-select"],
    queryFn: () => getApi().get<Row[]>("/api/v2/units", { page: 1, pageSize: 200 }),
    staleTime: 5 * 60 * 1000,
  });

  const [form, setForm] = useState({
    unitId: "",
    roundName: "",
    startTime: "22:00",
    endTime: "06:00",
    graceMinutes: 15,
    daysOfWeek: "Mon,Tue,Wed,Thu,Fri,Sat,Sun",
    qrIds: "",
  });

  // Fetch checkpoints when a unit is selected
  const checkpoints = useQuery({
    queryKey: ["checkpoints-for-unit", form.unitId],
    enabled: Boolean(form.unitId),
    queryFn: () => getApi().get<Row[]>("/api/v2/patrol/checkpoints", { unitId: Number(form.unitId), page: 1, pageSize: 100 }),
  });

  const create = useCommand<Record<string, unknown>>({
    path: "/api/v2/patrol/rounds",
    invalidate: ["patrol-summary", "patrol-checkpoints"],
    successMessage: "Patrol round created",
    onDone: () => {
      setCreating(false);
      setForm({
        unitId: "",
        roundName: "",
        startTime: "22:00",
        endTime: "06:00",
        graceMinutes: 15,
        daysOfWeek: "Mon,Tue,Wed,Thu,Fri,Sat,Sun",
        qrIds: "",
      });
    },
  });

  const rows = summary.data?.data ?? [];
  const expected = rows.reduce((n, r) => n + Number(r.ExpectedScans ?? 0), 0);
  const actual = rows.reduce((n, r) => n + Number(r.ActualScans ?? r.ScanCount ?? 0), 0);

  const availableCheckpoints = checkpoints.data?.data ?? [];

  return (
    <div>
      <PageHeader
        title="Patrol rounds"
        description="What is scheduled, and how much of it actually happened."
        actions={
          <div className="flex items-center gap-2">
            <Button variant="outline" onClick={() => router.push("/operations/patrol")}>
              Scan log
            </Button>
            <Button variant="outline" onClick={() => setShowPrintModal(true)}>
              <svg className="size-4 mr-1.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="6 9 6 2 18 2 18 9" />
                <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
                <rect x="6" y="14" width="12" height="8" />
              </svg>
              Print / Save PDF Report
            </Button>
            <Button onClick={() => setCreating((v) => !v)}>{creating ? "Cancel" : "New round"}</Button>
          </div>
        }
      />

      {creating ? (
        <Card className="mb-6 grid gap-4 md:grid-cols-2">
          <div>
            <Label required>Site</Label>
            <Select value={form.unitId} onChange={(e) => setForm((f) => ({ ...f, unitId: e.target.value }))}>
              <option value="">Choose a site…</option>
              {(units.data?.data ?? []).map((u, i) => (
                <option key={String(u.UnitID ?? i)} value={String(u.UnitID ?? "")}>
                  {String(u.UnitName ?? "")}
                </option>
              ))}
            </Select>
          </div>

          <div>
            <Label required>Round name</Label>
            <Input
              value={form.roundName}
              placeholder="e.g. Night Round 1"
              onChange={(e) => setForm((f) => ({ ...f, roundName: e.target.value }))}
            />
          </div>

          <div>
            <Label required>Starts at</Label>
            <Input type="time" value={form.startTime} onChange={(e) => setForm((f) => ({ ...f, startTime: e.target.value }))} />
          </div>

          <div>
            <Label required>Ends at</Label>
            <Input type="time" value={form.endTime} onChange={(e) => setForm((f) => ({ ...f, endTime: e.target.value }))} />
          </div>

          <div>
            <Label>Grace period (minutes)</Label>
            <Input
              type="number"
              value={form.graceMinutes}
              onChange={(e) => setForm((f) => ({ ...f, graceMinutes: Number(e.target.value) }))}
            />
          </div>

          <div>
            <Label required>QR Checkpoint IDs (comma separated)</Label>
            <Input
              value={form.qrIds}
              placeholder={availableCheckpoints.length > 0 ? `Available: ${availableCheckpoints.map(c => c.QRID ?? c.QrId).join(", ")}` : "1, 2, 3"}
              onChange={(e) => setForm((f) => ({ ...f, qrIds: e.target.value }))}
            />
            {availableCheckpoints.length > 0 ? (
              <p className="mt-1 text-xs text-[var(--diti-muted)]">
                Site checkpoints: {availableCheckpoints.map(c => `${c.QRID ?? c.QrId} (${c.CheckpointName ?? c.Name})`).join(" · ")}
              </p>
            ) : (
              <p className="mt-1 text-xs text-[var(--diti-muted)]">
                Select a site to view its assigned QR checkpoints.
              </p>
            )}
          </div>

          <div className="md:col-span-2 flex justify-end gap-2 border-t border-[var(--diti-border)] pt-4">
            <Button variant="outline" onClick={() => setCreating(false)}>
              Cancel
            </Button>
            <Button
              loading={create.isPending}
              disabled={!form.unitId || !form.roundName || !form.startTime || !form.endTime}
              onClick={() =>
                create.mutate({
                  unitId: Number(form.unitId),
                  roundName: form.roundName,
                  startTime: form.startTime,
                  endTime: form.endTime,
                  graceMinutes: Number(form.graceMinutes || 15),
                  daysOfWeek: form.daysOfWeek,
                  qrIds: form.qrIds
                    ? form.qrIds.split(/[,\s]+/).filter(Boolean).map(Number)
                    : availableCheckpoints.map((c) => Number(c.QRID ?? c.QrId)).filter(Boolean),
                })
              }
            >
              Create patrol round
            </Button>
          </div>
        </Card>
      ) : null}

      <div className="mb-6 flex items-end gap-3">
        <div>
          <Label>Since</Label>
          <Input type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
        </div>
      </div>

      <div className="mb-8 grid gap-4 sm:grid-cols-3">
        <StatCard label="Rounds scheduled" value={count(rows.length)} />
        <StatCard label="Scans expected" value={count(expected)} />
        <StatCard
          label="Compliance"
          value={expected > 0 ? percent((actual / expected) * 100) : "—"}
          tone={expected > 0 && actual / expected < 0.9 ? "danger" : "success"}
        />
      </div>

      {summary.isLoading ? (
        <Skeleton className="h-64" />
      ) : (
        <DataTable
          columns={[
            { id: "unit", header: "Site", cell: (r) => cell(r, "UnitName") },
            { id: "round", header: "Round", cell: (r) => cell(r, "RoundName") },
            { id: "cp", header: "Checkpoints", className: "text-right", hideOnMobile: true, cell: (r) => <span className="tabular font-medium">{count(r.CheckpointCount)}</span> },
            { id: "exp", header: "Expected", className: "text-right", cell: (r) => <span className="tabular font-medium">{count(r.ExpectedScans)}</span> },
            { id: "act", header: "Scanned", className: "text-right", cell: (r) => <span className="tabular font-medium text-[var(--diti-primary)]">{count(r.ActualScans ?? r.ScanCount)}</span> },
            {
              id: "pct",
              header: "Compliance",
              className: "text-right",
              cell: (r) => {
                const e = Number(r.ExpectedScans ?? 0);
                const a = Number(r.ActualScans ?? r.ScanCount ?? 0);
                if (e === 0) return <span className="text-muted">—</span>;
                const pct = (a / e) * 100;
                return (
                  <span className={pct < 90 ? "tabular font-semibold text-danger" : "tabular font-semibold text-success"}>
                    {percent(pct)}
                  </span>
                );
              },
            },
          ]}
          rows={rows}
          rowKey={(r, i) => String(r.RoundID ?? i)}
          empty={<EmptyState title="No rounds scheduled" description="Create one and assign it checkpoints." />}
        />
      )}

      {/* Printable Patrol Compliance Report Modal */}
      <PrintModal
        open={showPrintModal}
        onClose={() => setShowPrintModal(false)}
        title="PATROL ROUNDS COMPLIANCE REPORT"
      >
        <GenericReportPrintTemplate
          title="PATROL ROUNDS COMPLIANCE REPORT"
          filters={{ from }}
          columns={[
            { key: "UnitName", label: "Site" },
            { key: "RoundName", label: "Round Name" },
            { key: "CheckpointCount", label: "Checkpoints", align: "right" },
            { key: "ExpectedScans", label: "Expected Scans", align: "right" },
            { key: "ActualScans", label: "Actual Scans", align: "right" },
          ]}
          rows={rows}
        />
      </PrintModal>
    </div>
  );
}
