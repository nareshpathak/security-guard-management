import { toast } from "sonner";

export interface SystemNotification {
  id: string;
  type: "sos" | "incident" | "attendance" | "system";
  title: string;
  message: string;
  timestamp: string;
  read?: boolean;
  metadata?: Record<string, unknown>;
}

type NotificationListener = (notification: SystemNotification) => void;

class NotificationService {
  private listeners: Set<NotificationListener> = new Set();
  private history: SystemNotification[] = [];

  public subscribe(listener: NotificationListener): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  public notify(notification: Omit<SystemNotification, "id" | "timestamp">) {
    const item: SystemNotification = {
      ...notification,
      id: `notif-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`,
      timestamp: new Date().toISOString(),
      read: false,
    };

    this.history.unshift(item);
    if (this.history.length > 100) this.history.pop();

    this.listeners.forEach((fn) => fn(item));

    if (item.type === "sos") {
      toast.error(`🚨 SOS ALERT: ${item.title}`, {
        description: item.message,
        duration: 10000,
      });
    } else if (item.type === "incident") {
      toast.warning(`⚠️ INCIDENT: ${item.title}`, {
        description: item.message,
      });
    } else {
      toast.info(item.title, {
        description: item.message,
      });
    }
  }

  public getHistory(): SystemNotification[] {
    return [...this.history];
  }
}

export const notificationService = new NotificationService();
