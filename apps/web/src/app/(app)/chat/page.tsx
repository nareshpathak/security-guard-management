"use client";

import { PageHeader, EmptyState } from "@diti365/ui";

/**
 * Chat is specified in the PRD but has no API behind it yet - no threads
 * endpoint, no SignalR hub.
 *
 * This page says so plainly rather than rendering an empty inbox that looks
 * broken. When the hub lands, the screen replaces this text; until then nobody
 * files a bug about a chat that was never built.
 */
export default function ChatPage() {
  return (
    <div>
      <PageHeader title="Chat" description="Messaging between office and field staff." />
      <EmptyState
        title="Not built yet"
        description="Chat needs a real-time hub on the API side, which is not in place. Tasks and complaints carry conversations in the meantime, and both notify the right people."
      />
    </div>
  );
}
