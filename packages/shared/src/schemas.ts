import { z } from "zod";

export const loginSchema = z.object({
  loginId: z.string().min(1, "Login id is required"),
  password: z.string().min(1, "Password is required"),
});

export type LoginFormValues = z.infer<typeof loginSchema>;

export const clientSchema = z.object({
  clientName: z.string().min(1, "Client name is required"),
  contactPerson: z.string().optional(),
  contactNo: z.string().optional(),
  email: z.string().email().optional().or(z.literal("")),
  address: z.string().optional(),
  gstin: z.string().optional(),
  pan: z.string().optional(),
  clientCode: z.string().optional(),
});

export const unitSchema = z.object({
  clientId: z.coerce.number().min(1, "Client is required"),
  unitName: z.string().min(1, "Unit name is required"),
  address: z.string().optional(),
  unitCode: z.string().optional(),
  geofenceRadiusMeters: z.coerce.number().default(150),
  latitude: z.coerce.number().optional(),
  longitude: z.coerce.number().optional(),
  agreementNo: z.string().optional(),
});

export const deploySchema = z.object({
  empId: z.coerce.number().min(1, "Employee is required"),
  unitId: z.coerce.number().min(1, "Unit is required"),
  postId: z.coerce.number().optional(),
  shiftId: z.coerce.number().optional(),
  fromDate: z.string().optional(),
  isReliever: z.boolean().default(false),
  remark: z.string().optional(),
});

export const recruitSchema = z.object({
  name: z.string().min(1, "Name is required"),
  mobile: z.string().optional(),
  aadhaar: z.string().optional(),
  sourceBy: z.string().optional(),
  remark: z.string().optional(),
});

export const advanceSchema = z.object({
  empId: z.coerce.number().min(1),
  amount: z.coerce.number().positive(),
  installment: z.coerce.number().optional(),
  reason: z.string().optional(),
  issueDate: z.string().optional(),
});

export const incidentSchema = z.object({
  unitId: z.coerce.number().min(1),
  remark: z.string().optional(),
  severity: z.coerce.number().optional(),
  photoUrl: z.string().optional(),
});

export const gatePassSchema = z.object({
  unitId: z.coerce.number().min(1),
  name: z.string().min(1),
  mobile: z.string().optional(),
  purpose: z.string().optional(),
  whomToMeet: z.string().optional(),
  vehicleNo: z.string().optional(),
});

export const taskSchema = z.object({
  heading: z.string().min(1),
  assignedTo: z.coerce.number().min(1),
  description: z.string().optional(),
  unitId: z.coerce.number().optional(),
  endDate: z.string().optional(),
});
