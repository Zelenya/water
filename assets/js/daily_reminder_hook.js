import {
  getLocalStorageItem,
  removeLocalStorageItem,
  setLocalStorageItem,
} from "./local_storage";

const STORAGE_KEY = "garden-daily-reminder";

export const GardenDailyReminder = {
  mounted() {
    this.check = () => this.schedule();
    window.addEventListener("focus", this.check);
    window.addEventListener("pageshow", this.check);
    document.addEventListener("visibilitychange", this.check);
    this.schedule();
  },

  updated() {
    this.schedule();
  },

  reconnected() {
    this.schedule();
  },

  destroyed() {
    clearTimeout(this.timer);
    window.removeEventListener("focus", this.check);
    window.removeEventListener("pageshow", this.check);
    document.removeEventListener("visibilitychange", this.check);
  },

  schedule() {
    clearTimeout(this.timer);

    const reminder = this.reminder();
    if (!reminder || this.isAlreadySent(reminder.date)) return;

    const delayMs = reminder.notifyAtMs - Date.now();
    if (delayMs <= 0) {
      this.show(reminder);
      return;
    }
    this.timer = setTimeout(() => this.show(reminder), delayMs);
  },

  show(reminder) {
    if (Date.now() < reminder.notifyAtMs) {
      this.schedule();
      return;
    }

    if (!("Notification" in window)) return;

    if (window.Notification.permission === "default") {
      window.Notification.requestPermission().then(() => this.schedule());
      return;
    }

    if (window.Notification.permission !== "granted") return;
    if (this.isAlreadySent(reminder.date)) return;

    if (!setLocalStorageItem(STORAGE_KEY, reminder.date)) return;

    try {
      const notification = new window.Notification("Garden reminder", {
        body: reminder.body,
      });

      notification.onclick = () => {
        window.focus();
        notification.close();
      };
    } catch (_error) {
      removeLocalStorageItem(STORAGE_KEY);
    }
  },

  reminder() {
    const data = this.el.dataset;
    const notifyAtMs = Number.parseInt(data.dailyReminderNotifyAtMs, 10);
    const date = data.dailyReminderDate;

    if (!Number.isFinite(notifyAtMs) || !date) {
      return null;
    } else {
      return {
        body: data.dailyReminderBody || "You got mail!",
        date,
        notifyAtMs,
      };
    }
  },

  isAlreadySent(date) {
    return getLocalStorageItem(STORAGE_KEY) === date;
  },
};
