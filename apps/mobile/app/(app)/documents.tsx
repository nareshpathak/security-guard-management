import { useQuery } from "@tanstack/react-query";
import { FlatList, Text, View } from "react-native";
import type { Row } from "@diti365/shared";
import { Card, Empty, Loading, Pill } from "@/components/ui";
import { getApi } from "@/lib/api";

export default function DocumentsScreen() {
  const docs = useQuery({
    queryKey: ["my-documents"],
    // Everything lapsing within a year, so a guard can see what is coming
    // rather than only what is already a problem.
    queryFn: () => getApi().get<Row[]>("/api/v2/documents/expiring", { withinDays: 365, page: 1, pageSize: 50 }),
  });

  if (docs.isLoading) return <Loading />;

  return (
    <View className="flex-1 bg-bg pt-16">
      <Text className="px-4 pb-3 text-2xl font-semibold text-text">My documents</Text>

      <FlatList
        data={docs.data?.data ?? []}
        keyExtractor={(r, i) => String(r.DocumentID ?? i)}
        contentContainerClassName="gap-3 px-4 pb-8"
        ListEmptyComponent={
          <Empty title="Nothing lapsing" hint="Your documents are all valid for more than a year." />
        }
        renderItem={({ item }) => {
          const days = Math.ceil((new Date(String(item.ExpiryDate)).getTime() - Date.now()) / 86_400_000);
          return (
            <Card className="gap-2">
              <Text className="text-base font-medium text-text">{String(item.DocTypeName ?? "Document")}</Text>
              <Pill
                text={
                  days < 0
                    ? `Expired ${Math.abs(days)} days ago`
                    : days <= 30
                      ? `Expires in ${days} days`
                      : `Valid until ${new Date(String(item.ExpiryDate)).toLocaleDateString("en-IN")}`
                }
                tone={days < 0 ? "danger" : days <= 30 ? "warning" : "success"}
              />
            </Card>
          );
        }}
      />
    </View>
  );
}
