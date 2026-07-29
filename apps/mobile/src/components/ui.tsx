import { ActivityIndicator, Pressable, Text, View, type PressableProps } from "react-native";

/**
 * The handful of primitives every screen needs.
 *
 * Touch targets are 48 dp minimum and primary actions sit in the bottom third,
 * because this app is used one-handed, outdoors, often in gloves.
 */

export function Button({
  title,
  onPress,
  loading,
  disabled,
  tone = "primary",
  className = "",
  ...rest
}: PressableProps & {
  title: string;
  loading?: boolean;
  tone?: "primary" | "danger" | "outline" | "ghost";
  className?: string;
}) {
  const base = "min-h-[48px] flex-row items-center justify-center rounded-xl px-5";
  const tones = {
    primary: "bg-primary",
    danger: "bg-danger",
    outline: "border border-border bg-surface",
    ghost: "bg-transparent",
  } as const;
  const labels = {
    primary: "text-white",
    danger: "text-white",
    outline: "text-text",
    ghost: "text-primary",
  } as const;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={title}
      accessibilityState={{ disabled: Boolean(disabled || loading), busy: Boolean(loading) }}
      disabled={disabled || loading}
      onPress={onPress}
      className={`${base} ${tones[tone]} ${disabled || loading ? "opacity-50" : ""} ${className}`}
      {...rest}
    >
      {loading ? (
        <ActivityIndicator color={tone === "outline" || tone === "ghost" ? "#0B5FFF" : "#fff"} />
      ) : (
        <Text className={`text-base font-semibold ${labels[tone]}`}>{title}</Text>
      )}
    </Pressable>
  );
}

export function Card({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return (
    <View className={`rounded-2xl border border-border bg-surface p-4 ${className}`}>{children}</View>
  );
}

export function Stat({ label, value, tone }: { label: string; value: string; tone?: "danger" | "success" | "warning" }) {
  const colour =
    tone === "danger" ? "text-danger" : tone === "success" ? "text-success" : tone === "warning" ? "text-warning" : "text-text";
  return (
    <View className="flex-1">
      <Text className="text-xs uppercase tracking-wide text-muted">{label}</Text>
      <Text className={`mt-1 text-2xl font-semibold ${colour}`}>{value}</Text>
    </View>
  );
}

export function Pill({ text, tone = "neutral" }: { text: string; tone?: "success" | "danger" | "warning" | "info" | "neutral" }) {
  const tones = {
    success: "bg-success/10 text-success",
    danger: "bg-danger/10 text-danger",
    warning: "bg-warning/10 text-warning",
    info: "bg-info/10 text-info",
    neutral: "bg-black/5 text-muted",
  } as const;
  return (
    <View className={`self-start rounded-full px-2.5 py-1 ${tones[tone].split(" ")[0]}`}>
      <Text className={`text-xs font-medium ${tones[tone].split(" ")[1]}`}>{text}</Text>
    </View>
  );
}

export function Empty({ title, hint }: { title: string; hint?: string }) {
  return (
    <View className="items-center justify-center px-6 py-16">
      <Text className="text-center text-base font-semibold text-text">{title}</Text>
      {hint ? <Text className="mt-2 text-center text-sm text-muted">{hint}</Text> : null}
    </View>
  );
}

export function Loading() {
  return (
    <View className="flex-1 items-center justify-center py-16">
      <ActivityIndicator color="#0B5FFF" />
    </View>
  );
}
