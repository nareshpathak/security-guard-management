"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { DataTable, EmptyState, ErrorState, PageHeader, Skeleton, Button } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { getApi } from "@/lib/api";

/**
 * The reference data every dropdown in the product is built from, in one call.
 *
 * /masters/bootstrap returns thirteen result sets. Their order is the contract,
 * so they are named here rather than guessed from their contents.
 */
const SET_NAMES = [
  "Branches",
  "Designations",
  "Shifts",
  "Roles",
  "Document types",
  "Complaint types",
  "Incident types",
  "Leave types",
  "Item categories",
  "Items",
  "Salary heads",
  "Task types",
  "Qualifications",
];

export default function MastersPage() {
  const [active, setActive] = useState(0);

  const bootstrap = useQuery({
    queryKey: ["masters-bootstrap"],
    queryFn: () => getApi().get<Row[][]>("/api/v2/masters/bootstrap"),
    // Reference data changes when someone edits it, not on a timer.
    staleTime: 10 * 60 * 1000,
  });

  const sets = bootstrap.data?.data ?? [];
  const rows = sets[active] ?? [];

  return (
    <div>
      <PageHeader
        title="Reference data"
        description="Branches, designations, shifts and the rest of the lists the product offers."
      />

      {bootstrap.isLoading ? <Skeleton className="h-64" /> : null}
      {bootstrap.isError ? (
        <ErrorState
          message={bootstrap.error instanceof Error ? bootstrap.error.message : "Could not load reference data."}
          onRetry={() => bootstrap.refetch()}
        />
      ) : null}

      {sets.length > 0 ? (
        <>
          <div className="mb-4 flex flex-wrap gap-2">
            {sets.map((s, i) => (
              <Button
                key={i}
                size="sm"
                variant={active === i ? "primary" : "outline"}
                onClick={() => setActive(i)}
              >
                {SET_NAMES[i] ?? `Set ${i + 1}`}
                <span className="ml-1 text-[11px] opacity-70">{s.length}</span>
              </Button>
            ))}
          </div>

          <DataTable
            columns={
              rows.length === 0
                ? []
                : Object.keys(rows[0])
                    .filter((k) => !/^(CompanyID|IsCancel|InsertUserID|UpdateUserID)$/i.test(k))
                    .slice(0, 6)
                    .map((k) => ({
                      id: k,
                      header: k.replace(/([a-z])([A-Z])/g, "$1 $2"),
                      cell: (r: Row) =>
                        r[k] === null || r[k] === undefined || r[k] === "" ? (
                          <span className="text-muted">—</span>
                        ) : typeof r[k] === "boolean" ? (
                          (r[k] ? "Yes" : "No")
                        ) : (
                          String(r[k])
                        ),
                    }))
            }
            rows={rows}
            rowKey={(_, i) => i}
            empty={<EmptyState title="This list is empty" />}
          />
        </>
      ) : null}
    </div>
  );
}
