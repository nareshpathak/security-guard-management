"use client";

import { useQuery } from "@tanstack/react-query";
import {
  DataTable,
  EmptyState,
  ErrorState,
  PageHeader,
  Pagination,
  Skeleton,
  StatusPill,
} from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { cell, useListQueryState } from "@/lib/list-query";

export default function InvoicesPage() {
  const q = useListQueryState();
  const list = useQuery({
    queryKey: ["invoices", q.page, q.status],
    queryFn: async () =>
      getApi().get<Row[]>("/api/v2/invoices", {
        page: q.page,
        pageSize: q.pageSize,
        status: q.status || undefined,
      }),
  });

  return (
    <div>
      <PageHeader title="Invoices" description="Client billing generated from deployed strength and rates." />
      {list.isLoading ? <Skeleton className="h-64" /> : null}
      {list.isError ? (
        <ErrorState message={list.error instanceof Error ? list.error.message : "Failed"} onRetry={() => list.refetch()} />
      ) : null}
      {list.data ? (
        <>
          <DataTable
            columns={[
              { id: "no", header: "Invoice", cell: (r) => cell(r, "InvoiceNo", "BillNo", "BID") },
              { id: "client", header: "Client", cell: (r) => cell(r, "ClientName") },
              { id: "period", header: "Period", cell: (r) => `${cell(r, "Month")}/${cell(r, "Year")}` },
              { id: "amt", header: "Amount", cell: (r) => cell(r, "NetAmount", "TotalAmount", "Amount") },
              {
                id: "status",
                header: "Status",
                cell: (r) => <StatusPill>{cell(r, "Status", "BillStatus")}</StatusPill>,
              },
            ]}
            rows={list.data.data}
            rowKey={(r, i) => String(r.BID ?? r.Bid ?? r.InvoiceID ?? i)}
            empty={<EmptyState title="No invoices" description="Generate from Finance → Payroll / invoice tools." />}
          />
          <Pagination
            page={q.page}
            pageSize={q.pageSize}
            total={list.data.meta?.total ?? list.data.data.length}
            onPageChange={(page) => q.setParams({ page })}
          />
        </>
      ) : null}
    </div>
  );
}
