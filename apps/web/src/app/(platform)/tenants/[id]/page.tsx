"use client";

import { useQuery } from "@tanstack/react-query";
import { useParams } from "next/navigation";
import { DataTable, EmptyState, ErrorState, PageHeader, Skeleton } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Status } from "@/components/status";
import { getApi } from "@/lib/api";
import { cell } from "@/lib/list-query";
import { dateTime } from "@/lib/format";

/** One tenant's sign-in history - the first thing to check on a support call. */
export default function TenantDetailPage() {
  const { id } = useParams<{ id: string }>();

  const logins = useQuery({
    queryKey: ["tenant-logins", id],
    queryFn: () => getApi().get<Row[]>(`/api/v2/companies/${id}/logins`, { page: 1, pageSize: 100 }),
  });

  if (logins.isLoading) return <Skeleton className="h-64" />;
  if (logins.isError)
    return (
      <ErrorState
        message={logins.error instanceof Error ? logins.error.message : "Could not load this tenant."}
        onRetry={() => logins.refetch()}
      />
    );

  return (
    <div>
      <PageHeader title={`Tenant ${id}`} description="Recent sign-ins for this agency." />
      <DataTable
        columns={[
          { id: "at", header: "When", cell: (r) => <span className="tabular">{dateTime(r.LoginAt ?? r.InsertDate)}</span> },
          { id: "user", header: "User", cell: (r) => cell(r, "UserName", "Name") },
          { id: "role", header: "Role", hideOnMobile: true, cell: (r) => cell(r, "RoleCode") },
          { id: "ip", header: "From", hideOnMobile: true, cell: (r) => <span className="tabular text-muted">{cell(r, "IpAddress", "Ip")}</span> },
          {
            id: "result",
            header: "Result",
            cell: (r) => <Status value={r.IsSuccess === false ? "Rejected" : "Approved"} />,
          },
        ]}
        rows={logins.data?.data ?? []}
        rowKey={(r, i) => String(r.LogID ?? i)}
        empty={<EmptyState title="No sign-ins recorded" />}
      />
    </div>
  );
}
