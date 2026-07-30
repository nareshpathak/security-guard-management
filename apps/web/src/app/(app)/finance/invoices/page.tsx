"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
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
  Select,
  Skeleton,
  StatCard,
  StatusPill,
} from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Modal } from "@/components/modal";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";
import { cell, useListQueryState } from "@/lib/list-query";
import { money } from "@/lib/format";

export default function InvoicesPage() {
  const q = useListQueryState();
  const { has } = useAuth();
  const [generateModal, setGenerateModal] = useState(false);
  const [receiptModal, setReceiptModal] = useState(false);
  const [selectedInvoice, setSelectedInvoice] = useState<Row | null>(null);

  const [genForm, setGenForm] = useState({
    clientId: "",
    month: String(new Date().getMonth() + 1),
    year: String(new Date().getFullYear()),
    gstPercent: "18.00",
  });

  const [receiptForm, setReceiptForm] = useState({
    amount: "",
    mode: "NEFT",
    refNo: "",
    remark: "",
  });

  const listQuery = useQuery({
    queryKey: ["invoices", q.page, q.status],
    queryFn: async () =>
      getApi().get<Row[]>("/api/v2/invoices", {
        page: q.page,
        pageSize: q.pageSize,
        status: q.status || undefined,
      }),
  });

  const clientsQuery = useQuery({
    queryKey: ["clients-dropdown"],
    queryFn: () => getApi().get<Row[]>("/api/v2/clients"),
    staleTime: 5 * 60 * 1000,
  });

  const genCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/invoices/generate",
    invalidate: ["invoices"],
    successMessage: "Tax Invoice generated successfully",
    onDone: () => {
      setGenerateModal(false);
      setGenForm({
        clientId: "",
        month: String(new Date().getMonth() + 1),
        year: String(new Date().getFullYear()),
        gstPercent: "18.00",
      });
    },
  });

  const receiptCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/receipts",
    invalidate: ["invoices", "receipts"],
    successMessage: "Payment receipt recorded successfully",
    onDone: () => {
      setReceiptModal(false);
      setSelectedInvoice(null);
      setReceiptForm({ amount: "", mode: "NEFT", refNo: "", remark: "" });
    },
  });

  const rows = listQuery.data?.data ?? [];
  const clients = clientsQuery.data?.data ?? [];

  const totalInvoiced = rows.reduce(
    (acc, r) => acc + Number(r.NetAmount ?? r.TotalAmount ?? r.Amount ?? 0),
    0
  );
  const totalBalance = rows.reduce(
    (acc, r) => acc + Number(r.BalanceAmount ?? r.Outstanding ?? 0),
    0
  );

  return (
    <div>
      <PageHeader
        title="Client Billing Invoices"
        description="Tax invoices generated from guard shift deployments, billing rates, and GST compliance."
        actions={
          <div className="flex items-center gap-2">
            {has(Perm.invoiceEdit) ? (
              <Button variant="primary" onClick={() => setGenerateModal(true)}>
                + Generate Tax Invoice
              </Button>
            ) : null}
          </div>
        }
      />

      {/* KPI Overview */}
      <div className="mb-6 grid gap-4 sm:grid-cols-3">
        <StatCard label="Total Invoiced Value" value={money(totalInvoiced)} tone="default" />
        <StatCard
          label="Outstanding Receivables"
          value={money(totalBalance)}
          tone={totalBalance > 0 ? "danger" : "success"}
        />
        <StatCard
          label="Collections Received"
          value={money(Math.max(0, totalInvoiced - totalBalance))}
          tone="success"
        />
      </div>

      {/* Filter Tabs */}
      <div className="mb-4 flex flex-wrap items-center gap-2 border-b border-[var(--diti-border)] pb-2">
        {["", "Unpaid", "Partial", "Paid", "Overdue"].map((st) => (
          <Button
            key={st}
            size="sm"
            variant={(q.status ?? "") === st ? "primary" : "ghost"}
            onClick={() => q.setParams({ status: st || undefined, page: 1 })}
          >
            {st || "All Invoices"}
          </Button>
        ))}
      </div>

      {listQuery.isLoading ? <Skeleton className="h-64" /> : null}
      {listQuery.isError ? (
        <ErrorState
          message={
            listQuery.error instanceof Error ? listQuery.error.message : "Failed to load invoices"
          }
          onRetry={() => listQuery.refetch()}
        />
      ) : null}

      {listQuery.data ? (
        <>
          <DataTable
            columns={[
              {
                id: "no",
                header: "Invoice No",
                cell: (r) => (
                  <Link
                    href={`/finance/invoices/${cell(r, "BID", "Bid", "InvoiceID")}`}
                    className="font-semibold text-blue-600 hover:underline"
                  >
                    {cell(r, "InvoiceNo", "BillNo", "BID")}
                  </Link>
                ),
              },
              { id: "client", header: "Client", cell: (r) => cell(r, "ClientName") },
              {
                id: "period",
                header: "Period",
                cell: (r) => `${cell(r, "Month")}/${cell(r, "Year")}`,
              },
              {
                id: "amt",
                header: "Net Amount",
                className: "text-right",
                cell: (r) => (
                  <span className="tabular font-medium">
                    {money(r.NetAmount ?? r.TotalAmount ?? r.Amount)}
                  </span>
                ),
              },
              {
                id: "status",
                header: "Status",
                cell: (r) => <StatusPill>{cell(r, "Status", "BillStatus")}</StatusPill>,
              },
              {
                id: "actions",
                header: "Actions",
                className: "text-right",
                cell: (r) => (
                  <div className="flex items-center justify-end gap-2">
                    {has(Perm.invoiceEdit) && String(r.Status ?? "").toLowerCase() !== "paid" ? (
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => {
                          setSelectedInvoice(r);
                          setReceiptForm({
                            amount: String(r.BalanceAmount ?? r.NetAmount ?? ""),
                            mode: "NEFT",
                            refNo: "",
                            remark: "",
                          });
                          setReceiptModal(true);
                        }}
                      >
                        Record Receipt
                      </Button>
                    ) : null}
                    <Link href={`/finance/invoices/${cell(r, "BID", "Bid", "InvoiceID")}`}>
                      <Button size="sm" variant="ghost">
                        View Tax Invoice →
                      </Button>
                    </Link>
                  </div>
                ),
              },
            ]}
            rows={rows}
            rowKey={(r, i) => String(r.BID ?? r.Bid ?? r.InvoiceID ?? i)}
            empty={
              <EmptyState
                title="No invoices found"
                description="Click Generate Tax Invoice to bill client deployment."
              />
            }
          />
          <Pagination
            page={q.page}
            pageSize={q.pageSize}
            total={listQuery.data.meta?.total ?? rows.length}
            onPageChange={(page) => q.setParams({ page })}
          />
        </>
      ) : null}

      {/* Generate Invoice Modal */}
      <Modal
        open={generateModal}
        onOpenChange={setGenerateModal}
        title="Generate Tax Invoice"
        description="Compute monthly client deployment hours and generate GST invoice."
        footer={
          <Button
            loading={genCmd.isPending}
            disabled={!genForm.clientId || !genForm.month || !genForm.year}
            onClick={() =>
              genCmd.mutate({
                clientId: Number(genForm.clientId),
                month: Number(genForm.month),
                year: Number(genForm.year),
                gstPercent: Number(genForm.gstPercent),
              })
            }
          >
            Generate Invoice
          </Button>
        }
      >
        <div>
          <Label required>Client</Label>
          <Select
            value={genForm.clientId}
            onChange={(e) => setGenForm((f) => ({ ...f, clientId: e.target.value }))}
          >
            <option value="">Select Client...</option>
            {clients.map((c, i) => (
              <option key={String(c.ClientID ?? c.Id ?? i)} value={String(c.ClientID ?? c.Id ?? "")}>
                {String(c.ClientName ?? c.Name ?? "")}
              </option>
            ))}
          </Select>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <Label required>Billing Month (1-12)</Label>
            <Input
              type="number"
              min="1"
              max="12"
              value={genForm.month}
              onChange={(e) => setGenForm((f) => ({ ...f, month: e.target.value }))}
            />
          </div>
          <div>
            <Label required>Billing Year (YYYY)</Label>
            <Input
              type="number"
              value={genForm.year}
              onChange={(e) => setGenForm((f) => ({ ...f, year: e.target.value }))}
            />
          </div>
        </div>
        <div>
          <Label>GST Rate (%)</Label>
          <Input
            type="number"
            step="0.01"
            value={genForm.gstPercent}
            onChange={(e) => setGenForm((f) => ({ ...f, gstPercent: e.target.value }))}
          />
        </div>
      </Modal>

      {/* Record Receipt Modal */}
      <Modal
        open={receiptModal}
        onOpenChange={setReceiptModal}
        title="Record Payment Receipt"
        description={selectedInvoice ? `Recording collection for Invoice #${cell(selectedInvoice, "InvoiceNo", "BID")}` : "Payment Collection Entry"}
        footer={
          <Button
            loading={receiptCmd.isPending}
            disabled={!selectedInvoice || !receiptForm.amount}
            onClick={() =>
              receiptCmd.mutate({
                clientId: Number(selectedInvoice?.ClientID ?? 0),
                bid: Number(selectedInvoice?.BID ?? selectedInvoice?.Bid ?? 0),
                amount: Number(receiptForm.amount),
                mode: receiptForm.mode,
                refNo: receiptForm.refNo || undefined,
                remark: receiptForm.remark || undefined,
              })
            }
          >
            Save Payment Receipt
          </Button>
        }
      >
        <div>
          <Label required>Receipt Amount (₹)</Label>
          <Input
            type="number"
            step="0.01"
            value={receiptForm.amount}
            onChange={(e) => setReceiptForm((f) => ({ ...f, amount: e.target.value }))}
          />
        </div>
        <div>
          <Label required>Payment Mode</Label>
          <Select
            value={receiptForm.mode}
            onChange={(e) => setReceiptForm((f) => ({ ...f, mode: e.target.value }))}
          >
            <option value="NEFT">NEFT / RTGS / Bank Transfer</option>
            <option value="Cheque">Cheque</option>
            <option value="UPI">UPI / Digital</option>
            <option value="Cash">Cash</option>
          </Select>
        </div>
        <div>
          <Label>Bank Reference / Txn / Cheque No</Label>
          <Input
            placeholder="e.g. UTR1293840129"
            value={receiptForm.refNo}
            onChange={(e) => setReceiptForm((f) => ({ ...f, refNo: e.target.value }))}
          />
        </div>
        <div>
          <Label>Remarks</Label>
          <Input
            placeholder="Remarks or Payment Notes"
            value={receiptForm.remark}
            onChange={(e) => setReceiptForm((f) => ({ ...f, remark: e.target.value }))}
          />
        </div>
      </Modal>
    </div>
  );
}
