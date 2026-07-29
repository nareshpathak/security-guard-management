import { FieldForm } from "@/components/field-form";

/** Fieldreport_frag: a supervisor's visit record for a site. */
export default function FieldReportScreen() {
  return (
    <FieldForm
      title="Field report"
      intro="Your visit to the site: who you met, what you found."
      endpoint="/api/v2/field-reports"
      label={(v) => `Field report · ${v.contactPerson ?? ""}`}
      fields={[
        { name: "contactPerson", label: "Person met", required: true },
        { name: "mobileNo", label: "Their mobile", keyboard: "phone-pad", maxLength: 10 },
        {
          name: "remark",
          label: "What you found",
          required: true,
          multiline: true,
          hint: "Turnout, grooming, equipment, client mood. Be specific.",
        },
      ]}
    />
  );
}
