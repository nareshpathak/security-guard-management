"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useSearchParams } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@diti365/ui";
import { ApiError, type SpResult } from "@diti365/shared";
import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { getApi } from "@/lib/api";
import { cell, useListQueryState } from "@/lib/list-query";
import { date } from "@/lib/format";

type Scope = "assigned-to-me" | "assigned-by-me" | "all";

export default function TasksPage() {
  const qc = useQueryClient();
  const params = useSearchParams();
  const q = useListQueryState();
  const scope = (params.get("scope") as Scope) ?? "assigned-to-me";

  const setStatus = useMutation({
    mutationFn: async ({ id, status }: { id: number; status: string }) =>
      (await getApi().post<SpResult>(`/api/v2/tasks/${id}/status`, { status })).data,
    onSuccess: async (res) => {
      toast.success(res.message || "Task updated");
      await qc.invalidateQueries({ queryKey: ["tasks"] });
    },
    onError: (err) =>
      toast.error(err instanceof ApiError ? err.message : "Could not update this task."),
  });

  const scopes: { id: Scope; label: string }[] = [
    { id: "assigned-to-me", label: "Assigned to me" },
    { id: "assigned-by-me", label: "Raised by me" },
    { id: "all", label: "All" },
  ];

  return (
    <ResourceList
      title="Tasks"
      description="Work assigned across the agency, with what is overdue called out."
      actions={
        <div className="flex gap-2">
          {scopes.map((s) => (
            <Button
              key={s.id}
              size="sm"
              variant={scope === s.id ? "primary" : "outline"}
              onClick={() =>
                q.setParams({ scope: s.id === "assigned-to-me" ? undefined : s.id, page: 1 })
              }
            >
              {s.label}
            </Button>
          ))}
        </div>
      }
      path="/api/v2/tasks"
      queryKey="tasks"
      params={{ scope }}
      searchPlaceholder="Heading or description…"
      rowKey={(r, i) => String(r.TaskID ?? i)}
      emptyTitle={scope === "assigned-to-me" ? "Nothing assigned to you" : "No tasks"}
      emptyDescription="Tasks are raised against a site or a person and tracked to completion."
      columns={[
        {
          id: "heading",
          header: "Task",
          cell: (r) => (
            <div>
              <div className="font-medium text-text">{cell(r, "Heading", "Title")}</div>
              <div className="text-xs text-muted">{cell(r, "UnitName")}</div>
            </div>
          ),
        },
        {
          id: "assigned",
          header: "Assigned to",
          hideOnMobile: true,
          cell: (r) => cell(r, "AssignedToName", "EmpFullName"),
        },
        {
          id: "due",
          header: "Due",
          cell: (r) => {
            const due = r.DueDate ?? r.TargetDate;
            if (!due) return <span className="text-muted">—</span>;
            const overdue =
              new Date(String(due)) < new Date() &&
              !["completed", "done", "closed"].includes(String(r.Status ?? "").toLowerCase());
            return (
              <span className={overdue ? "tabular font-medium text-danger" : "tabular"}>
                {date(due)}
              </span>
            );
          },
        },
        {
          id: "priority",
          header: "Priority",
          hideOnMobile: true,
          cell: (r) => <Status value={r.Priority} />,
        },
        { id: "status", header: "Status", cell: (r) => <Status value={r.Status} /> },
        {
          id: "actions",
          header: "",
          cell: (r) => {
            const id = Number(r.TaskID);
            const status = String(r.Status ?? "").toLowerCase();
            if (["completed", "done", "closed"].includes(status)) return null;
            return (
              <Button
                size="sm"
                variant="outline"
                loading={setStatus.isPending && setStatus.variables?.id === id}
                onClick={(e) => {
                  // The row itself navigates; the button must not.
                  e.stopPropagation();
                  setStatus.mutate({ id, status: status === "new" ? "In Progress" : "Completed" });
                }}
              >
                {status === "new" ? "Start" : "Complete"}
              </Button>
            );
          },
        },
      ]}
    />
  );
}
