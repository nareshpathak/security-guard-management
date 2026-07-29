import { FieldForm } from "@/components/field-form";

/** Clientrelation_frag: a courtesy visit to an existing client. */
export default function ClientRelationScreen() {
  return (
    <FieldForm
      title="Client relation visit"
      intro="A visit to a client you already serve."
      endpoint="/api/v2/sales/client-relations"
      label={(v) => `Client visit · ${v.contactPerson ?? ""}`}
      fields={[
        { name: "contactPerson", label: "Person met", required: true },
        { name: "mobileNo", label: "Their mobile", keyboard: "phone-pad", maxLength: 10 },
        { name: "timing", label: "Timing" },
        { name: "remark", label: "What was discussed", required: true, multiline: true },
      ]}
    />
  );
}
