"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import {
  Button,
  DataTable,
  EmptyState,
  ErrorState,
  Input,
  Label,
  PageHeader,
  Skeleton,
} from "@diti365/ui";
import { ApiError, type Row, type SpResult } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { cell } from "@/lib/list-query";

export default function PayrollPage() {
  const qc = useQueryClient();
  const [monthYear, setMonthYear] = useState(() => {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
  });
  const [empId, setEmpId] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [validation, setValidation] = useState<Row[][] | null>(null);
  const [slip, setSlip] = useState<Row | null>(null);

  const generate = useMutation({
    mutationFn: async () =>
      (await getApi().post<SpResult>("/api/v2/payroll/runs", { monthYear })).data,
    onSuccess: (res) => setMessage(`${res.message} (run ${res.id})`),
    onError: (err) => setMessage(err instanceof ApiError ? err.message : "Failed"),
  });

  const validate = useMutation({
    // A read, not a command: it changes nothing and answers "what would block a
    // run for this month". The API exposes it as GET /payroll/validate.
    mutationFn: async () =>
      (await getApi().get<Row[][]>("/api/v2/payroll/validate", { monthYear })).data,
    onSuccess: (data) => {
      setValidation(data);
      setMessage("Validation complete");
    },
    onError: (err) => setMessage(err instanceof ApiError ? err.message : "Failed"),
  });

  const loadSlip = useMutation({
    mutationFn: async () =>
      (await getApi().get<Row | null>(`/api/v2/payroll/slips/${empId}/${monthYear}`)).data,
    onSuccess: (data) => setSlip(data),
    onError: (err) => setMessage(err instanceof ApiError ? err.message : "Failed"),
  });

  return (
    <div>
      <PageHeader
        title="Payroll"
        description="Validate and generate payroll from approved attendance. Figures come from the database procedures."
      />
      {message ? <p className="mb-4 text-sm">{message}</p> : null}

      <div className="mb-6 flex flex-wrap items-end gap-3 rounded-[var(--diti-radius-lg)] border border-[var(--diti-border)] bg-[var(--diti-surface)] p-4">
        <div>
          <Label required>Month (YYYY-MM)</Label>
          <Input value={monthYear} onChange={(e) => setMonthYear(e.target.value)} className="w-40" />
        </div>
        <Button variant="outline" loading={validate.isPending} onClick={() => validate.mutate()}>
          Validate
        </Button>
        <Button loading={generate.isPending} onClick={() => generate.mutate()}>
          Generate run
        </Button>
        <div>
          <Label>Emp id for slip</Label>
          <Input value={empId} onChange={(e) => setEmpId(e.target.value)} className="w-28" />
        </div>
        <Button variant="secondary" loading={loadSlip.isPending} disabled={!empId} onClick={() => loadSlip.mutate()}>
          Load slip
        </Button>
      </div>

      {validation ? (
        <div className="mb-8">
          <h2 className="mb-3 text-sm font-semibold text-[var(--diti-muted)]">Validation sets</h2>
          {validation.map((rows, idx) => (
            <div key={idx} className="mb-4">
              <DataTable
                columns={
                  rows[0]
                    ? Object.keys(rows[0]).slice(0, 8).map((key) => ({
                        id: key,
                        header: key,
                        cell: (r: Row) => String(r[key] ?? "—"),
                      }))
                    : []
                }
                rows={rows}
                rowKey={(_, i) => `${idx}-${i}`}
                empty={<EmptyState title="Empty validation set" />}
              />
            </div>
          ))}
        </div>
      ) : null}

      {slip ? (
        <div className="rounded-[var(--diti-radius-lg)] border border-[var(--diti-border)] bg-[var(--diti-surface)] p-4">
          <h2 className="mb-3 text-sm font-semibold">Salary slip</h2>
          <dl className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
            {Object.entries(slip).map(([k, v]) => (
              <div key={k}>
                <dt className="text-xs text-[var(--diti-muted)]">{k}</dt>
                <dd className="text-sm font-medium">{String(v ?? "—")}</dd>
              </div>
            ))}
          </dl>
        </div>
      ) : null}

      {/* keep qc referenced for future lock/register */}
      <span className="hidden">{String(!!qc)}</span>
    </div>
  );
}
