"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import {
  Button,
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
import { SearchField, cell, useListQueryState } from "@/lib/list-query";

export default function EmployeesPage() {
  const router = useRouter();
  const q = useListQueryState();
  const [search, setSearch] = useState(q.search);

  useEffect(() => {
    const t = setTimeout(() => q.setParams({ search, page: 1 }), 300);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search]);

  const list = useQuery({
    queryKey: ["employees", q.page, q.pageSize, q.search, q.status, q.unitId, q.branchId],
    queryFn: async () => {
      const res = await getApi().get<Row[]>("/api/v2/employees", {
        page: q.page,
        pageSize: q.pageSize,
        search: q.search || undefined,
        status: q.status || undefined,
        unitId: q.unitId,
        branchId: q.branchId,
        sortBy: q.sortBy ?? "EmpFullName",
        sortDir: q.sortDir ?? "asc",
      });
      return res;
    },
  });

  return (
    <div>
      <PageHeader
        title="Guards"
        description="Employee master list with deployment and verification status."
        actions={
          <Button variant="outline" onClick={() => router.push("/people/recruits")}>
            Recruit pipeline
          </Button>
        }
      />
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <SearchField value={search} onChange={setSearch} placeholder="Search name, code, mobile" />
        <select
          className="h-9 rounded-[var(--diti-radius-md)] border border-[var(--diti-border)] bg-[var(--diti-surface)] px-3 text-sm"
          value={q.status}
          onChange={(e) => q.setParams({ status: e.target.value || undefined, page: 1 })}
        >
          <option value="">All statuses</option>
          <option value="Active">Active</option>
          <option value="Left">Left</option>
          <option value="Blacklisted">Blacklisted</option>
        </select>
      </div>

      {list.isLoading ? <Skeleton className="h-64" /> : null}
      {list.isError ? (
        <ErrorState
          message={list.error instanceof Error ? list.error.message : "Failed to load"}
          onRetry={() => list.refetch()}
        />
      ) : null}
      {list.data ? (
        <>
          <DataTable
            columns={[
              {
                id: "code",
                header: "Code",
                cell: (r) => (
                  <span className="font-mono text-xs">{cell(r, "EmpCode", "empCode")}</span>
                ),
              },
              { id: "name", header: "Name", cell: (r) => cell(r, "EmpFullName", "Name", "name") },
              {
                id: "desig",
                header: "Designation",
                hideOnMobile: true,
                cell: (r) => cell(r, "DesignationName", "Designation"),
              },
              {
                id: "unit",
                header: "Unit",
                hideOnMobile: true,
                cell: (r) => cell(r, "UnitName", "Unit"),
              },
              { id: "mobile", header: "Mobile", cell: (r) => cell(r, "Mobile1", "MobileNo", "Mobile") },
              {
                id: "status",
                header: "Status",
                cell: (r) => {
                  const s = cell(r, "EmpStatus", "Status");
                  return (
                    <StatusPill tone={s === "Active" ? "success" : s === "Blacklisted" ? "danger" : "neutral"}>
                      {s}
                    </StatusPill>
                  );
                },
              },
            ]}
            rows={list.data.data}
            rowKey={(r) => String(r.EmpID ?? r.EmpId)}
            onRowClick={(r) => router.push(`/people/employees/${r.EmpID ?? r.EmpId}`)}
            empty={
              <EmptyState
                title="No guards found"
                description="Adjust filters or convert a recruit into an employee."
                action={
                  <Button onClick={() => router.push("/people/recruits")}>Open recruits</Button>
                }
              />
            }
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
