import { FieldForm } from "@/components/field-form";

/** Turnout_frag: the filed turnout register for a unit and shift. */
export default function TurnoutEntryScreen() {
  return (
    <FieldForm
      title="Turnout entry"
      intro="The strength you actually saw on the ground for this shift."
      endpoint="/api/v2/turnout"
      label={(v) => `Turnout · ${v.requiredNos ?? "?"} required`}
      withPhoto={false}
      fields={[
        { name: "requiredNos", label: "Required", required: true, keyboard: "number-pad", maxLength: 3 },
        { name: "presentNos", label: "Present", required: true, keyboard: "number-pad", maxLength: 3 },
        { name: "absentNos", label: "Absent", keyboard: "number-pad", maxLength: 3 },
        { name: "relieverNos", label: "Relievers used", keyboard: "number-pad", maxLength: 3 },
        { name: "remark", label: "Remark", multiline: true },
      ]}
    />
  );
}
