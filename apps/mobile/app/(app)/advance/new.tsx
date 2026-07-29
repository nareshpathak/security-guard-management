import { FieldForm } from "@/components/field-form";

/** Issueadvnce_frag. */
export default function IssueAdvanceScreen() {
  return (
    <FieldForm
      title="Issue an advance"
      intro="Recovered from salary in instalments. Both figures are needed."
      endpoint="/api/v2/advances"
      label={(v) => `Advance · employee ${v.empId ?? ""}`}
      withPhoto={false}
      withLocation={false}
      fields={[
        { name: "empId", label: "Employee id", required: true, keyboard: "number-pad" },
        { name: "amount", label: "Amount", required: true, keyboard: "number-pad" },
        {
          name: "installmentAmount",
          label: "Recover per month",
          required: true,
          keyboard: "number-pad",
          hint: "Keep this affordable. It comes straight out of take-home pay.",
        },
        { name: "reason", label: "Reason", required: true, multiline: true },
      ]}
    />
  );
}
