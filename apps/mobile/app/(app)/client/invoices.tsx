import { MobileList, shortDate } from "@/components/mobile-list";

export default function ClientInvoicesScreen() {
  return (
    <MobileList
      title="Invoices"
      subtitle="Raised against your account"
      path="/api/v2/invoices"
      queryKey="client-invoices"
      emptyTitle="No invoices yet"
      line={{
        title: (r) => String(r.InvoiceNo ?? "Invoice"),
        subtitle: (r) => `${shortDate(r.InvoiceDate)} · due ${shortDate(r.DueDate)}`,
        badge: (r) => {
          const status = String(r.Status ?? "");
          return {
            text: status,
            tone:
              status === "Paid" ? "success" : status === "Overdue" ? "danger" : status === "PartPaid" ? "warning" : "info",
          };
        },
        detail: (r) =>
          `₹${Number(r.GrandTotal ?? 0).toLocaleString("en-IN")} · ₹${Number(
            Number(r.GrandTotal ?? 0) - Number(r.ReceivedAmount ?? 0),
          ).toLocaleString("en-IN")} outstanding`,
      }}
    />
  );
}
