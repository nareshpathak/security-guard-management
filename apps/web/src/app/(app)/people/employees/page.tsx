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
import { GenericReportPrintTemplate, PrintModal } from "@/components/print-template";
import { getApi } from "@/lib/api";
import { SearchField, cell, useListQueryState } from "@/lib/list-query";

export default function EmployeesPage() {
  const router = useRouter();
  const q = useListQueryState();
  const [search, setSearch] = useState(q.search);
  const [showPrintModal, setShowPrintModal] = useState(false);
  const [pvPendingFilter, setPvPendingFilter] = useState(false);
  const [gunmanFilter, setGunmanFilter] = useState(false);

  useEffect(() => {
    const t = setTimeout(() => q.setParams({ search, page: 1 }), 300);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search]);

  const list = useQuery({
    queryKey: [
      "employees",
      q.page,
      q.pageSize,
      q.search,
      q.status,
      q.unitId,
      q.branchId,
      pvPendingFilter,
      gunmanFilter,
    ],
    queryFn: async () => {
      const res = await getApi().get<Row[]>("/api/v2/employees", {
        page: q.page,
        pageSize: q.pageSize,
        search: q.search || undefined,
        status: q.status || undefined,
        unitId: q.unitId,
        branchId: q.branchId,
        pvPending: pvPendingFilter || undefined,
        isGunman: gunmanFilter || undefined,
        sortBy: q.sortBy ?? "EmpFullName",
        sortDir: q.sortDir ?? "asc",
      });
      return res;
    },
  });

  const rows = list.data?.data ?? [];

  return (
    <div>
      <PageHeader
        title="Guard & Workforce Directory"
        description="Master directory of deployed guards, verification status, and qualifications."
        actions={
          <div className="flex items-center gap-2">
            <Button variant="outline" onClick={() => setShowPrintModal(true)}>
              <svg className="size-4 mr-1.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="6 9 6 2 18 2 18 9" />
                <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
                <rect x="6" y="14" width="12" height="8" />
              </svg>
              Print Guard Roster
            </Button>
            <Button variant="primary" onClick={() => router.push("/people/recruits")}>
              + Recruit Pipeline
            </Button>
          </div>
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
        <Button
          size="sm"
          variant={pvPendingFilter ? "danger" : "outline"}
          onClick={() => setPvPendingFilter((v) => !v)}
        >
          {pvPendingFilter ? "✓ PV Pending Only" : "PV Pending"}
        </Button>
        <Button
          size="sm"
          variant={gunmanFilter ? "primary" : "outline"}
          onClick={() => setGunmanFilter((v) => !v)}
        >
          {gunmanFilter ? "✓ Armed Gunmen Only" : "Armed Gunmen"}
        </Button>
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
                  <span className="font-mono text-xs font-semibold">{cell(r, "EmpCode", "empCode")}</span>
                ),
              },
              { id: "name", header: "Name", cell: (r) => <span className="font-medium text-text">{cell(r, "EmpFullName", "Name", "name")}</span> },
              {
                id: "desig",
                header: "Designation",
                hideOnMobile: true,
                cell: (r) => cell(r, "DesignationName", "Designation"),
              },
              {
                id: "unit",
                header: "Unit / Site",
                hideOnMobile: true,
                cell: (r) => cell(r, "UnitName", "Unit"),
              },
              { id: "mobile", header: "Mobile", cell: (r) => <span className="tabular">{cell(r, "Mobile1", "MobileNo", "Mobile")}</span> },
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
            rows={rows}
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
            total={list.data.meta?.total ?? rows.length}
            onPageChange={(page) => q.setParams({ page })}
          />
        </>
      ) : null}

      {/* Printable Guard Roster Modal */}
      <PrintModal
        open={showPrintModal}
        onClose={() => setShowPrintModal(false)}
        title="MASTER GUARD & WORKFORCE ROSTER REPORT"
      >
        <GenericReportPrintTemplate
          title="MASTER GUARD & WORKFORCE ROSTER REPORT"
          columns={[
            { key: "EmpCode", label: "Emp Code" },
            { key: "EmpFullName", label: "Guard Name" },
            { key: "DesignationName", label: "Designation" },
            { key: "UnitName", label: "Deployed Unit" },
            { key: "Mobile1", label: "Mobile No" },
            { key: "EmpStatus", label: "Status" },
          ]}
          rows={rows}
        />
      </PrintModal>
    </div>
  );
}
