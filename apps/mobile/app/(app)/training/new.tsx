import { FieldForm } from "@/components/field-form";

/** Training_frag. */
export default function TrainingScreen() {
  return (
    <FieldForm
      title="Record training"
      intro="Fire drill, access control, grooming — whatever you ran today."
      endpoint="/api/v2/hr/trainings"
      label={(v) => `Training · ${v.topic ?? ""}`}
      fields={[
        { name: "topic", label: "Topic", required: true },
        { name: "timing", label: "Timing", hint: "e.g. 10:00 - 12:00" },
        { name: "nop", label: "How many attended", required: true, keyboard: "number-pad", maxLength: 3 },
        { name: "remark", label: "Notes", multiline: true },
      ]}
    />
  );
}
