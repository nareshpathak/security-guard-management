"use client";

import { useQuery } from "@tanstack/react-query";
import { Button, Card, ErrorState, PageHeader, Skeleton } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Status } from "@/components/status";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";

/**
 * What the server thinks this session is.
 *
 * Useful precisely when something looks wrong: a user seeing another branch's
 * data, or none of their own, is nearly always a claim that is not what they
 * expect. This shows the claims the API is actually enforcing.
 */
export default function SessionPage() {
  const { logout } = useAuth();

  const me = useQuery({
    queryKey: ["me"],
    queryFn: () => getApi().get<Row>("/api/v2/me"),
  });

  if (me.isLoading) return <Skeleton className="h-64" />;
  if (me.isError)
    return (
      <ErrorState
        message={me.error instanceof Error ? me.error.message : "Could not read your session."}
        onRetry={() => me.refetch()}
      />
    );

  const m = me.data?.data ?? {};

  const rows: [string, React.ReactNode][] = [
    ["User", String(m.userName ?? m.UserName ?? "—")],
    ["Name", String(m.name ?? m.Name ?? "—")],
    ["Role", <Status key="r" value={m.roleCode ?? m.RoleCode} />],
    ["Company", String(m.companyId ?? m.CompanyId ?? "—")],
    ["Branch", String(m.branchId ?? m.BranchId ?? "all branches")],
    ["Employee record", String(m.empId ?? m.EmpId ?? "not linked")],
    ["Client record", String(m.clientId ?? m.ClientId ?? "not a client login")],
  ];

  return (
    <div className="max-w-xl">
      <PageHeader
        title="This session"
        description="The claims the API is enforcing for you right now."
      />

      <Card className="mb-4 divide-y divide-border">
        {rows.map(([label, value]) => (
          <div key={label} className="flex items-center justify-between gap-4 py-3 first:pt-0 last:pb-0">
            <span className="text-sm text-muted">{label}</span>
            <span className="text-sm font-medium text-text">{value}</span>
          </div>
        ))}
      </Card>

      <div className="flex gap-2">
        <Button variant="outline" onClick={() => me.refetch()}>
          Refresh
        </Button>
        <Button variant="danger" onClick={() => void logout()}>
          Sign out everywhere on this browser
        </Button>
      </div>

      <p className="mt-4 text-xs text-muted">
        Company and branch come from the signed token, never from anything the browser sends. If
        the company shown here is wrong, sign out and back in.
      </p>
    </div>
  );
}
