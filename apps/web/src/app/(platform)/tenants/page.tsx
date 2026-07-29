"use client";

import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { cell } from "@/lib/list-query";
import { count, date } from "@/lib/format";

/**
 * The platform view: every tenant on the installation.
 *
 * Only SUPER_ADMIN reaches this. Unlike every other list in the app, these rows
 * deliberately cross tenant boundaries, which is why the endpoint behind it is
 * the one place TenantGuard does not apply.
 */
export default function TenantsPage() {
  return (
    <ResourceList
      title="Tenants"
      description="Every agency on this installation, and when their subscription lapses."
      path="/api/v2/companies"
      queryKey="tenants"
      searchPlaceholder="Agency name or code…"
      rowKey={(r, i) => String(r.CompanyID ?? i)}
      emptyTitle="No tenants"
      emptyDescription="Agencies are onboarded from the platform console."
      columns={[
        {
          id: "company",
          header: "Agency",
          cell: (r) => (
            <div>
              <div className="font-medium text-text">{cell(r, "CompanyName")}</div>
              <div className="tabular text-xs text-muted">{cell(r, "CompanyCode")}</div>
            </div>
          ),
        },
        { id: "plan", header: "Plan", hideOnMobile: true, cell: (r) => cell(r, "PlanName") },
        {
          id: "users",
          header: "Users",
          className: "text-right",
          cell: (r) => {
            const used = Number(r.UserCount ?? 0);
            const limit = Number(r.MaxUsers ?? 0);
            // Over the limit is a billing conversation, so it is called out
            // rather than left for someone to notice.
            const over = limit > 0 && used > limit;
            return (
              <span className={over ? "tabular font-medium text-danger" : "tabular"}>
                {count(used)}
                {limit > 0 ? ` / ${count(limit)}` : ""}
              </span>
            );
          },
        },
        {
          id: "expires",
          header: "Expires",
          cell: (r) => {
            const exp = r.ExpiryDate ?? r.ValidTill;
            if (!exp) return <span className="text-muted">—</span>;
            const days = Math.ceil((new Date(String(exp)).getTime() - Date.now()) / 86_400_000);
            return (
              <div>
                <div className={days <= 30 ? "tabular font-medium text-warning" : "tabular"}>
                  {date(exp)}
                </div>
                {days < 0 ? (
                  <div className="text-xs text-danger">lapsed</div>
                ) : days <= 30 ? (
                  <div className="text-xs text-warning">{days} d left</div>
                ) : null}
              </div>
            );
          },
        },
        {
          id: "status",
          header: "Status",
          cell: (r) => <Status value={r.IsExpired ? "Expired" : r.IsActive === false ? "Inactive" : "Active"} />,
        },
      ]}
    />
  );
}
