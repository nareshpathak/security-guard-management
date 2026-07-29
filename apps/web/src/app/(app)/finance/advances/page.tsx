"use client";

import { useMutation } from "@tanstack/react-query";
import { useState } from "react";
import { Button, Input, Label, PageHeader } from "@diti365/ui";
import { ApiError, type SpResult } from "@diti365/shared";
import { getApi } from "@/lib/api";

export default function AdvancesPage() {
  const [form, setForm] = useState({ empId: "", amount: "", reason: "" });
  const [message, setMessage] = useState<string | null>(null);

  const create = useMutation({
    mutationFn: async () =>
      (await getApi().post<SpResult>("/api/v2/advances", {
        empId: Number(form.empId),
        amount: Number(form.amount),
        reason: form.reason || undefined,
      })).data,
    onSuccess: (res) => {
      setMessage(`${res.message} (id ${res.id})`);
      setForm({ empId: "", amount: "", reason: "" });
    },
    onError: (err) => setMessage(err instanceof ApiError ? err.message : "Failed"),
  });

  return (
    <div>
      <PageHeader title="Advances" description="Record salary advances. Recovery is applied in payroll procedures." />
      {message ? <p className="mb-4 text-sm">{message}</p> : null}
      <div className="grid max-w-xl gap-3 rounded-[var(--diti-radius-lg)] border border-[var(--diti-border)] bg-[var(--diti-surface)] p-4">
        <div>
          <Label required>Employee id</Label>
          <Input value={form.empId} onChange={(e) => setForm((f) => ({ ...f, empId: e.target.value }))} />
        </div>
        <div>
          <Label required>Amount</Label>
          <Input value={form.amount} onChange={(e) => setForm((f) => ({ ...f, amount: e.target.value }))} />
        </div>
        <div>
          <Label>Reason</Label>
          <Input value={form.reason} onChange={(e) => setForm((f) => ({ ...f, reason: e.target.value }))} />
        </div>
        <Button
          loading={create.isPending}
          disabled={!form.empId || !form.amount}
          onClick={() => create.mutate()}
        >
          Record advance
        </Button>
      </div>
    </div>
  );
}
