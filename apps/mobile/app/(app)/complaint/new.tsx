import { FieldForm } from "@/components/field-form";

export default function NewComplaintScreen() {
  return (
    <FieldForm
      title="Raise a complaint"
      intro="Something about your duty, pay or site that needs attention."
      endpoint="/api/v2/complaints"
      label={(v) => `Complaint · ${v.subject?.slice(0, 30) ?? ""}`}
      withLocation={false}
      fields={[
        { name: "subject", label: "Subject", required: true, maxLength: 150 },
        { name: "description", label: "Details", required: true, multiline: true },
      ]}
    />
  );
}
