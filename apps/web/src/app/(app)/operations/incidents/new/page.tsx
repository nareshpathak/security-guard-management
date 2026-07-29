"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Card, Input, Label, PageHeader, Select, TextArea } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { useCommand } from "@/lib/use-command";
import { isoDate } from "@/lib/format";

const SEVERITY = ["Low", "Medium", "High", "Critical"];

/**
 * Recording an incident from the console, usually because it came in by phone
 * before anyone filed it on the app.
 *
 * The type list comes from the generic lookup endpoint rather than the
 * bootstrap: incident types are tenant-configurable and change more often than
 * the rest of the reference data.
 */
export default function NewIncidentPage() {
  const router = useRouter();

  const types = useQuery({
    queryKey: ["lookup", "IncidentType"],
    queryFn: () => getApi().get<Row[]>("/api/v2/masters/lookup/IncidentType"),
    staleTime: 10 * 60 * 1000,
  });

  const units = useQuery({
    queryKey: ["units-for-select"],
    queryFn: () => getApi().get<Row[]>("/api/v2/units", { page: 1, pageSize: 200 }),
    staleTime: 5 * 60 * 1000,
  });

  const [form, setForm] = useState({
    unitId: "",
    incidentTypeId: "",
    incidentDate: isoDate(new Date()),
    severity: "Medium",
    empId: "",
    description: "",
  });

  const save = useCommand<Record<string, unknown>>({
    path: "/api/v2/incidents",
    invalidate: ["incidents", "approvals-incidents"],
    successMessage: "Incident recorded",
    onDone: () => router.push("/operations/incidents"),
  });

  return (
    <div className="max-w-2xl">
      <PageHeader
        title="Record an incident"
        description="Something that went wrong at a site. Write it while the details are fresh."
        actions={
          <Button variant="outline" onClick={() => router.push("/operations/incidents")}>
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
            value={form.incidentTypeId}
            onChange={(e) => setForm((f) => ({ ...f, incidentTypeId: e.target.value }))}
          >
            <option value="">Choose a type…</option>
            {(types.data?.data ?? []).map((t, i) => (
              <option key={String(t.Id ?? t.ID ?? i)} value={String(t.Id ?? t.ID ?? "")}>
                {String(t.Name ?? t.TypeName ?? "")}
              </option>
            ))}
          </Select>
        </div>

        <div>
          <Label required>When</Label>
          <Input
            type="date"
            value={form.incidentDate}
            onChange={(e) => setForm((f) => ({ ...f, incidentDate: e.target.value }))}
          />
        </div>

        <div>
          <Label required>How serious</Label>
          <Select value={form.severity} onChange={(e) => setForm((f) => ({ ...f, severity: e.target.value }))}>
            {SEVERITY.map((s) => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </Select>
        </div>

        <div>
          <Label>Guard involved (employee id)</Label>
          <Input
            inputMode="numeric"
            value={form.empId}
            onChange={(e) => setForm((f) => ({ ...f, empId: e.target.value.replace(/\D/g, "") }))}
          />
        </div>

        <div className="md:col-span-2">
          <Label required>What happened</Label>
          <TextArea
            value={form.description}
            onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
            placeholder="Times, names, what was done. This is the record if it is ever questioned."
          />
        </div>

        <div className="md:col-span-2">
          <Button
            loading={save.isPending}
            disabled={!form.unitId || form.description.trim().length < 15}
            onClick={() =>
              save.mutate({
                unitId: Number(form.unitId),
                incidentTypeId: form.incidentTypeId ? Number(form.incidentTypeId) : undefined,
                incidentDate: form.incidentDate,
                severity: form.severity,
                empId: form.empId ? Number(form.empId) : undefined,
                description: form.description.trim(),
              })
            }
          >
            Record incident
          </Button>
        </div>
      </Card>
    </div>
  );
}
