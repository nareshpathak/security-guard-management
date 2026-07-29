import { FieldForm } from "@/components/field-form";

/** Request_frag: leave, advance, transfer, uniform. */
export default function RequestScreen() {
  return (
    <FieldForm
      title="Make a request"
      intro="Leave, an advance, a transfer or uniform. Your supervisor decides."
      endpoint="/api/v2/hr/requests"
      label={(v) => `Request · ${v.requestType ?? ""}`}
      withPhoto={false}
      withLocation={false}
      fields={[
        {
          name: "requestType",
          label: "What are you asking for",
          required: true,
          hint: "Leave, Advance, Transfer or Uniform",
        },
        { name: "fromDate", label: "From", hint: "yyyy-mm-dd", maxLength: 10 },
        { name: "toDate", label: "To", hint: "yyyy-mm-dd", maxLength: 10 },
        { name: "amount", label: "Amount, if an advance", keyboard: "number-pad" },
        { name: "reason", label: "Reason", required: true, multiline: true },
      ]}
    />
  );
}
