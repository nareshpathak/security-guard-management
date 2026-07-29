"use client";

import { useQuery } from "@tanstack/react-query";
import { Card, ErrorState, PageHeader, Skeleton } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Status } from "@/components/status";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { count, date } from "@/lib/format";

/**
 * The tenant's own record.
 *
 * Read-only for now: changing a company's plan or user limit is a billing
 * action, and doing it from the same screen that shows the address invites
 * accidents.
 */
export default function CompanyPage() {
  const { user } = useAuth();

  const companies = useQuery({
    queryKey: ["my-company"],
    queryFn: () => getApi().get<Row[]>("/api/v2/companies"),
  });

  if (companies.isLoading) return <Skeleton className="h-64" />;
  if (companies.isError)
    return (
      <ErrorState
        message={companies.error instanceof Error ? companies.error.message : "Could not load the company."}
        onRetry={() => companies.refetch()}
      />
    );

  const me = (companies.data?.data ?? []).find((c) => Number(c.CompanyID) === user?.companyId)
    ?? companies.data?.data?.[0];

  if (!me) return <ErrorState title="No company record" message="This account is not linked to a tenant." />;

  const rows: [string, React.ReactNode][] = [
    ["Code", String(me.CompanyCode ?? "—")],
    ["Plan", String(me.PlanName ?? "—")],
    ["Users", `${count(me.UserCount)}${me.MaxUsers ? ` of ${count(me.MaxUsers)}` : ""}`],
    ["Subscription expires", date(me.ExpiryDate ?? me.ValidTill)],
    ["Address", String(me.Address ?? me.CompanyAddress ?? "—")],
    ["GSTIN", String(me.GSTIN ?? "—")],
    ["Status", <Status key="s" value={me.IsExpired ? "Expired" : "Active"} />],
  ];

  return (
    <div className="max-w-2xl">
      <PageHeader title={String(me.CompanyName ?? "Company")} description="Your agency's record on this platform." />
      <Card className="divide-y divide-border">
        {rows.map(([label, value]) => (
          <div key={label} className="flex items-center justify-between gap-4 py-3 first:pt-0 last:pb-0">
            <span className="text-sm text-muted">{label}</span>
            <span className="text-sm font-medium text-text">{value}</span>
          </div>
        ))}
      </Card>
    </div>
  );
}
