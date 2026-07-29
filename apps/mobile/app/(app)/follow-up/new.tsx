import { FieldForm } from "@/components/field-form";

/** Followup_frag / Nextfollowup_frag. */
export default function FollowUpScreen() {
  return (
    <FieldForm
      title="Log a follow-up"
      intro="What came of the last conversation, and when to call again."
      endpoint="/api/v2/sales/follow-ups"
      label={(v) => `Follow-up · ${v.companyName ?? ""}`}
      withPhoto={false}
      fields={[
        { name: "companyName", label: "Company", required: true },
        { name: "contactPerson", label: "Contact person" },
        { name: "remark", label: "Outcome", required: true, multiline: true },
        {
          name: "nextFollowUpDate",
          label: "Call again on",
          hint: "Format yyyy-mm-dd. Leave blank to stop following up.",
          maxLength: 10,
        },
      ]}
    />
  );
}
