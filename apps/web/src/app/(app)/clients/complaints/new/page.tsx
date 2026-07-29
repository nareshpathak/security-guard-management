"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Card, Input, Label, PageHeader, Select, TextArea } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { useCommand } from "@/lib/use-command";

/** Logging a complaint on a client's behalf, usually after a phone call. */
export default function NewComplaintPage() {
  const router = useRouter();

  const types = useQuery({
    queryKey: ["complaint-types"],
    queryFn: () => getApi().get<Row[]>("/api/v2/masters/complaint-types"),
    staleTime: Infinity,
  });

  const units = useQuery({
    queryKey: ["units-for-select"],
    queryFn: () => getApi().get<Row[]>("/api/v2/units", { page: 1, pageSize: 200 }),
    staleTime: 5 * 60 * 1000,
  });

  const [typeId, setTypeId] = useState("");

  // Two-level lookup: sub-types hang off the chosen complaint type.
  const subTypes = useQuery({
    queryKey: ["lookup", "ComplaintSubType", typeId],
    enabled: Boolean(typeId),
    queryFn: () => getApi().get<Row[]>(`/api/v2/masters/lookup/ComplaintSubType/${typeId}`),
    staleTime: 10 * 60 * 1000,
  });

  const [form, setForm] = useState({
    unitId: "",
    complaintTypeId: "",
    complaintSubTypeId: "",
    subject: "",
    description: "",
    raisedBy: "",
  });

  const save = useCommand<Record<string, unknown>>({
    path: "/api/v2/complaints",
    invalidate: ["complaints", "approvals-complaints", "clients"],
    successMessage: "Complaint logged. The site supervisor is notified.",
    onDone: () => router.push("/clients/complaints"),
  });

  return (
    <div className="max-w-2xl">
      <PageHeader
        title="Log a complaint"
        description="Raised by a client, usually on the phone. The clock starts now."
        actions={
          <Button variant="outline" onClick={() => router.push("/clients/complaints")}>
            Back
          </Button>
        }
      />

      <Card className="grid gap-4 md:grid-cols-2">
        <div>
          <Label required>Site</Label>
          <Select value={form.unitId} onChange={(e) => setForm((f) => ({ ...f, unitId: e.target.value }))}>
            <option value="">Choose a site…</option>
            {(units.data?.data ?? []).map((u, i) => (
              <option key={String(u.UnitID ?? i)} value={String(u.UnitID ?? "")}>
                {String(u.UnitName ?? "")} — {String(u.ClientName ?? "")}
              </option>
            ))}
          </Select>
        </div>

        <div>
          <Label required>Type</Label>
          <Select
            value={form.complaintTypeId}
            onChange={(e) => {
              setForm((f) => ({ ...f, complaintTypeId: e.target.value, complaintSubTypeId: "" }));
              setTypeId(e.target.value);
            }}
          >
            <option value="">Choose a type…</option>
            {(types.data?.data ?? []).map((t, i) => (
              <option key={String(t.ComplaintTypeID ?? i)} value={String(t.ComplaintTypeID ?? "")}>
                {String(t.ComplaintTypeName ?? t.TypeName ?? "")}
              </option>
            ))}
          </Select>
        </div>

        <div>
          <Label>Sub-type</Label>
          <Select
            value={form.complaintSubTypeId}
            disabled={!form.complaintTypeId}
            onChange={(e) => setForm((f) => ({ ...f, complaintSubTypeId: e.target.value }))}
          >
            <option value="">{form.complaintTypeId ? "Optional" : "Pick a type first"}</option>
            {(subTypes.data?.data ?? []).map((t, i) => (
              <option key={String(t.Id ?? t.ID ?? i)} value={String(t.Id ?? t.ID ?? "")}>
                {String(t.Name ?? t.TypeName ?? "")}
              </option>
            ))}
          </Select>
        </div>

        <div className="md:col-span-2">
          <Label required>Subject</Label>
          <Input value={form.subject} maxLength={150} onChange={(e) => setForm((f) => ({ ...f, subject: e.target.value }))} />
        </div>

        <div className="md:col-span-2">
          <Label required>What was said</Label>
          <TextArea
            value={form.description}
            onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
            placeholder="In the client's words where you can. This is what the supervisor will act on."
          />
        </div>

        <div>
          <Label>Raised by</Label>
          <Input value={form.raisedBy} onChange={(e) => setForm((f) => ({ ...f, raisedBy: e.target.value }))} />
        </div>

        <div className="md:col-span-2">
          <Button
            loading={save.isPending}
            disabled={!form.unitId || !form.subject || form.description.trim().length < 10}
            onClick={() =>
              save.mutate({
                unitId: Number(form.unitId),
                complaintTypeId: form.complaintTypeId ? Number(form.complaintTypeId) : undefined,
                complaintSubTypeId: form.complaintSubTypeId ? Number(form.complaintSubTypeId) : undefined,
                subject: form.subject.trim(),
                description: form.description.trim(),
                raisedBy: form.raisedBy.trim() || undefined,
              })
            }
          >
            Log complaint
          </Button>
        </div>
      </Card>
    </div>
  );
}
