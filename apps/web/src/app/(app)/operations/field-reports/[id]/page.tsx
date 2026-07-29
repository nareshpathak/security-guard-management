"use client";

import { useQuery } from "@tanstack/react-query";
import { useParams, useRouter } from "next/navigation";
import { Button, Card, DataTable, EmptyState, ErrorState, PageHeader, Skeleton } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { cell } from "@/lib/list-query";
import { dateTime } from "@/lib/format";

/** One field report, with the per-guard remarks the supervisor recorded. */
export default function FieldReportDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();

  const detail = useQuery({
    queryKey: ["field-report", id],
    queryFn: () => getApi().get<Row[][]>(`/api/v2/field-reports/${id}`),
  });

  if (detail.isLoading) return <Skeleton className="h-96" />;
  if (detail.isError)
    return (
      <ErrorState
        message={detail.error instanceof Error ? detail.error.message : "Could not load this report."}
        onRetry={() => detail.refetch()}
      />
    );

  const [header = [], guards = []] = detail.data?.data ?? [];
  const r = header[0] ?? {};

  return (
    <div className="max-w-3xl">
      <PageHeader
        title={String(r.UnitName ?? `Field report ${id}`)}
        description={`${dateTime(r.Createdate)} · ${cell(r, "SupervisorName")}`}
        actions={
          <Button variant="outline" onClick={() => router.push("/operations/field-reports")}>
            Back
          </Button>
        }
      />

      <Card className="mb-6 space-y-3">
        <div>
          <div className="text-xs uppercase tracking-wide text-muted">Person met</div>
          <div className="mt-1 text-sm text-text">{cell(r, "ContactPerson")}</div>
        </div>
        <div>
          <div className="text-xs uppercase tracking-wide text-muted">Findings</div>
          <p className="mt-1 whitespace-pre-wrap text-sm text-text">{cell(r, "Remark")}</p>
        </div>
        {r.Latitude ? (
          <div>
            <div className="text-xs uppercase tracking-wide text-muted">Filed from</div>
            <a
              className="tabular mt-1 inline-block text-sm text-primary underline"
              href={`https://www.google.com/maps?q=${r.Latitude},${r.Longitude}`}
              target="_blank"
              rel="noopener noreferrer"
            >
              {Number(r.Latitude).toFixed(5)}, {Number(r.Longitude).toFixed(5)}
            </a>
          </div>
        ) : null}
      </Card>

      <h2 className="mb-3 text-sm font-semibold text-muted">Guard by guard</h2>
      <DataTable
        columns={[
          { id: "emp", header: "Guard", cell: (r) => cell(r, "EmpFullName") },
          { id: "code", header: "Code", hideOnMobile: true, cell: (r) => <span className="tabular">{cell(r, "EmpCode")}</span> },
          { id: "remark", header: "Remark", cell: (r) => <span className="line-clamp-2">{cell(r, "Remark")}</span> },
        ]}
        rows={guards}
        rowKey={(_, i) => i}
        empty={<EmptyState title="No per-guard remarks" description="The supervisor recorded a site-level note only." />}
      />
    </div>
  );
}
