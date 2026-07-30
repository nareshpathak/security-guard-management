"use client";

import { useParams, useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { Button, Card, ErrorState, Input, Label, PageHeader, Skeleton } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Status } from "@/components/status";
import { Modal } from "@/components/modal";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";

export default function EmployeeFamilyPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);
  const router = useRouter();
  const { has } = useAuth();
  const canEdit = has(Perm.employeeEdit);

  const [adding, setAdding] = useState(false);
  const [form, setForm] = useState({ name: "", relation: "", mobileNo: "", isNominee: false });

  const detail = useQuery({
    queryKey: ["employee", id],
    enabled: Number.isFinite(id) && id > 0,
    queryFn: () => getApi().get<Row[][]>(`/api/v2/employees/${id}`),
  });

  const add = useCommand<typeof form>({
    path: `/api/v2/employees/${id}/family`,
    invalidate: ["employee"],
    successMessage: "Family member added",
    onDone: () => {
      setAdding(false);
      setForm({ name: "", relation: "", mobileNo: "", isNominee: false });
    },
  });

  if (detail.isLoading) return <Skeleton className="h-96" />;
  if (detail.isError)
    return (
      <ErrorState
        message={detail.error instanceof Error ? detail.error.message : "Could not load employee details."}
        onRetry={() => detail.refetch()}
      />
    );

  const sets = detail.data?.data ?? [];
  const core = sets[0]?.[0] ?? {};
  const family = sets[2] ?? [];

  return (
    <div>
      <PageHeader
        title={`Family Details — ${String(core.EmpFullName ?? `Employee ${id}`)}`}
        description="Dependents, emergency contacts, and nominees for insurance and statutory claims."
        actions={
          <Button variant="outline" onClick={() => router.push(`/people/employees/${id}`)}>
            Back to Employee 360
          </Button>
        }
      />

      <Card className="mb-4 divide-y divide-border">
        {family.length === 0 ? (
          <p className="py-4 text-sm text-muted">
            Nobody recorded yet. Add family members and designate nominees for emergency contacts.
          </p>
        ) : (
          family.map((m: Row, i: number) => (
            <div key={i} className="flex items-center justify-between gap-4 py-3 first:pt-0 last:pb-0">
              <div>
                <div className="font-medium text-text">{String(m.Name ?? "")}</div>
                <div className="text-xs text-muted">
                  {String(m.Relation ?? "")} · {String(m.MobileNo ?? "—")}
                </div>
              </div>
              {m.IsNominee ? <Status value="Nominee" /> : null}
            </div>
          ))
        )}
      </Card>

      {canEdit ? <Button onClick={() => setAdding(true)}>Add family member</Button> : null}

      <Modal
        open={adding}
        onOpenChange={setAdding}
        title="Add family member"
        footer={
          <Button loading={add.isPending} disabled={!form.name || !form.relation} onClick={() => add.mutate(form)}>
            Add
          </Button>
        }
      >
        <div className="space-y-4">
          <div>
            <Label required>Name</Label>
            <Input value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} />
          </div>
          <div>
            <Label required>Relation</Label>
            <Input value={form.relation} onChange={(e) => setForm((f) => ({ ...f, relation: e.target.value }))} />
          </div>
          <div>
            <Label>Mobile Number</Label>
            <Input value={form.mobileNo} onChange={(e) => setForm((f) => ({ ...f, mobileNo: e.target.value }))} />
          </div>
          <label className="flex items-center gap-2 text-sm text-text">
            <input
              type="checkbox"
              className="size-4 accent-[var(--diti-primary)]"
              checked={form.isNominee}
              onChange={(e) => setForm((f) => ({ ...f, isNominee: e.target.checked }))}
            />
            This person is the nominee
          </label>
        </div>
      </Modal>
    </div>
  );
}
