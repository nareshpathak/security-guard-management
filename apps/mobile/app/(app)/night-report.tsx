import { FieldForm } from "@/components/field-form";

/** Shownightpatrol_frag: the end-of-shift summary a night patrol files. */
export default function NightReportScreen() {
  return (
    <FieldForm
      title="Night report"
      intro="Your end-of-shift summary. File it before you hand over."
      endpoint="/api/v2/field-reports"
      label={() => "Night report"}
      fields={[
        { name: "contactPerson", label: "Handed over to", required: true },
        {
          name: "remark",
          label: "The night in summary",
          required: true,
          multiline: true,
          hint: "Rounds completed, anything unusual, anything the day shift must know.",
        },
      ]}
    />
  );
}
