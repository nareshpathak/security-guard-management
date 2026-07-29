import { FieldForm } from "@/components/field-form";

export default function NewVisitScreen() {
  return (
    <FieldForm
      title="Log a visit"
      intro="A prospect you have just met. The follow-up date drives your reminders."
      endpoint="/api/v2/sales/visits"
      label={(v) => `Sales visit · ${v.companyName ?? ""}`}
      fields={[
        { name: "companyName", label: "Company", required: true },
        { name: "contactPerson", label: "Contact person", required: true },
        { name: "mobileNo", label: "Mobile", keyboard: "phone-pad", maxLength: 10 },
        { name: "purpose", label: "Purpose" },
        { name: "remark", label: "What was discussed", multiline: true },
        {
          name: "nextFollowUpDate",
          label: "Next follow-up",
          hint: "Format yyyy-mm-dd. Leave blank if there is nothing to chase.",
          maxLength: 10,
        },
      ]}
    />
  );
}
