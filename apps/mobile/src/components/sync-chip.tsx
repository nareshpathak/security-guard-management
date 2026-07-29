import { Pressable, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { useSyncEngine } from "@/lib/sync";

/**
 * The persistent "3 pending" chip.
 *
 * The PRD calls for the sync state to be visible at all times, and it is right
 * to: a guard whose punch is sitting unsent needs to know before he goes home,
 * not when payroll runs three weeks later.
 */
export function SyncChip() {
  const { pending } = useSyncEngine();
  const router = useRouter();

  if (pending === 0) return null;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`${pending} item${pending === 1 ? "" : "s"} waiting to sync. Open the sync centre.`}
      onPress={() => router.push("/(app)/sync")}
      className="flex-row items-center gap-2 self-start rounded-full bg-warning/15 px-3 py-1.5"
    >
      <View className="h-2 w-2 rounded-full bg-warning" />
      <Text className="text-xs font-medium text-warning">
        {pending} waiting to sync
      </Text>
    </Pressable>
  );
}
