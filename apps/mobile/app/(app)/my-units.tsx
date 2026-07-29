import { useRouter } from "expo-router";
import { MobileList } from "@/components/mobile-list";

/**
 * Myunits_frag: the sites this supervisor is responsible for, with the one
 * number that matters on each - how many guards are short right now.
 */
export default function MyUnitsScreen() {
  const router = useRouter();

  return (
    <MobileList
      title="My sites"
      subtitle="Strength against contract, right now"
      path="/api/v2/turnout/live"
      queryKey="my-units"
      emptyTitle="No sites assigned to you"
      line={{
        title: (r) => String(r.UnitName ?? "Site"),
        subtitle: (r) => String(r.ClientName ?? ""),
        badge: (r) => {
          const gap = Number(r.VacantNos ?? 0);
          return gap > 0
            ? { text: `${gap} short`, tone: "danger" }
            : { text: "At strength", tone: "success" };
        },
        detail: (r) =>
          `${String(r.PresentNos ?? 0)} present of ${String(r.RequiredNos ?? 0)} required`,
      }}
    />
  );
}
