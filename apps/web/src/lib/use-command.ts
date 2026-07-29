"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { ApiError, type SpResult } from "@diti365/shared";
import { getApi } from "./api";

/**
 * A write to the API, with the three things every write needs and that are
 * otherwise forgotten one at a time: a success message, an error message the
 * user can act on, and the cache invalidated so the list they are looking at
 * reflects what just happened.
 */
export function useCommand<TInput = void>({
  path,
  method = "post",
  invalidate = [],
  successMessage,
  onDone,
}: {
  /** Static path, or a function of the input for id-bearing routes. */
  path: string | ((input: TInput) => string);
  method?: "post" | "put" | "patch" | "delete";
  /** Query-key prefixes to refetch afterwards. */
  invalidate?: string[];
  successMessage?: string | ((result: SpResult) => string);
  onDone?: (result: SpResult) => void;
}) {
  const qc = useQueryClient();

  return useMutation({
    mutationFn: async (input: TInput) => {
      const url = typeof path === "function" ? path(input) : path;
      const api = getApi();
      const body = input as unknown;

      const { data } =
        method === "delete"
          ? await api.delete<SpResult>(url)
          : method === "put"
            ? await api.put<SpResult>(url, body)
            : method === "patch"
              ? await api.patch<SpResult>(url, body)
              : await api.post<SpResult>(url, body);

      return data;
    },
    onSuccess: async (result) => {
      toast.success(
        typeof successMessage === "function"
          ? successMessage(result)
          : (successMessage ?? result?.message ?? "Saved"),
      );
      await Promise.all(invalidate.map((key) => qc.invalidateQueries({ queryKey: [key] })));
      onDone?.(result);
    },
    onError: (error) => {
      /*  The API's own message is written for end users and usually says
          exactly what is wrong - "attendance is locked for this month", "the
          guard is already deployed". Replacing it with a generic string would
          throw away the useful half of the response.  */
      toast.error(
        error instanceof ApiError
          ? (error.detail ?? error.message)
          : "Something went wrong. Try again.",
      );
    },
  });
}
