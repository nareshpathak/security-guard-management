"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { Button, Card, EmptyState, Input, Label, PageHeader, Skeleton, TextArea } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Status } from "@/components/status";
import { Modal } from "@/components/modal";
import { getApi } from "@/lib/api";
import { useCommand } from "@/lib/use-command";
import { cell } from "@/lib/list-query";
import { date, money } from "@/lib/format";

type Queue = "attendance" | "requests" | "advances" | "incidents" | "complaints" | "incdec";

const QUEUES: { id: Queue; label: string }[] = [
  { id: "attendance", label: "Attendance" },
  { id: "requests", label: "Requests" },
  { id: "advances", label: "Advances" },
  { id: "incidents", label: "Incidents" },
  { id: "complaints", label: "Complaints" },
  { id: "incdec", label: "Strength changes" },
];

/**
 * One queue for every decision waiting on this user.
 *
 * The PRD asks for a unified approval queue and it is right to: an operations
 * manager should not have to remember that advances live under Finance and
 * strength changes under Deployment. Each tab is a different endpoint; the
 * shape of the decision - approve, reject with a reason - is the same.
 */
export default function ApprovalsPage() {
  const [queue, setQueue] = useState<Queue>("attendance");

  return (
    <div>
      <PageHeader
        title="Approvals"
        description="Everything waiting on a decision from you."
        actions={
          <div className="flex flex-wrap gap-2">
            {QUEUES.map((q) => (
              <Button
                key={q.id}
                size="sm"
                variant={queue === q.id ? "primary" : "outline"}
                onClick={() => setQueue(q.id)}
              >
                {q.label}
              </Button>
            ))}
          </div>
        }
      />

      {queue === "attendance" ? <AttendanceQueue /> : null}
      {queue === "requests" ? <RequestQueue /> : null}
      {queue === "advances" ? <AdvanceQueue /> : null}
      {queue === "incidents" ? <IncidentQueue /> : null}
      {queue === "complaints" ? <ComplaintQueue /> : null}
      {queue === "incdec" ? <IncDecQueue /> : null}
    </div>
  );
}

// ---------------------------------------------------------------- attendance

function AttendanceQueue() {
  const list = useQuery({
    queryKey: ["approvals-attendance"],
    queryFn: () => getApi().get<Row[]>("/api/v2/attendance/pending-approval", { page: 1, pageSize: 100 }),
  });

  const decide = useCommand<{ attendanceIds: number[]; approve: boolean; rejectReason?: string }>({
    path: "/api/v2/attendance/approve",
    invalidate: ["approvals-attendance", "attendance"],
  });

  const rows = list.data?.data ?? [];

  return (
    <QueueShell
      loading={list.isLoading}
      empty={rows.length === 0}
      emptyTitle="No attendance waiting"
      emptyHint="Punches from the last three days appear here until someone approves them."
      bulk={
        rows.length > 0 ? (
          <Button
            variant="outline"
            loading={decide.isPending}
            onClick={() =>
              decide.mutate({
                attendanceIds: rows.map((r) => Number(r.AttendanceID)),
                approve: true,
              })
            }
          >
            Approve all {rows.length}
          </Button>
        ) : null
      }
    >
      {rows.map((r, i) => {
        const distance = Number(r.InDistanceMeters ?? 0);
        const far = distance > Number(r.GeofenceRadiusMeters ?? 100);
        return (
          <DecisionCard
            key={String(r.AttendanceID ?? i)}
            title={String(r.EmpFullName ?? "")}
            subtitle={`${cell(r, "UnitName")} · ${date(r.AttendanceDate)}`}
            badge={
              // The distance is the decision. A punch 800 m away with no reason
              // is the one thing this screen exists to catch.
              <Status value={far ? `${distance} m — outside` : `${distance} m`} />
            }
            detail={r.Remark ? `Reason given: ${String(r.Remark)}` : undefined}
            pending={decide.isPending}
            onApprove={() => decide.mutate({ attendanceIds: [Number(r.AttendanceID)], approve: true })}
            onReject={(reason) =>
              decide.mutate({ attendanceIds: [Number(r.AttendanceID)], approve: false, rejectReason: reason })
            }
          />
        );
      })}
    </QueueShell>
  );
}

// ---------------------------------------------------------------- requests

function RequestQueue() {
  const list = useQuery({
    queryKey: ["approvals-requests"],
    queryFn: () => getApi().get<Row[]>("/api/v2/hr/requests", { status: "Pending", page: 1, pageSize: 100 }),
  });

  const decide = useCommand<{ id: number; approve: boolean; remark?: string }>({
    path: (i) => `/api/v2/hr/requests/${i.id}/approve`,
    invalidate: ["approvals-requests", "hr-requests"],
  });

  const rows = list.data?.data ?? [];

  return (
    <QueueShell loading={list.isLoading} empty={rows.length === 0} emptyTitle="No requests waiting">
      {rows.map((r, i) => (
        <DecisionCard
          key={String(r.RequestID ?? i)}
          title={String(r.EmpFullName ?? "")}
          subtitle={`${cell(r, "RequestType")} · ${cell(r, "EmpCode")} · ${cell(r, "UnitName")}`}
          badge={
            r.Amount ? <Status value={money(r.Amount)} /> : r.DayCount ? <Status value={`${r.DayCount} day(s)`} /> : null
          }
          detail={String(r.Reason ?? "")}
          pending={decide.isPending}
          onApprove={() => decide.mutate({ id: Number(r.RequestID), approve: true })}
          onReject={(remark) => decide.mutate({ id: Number(r.RequestID), approve: false, remark })}
        />
      ))}
    </QueueShell>
  );
}

// ---------------------------------------------------------------- advances

function AdvanceQueue() {
  const list = useQuery({
    queryKey: ["approvals-advances"],
    queryFn: () => getApi().get<Row[]>("/api/v2/advances", { status: "Pending", page: 1, pageSize: 100 }),
  });

  const decide = useCommand<{ id: number; approve: boolean; remark?: string }>({
    path: (i) => `/api/v2/advances/${i.id}/approve`,
    invalidate: ["approvals-advances", "advances"],
  });

  const rows = list.data?.data ?? [];

  return (
    <QueueShell loading={list.isLoading} empty={rows.length === 0} emptyTitle="No advances waiting">
      {rows.map((r, i) => (
        <DecisionCard
          key={String(r.AdvanceID ?? i)}
          title={String(r.EmpFullName ?? "")}
          subtitle={`${cell(r, "EmpCode")} · ${cell(r, "UnitName")}`}
          badge={<Status value={money(r.Amount)} />}
          detail={`Recovering ${money(r.InstallmentAmount)} a month. ${String(r.Reason ?? "")}`}
          pending={decide.isPending}
          onApprove={() => decide.mutate({ id: Number(r.AdvanceID), approve: true })}
          onReject={(remark) => decide.mutate({ id: Number(r.AdvanceID), approve: false, remark })}
        />
      ))}
    </QueueShell>
  );
}

// ---------------------------------------------------------------- incidents

function IncidentQueue() {
  const ninety = new Date();
  ninety.setDate(ninety.getDate() - 90);

  const list = useQuery({
    queryKey: ["approvals-incidents"],
    queryFn: () =>
      getApi().get<Row[]>("/api/v2/reports/incident", {
        from: ninety.toISOString().slice(0, 10),
        page: 1,
        pageSize: 100,
      }),
  });

  const close = useCommand<{ id: number; closingRemark: string }>({
    path: (i) => `/api/v2/incidents/${i.id}/close`,
    invalidate: ["approvals-incidents", "incidents"],
    successMessage: "Incident closed",
  });

  const open = (list.data?.data ?? []).filter((r) => !r.IsClosed);

  return (
    <QueueShell
      loading={list.isLoading}
      empty={open.length === 0}
      emptyTitle="No open incidents"
      emptyHint="Everything raised in the last 90 days has been closed."
    >
      {open.map((r, i) => (
        <DecisionCard
          key={String(r.IncidentID ?? i)}
          title={String(r.IncidentTypeName ?? r.TypeName ?? "Incident")}
          subtitle={`${cell(r, "UnitName")} · ${date(r.IncidentDate ?? r.Dated)}`}
          detail={String(r.Description ?? r.Remark ?? "")}
          pending={close.isPending}
          approveLabel="Close"
          rejectLabel="Close with note"
          onApprove={() => close.mutate({ id: Number(r.IncidentID), closingRemark: "Closed from the console" })}
          onReject={(remark) => close.mutate({ id: Number(r.IncidentID), closingRemark: remark })}
        />
      ))}
    </QueueShell>
  );
}

// ---------------------------------------------------------------- complaints

function ComplaintQueue() {
  const list = useQuery({
    queryKey: ["approvals-complaints"],
    queryFn: () => getApi().get<Row[]>("/api/v2/complaints", { page: 1, pageSize: 100 }),
  });

  const update = useCommand<{ id: number; status: string; remark?: string }>({
    path: (i) => `/api/v2/complaints/${i.id}/status`,
    invalidate: ["approvals-complaints", "complaints"],
    successMessage: "Complaint updated",
  });

  const open = (list.data?.data ?? []).filter((r) => !r.IsClosed);

  return (
    <QueueShell loading={list.isLoading} empty={open.length === 0} emptyTitle="No open complaints">
      {open.map((r, i) => {
        const raised = new Date(String(r.ComplaintDate ?? r.InsertDate));
        const days = Number.isNaN(raised.getTime())
          ? null
          : Math.floor((Date.now() - raised.getTime()) / 86_400_000);
        return (
          <DecisionCard
            key={String(r.ComplaintID ?? i)}
            title={String(r.Subject ?? r.Description ?? "Complaint")}
            subtitle={`${cell(r, "ClientName")} · ${cell(r, "UnitName")}`}
            badge={
              days !== null ? (
                // Seven days open is where a complaint stops being a ticket and
                // starts being a reason the client leaves.
                <Status value={days >= 7 ? `${days} days open` : `${days} days`} />
              ) : null
            }
            detail={String(r.Remark ?? "")}
            pending={update.isPending}
            approveLabel="Resolve"
            rejectLabel="Add a note"
            onApprove={() => update.mutate({ id: Number(r.ComplaintID), status: "Closed" })}
            onReject={(remark) => update.mutate({ id: Number(r.ComplaintID), status: "InProgress", remark })}
          />
        );
      })}
    </QueueShell>
  );
}

// ---------------------------------------------------------------- inc/dec

function IncDecQueue() {
  const list = useQuery({
    queryKey: ["approvals-incdec"],
    queryFn: () => getApi().get<Row[]>("/api/v2/reports/incdec", { page: 1, pageSize: 100 }),
  });

  const approve = useCommand<{ changeId: number; approve: boolean; remark?: string }>({
    path: (i) => `/api/v2/deployments/incdec/${i.changeId}/approve`,
    invalidate: ["approvals-incdec", "deployments"],
  });

  const pending = (list.data?.data ?? []).filter((r) => !r.IsApproved);

  return (
    <QueueShell
      loading={list.isLoading}
      empty={pending.length === 0}
      emptyTitle="No strength changes waiting"
      emptyHint="A change to a site's contracted strength needs approval before it takes effect."
    >
      {pending.map((r, i) => (
        <DecisionCard
          key={String(r.ChangeID ?? i)}
          title={String(r.UnitName ?? "Site")}
          subtitle={`${cell(r, "ClientName")} · ${date(r.EffectiveFrom ?? r.InsertDate)}`}
          badge={<Status value={`${Number(r.ChangeNos ?? 0) > 0 ? "+" : ""}${String(r.ChangeNos ?? 0)} guards`} />}
          detail={String(r.Reason ?? r.Remark ?? "")}
          pending={approve.isPending}
          onApprove={() => approve.mutate({ changeId: Number(r.ChangeID), approve: true })}
          onReject={(remark) => approve.mutate({ changeId: Number(r.ChangeID), approve: false, remark })}
        />
      ))}
    </QueueShell>
  );
}

// ---------------------------------------------------------------- shared

function QueueShell({
  loading,
  empty,
  emptyTitle,
  emptyHint,
  bulk,
  children,
}: {
  loading: boolean;
  empty: boolean;
  emptyTitle: string;
  emptyHint?: string;
  bulk?: React.ReactNode;
  children: React.ReactNode;
}) {
  if (loading)
    return (
      <div className="space-y-3">
        {[0, 1, 2].map((i) => (
          <Skeleton key={i} className="h-28" />
        ))}
      </div>
    );

  if (empty) return <EmptyState title={emptyTitle} description={emptyHint} />;

  return (
    <div className="space-y-3">
      {bulk ? <div className="flex justify-end">{bulk}</div> : null}
      {children}
    </div>
  );
}

function DecisionCard({
  title,
  subtitle,
  badge,
  detail,
  pending,
  approveLabel = "Approve",
  rejectLabel = "Reject",
  onApprove,
  onReject,
}: {
  title: string;
  subtitle?: string;
  badge?: React.ReactNode;
  detail?: string;
  pending?: boolean;
  approveLabel?: string;
  rejectLabel?: string;
  onApprove: () => void;
  onReject: (reason: string) => void;
}) {
  const [rejecting, setRejecting] = useState(false);
  const [reason, setReason] = useState("");

  return (
    <Card className="space-y-3">
      <div className="flex items-start justify-between gap-4">
        <div className="min-w-0">
          <div className="font-medium text-text">{title}</div>
          {subtitle ? <div className="text-xs text-muted">{subtitle}</div> : null}
        </div>
        {badge}
      </div>

      {detail ? <p className="text-sm text-muted">{detail}</p> : null}

      <div className="flex gap-2">
        <Button size="sm" loading={pending} onClick={onApprove}>
          {approveLabel}
        </Button>
        <Button size="sm" variant="outline" onClick={() => setRejecting(true)}>
          {rejectLabel}
        </Button>
      </div>

      <Modal
        open={rejecting}
        onOpenChange={setRejecting}
        title={rejectLabel}
        description="The reason is recorded and shown to the person who raised this."
        footer={
          <Button
            variant="danger"
            loading={pending}
            disabled={reason.trim().length < 5}
            onClick={() => {
              onReject(reason.trim());
              setRejecting(false);
              setReason("");
            }}
          >
            {rejectLabel}
          </Button>
        }
      >
        <div>
          <Label required>Reason</Label>
          <TextArea value={reason} onChange={(e) => setReason(e.target.value)} />
        </div>
      </Modal>
    </Card>
  );
}
