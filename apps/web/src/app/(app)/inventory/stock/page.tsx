import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import {
  Button,
  Card,
  DataTable,
  EmptyState,
  ErrorState,
  Input,
  Label,
  PageHeader,
  Pagination,
  Select,
  Skeleton,
  StatCard,
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
import { count, money } from "@/lib/format";

export default function StockPage() {
  const q = useListQueryState();
  const { has } = useAuth();
  const [stockInModal, setStockInModal] = useState(false);
  const [issueModal, setIssueModal] = useState(false);
  const [showPrintModal, setShowPrintModal] = useState(false);

  const [stockInForm, setStockInForm] = useState({
    itemId: "",
    qty: "",
    rate: "",
    remark: "",
  });

  const [issueForm, setIssueForm] = useState({
    empId: "",
    itemId: "",
    qty: "1",
    rate: "",
    recoverInSalary: true,
    remark: "",
  });

  const stockQuery = useQuery({
    queryKey: ["uniform-stock", q.search, q.page, q.pageSize],
    queryFn: () =>
      getApi().get<Row[]>("/api/v2/uniform/stock", {
        search: q.search,
        page: q.page,
        pageSize: q.pageSize,
      }),
  });

  const itemsQuery = useQuery({
    queryKey: ["uniform-items-master"],
    queryFn: () => getApi().get<Row[]>("/api/v2/masters/lookup/uniformitem"),
    staleTime: 5 * 60 * 1000,
  });

  const stockInCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/uniform/stock-in",
    invalidate: ["uniform-stock", "uniform-ledger"],
    successMessage: "Stock inward recorded successfully",
    onDone: () => {
      setStockInModal(false);
      setStockInForm({ itemId: "", qty: "", rate: "", remark: "" });
    },
  });

  const issueCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/uniform/issue",
    invalidate: ["uniform-stock", "uniform-issues", "uniform-ledger"],
    successMessage: "Uniform issued to employee successfully",
    onDone: () => {
      setIssueModal(false);
      setIssueForm({ empId: "", itemId: "", qty: "1", rate: "", recoverInSalary: true, remark: "" });
    },
  });

  const rows = stockQuery.data?.data ?? [];
  const items = itemsQuery.data?.data ?? [];

  const totalInHand = rows.reduce((n, r) => n + Number(r.InHandQty ?? r.BalanceQty ?? 0), 0);
  const totalIssued = rows.reduce((n, r) => n + Number(r.IssuedQty ?? 0), 0);
  const lowStockCount = rows.filter((r) => {
    const inHand = Number(r.InHandQty ?? r.BalanceQty ?? 0);
    const reorder = Number(r.ReorderLevel ?? 0);
    return reorder > 0 && inHand <= reorder;
  }).length;

  return (
    <div>
      <PageHeader
        title="Uniform & Equipment Stock"
        description="Live store inventory levels, issued kit balances, and reorder alerts."
        actions={
          <div className="flex items-center gap-2">
            <Button variant="outline" onClick={() => setShowPrintModal(true)}>
              <svg className="size-4 mr-1.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="6 9 6 2 18 2 18 9" />
                <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
                <rect x="6" y="14" width="12" height="8" />
              </svg>
              Print / Save PDF Report
            </Button>
            {has(Perm.inventoryEdit) ? (
              <>
                <Button variant="outline" onClick={() => setIssueModal(true)}>
                  Issue Kit
                </Button>
                <Button variant="primary" onClick={() => setStockInModal(true)}>
                  + Stock In
                </Button>
              </>
            ) : null}
          </div>
        }
      />

      {/* Inventory KPI Summary Header */}
      <div className="mb-6 grid gap-4 sm:grid-cols-3">
        <StatCard label="In Store Balance" value={count(totalInHand)} tone="default" />
        <StatCard label="Issued with Guards" value={count(totalIssued)} tone="default" />
        <StatCard
          label="Low Stock Items"
          value={count(lowStockCount)}
          tone={lowStockCount > 0 ? "danger" : "success"}
          hint={lowStockCount > 0 ? "Requires reordering" : "All stock levels optimal"}
        />
      </div>

      {/* Search & Toolbar */}
      <div className="mb-4 flex items-center justify-between gap-3">
        <div className="w-full max-w-sm">
          <Input
            placeholder="Search uniform item..."
            value={q.search}
            onChange={(e) => q.setParams({ search: e.target.value, page: 1 })}
          />
        </div>
      </div>

      {stockQuery.isLoading ? <Skeleton className="h-64" /> : null}
      {stockQuery.isError ? (
        <ErrorState
          message={stockQuery.error instanceof Error ? stockQuery.error.message : "Could not load stock list."}
          onRetry={() => stockQuery.refetch()}
        />
      ) : null}

      {stockQuery.data ? (
        <>
          <DataTable
            columns={[
              {
                id: "item",
                header: "Item",
                cell: (r) => (
                  <div>
                    <div className="font-semibold text-text">{cell(r, "ItemName")}</div>
                    <div className="text-xs text-muted">{cell(r, "CategoryName", "ItemCode")}</div>
                  </div>
                ),
              },
              {
                id: "inhand",
                header: "In Store",
                className: "text-right",
                cell: (r) => {
                  const inHand = Number(r.InHandQty ?? r.BalanceQty ?? 0);
                  const reorder = Number(r.ReorderLevel ?? 0);
                  const low = reorder > 0 && inHand <= reorder;
                  return (
                    <span className={low ? "tabular font-bold text-danger" : "tabular font-medium"}>
                      {count(inHand)}
                    </span>
                  );
                },
              },
              {
                id: "issued",
                header: "With Guards",
                className: "text-right",
                cell: (r) => <span className="tabular font-medium text-blue-600">{count(r.IssuedQty)}</span>,
              },
              {
                id: "reorder",
                header: "Reorder At",
                className: "text-right",
                hideOnMobile: true,
                cell: (r) => <span className="tabular text-muted">{count(r.ReorderLevel)}</span>,
              },
              {
                id: "rate",
                header: "Rate",
                className: "text-right",
                hideOnMobile: true,
                cell: (r) => <span className="tabular">{money(r.Rate ?? r.UnitRate)}</span>,
              },
              {
                id: "status",
                header: "Status",
                cell: (r) => {
                  const inHand = Number(r.InHandQty ?? r.BalanceQty ?? 0);
                  const reorder = Number(r.ReorderLevel ?? 0);
                  if (inHand === 0) return <Status value="Out of stock" />;
                  if (reorder > 0 && inHand <= reorder) return <Status value="Low" />;
                  return <Status value="In Stock" />;
                },
              },
            ]}
            rows={rows}
            rowKey={(r, i) => String(r.ItemID ?? i)}
            empty={
              <EmptyState
                title="No stock recorded"
                description="Click Stock In to record initial store inventory."
              />
            }
          />
          <Pagination
            page={q.page}
            pageSize={q.pageSize}
            total={stockQuery.data.meta?.total ?? rows.length}
            onPageChange={(page) => q.setParams({ page })}
          />
        </>
      ) : null}

      {/* Stock-In Modal */}
      <Modal
        open={stockInModal}
        onOpenChange={setStockInModal}
        title="Stock Inward Entry"
        description="Record new uniform or equipment received into the store."
        footer={
          <Button
            loading={stockInCmd.isPending}
            disabled={!stockInForm.itemId || !stockInForm.qty}
            onClick={() =>
              stockInCmd.mutate({
                itemId: Number(stockInForm.itemId),
                qty: Number(stockInForm.qty),
                rate: stockInForm.rate ? Number(stockInForm.rate) : undefined,
                remark: stockInForm.remark || undefined,
              })
            }
          >
            Save Stock In
          </Button>
        }
      >
        <div>
          <Label required>Uniform / Equipment Item</Label>
          <Select
            value={stockInForm.itemId}
            onChange={(e) => setStockInForm((f) => ({ ...f, itemId: e.target.value }))}
          >
            <option value="">Choose item...</option>
            {items.map((it, i) => (
              <option key={String(it.ItemID ?? it.Id ?? i)} value={String(it.ItemID ?? it.Id ?? "")}>
                {String(it.ItemName ?? it.Name ?? "")}
              </option>
            ))}
          </Select>
        </div>
        <div>
          <Label required>Quantity Received</Label>
          <Input
            type="number"
            placeholder="e.g. 50"
            value={stockInForm.qty}
            onChange={(e) => setStockInForm((f) => ({ ...f, qty: e.target.value }))}
          />
        </div>
        <div>
          <Label>Unit Rate (₹)</Label>
          <Input
            type="number"
            step="0.01"
            placeholder="e.g. 450.00"
            value={stockInForm.rate}
            onChange={(e) => setStockInForm((f) => ({ ...f, rate: e.target.value }))}
          />
        </div>
        <div>
          <Label>Supplier Invoice / Remark</Label>
          <Input
            placeholder="Invoice Ref or Remarks"
            value={stockInForm.remark}
            onChange={(e) => setStockInForm((f) => ({ ...f, remark: e.target.value }))}
          />
        </div>
      </Modal>

      {/* Issue Kit Modal */}
      <Modal
        open={issueModal}
        onOpenChange={setIssueModal}
        title="Issue Uniform / Kit to Guard"
        description="Allocate store inventory to an employee."
        footer={
          <Button
            loading={issueCmd.isPending}
            disabled={!issueForm.empId || !issueForm.itemId || !issueForm.qty}
            onClick={() =>
              issueCmd.mutate({
                empId: Number(issueForm.empId),
                itemId: Number(issueForm.itemId),
                qty: Number(issueForm.qty),
                rate: issueForm.rate ? Number(issueForm.rate) : undefined,
                recoverInSalary: issueForm.recoverInSalary,
                remark: issueForm.remark || undefined,
              })
            }
          >
            Issue Kit
          </Button>
        }
      >
        <div>
          <Label required>Employee ID</Label>
          <Input
            type="number"
            placeholder="e.g. 1001"
            value={issueForm.empId}
            onChange={(e) => setIssueForm((f) => ({ ...f, empId: e.target.value }))}
          />
        </div>
        <div>
          <Label required>Uniform / Equipment Item</Label>
          <Select
            value={issueForm.itemId}
            onChange={(e) => setIssueForm((f) => ({ ...f, itemId: e.target.value }))}
          >
            <option value="">Choose item...</option>
            {items.map((it, i) => (
              <option key={String(it.ItemID ?? it.Id ?? i)} value={String(it.ItemID ?? it.Id ?? "")}>
                {String(it.ItemName ?? it.Name ?? "")}
              </option>
            ))}
          </Select>
        </div>
        <div>
          <Label required>Quantity Issued</Label>
          <Input
            type="number"
            value={issueForm.qty}
            onChange={(e) => setIssueForm((f) => ({ ...f, qty: e.target.value }))}
          />
        </div>
        <div>
          <Label>Issue Rate (₹)</Label>
          <Input
            type="number"
            step="0.01"
            placeholder="Optional issue rate"
            value={issueForm.rate}
            onChange={(e) => setIssueForm((f) => ({ ...f, rate: e.target.value }))}
          />
        </div>
        <div className="flex items-center gap-2 pt-2">
          <input
            type="checkbox"
            id="recoverInSalary"
            checked={issueForm.recoverInSalary}
            onChange={(e) => setIssueForm((f) => ({ ...f, recoverInSalary: e.target.checked }))}
            className="size-4 rounded border-[var(--diti-border)] text-blue-600 focus:ring-blue-500"
          />
          <Label htmlFor="recoverInSalary" className="!mb-0 cursor-pointer">
            Recover amount in monthly payroll salary deduction
          </Label>
        </div>
        <div>
          <Label>Issue Remarks</Label>
          <Input
            placeholder="e.g. Initial Joining Kit Issue"
            value={issueForm.remark}
            onChange={(e) => setIssueForm((f) => ({ ...f, remark: e.target.value }))}
          />
        </div>
      </Modal>

      {/* Printable Stock Statement Modal */}
      <PrintModal
        open={showPrintModal}
        onClose={() => setShowPrintModal(false)}
        title="UNIFORM & EQUIPMENT STORE STOCK STATEMENT"
      >
        <GenericReportPrintTemplate
          title="UNIFORM & EQUIPMENT STORE STOCK STATEMENT"
          columns={[
            { key: "ItemName", label: "Item Name" },
            { key: "InHandQty", label: "In Store Qty", align: "right" },
            { key: "IssuedQty", label: "With Guards Qty", align: "right" },
            { key: "ReorderLevel", label: "Reorder Level", align: "right" },
          ]}
          rows={rows}
        />
      </PrintModal>
    </div>
  );
}
