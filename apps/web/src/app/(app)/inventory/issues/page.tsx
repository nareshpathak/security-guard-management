"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
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
} from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Modal } from "@/components/modal";
import { Status } from "@/components/status";
import { GenericReportPrintTemplate, PrintModal } from "@/components/print-template";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";
import { cell, useListQueryState } from "@/lib/list-query";
import { count, date } from "@/lib/format";

export default function IssuesPage() {
  const q = useListQueryState();
  const { has } = useAuth();
  const [returnModal, setReturnModal] = useState(false);
  const [showPrintModal, setShowPrintModal] = useState(false);
  const [selectedIssue, setSelectedIssue] = useState<Row | null>(null);

  const [returnForm, setReturnForm] = useState({
    qty: "1",
    remark: "",
  });

  const issuesQuery = useQuery({
    queryKey: ["uniform-issues", q.search, q.page, q.pageSize],
    queryFn: () =>
      getApi().get<Row[]>("/api/v2/uniform/ledger", {
        onlyOutstanding: true,
        search: q.search,
        page: q.page,
        pageSize: q.pageSize,
      }),
  });

  const returnCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/uniform/return",
    invalidate: ["uniform-issues", "uniform-stock", "uniform-ledger"],
    successMessage: "Kit return recorded successfully",
    onDone: () => {
      setReturnModal(false);
      setSelectedIssue(null);
      setReturnForm({ qty: "1", remark: "" });
    },
  });

  const rows = issuesQuery.data?.data ?? [];

  return (
    <div>
      <PageHeader
        title="Issued & Outstanding Kit"
        description="Uniforms and equipment currently allocated to guards."
        actions={
          <div className="flex items-center gap-2">
            <Button variant="outline" onClick={() => setShowPrintModal(true)}>
              <svg className="size-4 mr-1.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="6 9 6 2 18 2 18 9" />
                <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
                <rect x="6" y="14" width="12" height="8" />
              </svg>
              Print Outstanding Kit Voucher
            </Button>
          </div>
        }
      />

      <div className="mb-4 flex items-center justify-between gap-3">
        <div className="w-full max-w-sm">
          <Input
            placeholder="Search employee or item..."
            value={q.search}
            onChange={(e) => q.setParams({ search: e.target.value, page: 1 })}
          />
        </div>
      </div>

      {issuesQuery.isLoading ? <Skeleton className="h-64" /> : null}
      {issuesQuery.isError ? (
        <ErrorState
          message={issuesQuery.error instanceof Error ? issuesQuery.error.message : "Could not load issues list."}
          onRetry={() => issuesQuery.refetch()}
        />
      ) : null}

      {issuesQuery.data ? (
        <>
          <DataTable
            columns={[
              {
                id: "when",
                header: "Issued Date",
                cell: (r) => <span className="tabular font-medium">{date(r.IssueDate ?? r.Dated)}</span>,
              },
              {
                id: "emp",
                header: "Employee",
                cell: (r) => (
                  <div>
                    <div className="font-semibold text-text">{cell(r, "EmpFullName")}</div>
                    <div className="tabular text-xs text-muted">ID: {cell(r, "EmpCode", "EmpId")}</div>
                  </div>
                ),
              },
              { id: "item", header: "Item", cell: (r) => <span className="font-medium">{cell(r, "ItemName")}</span> },
              {
                id: "out",
                header: "Still Out",
                className: "text-right",
                cell: (r) => {
                  const out = Number(r.IssuedQty ?? 0) - Number(r.RecievedQty ?? r.ReturnedQty ?? 0);
                  return <span className="tabular font-bold text-amber-600">{count(out)}</span>;
                },
              },
              { id: "status", header: "Status", cell: (r) => <Status value={r.Status ?? "Issued"} /> },
              {
                id: "action",
                header: "Action",
                className: "text-right",
                cell: (r) =>
                  has(Perm.inventoryEdit) ? (
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => {
                        setSelectedIssue(r);
                        setReturnForm({ qty: "1", remark: "" });
                        setReturnModal(true);
                      }}
                    >
                      Return Kit
                    </Button>
                  ) : null,
              },
            ]}
            rows={rows}
            rowKey={(r, i) => String(r.IssueID ?? r.LedgerID ?? i)}
            empty={
              <EmptyState
                title="Nothing outstanding"
                description="Everything issued has been returned or recovered."
              />
            }
          />
          <Pagination
            page={q.page}
            pageSize={q.pageSize}
            total={issuesQuery.data.meta?.total ?? rows.length}
            onPageChange={(page) => q.setParams({ page })}
          />
        </>
      ) : null}

      {/* Return Kit Modal */}
      <Modal
        open={returnModal}
        onOpenChange={setReturnModal}
        title="Return / Receive Kit"
        description={selectedIssue ? `Returning kit issued to ${cell(selectedIssue, "EmpFullName")}` : "Kit Return Entry"}
        footer={
          <Button
            loading={returnCmd.isPending}
            disabled={!selectedIssue || !returnForm.qty}
            onClick={() =>
              returnCmd.mutate({
                issueId: Number(selectedIssue?.IssueID ?? selectedIssue?.LedgerID ?? 0),
                qty: Number(returnForm.qty),
                remark: returnForm.remark || undefined,
              })
            }
          >
            Confirm Return
          </Button>
        }
      >
        {selectedIssue ? (
          <div className="rounded-lg border border-[var(--diti-border)] bg-[var(--diti-surface-sunken)] p-3 text-xs space-y-1 mb-3">
            <div><strong>Item:</strong> {cell(selectedIssue, "ItemName")}</div>
            <div><strong>Employee:</strong> {cell(selectedIssue, "EmpFullName")}</div>
            <div><strong>Issued Date:</strong> {date(selectedIssue.IssueDate ?? selectedIssue.Dated)}</div>
          </div>
        ) : null}
        <div>
          <Label required>Quantity Returned</Label>
          <Input
            type="number"
            value={returnForm.qty}
            onChange={(e) => setReturnForm((f) => ({ ...f, qty: e.target.value }))}
          />
        </div>
        <div>
          <Label>Remarks / Return Condition</Label>
          <Input
            placeholder="e.g. Good condition / Damaged upon resignation"
            value={returnForm.remark}
            onChange={(e) => setReturnForm((f) => ({ ...f, remark: e.target.value }))}
          />
        </div>
      </Modal>

      {/* Printable Kit Voucher Modal */}
      <PrintModal
        open={showPrintModal}
        onClose={() => setShowPrintModal(false)}
        title="OUTSTANDING KIT & UNIFORM ALLOCATION REPORT"
      >
        <GenericReportPrintTemplate
          title="OUTSTANDING KIT & UNIFORM ALLOCATION REPORT"
          columns={[
            { key: "IssueDate", label: "Issue Date" },
            { key: "EmpFullName", label: "Guard Name" },
            { key: "ItemName", label: "Uniform Item" },
            { key: "IssuedQty", label: "Issued Qty", align: "right" },
            { key: "Status", label: "Status" },
          ]}
          rows={rows}
        />
      </PrintModal>
    </div>
  );
}
