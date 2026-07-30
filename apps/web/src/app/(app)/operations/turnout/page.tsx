"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import {
  Button,
  DataTable,
  EmptyState,
  ErrorState,
  Input,
  Label,
  PageHeader,
  Select,
  Skeleton,
  StatCard,
  StatusPill,
} from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Modal } from "@/components/modal";
import { GenericReportPrintTemplate, PrintModal } from "@/components/print-template";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";
import { cell } from "@/lib/list-query";
import { count, isoDate } from "@/lib/format";

export default function TurnoutPage() {
  const { has } = useAuth();
  const [turnoutModal, setTurnoutModal] = useState(false);
  const [showPrintModal, setShowPrintModal] = useState(false);

  const [turnoutForm, setTurnoutForm] = useState({
    unitId: "",
    turnoutDate: isoDate(new Date()),
    shiftId: "",
    requiredNos: "",
    presentNos: "",
    absentNos: "0",
    relieverNos: "0",
    remark: "",
  });

  const live = useQuery({
    queryKey: ["turnout-live-page"],
    queryFn: async () => (await getApi().get<Row[]>("/api/v2/turnout/live")).data,
    refetchInterval: 30_000,
  });

  const vacant = useQuery({
    queryKey: ["vacant-page"],
    queryFn: async () =>
      (await getApi().get<Row[]>("/api/v2/turnout/vacant-posts", { minutesAhead: 60 })).data,
    refetchInterval: 30_000,
  });

  const unitsQuery = useQuery({
    queryKey: ["units-dropdown"],
    queryFn: () => getApi().get<Row[]>("/api/v2/units"),
    staleTime: 5 * 60 * 1000,
  });

  const turnoutCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/turnout",
    invalidate: ["turnout-live-page", "vacant-page"],
    successMessage: "Shift turnout recorded successfully",
    onDone: () => {
      setTurnoutModal(false);
      setTurnoutForm({
        unitId: "",
        turnoutDate: isoDate(new Date()),
        shiftId: "",
        requiredNos: "",
        presentNos: "",
        absentNos: "0",
        relieverNos: "0",
        remark: "",
      });
    },
  });

  const rows = live.data ?? [];
  const units = unitsQuery.data?.data ?? [];
  const vacantPosts = vacant.data ?? [];

  const required = rows.reduce((n, r) => n + Number(r.RequiredNos ?? r.Required ?? 0), 0);
  const present = rows.reduce((n, r) => n + Number(r.PresentNos ?? r.Present ?? 0), 0);
  const absent = rows.reduce((n, r) => n + Number(r.AbsentNos ?? r.Absent ?? 0), 0);

  return (
    <div>
      <PageHeader
        title="Live Turnout Board"
        description="Required vs present guards per client site. Real-time vacancy detection and shift strength audit."
        actions={
          <div className="flex items-center gap-2">
            <Button variant="outline" onClick={() => setShowPrintModal(true)}>
              <svg className="size-4 mr-1.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="6 9 6 2 18 2 18 9" />
                <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
                <rect x="6" y="14" width="12" height="8" />
              </svg>
              Print Turnout Report
            </Button>
            {has(Perm.deploymentEdit) ? (
              <Button variant="primary" onClick={() => setTurnoutModal(true)}>
                + Record Site Turnout
              </Button>
            ) : null}
          </div>
        }
      />

      {/* KPI Overview Header */}
      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard label="Contracted Guards" value={count(required)} tone="default" />
        <StatCard label="Guards On Duty" value={count(present)} tone="success" />
        <StatCard label="Absentee Guard Shortage" value={count(absent || Math.max(required - present, 0))} tone="danger" />
        <StatCard label="Vacant Unfilled Posts" value={count(vacantPosts.length)} tone="warning" hint={vacantPosts.length > 0 ? "Requires immediate reliever" : "All posts filled"} />
      </div>

      {vacantPosts.length > 0 ? (
        <div className="mb-6 rounded-xl border border-amber-500/20 bg-amber-500/10 p-4 text-amber-600">
          <div className="font-semibold text-sm">⚠️ {vacantPosts.length} Vacant Posts Detected</div>
          <div className="mt-1 text-xs">
            The following sites are under-strength and require reliever deployment.
          </div>
        </div>
      ) : null}

      {live.isLoading ? <Skeleton className="h-64" /> : null}
      {live.isError ? (
        <ErrorState message={live.error instanceof Error ? live.error.message : "Failed"} onRetry={() => live.refetch()} />
      ) : null}

      {live.data ? (
        <DataTable
          columns={[
            { id: "unit", header: "Unit Site", cell: (r) => <span className="font-semibold text-text">{cell(r, "UnitName")}</span> },
            { id: "client", header: "Client", hideOnMobile: true, cell: (r) => cell(r, "ClientName") },
            { id: "req", header: "Required Nos", className: "text-right", cell: (r) => <span className="tabular font-medium">{cell(r, "RequiredNos", "Required")}</span> },
            { id: "pres", header: "Present Nos", className: "text-right", cell: (r) => <span className="tabular font-bold text-success">{cell(r, "PresentNos", "Present")}</span> },
            {
              id: "gap",
              header: "Strength Status",
              className: "text-right",
              cell: (r) => {
                const gap = Number(r.RequiredNos ?? r.Required ?? 0) - Number(r.PresentNos ?? r.Present ?? 0);
                return gap > 0 ? (
                  <StatusPill tone="danger">-{gap} Short</StatusPill>
                ) : (
                  <StatusPill tone="success">Optimal</StatusPill>
                );
              },
            },
          ]}
          rows={rows}
          rowKey={(r, i) => String(r.UnitID ?? r.UnitId ?? i)}
          empty={<EmptyState title="No turnout recorded for today" description="Click Record Site Turnout to enter shift strength." />}
        />
      ) : null}

      {/* Record Turnout Modal */}
      <Modal
        open={turnoutModal}
        onOpenChange={setTurnoutModal}
        title="Record Site Turnout"
        description="Enter shift turnout numbers for client unit."
        footer={
          <Button
            loading={turnoutCmd.isPending}
            disabled={!turnoutForm.unitId || !turnoutForm.requiredNos || !turnoutForm.presentNos}
            onClick={() =>
              turnoutCmd.mutate({
                unitId: Number(turnoutForm.unitId),
                turnoutDate: turnoutForm.turnoutDate,
                shiftId: turnoutForm.shiftId ? Number(turnoutForm.shiftId) : undefined,
                requiredNos: Number(turnoutForm.requiredNos),
                presentNos: Number(turnoutForm.presentNos),
                absentNos: Number(turnoutForm.absentNos),
                relieverNos: Number(turnoutForm.relieverNos),
                remark: turnoutForm.remark || undefined,
              })
            }
          >
            Save Turnout Entry
          </Button>
        }
      >
        <div>
          <Label required>Unit Site</Label>
          <Select
            value={turnoutForm.unitId}
            onChange={(e) => setTurnoutForm((f) => ({ ...f, unitId: e.target.value }))}
          >
            <option value="">Select Unit Site...</option>
            {units.map((u, i) => (
              <option key={String(u.UnitID ?? u.Id ?? i)} value={String(u.UnitID ?? u.Id ?? "")}>
                {String(u.UnitName ?? u.Name ?? "")}
              </option>
            ))}
          </Select>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <Label required>Contracted Required Nos</Label>
            <Input
              type="number"
              placeholder="e.g. 5"
              value={turnoutForm.requiredNos}
              onChange={(e) => setTurnoutForm((f) => ({ ...f, requiredNos: e.target.value }))}
            />
          </div>
          <div>
            <Label required>Present Guards</Label>
            <Input
              type="number"
              placeholder="e.g. 5"
              value={turnoutForm.presentNos}
              onChange={(e) => setTurnoutForm((f) => ({ ...f, presentNos: e.target.value }))}
            />
          </div>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <Label>Absent Guards</Label>
            <Input
              type="number"
              value={turnoutForm.absentNos}
              onChange={(e) => setTurnoutForm((f) => ({ ...f, absentNos: e.target.value }))}
            />
          </div>
          <div>
            <Label>Relievers Deployed</Label>
            <Input
              type="number"
              value={turnoutForm.relieverNos}
              onChange={(e) => setTurnoutForm((f) => ({ ...f, relieverNos: e.target.value }))}
            />
          </div>
        </div>
        <div>
          <Label>Turnout Remarks</Label>
          <Input
            placeholder="Turnout remarks or shift supervisor notes"
            value={turnoutForm.remark}
            onChange={(e) => setTurnoutForm((f) => ({ ...f, remark: e.target.value }))}
          />
        </div>
      </Modal>

      {/* Printable Turnout Report Modal */}
      <PrintModal
        open={showPrintModal}
        onClose={() => setShowPrintModal(false)}
        title="LIVE SHIFT TURNOUT & STRENGTH AUDIT REPORT"
      >
        <GenericReportPrintTemplate
          title="LIVE SHIFT TURNOUT & STRENGTH AUDIT REPORT"
          columns={[
            { key: "UnitName", label: "Unit Site Name" },
            { key: "ClientName", label: "Client" },
            { key: "RequiredNos", label: "Required", align: "right" },
            { key: "PresentNos", label: "Present", align: "right" },
          ]}
          rows={rows}
        />
      </PrintModal>
    </div>
  );
}
