import { FieldForm } from "@/components/field-form";

export default function NewIncidentScreen() {
  return (
    <FieldForm
      title="Report an incident"
      intro="Anything that went wrong at the site. Your supervisor is notified as soon as this syncs."
      endpoint="/api/v2/incidents"
      label={(v) => `Incident · ${v.subject?.slice(0, 30) ?? "report"}`}
      fields={[
        { name: "subject", label: "What happened", required: true, maxLength: 150 },
        {
          name: "description",
          label: "Describe it",
          required: true,
          multiline: true,
          hint: "Times, names and what you did. Write it while it is fresh.",
        },
        { name: "severity", label: "How serious", hint: "Low, Medium, High or Critical" },
      ]}
    />
  );
}
