"use client";

import { useQuery } from "@tanstack/react-query";
import { DataTable, EmptyState, ErrorState, PageHeader, Skeleton } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Status } from "@/components/status";
import { getApi } from "@/lib/api";
import { cell } from "@/lib/list-query";

/**
 * Branches come from the masters bootstrap - the first of its thirteen result
 * sets - rather than a dedicated endpoint, because that call is already made
 * and cached on every page load.
 */
export default function BranchesPage() {
  const bootstrap = useQuery({
    queryKey: ["masters-bootstrap"],
    queryFn: () => getApi().get<Row[][]>("/api/v2/masters/bootstrap"),
    staleTime: 10 * 60 * 1000,
  });

  if (bootstrap.isLoading) return <Skeleton className="h-64" />;
  if (bootstrap.isError)
    return (
      <ErrorState
        message={bootstrap.error instanceof Error ? bootstrap.error.message : "Could not load branches."}
        onRetry={() => bootstrap.refetch()}
      />
    );

  const branches = bootstrap.data?.data?.[0] ?? [];

  return (
    <div>
      <PageHeader title="Branches" description="The offices this agency operates from." />
      <DataTable
        columns={[
          { id: "name", header: "Branch", cell: (r) => cell(r, "BranchName") },
          { id: "code", header: "Code", cell: (r) => <span className="tabular">{cell(r, "BranchCode")}</span> },
          { id: "city", header: "City", hideOnMobile: true, cell: (r) => cell(r, "CityName", "City") },
          { id: "contact", header: "Contact", hideOnMobile: true, cell: (r) => cell(r, "ContactNo", "MobileNo") },
          {
            id: "status",
            header: "Status",
            cell: (r) => <Status value={r.IsActive === false ? "Inactive" : "Active"} />,
          },
        ]}
        rows={branches}
        rowKey={(r, i) => String(r.BranchID ?? i)}
        empty={<EmptyState title="No branches" description="Every agency has at least a head office." />}
      />
    </div>
  );
}
