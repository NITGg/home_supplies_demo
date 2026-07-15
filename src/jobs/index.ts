import { registerCourierCouponExpiryReminderJob } from "./courierCouponExpiryReminder.job";
import { registerLogJobs } from "./logsJobs";
import { registerOrderJobs } from "./registerOrderJobs";
import env from "@/config/env";

export function initJobs() {
  if (env.PROD) {
    registerOrderJobs();
    registerCourierCouponExpiryReminderJob();
    registerLogJobs();
  }
}
