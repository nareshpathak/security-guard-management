"use client";

import { AppFrame } from "@/components/app-frame";

/**
 * The platform section shares the app chrome. Access is not enforced here:
 * every endpoint underneath requires M2.Tenant.Manage, so a non-platform user
 * who reaches these URLs sees empty screens and 403s, not another tenant's data.
 */
export default function PlatformLayout({ children }: { children: React.ReactNode }) {
  return <AppFrame>{children}</AppFrame>;
}
