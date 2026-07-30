"use client";

import { useQuery } from "@tanstack/react-query";
import { useSearchParams } from "next/navigation";
import { useMemo, useState } from "react";
import {
  Button,
  DataTable,
  EmptyState,
  ErrorState,
  Input,
  Label,
  PageHeader,
  Pagination,
  Skeleton,
  type Column,
} from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Status } from "@/components/status";
import { GenericReportPrintTemplate, PrintModal } from "@/components/print-template";
import { getApi } from "@/lib/api";
import { useListQueryState } from "@/lib/list-query";
import { date, dateTime, isoDate, money } from "@/lib/format";

type ReportKey = { key?: string; Key?: string; name?: string; Name?: string; title?: string };

const REPORT_CATEGORIES = [
  { id: "all", label: "All Reports" },
  { id: "workforce", label: "Workforce & Guards" },
  { id: "operations", label: "Security Operations" },
  { id: "attendance", label: "Attendance & Shifts" },
  { id: "clients", label: "Clients & Contracts" },
  { id: "finance", label: "Finance & Payroll" },
];

export default function ReportsPage() {
  const q = useListQueryState();
  const [showPrintModal, setShowPrintModal] = useState(false);
  const [activeCategory, setActiveCategory] = useState("all");
  const activeKey = useSearchParams().get("key") ?? "";

  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  const from = q.from ?? isoDate(thirtyDaysAgo);
  const to = q.to ?? isoDate(new Date());

  const keysQuery = useQuery({
    queryKey: ["report-keys"],
    queryFn: () => getApi().get<ReportKey[]>("/api/v2/reports"),
    staleTime: Infinity,
  });

  const reportQuery = useQuery({
    queryKey: ["report", activeKey, q.page, q.pageSize, from, to],
    enabled: activeKey.length > 0,
    queryFn: () =>
      getApi().get<Row[]>(`/api/v2/reports/${activeKey}`, {
        page: q.page,
        pageSize: q.pageSize,
        from,
        to,
      }),
  });

  const rawKeys = keysQuery.data?.data ?? [];

  // Filter keys by category
  const filteredKeys = useMemo(() => {
    if (activeCategory === "all") return rawKeys;
    return rawKeys.filter((k) => {
      const keyStr = String(k.key ?? k.Key ?? k ?? "").toLowerCase();
      if (activeCategory === "workforce") return /emp|guard|recruit|doc|training|lifecycle/.test(keyStr);
      if (activeCategory === "operations") return /deploy|turnout|patrol|gate|incident|report|event|task/.test(keyStr);
      if (activeCategory === "attendance") return /attend|shift|overtime|punch/.test(keyStr);
      if (activeCategory === "clients") return /client|unit|site|contract|complaint|relation/.test(keyStr);
      if (activeCategory === "finance") return /pay|invoice|receipt|ageing|advance|slip|financial/.test(keyStr);
      return true;
    });
  }, [rawKeys, activeCategory]);

  const rows = reportQuery.data?.data ?? [];

  const columns = useMemo<Column<Row>[]>(() => {
    if (rows.length === 0) return [];
    return Object.keys(rows[0])
      .filter((name) => !/^(CompanyID|IsCancel|InsertUserID|UpdateUserID|TotalRows)$/i.test(name))
      .map((name) => {
        const lower = name.toLowerCase();
        const isMoney = /amount|total|salary|wage|rate|value|payable|balance|outstanding/.test(lower);
        const isWhen = /date|on$|at$|time/.test(lower);
        const isStatus = /status|state|stage|priority/.test(lower);
        const isNumber = /count|nos|qty|days|hours|strength|meters|pct|percent/.test(lower);

        return {
          id: name,
          header: name.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/^./, (c) => c.toUpperCase()),
          className: isMoney || isNumber ? "text-right" : undefined,
          cell: (r: Row) => {
            const value = r[name];
            if (value === null || value === undefined || value === "")
              return <span className="text-muted">—</span>;
            if (isStatus) return <Status value={value} />;
            if (isMoney) return <span className="tabular font-medium">{money(value)}</span>;
            if (isWhen)
              return <span className="tabular font-medium">{/time/.test(lower) ? dateTime(value) : date(value)}</span>;
            if (isNumber) return <span className="tabular font-medium">{String(value)}</span>;
            if (typeof value === "boolean") return <Status value={value ? "Yes" : "No"} />;
            return String(value);
          },
        };
      });
  }, [rows]);

  const activeLabel = activeKey ? activeKey.replace(/([a-z])([A-Z])/g, "$1 $2").toUpperCase() : "";

  return (
    <div>
      <PageHeader
        title="Executive Business Reports Hub"
        description="Select a report category, apply custom date filters, and export branded PDF or CSV audit reports."
        actions={
          activeKey ? (
            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                onClick={() => setShowPrintModal(true)}
              >
                <svg className="size-4 mr-1.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <polyline points="6 9 6 2 18 2 18 9" />
                  <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
                  <rect x="6" y="14" width="12" height="8" />
                </svg>
                Print / Download PDF
              </Button>
              <Button
                variant="outline"
                onClick={() => {
                  const url = `${process.env.NEXT_PUBLIC_API_BASE_URL ?? ""}/api/v2/reports/${activeKey}/export?from=${from}&to=${to}`;
                  window.open(url, "_blank", "noopener");
                }}
              >
                Export CSV Data
              </Button>
            </div>
          ) : null
        }
      />

      {/* 5 Major Category Filters */}
      <div className="mb-4 flex flex-wrap gap-2 border-b border-[var(--diti-border)] pb-3">
        {REPORT_CATEGORIES.map((cat) => (
          <button
            key={cat.id}
            type="button"
            onClick={() => setActiveCategory(cat.id)}
            className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-all ${
              activeCategory === cat.id
                ? "bg-[var(--diti-primary)] text-white shadow-xs"
                : "bg-[var(--diti-surface)] text-[var(--diti-muted)] border border-[var(--diti-border)] hover:bg-slate-100 dark:hover:bg-zinc-800"
            }`}
          >
            {cat.label}
          </button>
        ))}
      </div>

      {keysQuery.isLoading ? <Skeleton className="mb-6 h-20" /> : null}
      {keysQuery.isError ? (
        <ErrorState message="Could not load the master report index." onRetry={() => keysQuery.refetch()} />
      ) : null}

      {/* Report Chips */}
      {filteredKeys.length > 0 ? (
        <div className="mb-6 flex flex-wrap gap-2">
          {filteredKeys.map((k, i) => {
            const key = String(k.key ?? k.Key ?? k ?? "");
            const label = String(k.name ?? k.Name ?? k.title ?? key).replace(/([a-z])([A-Z])/g, "$1 $2");
            const isSelected = activeKey === key;
            return (
              <Button
                key={key || i}
                size="sm"
                variant={isSelected ? "primary" : "outline"}
                onClick={() => q.setParams({ key, page: 1 })}
              >
                {label}
              </Button>
            );
          })}
        </div>
      ) : null}

      {activeKey ? (
        <>
          <div className="mb-4 flex flex-wrap items-end gap-3 rounded-xl border border-[var(--diti-border)] bg-[var(--diti-surface)] p-3.5 shadow-xs">
            <div>
              <Label>From Date</Label>
              <Input
                type="date"
                value={from}
                onChange={(e) => q.setParams({ from: e.target.value, page: 1 })}
              />
            </div>
            <div>
              <Label>To Date</Label>
              <Input
                type="date"
                value={to}
                onChange={(e) => q.setParams({ to: e.target.value, page: 1 })}
              />
            </div>
            <div className="ml-auto text-xs text-[var(--diti-muted)] font-medium">
              Report Target: <strong className="text-[var(--diti-primary)]">{activeLabel}</strong>
            </div>
          </div>

          {reportQuery.isLoading ? <Skeleton className="h-64" /> : null}
          {reportQuery.isError ? (
            <ErrorState
              message={reportQuery.error instanceof Error ? reportQuery.error.message : "Could not generate report."}
              onRetry={() => reportQuery.refetch()}
            />
          ) : null}

          {reportQuery.data ? (
            <>
              <DataTable
                columns={columns}
                rows={rows}
                rowKey={(_, i) => i}
                empty={
                  <EmptyState
                    title="No records found in selected period"
                    description="Widen the date range parameters to include earlier historical activity."
                  />
                }
              />
              {rows.length > 0 ? (
                <Pagination
                  page={q.page}
                  pageSize={q.pageSize}
                  total={reportQuery.data.meta?.total ?? rows.length}
                  onPageChange={(page) => q.setParams({ page })}
                />
              ) : null}
            </>
          ) : null}
        </>
      ) : (
        <EmptyState
          title="Select an Executive Report"
          description="Choose a report category above and select a report module to view and export live backend data."
        />
      )}

      {/* Executive Branded Print & PDF Export Modal */}
      <PrintModal
        open={showPrintModal}
        onClose={() => setShowPrintModal(false)}
        title={`${activeLabel} EXECUTIVE AUDIT REPORT`}
      >
        <GenericReportPrintTemplate
          title={`${activeLabel} EXECUTIVE AUDIT REPORT`}
          filters={{ from, to }}
          columns={columns.map((c) => ({ key: c.id, label: c.header }))}
          rows={rows}
        />
      </PrintModal>
    </div>
  );
}
