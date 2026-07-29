"use client";

import { useQuery } from "@tanstack/react-query";
import { Card, EmptyState, ErrorState, PageHeader, Skeleton } from "@diti365/ui";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";

/**
 * What the signed-in user can actually do.
 *
 * Grouped by module prefix - M8.Attendance.Approve becomes "Attendance:
 * Approve" under module 8 - because the raw codes are unreadable and the
 * grouping is already encoded in them.
 */
export default function RolesPage() {
  const { user } = useAuth();

  const permissions = useQuery({
    queryKey: ["my-permissions"],
    queryFn: () => getApi().get<string[]>("/api/v2/me/permissions"),
  });

  if (permissions.isLoading) return <Skeleton className="h-64" />;
  if (permissions.isError)
    return (
      <ErrorState
        message={permissions.error instanceof Error ? permissions.error.message : "Could not load permissions."}
        onRetry={() => permissions.refetch()}
      />
    );

  const codes = permissions.data?.data ?? [];

  const groups = new Map<string, string[]>();
  for (const code of codes) {
    const [, area = "General", action = code] = code.split(".");
    const list = groups.get(area) ?? [];
    list.push(action);
    groups.set(area, list);
  }

  return (
    <div className="max-w-3xl">
      <PageHeader
        title="Your permissions"
        description={`Role ${user?.roleCode ?? ""} · ${codes.length} permissions granted`}
      />

      {codes.length === 0 ? (
        <EmptyState title="No permissions" description="This role can sign in but do nothing. Ask an administrator." />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {[...groups.entries()]
            .sort(([a], [b]) => a.localeCompare(b))
            .map(([area, actions]) => (
              <Card key={area}>
                <h2 className="mb-2 text-sm font-semibold text-text">{area}</h2>
                <div className="flex flex-wrap gap-1.5">
                  {actions.sort().map((a) => (
                    <span
                      key={a}
                      className="rounded-full bg-primary-subtle px-2.5 py-0.5 text-xs font-medium text-primary"
                    >
                      {a}
                    </span>
                  ))}
                </div>
              </Card>
            ))}
        </div>
      )}
    </div>
  );
}
