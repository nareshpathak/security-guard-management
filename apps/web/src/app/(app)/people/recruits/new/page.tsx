"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Card, Input, Label, PageHeader, TextArea } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { MasterSelect } from "@/components/master-select";
import { getApi } from "@/lib/api";
import { useCommand } from "@/lib/use-command";

/**
 * Adding a recruit.
 *
 * The duplicate check runs as soon as a full mobile or Aadhaar is typed. The
 * legacy database has the same man entered four times under three spellings,
 * which is how one person ends up on two payrolls.
 */
export default function NewRecruitPage() {
  const router = useRouter();
  const [form, setForm] = useState({
    name: "",
    fatherName: "",
    mobile: "",
    aadhaar: "",
    designationId: "",
    qualificationId: "",
    remark: "",
  });

  const duplicate = useQuery({
    queryKey: ["recruit-duplicate", form.mobile, form.aadhaar],
    enabled: form.mobile.length === 10 || form.aadhaar.length === 12,
    queryFn: () =>
      getApi().get<Row[]>("/api/v2/recruits/check-duplicate", {
        mobile: form.mobile.length === 10 ? form.mobile : undefined,
        aadhaar: form.aadhaar.length === 12 ? form.aadhaar : undefined,
      }),
  });

  const save = useCommand<Record<string, unknown>>({
    path: "/api/v2/recruits",
    invalidate: ["recruits"],
    successMessage: "Recruit added",
    onDone: () => router.push("/people/recruits"),
  });

  const matches = duplicate.data?.data ?? [];

  return (
    <div className="max-w-2xl">
      <PageHeader
        title="New recruit"
        description="The start of the pipeline. Verification and documents come later."
        actions={
          <Button variant="outline" onClick={() => router.push("/people/recruits")}>
            Back
          </Button>
        }
      />

      {matches.length > 0 ? (
        <div
          role="alert"
          className="mb-6 rounded-lg border border-warning/30 bg-warning-subtle px-4 py-3 text-sm text-warning"
        >
          <strong>{matches.length} existing record{matches.length === 1 ? "" : "s"} match</strong> this
          mobile or Aadhaar:
          <ul className="mt-2 list-disc pl-5">
            {matches.slice(0, 3).map((m, i) => (
              <li key={i}>
                {String(m.EmpFullName ?? m.Name ?? "")} — {String(m.EmpCode ?? m.Status ?? "")}
                {m.IsBlacklisted ? " (blacklisted)" : ""}
              </li>
            ))}
          </ul>
          <p className="mt-2">Check before adding. A duplicate is how one person ends up on two payrolls.</p>
        </div>
      ) : null}

      <Card className="grid gap-4 md:grid-cols-2">
        <div>
          <Label required>Full name</Label>
          <Input value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} />
        </div>
        <div>
          <Label>Father&rsquo;s name</Label>
          <Input value={form.fatherName} onChange={(e) => setForm((f) => ({ ...f, fatherName: e.target.value }))} />
        </div>
        <div>
          <Label required>Mobile</Label>
          <Input
            inputMode="tel"
            maxLength={10}
            value={form.mobile}
            onChange={(e) => setForm((f) => ({ ...f, mobile: e.target.value.replace(/\D/g, "") }))}
          />
        </div>
        <div>
          <Label>Aadhaar</Label>
          <Input
            inputMode="numeric"
            maxLength={12}
            value={form.aadhaar}
            onChange={(e) => setForm((f) => ({ ...f, aadhaar: e.target.value.replace(/\D/g, "") }))}
          />
        </div>

        <MasterSelect
          label="Designation applied for"
          set="designations"
          value={form.designationId}
          onChange={(v) => setForm((f) => ({ ...f, designationId: v }))}
        />
        <MasterSelect
          label="Qualification"
          set="qualifications"
          value={form.qualificationId}
          onChange={(v) => setForm((f) => ({ ...f, qualificationId: v }))}
        />

        <div className="md:col-span-2">
          <Label>Remark</Label>
          <TextArea value={form.remark} onChange={(e) => setForm((f) => ({ ...f, remark: e.target.value }))} />
        </div>

        <div className="md:col-span-2">
          <Button
            loading={save.isPending}
            disabled={form.name.trim().length < 3 || form.mobile.length !== 10}
            onClick={() =>
              save.mutate({
                name: form.name.trim(),
                fatherName: form.fatherName.trim() || undefined,
                mobile: form.mobile,
                aadhaar: form.aadhaar || undefined,
                designationId: form.designationId ? Number(form.designationId) : undefined,
                qualificationId: form.qualificationId ? Number(form.qualificationId) : undefined,
                remark: form.remark || undefined,
              })
            }
          >
            Add recruit
          </Button>
        </div>
      </Card>
    </div>
  );
}
