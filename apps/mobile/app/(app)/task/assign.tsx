import { FieldForm } from "@/components/field-form";

/** Taskassign_frag. */
export default function AssignTaskScreen() {
  return (
    <FieldForm
      title="Assign a task"
      intro="It appears on their phone immediately."
      endpoint="/api/v2/tasks"
      label={(v) => `Task · ${v.heading ?? ""}`}
      withPhoto={false}
      withLocation={false}
      fields={[
        { name: "heading", label: "Task", required: true, maxLength: 150 },
        { name: "description", label: "What needs doing", required: true, multiline: true },
        { name: "assignedToEmpId", label: "Employee id", required: true, keyboard: "number-pad" },
        { name: "dueDate", label: "Due", hint: "yyyy-mm-dd", maxLength: 10 },
        { name: "priority", label: "Priority", hint: "Low, Medium, High or Critical" },
      ]}
    />
  );
}
