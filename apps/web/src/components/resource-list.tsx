"use client";

import { useQuery } from "@tanstack/react-query";
import {
  DataTable,
  EmptyState,
  ErrorState,
  PageHeader,
  Pagination,
  Skeleton,
  type Column,
} from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { SearchField, useListQueryState } from "@/lib/list-query";

/**
 * The shape every list screen in this app has: header, optional filters, a
 * paged table driven by the URL, and honest loading / empty / error states.
 *
 * It exists because the first few screens were each ~120 lines of the same
 * five blocks, and every copy was a chance for one of them to drift - a
 * missing error state, a page size that ignored the URL, a spinner where a
 * skeleton belongs. Screens are now a column list and a path.
 */
export function ResourceList({
  title,
  description,
  actions,
  path,
  queryKey,
  params,
  columns,
  rowKey,
  onRowClick,
  emptyTitle,
  emptyDescription,
  emptyAction,
  searchPlaceholder,
  filters,
  enabled = true,
  refetchInterval,
}: {
  title: string;
  description?: string;
  actions?: React.ReactNode;
  /** API path, e.g. "/api/v2/clients". */
  path: string;
  /** Stable prefix for the react-query cache key. */
  queryKey: string;
  /** Extra query-string values beyond page/pageSize/search. */
  params?: Record<string, string | number | boolean | undefined | null>;
  columns: Column<Row>[];
  rowKey: (row: Row, index: number) => string | number;
  onRowClick?: (row: Row) => void;
  emptyTitle: string;
  emptyDescription?: string;
  emptyAction?: React.ReactNode;
  /** Omit to hide the search box for endpoints that do not support @Search. */
  searchPlaceholder?: string;
  filters?: React.ReactNode;
  enabled?: boolean;
  /** Milliseconds. Only for genuinely live boards - turnout, tracking. */
  refetchInterval?: number;
}) {
  const q = useListQueryState();

  const query = useQuery({
    // Every value that changes the request is in the key, otherwise switching
    // filters would show the previous filter's rows from cache.
    queryKey: [queryKey, q.page, q.pageSize, q.search, params],
    enabled,
    refetchInterval,
    queryFn: () =>
      getApi().get<Row[]>(path, {
        page: q.page,
        pageSize: q.pageSize,
        search: q.search || undefined,
        ...params,
      }),
  });

  return (
    <div>
      <PageHeader title={title} description={description} actions={actions} />

      {searchPlaceholder || filters ? (
        <div className="mb-4 flex flex-wrap items-end gap-3">
          {searchPlaceholder ? (
            <SearchField
              value={q.search}
              placeholder={searchPlaceholder}
              // Reset to page 1: staying on page 7 of a narrower result set
              // shows an empty table and looks like a bug.
              onChange={(search) => q.setParams({ search, page: 1 })}
            />
          ) : null}
          {filters}
        </div>
      ) : null}

      {query.isLoading ? (
        <div className="space-y-2">
          <Skeleton className="h-11" />
          <Skeleton className="h-11 opacity-80" />
          <Skeleton className="h-11 opacity-60" />
          <Skeleton className="h-11 opacity-40" />
          <Skeleton className="h-11 opacity-20" />
        </div>
      ) : null}

      {query.isError ? (
        <ErrorState
          message={query.error instanceof Error ? query.error.message : "Could not load this list."}
          onRetry={() => query.refetch()}
        />
      ) : null}

      {query.data ? (
        <>
          <DataTable
            columns={columns}
            rows={query.data.data}
            rowKey={rowKey}
            onRowClick={onRowClick}
            empty={
              <EmptyState
                title={q.search ? `Nothing matches “${q.search}”` : emptyTitle}
                description={q.search ? "Try a shorter or different search." : emptyDescription}
                action={q.search ? undefined : emptyAction}
              />
            }
          />
          {query.data.data.length > 0 ? (
            <Pagination
              page={q.page}
              pageSize={q.pageSize}
              total={query.data.meta?.total ?? query.data.data.length}
              onPageChange={(page) => q.setParams({ page })}
            />
          ) : null}
        </>
      ) : null}
    </div>
  );
}
