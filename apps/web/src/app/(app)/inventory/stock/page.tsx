"use client";

import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { cell } from "@/lib/list-query";
import { count, money } from "@/lib/format";

export default function StockPage() {
  return (
    <ResourceList
      title="Uniform stock"
      description="What is on the shelf, what is out with guards, and what is running low."
      path="/api/v2/uniform/stock"
      queryKey="uniform-stock"
      searchPlaceholder="Item name…"
      rowKey={(r, i) => String(r.ItemID ?? i)}
      emptyTitle="No stock recorded"
      emptyDescription="Record a stock-in to start tracking uniform and equipment."
      columns={[
        {
          id: "item",
          header: "Item",
          cell: (r) => (
            <div>
              <div className="font-medium text-text">{cell(r, "ItemName")}</div>
              <div className="text-xs text-muted">{cell(r, "CategoryName", "ItemCode")}</div>
            </div>
          ),
        },
        {
          id: "inhand",
          header: "In store",
          className: "text-right",
          cell: (r) => {
            const inHand = Number(r.InHandQty ?? r.BalanceQty ?? 0);
            const reorder = Number(r.ReorderLevel ?? 0);
            // Below the reorder level is the only number on this screen that
            // requires someone to do something.
            const low = reorder > 0 && inHand <= reorder;
            return (
              <span className={low ? "tabular font-medium text-danger" : "tabular"}>
                {count(inHand)}
              </span>
            );
          },
        },
        {
          id: "issued",
          header: "With guards",
          className: "text-right",
          cell: (r) => <span className="tabular">{count(r.IssuedQty)}</span>,
        },
        {
          id: "reorder",
          header: "Reorder at",
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
          header: "",
          cell: (r) => {
            const inHand = Number(r.InHandQty ?? r.BalanceQty ?? 0);
            const reorder = Number(r.ReorderLevel ?? 0);
            if (inHand === 0) return <Status value="Out of stock" />;
            if (reorder > 0 && inHand <= reorder) return <Status value="Low" />;
            return null;
          },
        },
      ]}
    />
  );
}
