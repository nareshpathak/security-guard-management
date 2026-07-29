import { FieldForm } from "@/components/field-form";

/** Movement_frag: shifting a guard between sites or posts. */
export default function MovementScreen() {
  return (
    <FieldForm
      title="Move a guard"
      intro="Between sites or posts. The old deployment closes and a new one opens."
      endpoint="/api/v2/deployments/movement"
      label={(v) => `Movement · employee ${v.empId ?? ""}`}
      withPhoto={false}
      withLocation={false}
      fields={[
        { name: "empId", label: "Employee id", required: true, keyboard: "number-pad" },
        { name: "toUnitId", label: "Move to site id", required: true, keyboard: "number-pad" },
        { name: "effectiveFrom", label: "Effective from", hint: "yyyy-mm-dd", maxLength: 10 },
        { name: "remark", label: "Why", required: true, multiline: true },
      ]}
    />
  );
}
