import { MobileList } from "@/components/mobile-list";

/** Uniformstock_frag. */
export default function UniformStockScreen() {
  return (
    <MobileList
      title="Uniform stock"
      subtitle="What is on the shelf"
      path="/api/v2/uniform/stock"
      queryKey="uniform-stock"
      emptyTitle="No stock recorded"
      line={{
        title: (r) => String(r.ItemName ?? "Item"),
        subtitle: (r) => String(r.CategoryName ?? ""),
        badge: (r) => {
          const inHand = Number(r.InHandQty ?? r.BalanceQty ?? 0);
          const reorder = Number(r.ReorderLevel ?? 0);
          if (inHand === 0) return { text: "Out of stock", tone: "danger" };
          if (reorder > 0 && inHand <= reorder) return { text: `Low · ${inHand}`, tone: "warning" };
          return { text: String(inHand), tone: "success" };
        },
        detail: (r) => `${String(r.IssuedQty ?? 0)} out with guards`,
      }}
    />
  );
}
