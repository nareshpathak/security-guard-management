"use client";

import { useQuery } from "@tanstack/react-query";
import { useParams, useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Card, DataTable, EmptyState, ErrorState, Input, Label, PageHeader, Select, Skeleton } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Status } from "@/components/status";
import { Modal } from "@/components/modal";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";
import { cell } from "@/lib/list-query";
import { count, date, isoDate, moneyExact } from "@/lib/format";

const MODES = ["NEFT", "RTGS", "Cheque", "Cash", "UPI"];

/** One invoice, its lines, and the receipts posted against it. */
export default function InvoiceDetailPage() {
  const { bid } = useParams<{ bid: string }>();
  const router = useRouter();
  const { has } = useAuth();
  const [paying, setPaying] = useState(false);

  const detail = useQuery({
    queryKey: ["invoice", bid],
    queryFn: () => getApi().get<Row[][]>(`/api/v2/invoices/${bid}`),
  });

  const [form, setForm] = useState({
    amount: "",
    receivedOn: isoDate(new Date()),
    mode: "NEFT",
    refNo: "",
    remark: "",
  });

  const invoice = detail.data?.data?.[0]?.[0] ?? {};

  const receipt = useCommand<Record<string, unknown>>({
    path: "/api/v2/receipts",
    invalidate: ["invoice", "invoices", "receipts", "ageing"],
    successMessage: "Receipt recorded",
    onDone: () => {
      setPaying(false);
      setForm((f) => ({ ...f, amount: "", refNo: "", remark: "" }));
    },
  });

  if (detail.isLoading) return <Skeleton className="h-96" />;
  if (detail.isError)
    return (
      <ErrorState
        message={detail.error instanceof Error ? detail.error.message : "Could not load this invoice."}
        onRetry={() => detail.refetch()}
      />
    );

  const [, lines = [], receipts = []] = detail.data?.data ?? [];
  const outstanding = Number(invoice.GrandTotal ?? 0) - Number(invoice.ReceivedAmount ?? 0);

  return (
    <div>
      <PageHeader
        title={String(invoice.InvoiceNo ?? `Invoice ${bid}`)}
        description={`${cell(invoice, "ClientName")} · raised ${date(invoice.InvoiceDate)} · due ${date(invoice.DueDate)}`}
        actions={
          <div className="flex gap-2">
            <Button variant="outline" onClick={() => router.push("/finance/invoices")}>
              Back
            </Button>
            {outstanding > 0 && has(Perm.invoiceEdit) ? (
              <Button onClick={() => setPaying(true)}>Record a receipt</Button>
            ) : null}
          </div>
        }
      />

      <div className="mb-8 grid gap-4 sm:grid-cols-4">
        <Card>
          <div className="text-xs uppercase tracking-wide text-muted">Status</div>
          <div className="mt-2"><Status value={invoice.Status} /></div>
        </Card>
        <Card>
          <div className="text-xs uppercase tracking-wide text-muted">Invoiced</div>
          <div className="tabular mt-2 text-xl font-semibold">{moneyExact(invoice.GrandTotal)}</div>
        </Card>
        <Card>
          <div className="text-xs uppercase tracking-wide text-muted">Received</div>
          <div className="tabular mt-2 text-xl font-semibold text-success">{moneyExact(invoice.ReceivedAmount)}</div>
        </Card>
        <Card>
          <div className="text-xs uppercase tracking-wide text-muted">Outstanding</div>
          <div className={`tabular mt-2 text-xl font-semibold ${outstanding > 0 ? "text-warning" : ""}`}>
            {moneyExact(outstanding)}
          </div>
        </Card>
      </div>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold text-muted">Lines</h2>
        <DataTable
          columns={[
            { id: "unit", header: "Site", cell: (r) => cell(r, "UnitName") },
            { id: "post", header: "Post", hideOnMobile: true, cell: (r) => cell(r, "PostName", "DesignationName") },
            { id: "nos", header: "Guards", className: "text-right", cell: (r) => <span className="tabular">{count(r.Nos ?? r.Quantity)}</span> },
            { id: "rate", header: "Rate", className: "text-right", cell: (r) => <span className="tabular">{moneyExact(r.Rate)}</span> },
            { id: "amount", header: "Amount", className: "text-right", cell: (r) => <span className="tabular font-medium">{moneyExact(r.Amount)}</span> },
          ]}
          rows={lines}
          rowKey={(_, i) => i}
          empty={<EmptyState title="No lines" description="This invoice was raised with no billable deployment." />}
        />
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold text-muted">Receipts</h2>
        <DataTable
          columns={[
            { id: "on", header: "Received", cell: (r) => <span className="tabular">{date(r.ReceivedOn)}</span> },
            { id: "mode", header: "Mode", cell: (r) => cell(r, "Mode") },
            { id: "ref", header: "Reference", hideOnMobile: true, cell: (r) => <span className="tabular text-muted">{cell(r, "RefNo")}</span> },
            { id: "amount", header: "Amount", className: "text-right", cell: (r) => <span className="tabular font-medium">{moneyExact(r.Amount)}</span> },
          ]}
          rows={receipts}
          rowKey={(_, i) => i}
          empty={<EmptyState title="Nothing received yet" />}
        />
      </section>

      <Modal
        open={paying}
        onOpenChange={setPaying}
        title="Record a receipt"
        description={`Outstanding on this invoice: ${moneyExact(outstanding)}`}
        footer={
          <Button
            loading={receipt.isPending}
            disabled={!form.amount || Number(form.amount) <= 0}
            onClick={() =>
              receipt.mutate({
                clientId: invoice.ClientID,
                bid: Number(bid),
                amount: Number(form.amount),
                receivedOn: form.receivedOn,
                mode: form.mode,
                refNo: form.refNo || undefined,
                remark: form.remark || undefined,
              })
            }
          >
            Record
          </Button>
        }
      >
        <div>
          <Label required>Amount</Label>
          <Input
            type="number"
            step="0.01"
            value={form.amount}
            onChange={(e) => setForm((f) => ({ ...f, amount: e.target.value }))}
          />
          {Number(form.amount) > outstanding ? (
            <p className="mt-1 text-xs text-warning">
              That is more than is outstanding. The server will reject an overpayment.
            </p>
          ) : null}
        </div>
        <div>
          <Label required>Received on</Label>
          <Input type="date" value={form.receivedOn} onChange={(e) => setForm((f) => ({ ...f, receivedOn: e.target.value }))} />
        </div>
        <div>
          <Label>Mode</Label>
          <Select value={form.mode} onChange={(e) => setForm((f) => ({ ...f, mode: e.target.value }))}>
            {MODES.map((m) => (
              <option key={m} value={m}>
                {m}
              </option>
            ))}
          </Select>
        </div>
        <div>
          <Label>Reference</Label>
          <Input value={form.refNo} onChange={(e) => setForm((f) => ({ ...f, refNo: e.target.value }))} />
        </div>
      </Modal>
    </div>
  );
}
