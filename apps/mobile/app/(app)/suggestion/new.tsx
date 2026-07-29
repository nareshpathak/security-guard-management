import { FieldForm } from "@/components/field-form";

/** Suggestion_frag. */
export default function SuggestionScreen() {
  return (
    <FieldForm
      title="Make a suggestion"
      intro="Something that would make the work safer or easier. It reaches the office directly."
      endpoint="/api/v2/hr/suggestions"
      label={(v) => `Suggestion · ${v.subject?.slice(0, 30) ?? ""}`}
      withPhoto={false}
      withLocation={false}
      fields={[
        { name: "subject", label: "Subject", required: true, maxLength: 150 },
        { name: "description", label: "Your suggestion", required: true, multiline: true },
      ]}
    />
  );
}
