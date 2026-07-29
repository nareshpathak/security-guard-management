"use client";

import { useQuery } from "@tanstack/react-query";
import { useParams, useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Card, DataTable, EmptyState, ErrorState, Input, Label, PageHeader, Skeleton } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Status } from "@/components/status";
import { Modal } from "@/components/modal";
import { MasterSelect } from "@/components/master-select";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";
import { cell } from "@/lib/list-query";
import { count, isoDate } from "@/lib/format";

/**
 * One site: its posts, its patrol locations, and how it is doing today.
 *
 * Posts are what the client is billed for and what the roster is measured
 * against. Locations are the physical spots a patrol has to reach. Both live
 * here because both are answers to "what did we agree to guard".
 */
export default function UnitDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { has } = useAuth();
  const [addingPost, setAddingPost] = useState(false);
  const [addingLocation, setAddingLocation] = useState(false);

  const canEdit = has(Perm.clientEdit);

  const units = useQuery({
    queryKey: ["units", id],
    queryFn: () => getApi().get<Row[]>("/api/v2/units", { page: 1, pageSize: 200 }),
  });

  const roster = useQuery({
    queryKey: ["unit-roster", id],
    queryFn: () => getApi().get<Row[]>(`/api/v2/units/${id}/employees`),
  });

  const unit = (units.data?.data ?? []).find((u) => String(u.UnitID) === String(id));

  const [post, setPost] = useState({
    postName: "",
    designationId: "",
    shiftId: "",
    requiredStrength: "1",
    ratePerGuard: "",
    isArmed: false,
    effectiveFrom: isoDate(new Date()),
  });

  const [location, setLocation] = useState({ name: "", latitude: "", longitude: "", description: "" });

  const savePost = useCommand<Record<string, unknown>>({
    path: `/api/v2/units/${id}/posts`,
    invalidate: ["units", "turnout-live"],
    successMessage: "Post saved",
    onDone: () => setAddingPost(false),
  });

  const saveLocation = useCommand<Record<string, unknown>>({
    path: `/api/v2/units/${id}/locations`,
    invalidate: ["units"],
    successMessage: "Location saved",
    onDone: () => setAddingLocation(false),
  });

  if (units.isLoading) return <Skeleton className="h-96" />;
  if (units.isError)
    return (
      <ErrorState
        message={units.error instanceof Error ? units.error.message : "Could not load this site."}
        onRetry={() => units.refetch()}
      />
    );

  if (!unit) return <ErrorState title="Site not found" message="It may have been cancelled." />;

  const gap = Number(unit.RequiredStrength ?? 0) - Number(unit.DeployedNos ?? 0);

  return (
    <div>
      <PageHeader
        title={String(unit.UnitName ?? `Site ${id}`)}
        description={`${cell(unit, "ClientName")} · ${cell(unit, "Address")}`}
        actions={
          <div className="flex gap-2">
            <Button variant="outline" onClick={() => router.push("/clients/units")}>
              Back
            </Button>
            {canEdit ? (
              <>
                <Button variant="outline" onClick={() => setAddingLocation(true)}>
                  Add location
                </Button>
                <Button onClick={() => setAddingPost(true)}>Add post</Button>
              </>
            ) : null}
          </div>
        }
      />

      <div className="mb-8 grid gap-4 sm:grid-cols-4">
        <Card>
          <div className="text-xs uppercase tracking-wide text-muted">Contracted</div>
          <div className="tabular mt-2 text-2xl font-semibold">{count(unit.RequiredStrength)}</div>
        </Card>
        <Card>
          <div className="text-xs uppercase tracking-wide text-muted">Deployed</div>
          <div className="tabular mt-2 text-2xl font-semibold">{count(unit.DeployedNos)}</div>
        </Card>
        <Card>
          <div className="text-xs uppercase tracking-wide text-muted">Short by</div>
          <div className={`tabular mt-2 text-2xl font-semibold ${gap > 0 ? "text-danger" : "text-success"}`}>
            {gap > 0 ? gap : 0}
          </div>
        </Card>
        <Card>
          <div className="text-xs uppercase tracking-wide text-muted">Checkpoints</div>
          <div className="tabular mt-2 text-2xl font-semibold">{count(unit.CheckpointCount)}</div>
        </Card>
      </div>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold text-muted">Who is here today</h2>
        {roster.isLoading ? (
          <Skeleton className="h-48" />
        ) : (
          <DataTable
            columns={[
              { id: "emp", header: "Guard", cell: (r) => cell(r, "EmpFullName") },
              { id: "code", header: "Code", hideOnMobile: true, cell: (r) => <span className="tabular">{cell(r, "EmpCode")}</span> },
              { id: "desig", header: "Designation", hideOnMobile: true, cell: (r) => cell(r, "DesignationName") },
              { id: "shift", header: "Shift", cell: (r) => cell(r, "ShiftName") },
              { id: "status", header: "Today", cell: (r) => <Status value={r.Status ?? "Not marked"} /> },
            ]}
            rows={roster.data?.data ?? []}
            rowKey={(r, i) => String(r.EmpID ?? i)}
            onRowClick={(r) => router.push(`/people/employees/${r.EmpID}`)}
            empty={<EmptyState title="Nobody deployed here" description="Deploy a guard from Operations." />}
          />
        )}
      </section>

      <Modal
        open={addingPost}
        onOpenChange={setAddingPost}
        title="Add a post"
        description="A post is one guard's position on one shift. This is what the client is billed for."
        footer={
          <Button
            loading={savePost.isPending}
            disabled={!post.postName || !post.requiredStrength}
            onClick={() =>
              savePost.mutate({
                postName: post.postName,
                designationId: post.designationId ? Number(post.designationId) : undefined,
                shiftId: post.shiftId ? Number(post.shiftId) : undefined,
                requiredStrength: Number(post.requiredStrength),
                ratePerGuard: post.ratePerGuard ? Number(post.ratePerGuard) : undefined,
                isArmed: post.isArmed,
                effectiveFrom: post.effectiveFrom,
              })
            }
          >
            Add post
          </Button>
        }
      >
        <div>
          <Label required>Post name</Label>
          <Input
            value={post.postName}
            placeholder="Main gate, Reception, Rear gate…"
            onChange={(e) => setPost((p) => ({ ...p, postName: e.target.value }))}
          />
        </div>
        <MasterSelect label="Designation" set="designations" value={post.designationId} onChange={(v) => setPost((p) => ({ ...p, designationId: v }))} />
        <MasterSelect label="Shift" set="shifts" value={post.shiftId} onChange={(v) => setPost((p) => ({ ...p, shiftId: v }))} />
        <div>
          <Label required>Guards needed</Label>
          <Input
            inputMode="numeric"
            value={post.requiredStrength}
            onChange={(e) => setPost((p) => ({ ...p, requiredStrength: e.target.value.replace(/\D/g, "") }))}
          />
        </div>
        <div>
          <Label>Rate per guard</Label>
          <Input
            type="number"
            step="0.01"
            value={post.ratePerGuard}
            onChange={(e) => setPost((p) => ({ ...p, ratePerGuard: e.target.value }))}
          />
        </div>
        <label className="flex items-center gap-2 text-sm text-text">
          <input
            type="checkbox"
            className="size-4 accent-[var(--diti-primary)]"
            checked={post.isArmed}
            onChange={(e) => setPost((p) => ({ ...p, isArmed: e.target.checked }))}
          />
          This post is armed
        </label>
        {post.isArmed ? (
          <p className="rounded-md bg-warning-subtle px-3 py-2 text-xs text-warning">
            Only guards with a current gun licence may be deployed to an armed post.
          </p>
        ) : null}
      </Modal>

      <Modal
        open={addingLocation}
        onOpenChange={setAddingLocation}
        title="Add a patrol location"
        description="A physical spot a patrol has to reach. Checkpoints are attached to these."
        footer={
          <Button
            loading={saveLocation.isPending}
            disabled={!location.name}
            onClick={() =>
              saveLocation.mutate({
                name: location.name,
                latitude: location.latitude ? Number(location.latitude) : undefined,
                longitude: location.longitude ? Number(location.longitude) : undefined,
                description: location.description || undefined,
              })
            }
          >
            Add location
          </Button>
        }
      >
        <div>
          <Label required>Name</Label>
          <Input
            value={location.name}
            placeholder="Basement stairwell, Roof access…"
            onChange={(e) => setLocation((l) => ({ ...l, name: e.target.value }))}
          />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <Label>Latitude</Label>
            <Input value={location.latitude} onChange={(e) => setLocation((l) => ({ ...l, latitude: e.target.value }))} />
          </div>
          <div>
            <Label>Longitude</Label>
            <Input value={location.longitude} onChange={(e) => setLocation((l) => ({ ...l, longitude: e.target.value }))} />
          </div>
        </div>
        <p className="text-xs text-muted">
          Coordinates are optional but without them a scan here cannot be checked against a
          distance.
        </p>
      </Modal>
    </div>
  );
}
