"use client";

import { useQuery } from "@tanstack/react-query";
import { DataTable, EmptyState, ErrorState, PageHeader, Skeleton, StatusPill } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { cell } from "@/lib/list-query";

function expiryTone(value: string) {
  if (value === "—") return "neutral" as const;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "neutral" as const;
  const days = (d.getTime() - Date.now()) / 86_400_000;
  if (days < 0) return "danger" as const;
  if (days <= 30) return "warning" as const;
  return "success" as const;
}

export default function DocumentsPage() {
  const list = useQuery({
    queryKey: ["documents-expiring"],
    queryFn: async () =>
      (await getApi().get<Row[]>("/api/v2/documents/expiring", { withinDays: 90, page: 1, pageSize: 100 })).data,
  });

  return (
    <div>
      <PageHeader
        title="Document vault"
        description="Expiring police verifications, medicals, licences and agreements. Blob SAS upload is not enabled yet — register metadata via API when a URL is available."
      />
      {list.isLoading ? <Skeleton className="h-64" /> : null}
      {list.isError ? (
        <ErrorState message={list.error instanceof Error ? list.error.message : "Failed"} onRetry={() => list.refetch()} />
      ) : null}
      {list.data ? (
        <DataTable
          columns={[
            { id: "file", header: "Document", cell: (r) => cell(r, "FileName", "DocType", "OwnerType") },
            { id: "owner", header: "Owner", cell: (r) => `${cell(r, "OwnerType")} #${cell(r, "OwnerID", "OwnerId")}` },
            {
              id: "exp",
              header: "Expiry",
              cell: (r) => {
                const exp = cell(r, "ExpiryDate", "expiryDate");
                return <StatusPill tone={expiryTone(exp)}>{exp}</StatusPill>;
              },
            },
            { id: "url", header: "URL", hideOnMobile: true, cell: (r) => cell(r, "BlobUrl", "FileUrl") },
          ]}
          rows={list.data}
          rowKey={(r) => String(r.DocumentID ?? r.DocumentId ?? r.BlobUrl)}
          empty={
            <EmptyState
              title="No expiring documents"
              description="Nothing due in the next 90 days."
            />
          }
        />
      ) : null}
    </div>
  );
}
