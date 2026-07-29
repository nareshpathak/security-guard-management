"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Card, DataTable, EmptyState, Input, Label, PageHeader, Select, TextArea } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { MasterSelect } from "@/components/master-select";
import { getApi } from "@/lib/api";
import { useCommand } from "@/lib/use-command";
import { cell } from "@/lib/list-query";
import { isoDate } from "@/lib/format";

type Mode = "deploy" | "reliever" | "incdec" | "end";

const MODES: { id: Mode; label: string; blurb: string }[] = [
  { id: "deploy", label: "Deploy a guard", blurb: "Put someone on a post from a date." },
  { id: "reliever", label: "Send a reliever", blurb: "Cover a post for someone who is absent." },
  { id: "incdec", label: "Change strength", blurb: "Add or remove contracted posts. Needs approval." },
  { id: "end", label: "End a deployment", blurb: "Take someone off a post." },
];

/**
 * The four things anyone does to a deployment, in one place.
 *
 * They were four separate fragments in the legacy app and people used the wrong
 * one - ending a deployment when they meant to send a reliever, which loses the
 * post from the roster.
 */
export default function DeploymentActionPage() {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>("deploy");

  return (
    <div className="max-w-2xl">
      <PageHeader
        title="Deployment"
        description={MODES.find((m) => m.id === mode)?.blurb}
        actions={
          <Button variant="outline" onClick={() => router.push("/operations/deployment")}>
            Back
          </Button>
        }
      />

      <div className="mb-6 flex flex-wrap gap-2">
        {MODES.map((m) => (
          <Button key={m.id} size="sm" variant={mode === m.id ? "primary" : "outline"} onClick={() => setMode(m.id)}>
            {m.label}
          </Button>
        ))}
      </div>

      {mode === "deploy" ? <DeployForm /> : null}
      {mode === "reliever" ? <RelieverForm /> : null}
      {mode === "incdec" ? <IncDecForm /> : null}
      {mode === "end" ? <EndForm /> : null}
    </div>
  );
}

function UnitSelect({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  const units = useQuery({
    queryKey: ["units-for-select"],
    queryFn: () => getApi().get<Row[]>("/api/v2/units", { page: 1, pageSize: 200 }),
    staleTime: 5 * 60 * 1000,
  });

  return (
    <div>
      <Label required>Site</Label>
      <Select value={value} onChange={(e) => onChange(e.target.value)} disabled={units.isLoading}>
        <option value="">{units.isLoading ? "Loading…" : "Choose a site…"}</option>
        {(units.data?.data ?? []).map((u, i) => (
          <option key={String(u.UnitID ?? i)} value={String(u.UnitID ?? "")}>
            {String(u.UnitName ?? "")} — {String(u.ClientName ?? "")}
          </option>
        ))}
      </Select>
    </div>
  );
}

function DeployForm() {
  const [form, setForm] = useState({
    empId: "",
    unitId: "",
    shiftId: "",
    fromDate: isoDate(new Date()),
    remark: "",
    allowOverStrength: false,
    overStrengthReason: "",
  });

  const deploy = useCommand<Record<string, unknown>>({
    path: "/api/v2/deployments",
    invalidate: ["deployments", "turnout-live"],
    successMessage: "Guard deployed",
  });

  return (
    <Card className="grid gap-4 md:grid-cols-2">
      <div>
        <Label required>Employee id</Label>
        <Input
          inputMode="numeric"
          value={form.empId}
          onChange={(e) => setForm((f) => ({ ...f, empId: e.target.value.replace(/\D/g, "") }))}
        />
      </div>
      <UnitSelect value={form.unitId} onChange={(v) => setForm((f) => ({ ...f, unitId: v }))} />
      <MasterSelect label="Shift" set="shifts" value={form.shiftId} onChange={(v) => setForm((f) => ({ ...f, shiftId: v }))} />
      <div>
        <Label required>From</Label>
        <Input type="date" value={form.fromDate} onChange={(e) => setForm((f) => ({ ...f, fromDate: e.target.value }))} />
      </div>

      <div className="md:col-span-2">
        <Label>Remark</Label>
        <TextArea value={form.remark} onChange={(e) => setForm((f) => ({ ...f, remark: e.target.value }))} />
      </div>

      <div className="space-y-2 md:col-span-2">
        <label className="flex items-center gap-2 text-sm text-text">
          <input
            type="checkbox"
            className="size-4 accent-[var(--diti-primary)]"
            checked={form.allowOverStrength}
            onChange={(e) => setForm((f) => ({ ...f, allowOverStrength: e.target.checked }))}
          />
          Deploy even if this takes the site over contracted strength
        </label>
        {form.allowOverStrength ? (
          <div>
            <Label required>Why</Label>
            <Input
              value={form.overStrengthReason}
              onChange={(e) => setForm((f) => ({ ...f, overStrengthReason: e.target.value }))}
            />
            <p className="mt-1 text-xs text-muted">
              Over-strength guards are paid but may not be billable. The reason goes on the record.
            </p>
          </div>
        ) : null}
      </div>

      <div className="md:col-span-2">
        <Button
          loading={deploy.isPending}
          disabled={!form.empId || !form.unitId || (form.allowOverStrength && !form.overStrengthReason)}
          onClick={() =>
            deploy.mutate({
              empId: Number(form.empId),
              unitId: Number(form.unitId),
              shiftId: form.shiftId ? Number(form.shiftId) : undefined,
              fromDate: form.fromDate,
              remark: form.remark || undefined,
              allowOverStrength: form.allowOverStrength,
              overStrengthReason: form.overStrengthReason || undefined,
            })
          }
        >
          Deploy
        </Button>
      </div>
    </Card>
  );
}

function RelieverForm() {
  const [unitId, setUnitId] = useState("");
  const [relieverForEmpId, setRelieverForEmpId] = useState("");

  const available = useQuery({
    queryKey: ["relievers", unitId],
    enabled: Boolean(unitId),
    queryFn: () => getApi().get<Row[]>(`/api/v2/units/${unitId}/relievers`),
  });

  const deploy = useCommand<Record<string, unknown>>({
    path: "/api/v2/deployments",
    invalidate: ["deployments", "turnout-live", "relievers"],
    successMessage: "Reliever sent",
  });

  return (
    <Card className="space-y-4">
      <UnitSelect value={unitId} onChange={setUnitId} />

      <div>
        <Label>Covering for employee id</Label>
        <Input
          inputMode="numeric"
          value={relieverForEmpId}
          onChange={(e) => setRelieverForEmpId(e.target.value.replace(/\D/g, ""))}
        />
      </div>

      {unitId ? (
        <div>
          <h2 className="mb-2 text-sm font-semibold text-muted">Guards available nearby</h2>
          <DataTable
            columns={[
              { id: "emp", header: "Guard", cell: (r) => cell(r, "EmpFullName") },
              { id: "code", header: "Code", cell: (r) => <span className="tabular">{cell(r, "EmpCode")}</span> },
              { id: "unit", header: "Usual site", hideOnMobile: true, cell: (r) => cell(r, "UnitName") },
              {
                id: "act",
                header: "",
                cell: (r) => (
                  <Button
                    size="sm"
                    loading={deploy.isPending}
                    onClick={() =>
                      deploy.mutate({
                        empId: Number(r.EmpID),
                        unitId: Number(unitId),
                        isReliever: true,
                        relieverForEmpId: relieverForEmpId ? Number(relieverForEmpId) : undefined,
                        fromDate: isoDate(new Date()),
                      })
                    }
                  >
                    Send
                  </Button>
                ),
              },
            ]}
            rows={available.data?.data ?? []}
            rowKey={(r, i) => String(r.EmpID ?? i)}
            empty={
              <EmptyState
                title="Nobody available"
                description="No guard is free to cover this site right now. Try a different site or free someone up."
              />
            }
          />
        </div>
      ) : null}
    </Card>
  );
}

function IncDecForm() {
  const [form, setForm] = useState({ unitId: "", changeNos: "", effectiveFrom: isoDate(new Date()), reason: "" });

  const submit = useCommand<Record<string, unknown>>({
    path: "/api/v2/deployments/incdec",
    invalidate: ["deployments", "approvals-incdec"],
    successMessage: "Change submitted for approval",
  });

  return (
    <Card className="space-y-4">
      <UnitSelect value={form.unitId} onChange={(v) => setForm((f) => ({ ...f, unitId: v }))} />

      <div>
        <Label required>Change in guards</Label>
        <Input
          value={form.changeNos}
          placeholder="e.g. 2 to add two, -1 to remove one"
          onChange={(e) => setForm((f) => ({ ...f, changeNos: e.target.value.replace(/[^\d-]/g, "") }))}
        />
        <p className="mt-1 text-xs text-muted">
          This changes what the client is billed for, which is why it needs approval before it
          takes effect.
        </p>
      </div>

      <div>
        <Label required>Effective from</Label>
        <Input
          type="date"
          value={form.effectiveFrom}
          onChange={(e) => setForm((f) => ({ ...f, effectiveFrom: e.target.value }))}
        />
      </div>

      <div>
        <Label required>Reason</Label>
        <TextArea value={form.reason} onChange={(e) => setForm((f) => ({ ...f, reason: e.target.value }))} />
      </div>

      <Button
        loading={submit.isPending}
        disabled={!form.unitId || !form.changeNos || form.reason.trim().length < 5}
        onClick={() =>
          submit.mutate({
            unitId: Number(form.unitId),
            changeNos: Number(form.changeNos),
            effectiveFrom: form.effectiveFrom,
            reason: form.reason.trim(),
          })
        }
      >
        Submit for approval
      </Button>
    </Card>
  );
}

function EndForm() {
  const [form, setForm] = useState({ deploymentId: "", toDate: isoDate(new Date()), remark: "" });

  const end = useCommand<Record<string, unknown>>({
    path: () => `/api/v2/deployments/${form.deploymentId}/end`,
    invalidate: ["deployments", "turnout-live"],
    successMessage: "Deployment ended",
  });

  return (
    <Card className="space-y-4">
      <div>
        <Label required>Deployment id</Label>
        <Input
          inputMode="numeric"
          value={form.deploymentId}
          onChange={(e) => setForm((f) => ({ ...f, deploymentId: e.target.value.replace(/\D/g, "") }))}
        />
        <p className="mt-1 text-xs text-muted">
          From the deployments list. Ending a deployment leaves the post vacant — send a reliever
          instead if the absence is temporary.
        </p>
      </div>

      <div>
        <Label required>Last day</Label>
        <Input type="date" value={form.toDate} onChange={(e) => setForm((f) => ({ ...f, toDate: e.target.value }))} />
      </div>

      <div>
        <Label>Remark</Label>
        <TextArea value={form.remark} onChange={(e) => setForm((f) => ({ ...f, remark: e.target.value }))} />
      </div>

      <Button
        variant="danger"
        loading={end.isPending}
        disabled={!form.deploymentId}
        onClick={() => end.mutate({ toDate: form.toDate, remark: form.remark || undefined })}
      >
        End deployment
      </Button>
    </Card>
  );
}
