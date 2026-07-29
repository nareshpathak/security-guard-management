import { useEffect, useState } from "react";
import { AppState } from "react-native";
import * as Network from "expo-network";
import { flush, pendingCount } from "./outbox";

/**
 * When the outbox is drained.
 *
 * The PRD asks for four triggers - connectivity regained, app foreground, every
 * five minutes, and manual pull-to-refresh. The first three live here; the
 * fourth is wired into each screen's refresh control.
 */
const INTERVAL_MS = 5 * 60 * 1000;

export function useSyncEngine(): { pending: number; syncNow: () => Promise<void> } {
  const [pending, setPending] = useState(0);

  async function refreshCount() {
    setPending(await pendingCount());
  }

  async function syncNow() {
    await flush();
    await refreshCount();
  }

  useEffect(() => {
    void refreshCount();

    const timer = setInterval(() => void syncNow(), INTERVAL_MS);

    const appState = AppState.addEventListener("change", (next) => {
      // Coming back to the foreground is the single most likely moment for the
      // phone to have signal again.
      if (next === "active") void syncNow();
    });

    let lastOnline = true;
    const connectivity = setInterval(async () => {
      const state = await Network.getNetworkStateAsync();
      const online = Boolean(state.isInternetReachable);
      if (online && !lastOnline) void syncNow();
      lastOnline = online;
    }, 15_000);

    return () => {
      clearInterval(timer);
      clearInterval(connectivity);
      appState.remove();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return { pending, syncNow };
}
