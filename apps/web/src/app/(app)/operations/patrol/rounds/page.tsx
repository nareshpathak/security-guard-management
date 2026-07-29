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

/**
 * Patrol rounds: the schedule, and how well it is being kept.
 *
 * A round is a sequence of checkpoints with a start time. The compliance figure
 * next to it is the only number that says whether the site is actually being
 * walked.
 */
export default function PatrolRoundsPage() {
  const router = useRouter();
  const [creating, setCreating] = useState(false);
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

  const [form, setForm] = useState({ unitId: "", roundName: "", startTime: "22:00", checkpointIds: "" });

  const create = useCommand<Record<string, unknown>>({
    path: "/api/v2/patrol/rounds",
    invalidate: ["patrol-summary", "patrol-checkpoints"],
    successMessage: "Round created",
    onDone: () => {
      setCreating(false);
      setForm({ unitId: "", roundName: "", startTime: "22:00", checkpointIds: "" });
    },
  });

  const rows = summary.data?.data ?? [];
  const expected = rows.reduce((n, r) => n + Number(r.ExpectedScans ?? 0), 0);
  const actual = rows.reduce((n, r) => n + Number(r.ActualScans ?? r.ScanCount ?? 0), 0);

  return (
    <div>
      <PageHeader
        title="Patrol rounds"
        description="What is scheduled, and how much of it actually happened."
        actions={
          <div className="flex gap-2">
            <Button variant="outline" onClick={() => router.push("/operations/patrol")}>
              Scan log
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
              placeholder="e.g. Night round 1"
              onChange={(e) => setForm((f) => ({ ...f, roundName: e.target.value }))}
            />
          </div>

          <div>
            <Label required>Starts at</Label>
            <Input type="time" value={form.startTime} onChange={(e) => setForm((f) => ({ ...f, startTime: e.target.value }))} />
          </div>

          <div>
            <Label required>Checkpoint ids, in order</Label>
            <Input
              value={form.checkpointIds}
              placeholder="12, 15, 18"
              onChange={(e) => setForm((f) => ({ ...f, checkpointIds: e.target.value }))}
            />
            <p className="mt-1 text-xs text-muted">
              The order is the route. A guard scanning them out of sequence is flagged.
            </p>
          </div>

          <div className="md:col-span-2">
            <Button
              loading={create.isPending}
              disabled={!form.unitId || !form.roundName || !form.checkpointIds}
              onClick={() =>
                create.mutate({
                  unitId: Number(form.unitId),
                  roundName: form.roundName,
                  startTime: form.startTime,
                  checkpointIds: form.checkpointIds
                    .split(/[,\s]+/)
                    .filter(Boolean)
                    .map(Number),
                })
              }
            >
              Create round
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
            { id: "cp", header: "Checkpoints", className: "text-right", hideOnMobile: true, cell: (r) => <span className="tabular">{count(r.CheckpointCount)}</span> },
            { id: "exp", header: "Expected", className: "text-right", cell: (r) => <span className="tabular">{count(r.ExpectedScans)}</span> },
            { id: "act", header: "Scanned", className: "text-right", cell: (r) => <span className="tabular">{count(r.ActualScans ?? r.ScanCount)}</span> },
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
                  <span className={pct < 90 ? "tabular font-medium text-danger" : "tabular text-success"}>
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
    </div>
  );
}
