"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useParams, useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button, ErrorState, PageHeader, Skeleton } from "@diti365/ui";
import { ApiError, type Row, type SpResult } from "@diti365/shared";
import { Status } from "@/components/status";
import { getApi } from "@/lib/api";
import { cell } from "@/lib/list-query";
import { date, dateTime } from "@/lib/format";

export default function TaskDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const qc = useQueryClient();

  const task = useQuery({
    queryKey: ["task", id],
    // Three result sets: the task, its checklist, its history.
    queryFn: () => getApi().get<Row[][]>(`/api/v2/tasks/${id}`),
  });

  const toggle = useMutation({
    mutationFn: async (checklistId: number) =>
      (await getApi().post<SpResult>(`/api/v2/tasks/checklist/${checklistId}`, {})).data,
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ["task", id] });
    },
    onError: (err) => toast.error(err instanceof ApiError ? err.message : "Could not update the checklist."),
  });

  const setStatus = useMutation({
    mutationFn: async (status: string) =>
      (await getApi().post<SpResult>(`/api/v2/tasks/${id}/status`, { status })).data,
    onSuccess: async (res) => {
      toast.success(res.message || "Task updated");
      await qc.invalidateQueries({ queryKey: ["task", id] });
      await qc.invalidateQueries({ queryKey: ["tasks"] });
    },
    onError: (err) => toast.error(err instanceof ApiError ? err.message : "Could not update this task."),
  });

  if (task.isLoading) return <Skeleton className="h-64" />;
  if (task.isError)
    return (
      <ErrorState
        message={task.error instanceof Error ? task.error.message : "Could not load this task."}
        onRetry={() => task.refetch()}
      />
    );

  const [details = [], checklist = [], history = []] = task.data?.data ?? [];
  const t = details[0];
  if (!t) return <ErrorState title="Task not found" message="It may have been deleted." />;

  const status = String(t.Status ?? "").toLowerCase();
  const done = ["completed", "done", "closed"].includes(status);

  return (
    <div className="max-w-3xl">
      <PageHeader
        title={String(t.Heading ?? t.Title ?? `Task ${id}`)}
        description={`${cell(t, "UnitName")} · raised ${date(t.InsertDate)}`}
        actions={
          <div className="flex gap-2">
            <Button variant="outline" onClick={() => router.push("/tasks")}>
              Back
            </Button>
            {!done ? (
              <Button
                loading={setStatus.isPending}
                onClick={() => setStatus.mutate(status === "new" ? "In Progress" : "Completed")}
              >
                {status === "new" ? "Start" : "Mark complete"}
              </Button>
            ) : null}
          </div>
        }
      />

      <dl className="mb-6 grid gap-4 rounded-xl border border-border bg-surface p-5 shadow-sm sm:grid-cols-3">
        <div>
          <dt className="text-xs uppercase tracking-wide text-muted">Status</dt>
          <dd className="mt-1"><Status value={t.Status} /></dd>
        </div>
        <div>
          <dt className="text-xs uppercase tracking-wide text-muted">Assigned to</dt>
          <dd className="mt-1 text-sm">{cell(t, "AssignedToName", "EmpFullName")}</dd>
        </div>
        <div>
          <dt className="text-xs uppercase tracking-wide text-muted">Due</dt>
          <dd className="mt-1 tabular text-sm">{date(t.DueDate ?? t.TargetDate)}</dd>
        </div>
        <div className="sm:col-span-3">
          <dt className="text-xs uppercase tracking-wide text-muted">Description</dt>
          <dd className="mt-1 whitespace-pre-wrap text-sm">{cell(t, "Description", "Remark")}</dd>
        </div>
      </dl>

      {checklist.length > 0 ? (
        <section className="mb-6">
          <h2 className="mb-3 text-sm font-semibold text-muted">Checklist</h2>
          <ul className="divide-y divide-border rounded-xl border border-border bg-surface">
            {checklist.map((c, i) => {
              const checked = c.IsDone === true || c.IsDone === 1;
              return (
                <li key={String(c.ChecklistID ?? i)} className="flex items-center gap-3 px-4 py-3">
                  <input
                    type="checkbox"
                    className="size-4 accent-[var(--diti-primary)]"
                    checked={checked}
                    disabled={done || toggle.isPending}
                    onChange={() => toggle.mutate(Number(c.ChecklistID))}
                    id={`chk-${c.ChecklistID}`}
                  />
                  <label
                    htmlFor={`chk-${c.ChecklistID}`}
                    className={checked ? "text-sm text-muted line-through" : "text-sm"}
                  >
                    {cell(c, "ItemText", "Title", "Description")}
                  </label>
                </li>
              );
            })}
          </ul>
        </section>
      ) : null}

      {history.length > 0 ? (
        <section>
          <h2 className="mb-3 text-sm font-semibold text-muted">History</h2>
          <ol className="space-y-3 border-l border-border pl-5">
            {history.map((h, i) => (
              <li key={i} className="relative">
                <span className="absolute -left-[23px] top-1.5 size-2 rounded-full bg-primary" />
                <div className="text-sm">
                  <Status value={h.ToStatus ?? h.Status} />
                  <span className="ml-2 text-muted">{cell(h, "ChangedByName", "UserName")}</span>
                </div>
                <div className="tabular text-xs text-muted">{dateTime(h.ChangedOn ?? h.InsertDate)}</div>
                {h.Remark ? <p className="mt-1 text-sm">{String(h.Remark)}</p> : null}
              </li>
            ))}
          </ol>
        </section>
      ) : null}
    </div>
  );
}
