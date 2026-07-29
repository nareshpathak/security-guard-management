import { MobileList, shortDate } from "@/components/mobile-list";

/** Uniformledger_frag: what a guard has been issued and still owes. */
export default function UniformLedgerScreen() {
  return (
    <MobileList
      title="Uniform ledger"
      subtitle="Issued against returned, and what is still recoverable"
      path="/api/v2/uniform/ledger"
      queryKey="uniform-ledger"
      emptyTitle="Nothing issued"
      emptyHint="Uniform issued to you appears here until it is returned."
      line={{
        title: (r) => String(r.ItemName ?? "Item"),
        subtitle: (r) => `${String(r.EmpFullName ?? "")} · ${shortDate(r.IssueDate ?? r.Dated)}`,
        badge: (r) => {
          const owed = Number(r.RecoverableAmount ?? r.BalanceAmount ?? 0);
          return owed > 0
            ? { text: `₹${owed} to recover`, tone: "warning" }
            : { text: "Settled", tone: "success" };
        },
        detail: (r) =>
          `Issued ${String(r.IssuedQty ?? 0)}, returned ${String(r.RecievedQty ?? r.ReturnedQty ?? 0)}`,
      }}
    />
  );
}
