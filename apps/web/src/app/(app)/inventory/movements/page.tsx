"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { Button, Card, Input, Label, PageHeader, Select, TextArea } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { useCommand } from "@/lib/use-command";

type Mode = "stock-in" | "issue" | "return";

const MODES: { id: Mode; label: string; blurb: string }[] = [
  { id: "stock-in", label: "Stock in", blurb: "Kit arriving from a supplier." },
  { id: "issue", label: "Issue to a guard", blurb: "Kit leaving the store with someone." },
  { id: "return", label: "Take back", blurb: "Kit coming back, in whatever condition." },
];

/**
 * Everything that moves uniform stock.
 *
 * Three endpoints, one screen: the stock figure people trust is the one that
 * every movement passes through, and three separate pages made it easy to
 * record an issue as a stock-in.
 */
export default function InventoryMovementsPage() {
  const [mode, setMode] = useState<Mode>("issue");
  const [form, setForm] = useState({
    itemId: "",
    empId: "",
    qty: "",
    rate: "",
    condition: "Good",
    remark: "",
    recoverAmount: "",
  });

  const items = useQuery({
    queryKey: ["uniform-stock"],
    queryFn: () => getApi().get<Row[]>("/api/v2/uniform/stock", { page: 1, pageSize: 200 }),
    staleTime: 60_000,
  });

  const submit = useCommand<Record<string, unknown>>({
    path: () => `/api/v2/uniform/${mode}`,
    invalidate: ["uniform-stock", "uniform-ledger", "uniform-issues"],
    successMessage: "Recorded",
    onDone: () => setForm((f) => ({ ...f, qty: "", remark: "", recoverAmount: "" })),
  });

  const selected = (items.data?.data ?? []).find((i) => String(i.ItemID) === form.itemId);
  const inHand = Number(selected?.InHandQty ?? selected?.BalanceQty ?? 0);
  const overIssuing = mode === "issue" && Number(form.qty || 0) > inHand;

  return (
    <div className="max-w-2xl">
      <PageHeader title="Stock movement" description={MODES.find((m) => m.id === mode)?.blurb} />

      <div className="mb-6 flex flex-wrap gap-2">
        {MODES.map((m) => (
          <Button key={m.id} size="sm" variant={mode === m.id ? "primary" : "outline"} onClick={() => setMode(m.id)}>
            {m.label}
          </Button>
        ))}
      </div>

      <Card className="grid gap-4 md:grid-cols-2">
        <div className="md:col-span-2">
          <Label required>Item</Label>
          <Select value={form.itemId} onChange={(e) => setForm((f) => ({ ...f, itemId: e.target.value }))}>
            <option value="">Choose an item…</option>
            {(items.data?.data ?? []).map((i, idx) => (
              <option key={String(i.ItemID ?? idx)} value={String(i.ItemID ?? "")}>
                {String(i.ItemName ?? "")} — {String(i.InHandQty ?? i.BalanceQty ?? 0)} in store
              </option>
            ))}
          </Select>
        </div>

        {mode !== "stock-in" ? (
          <div>
            <Label required>Employee id</Label>
            <Input
              inputMode="numeric"
              value={form.empId}
              onChange={(e) => setForm((f) => ({ ...f, empId: e.target.value.replace(/\D/g, "") }))}
            />
          </div>
        ) : null}

        <div>
          <Label required>Quantity</Label>
          <Input
            inputMode="numeric"
            value={form.qty}
            aria-invalid={overIssuing}
            onChange={(e) => setForm((f) => ({ ...f, qty: e.target.value.replace(/\D/g, "") }))}
          />
          {overIssuing ? (
            <p className="mt-1 text-xs text-danger">
              Only {inHand} in store. The server will reject issuing more than exists.
            </p>
          ) : null}
        </div>

        {mode === "stock-in" ? (
          <div>
            <Label>Rate</Label>
            <Input
              type="number"
              step="0.01"
              value={form.rate}
              onChange={(e) => setForm((f) => ({ ...f, rate: e.target.value }))}
            />
          </div>
        ) : null}

        {mode === "return" ? (
          <>
            <div>
              <Label>Condition</Label>
              <Select value={form.condition} onChange={(e) => setForm((f) => ({ ...f, condition: e.target.value }))}>
                {["Good", "Damaged", "Lost"].map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </Select>
            </div>
            <div>
              <Label>Recover from salary</Label>
              <Input
                type="number"
                step="0.01"
                value={form.recoverAmount}
                onChange={(e) => setForm((f) => ({ ...f, recoverAmount: e.target.value }))}
              />
              <p className="mt-1 text-xs text-muted">
                Only for damaged or lost kit. This is deducted from a guard&apos;s pay, so leave it
                blank unless it is genuinely owed.
              </p>
            </div>
          </>
        ) : null}

        <div className="md:col-span-2">
          <Label>Remark</Label>
          <TextArea value={form.remark} onChange={(e) => setForm((f) => ({ ...f, remark: e.target.value }))} />
        </div>

        <div className="md:col-span-2">
          <Button
            loading={submit.isPending}
            disabled={!form.itemId || !form.qty || (mode !== "stock-in" && !form.empId)}
            onClick={() =>
              submit.mutate({
                itemId: Number(form.itemId),
                empId: form.empId ? Number(form.empId) : undefined,
                qty: Number(form.qty),
                rate: form.rate ? Number(form.rate) : undefined,
                condition: mode === "return" ? form.condition : undefined,
                recoverAmount: form.recoverAmount ? Number(form.recoverAmount) : undefined,
                remark: form.remark || undefined,
              })
            }
          >
            {MODES.find((m) => m.id === mode)?.label}
          </Button>
        </div>
      </Card>
    </div>
  );
}
