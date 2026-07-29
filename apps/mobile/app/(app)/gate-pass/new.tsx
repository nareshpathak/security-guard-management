import { FieldForm } from "@/components/field-form";

export default function NewGatePassScreen() {
  return (
    <FieldForm
      title="New gate pass"
      intro="For material or a visitor leaving the site."
      endpoint="/api/v2/gate-passes"
      label={(v) => `Gate pass · ${v.name ?? ""}`}
      fields={[
        { name: "name", label: "Name", required: true },
        { name: "mobileNo", label: "Mobile", keyboard: "phone-pad", maxLength: 10 },
        { name: "purpose", label: "Purpose", required: true },
        { name: "whomToMeet", label: "Whom to meet" },
        { name: "vehicleNo", label: "Vehicle number" },
        {
          name: "material",
          label: "Material being taken out",
          multiline: true,
          hint: "Describe it properly. This is the record if anything is questioned later.",
        },
      ]}
    />
  );
}
