import { useState, useRef, useEffect } from "react";
// import { useTranslation } from "react-i18next";
import { useForm, useFieldArray } from "react-hook-form";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Separator } from "@/components/ui/separator";
import { useToast } from "@/hooks/use-toast";
import {
  Send,
  Plus,
  Trash2,
  Loader2,
  CheckCircle2,
  XCircle,
  Bell,
} from "lucide-react";
import {
  notificationService,
  SendNotificationPayload,
  StreamLogEntry,
  StreamStats,
} from "@/services/notificationService";

interface NotificationForm {
  content: {
    title: { en: string; ar: string };
    body: { en: string; ar: string };
  };
  data: {
    page: string;
    navigate: string;
    customFields: { key: string; value: string }[];
  };
}

const defaultValues: NotificationForm = {
  content: {
    title: { en: "", ar: "" },
    body: { en: "", ar: "" },
  },
  data: {
    page: "",
    navigate: "",
    customFields: [],
  },
};

interface StreamLog {
  id: string;
  type: "started" | "progress" | "done" | "error";
  raw: string;
  message?: string;
  keyValues?: Record<string, string | number>;
  timestamp: Date;
}

interface SendNotificationModalProps {
  isOpen: boolean;
  onClose: () => void;
  userId: number;
  userType: "courier" | "customer";
}

export function SendNotificationModal({
  isOpen,
  onClose,
  userId,
  userType,
}: Readonly<SendNotificationModalProps>) {
// const { t } = useTranslation();
  const t = (key: string, fallback: string) => fallback;  const { toast } = useToast();
  const [isSending, setIsSending] = useState(false);
  const [logs, setLogs] = useState<StreamLog[]>([]);
  const [stats, setStats] = useState<StreamStats | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);

  const form = useForm<NotificationForm>({
    defaultValues,
  });

  const { fields, append, remove } = useFieldArray({
    control: form.control,
    name: "data.customFields",
  });

  // Auto-scroll logs
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [logs]);

  // Reset form when modal opens
  useEffect(() => {
    if (isOpen) {
      form.reset(defaultValues);
      setLogs([]);
      setStats(null);
    }
  }, [isOpen, form]);

  const addLog = (entry: StreamLogEntry) => {
    setLogs((prev) => [
      ...prev,
      {
        id: `${Date.now()}-${Math.random()}`,
        type: entry.type,
        raw: entry.raw,
        message: entry.message,
        keyValues: entry.keyValues,
        timestamp: entry.timestamp,
      },
    ]);
  };

  const onSubmit = async (data: NotificationForm) => {
    setIsSending(true);
    setLogs([]);
    setStats(null);

    const payload: SendNotificationPayload = {
      recipientType: "users",
      userIds: [userId],
      content: data.content,
    };

    // Build data object
    const customData: Record<string, string | number> = {};
    if (data.data.page) customData.page = data.data.page;
    if (data.data.navigate) customData.navigate = data.data.navigate;
    data.data.customFields.forEach((field) => {
      if (field.key.trim()) {
        customData[field.key] = field.value;
      }
    });

    if (Object.keys(customData).length > 0) {
      payload.data = customData;
    }

    await notificationService.sendNotificationStream(payload, {
      onLog: (entry: StreamLogEntry) => {
        addLog(entry);
      },
      onProgress: (progressStats: StreamStats) => {
        setStats(progressStats);
      },
      onError: (error: Error) => {
        addLog({
          type: "error",
          raw: error.message,
          timestamp: new Date(),
        });
        toast({
          variant: "destructive",
          title: t("error", "Error"),
          description: error.message,
        });
        setIsSending(false);
      },
      onComplete: () => {
        toast({
          title: t("success", "Success"),
          description:
            t("notificationSent", "Notification sent successfully"),
        });
        setIsSending(false);
      },
    });
  };

  const handleClose = () => {
    if (!isSending) {
      onClose();
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={handleClose}>
      <DialogContent className="max-w-4xl max-h-[90vh] overflow-hidden flex flex-col">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Bell className="h-5 w-5 text-primary" />
            {t("sendNotification", "Send Notification")}
          </DialogTitle>
          <DialogDescription>
            {t(
              "sendNotificationDesc",
              `Send a push notification to this ${userType}`,
            )}
          </DialogDescription>
        </DialogHeader>

        <div className="flex-1 overflow-hidden grid grid-cols-2 gap-4">
          {/* Form Section */}
          <div className="overflow-auto pr-2">
            <Form {...form}>
              <form
                onSubmit={form.handleSubmit(onSubmit)}
                className="space-y-4"
              >
                {/* Content Section */}
                <div className="space-y-3">
                  <h4 className="text-sm font-medium">
                    {t("notificationContent", "Notification Content")}
                  </h4>

                  {/* Title */}
                  <div className="grid gap-3 grid-cols-2">
                    <FormField
                      control={form.control}
                      name="content.title.en"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-xs">
                            {t("titleEn", "Title (English)")} *
                          </FormLabel>
                          <FormControl>
                            <Input {...field} className="h-8" />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="content.title.ar"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-xs">
                            {t("titleAr", "Title (Arabic)")} *
                          </FormLabel>
                          <FormControl>
                            <Input {...field} dir="rtl" className="h-8" />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                  </div>

                  {/* Body */}
                  <div className="grid gap-3 grid-cols-2">
                    <FormField
                      control={form.control}
                      name="content.body.en"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-xs">
                            {t("bodyEn", "Body (English)")} *
                          </FormLabel>
                          <FormControl>
                            <Textarea {...field} rows={2} />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="content.body.ar"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-xs">
                            {t("bodyAr", "Body (Arabic)")} *
                          </FormLabel>
                          <FormControl>
                            <Textarea {...field} rows={2} dir="rtl" />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                  </div>
                </div>

                <Separator />

                {/* Data Section */}
                <div className="space-y-3">
                  <h4 className="text-sm font-medium">
                    {t("notificationData", "Additional Data")}
                  </h4>

                  <div className="grid gap-3 grid-cols-2">
                    <FormField
                      control={form.control}
                      name="data.page"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-xs">
                            {t("page", "Page")}
                          </FormLabel>
                          <FormControl>
                            <Input
                              {...field}
                              placeholder="/maintenance"
                              className="h-8"
                            />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="data.navigate"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-xs">
                            {t("navigate", "Navigate")}
                          </FormLabel>
                          <FormControl>
                            <Input
                              {...field}
                              placeholder="maintenance"
                              className="h-8"
                            />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                  </div>

                  {/* Custom Fields */}
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <FormLabel className="text-xs">
                        {t("customFields", "Custom Fields")}
                      </FormLabel>
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        onClick={() => append({ key: "", value: "" })}
                        className="h-6 text-xs"
                      >
                        <Plus className="mr-1 h-3 w-3" />
                        {t("addField", "Add Field")}
                      </Button>
                    </div>

                    {fields.map((field, index) => (
                      <div key={field.id} className="flex gap-2 items-center">
                        <FormField
                          control={form.control}
                          name={`data.customFields.${index}.key`}
                          render={({ field }) => (
                            <FormItem className="flex-1">
                              <FormControl>
                                <Input
                                  {...field}
                                  placeholder=  {t("key", "Key")}
                                  className="h-7"
                                />
                              </FormControl>
                            </FormItem>
                          )}
                        />
                        <FormField
                          control={form.control}
                          name={`data.customFields.${index}.value`}
                          render={({ field }) => (
                            <FormItem className="flex-1">
                              <FormControl>
                                <Input
                                  {...field}
                                  placeholder={t("value", "Value")}
                                  className="h-7"
                                />
                              </FormControl>
                            </FormItem>
                          )}
                        />
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => remove(index)}
                          className="h-7 w-7 text-destructive hover:text-destructive"
                        >
                          <Trash2 className="h-3 w-3" />
                        </Button>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Submit Button */}
                <div className="flex justify-end gap-2 pt-2">
                  <Button
                    type="button"
                    variant="outline"
                    onClick={handleClose}
                    disabled={isSending}
                    size="sm"
                  >
                    {t("cancel", "Cancel")}
                  </Button>
                  <Button type="submit" disabled={isSending} size="sm">
                    {isSending ? (
                      <>
                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        {t("sending", "Sending...")}
                      </>
                    ) : (
                      <>
                        <Send className="mr-2 h-4 w-4" />
                        {t("sendNotification", "Send")}
                      </>
                    )}
                  </Button>
                </div>
              </form>
            </Form>
          </div>

          {/* Stream Output Section */}
          <div className="border rounded-lg flex flex-col overflow-hidden">
            <div className="px-3 py-2 border-b bg-muted/30 flex items-center gap-2">
              {isSending && <Loader2 className="h-4 w-4 animate-spin" />}
              <h4 className="text-sm font-medium">
                {t("streamOutput", "Output")}
              </h4>
            </div>

            {/* Stats */}
            {stats && (
              <div className="grid grid-cols-3 gap-2 p-2 border-b">
                <div className="bg-muted rounded p-2 text-center">
                  <p className="text-lg font-bold text-primary">
                    {stats.totalUsers || stats.total || 0}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    {t("totalUsers", "Total Users")}
                  </p>
                </div>
                <div className="bg-muted rounded p-2 text-center">
                  <p className="text-lg font-bold text-green-600">
                    {stats.successCount}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    {t("success", "Success")}
                  </p>
                </div>
                <div className="bg-muted rounded p-2 text-center">
                  <p className="text-lg font-bold text-destructive">
                    {stats.failCount}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    {t("failed", "Failed")}
                  </p>
                </div>
              </div>
            )}

            {/* Progress Bar */}
            {stats && (stats.totalUsers || stats.total || 0) > 0 && (
              <div className="px-2 py-1.5 border-b">
                <div className="flex justify-between text-xs mb-1">
                  <span>{t("progress", "Progress")}</span>
                  <span>
                    {stats.processed}/{stats.totalUsers || stats.total || 0}
                  </span>
                </div>
                <div className="h-1.5 bg-muted rounded-full overflow-hidden">
                  <div
                    className="h-full bg-primary transition-all duration-300"
                    style={{
                      width: `${(stats.processed / (stats.totalUsers || stats.total || 1)) * 100}%`,
                    }}
                  />
                </div>
              </div>
            )}

            {/* Logs */}
            <ScrollArea className="flex-1">
              <div ref={scrollRef} className="p-2 space-y-2 h-[200px]">
                {logs.length === 0 ? (
                  <p className="text-center text-muted-foreground text-sm py-4">
                    {t("noLogsYet", "No output yet")}
                  </p>
                ) : (
                  <div className="space-y-2">
                    {logs.map((log) => (
                      <div
                        key={log.id}
                        className={`rounded border p-2 text-sm ${
                          log.type === "error"
                            ? "border-destructive/50 bg-destructive/5"
                            : log.type === "done"
                              ? "border-green-500/50 bg-green-50 dark:bg-green-950/30"
                              : log.type === "started"
                                ? "border-blue-500/50 bg-blue-50 dark:bg-blue-950/30"
                                : "border-border bg-card"
                        }`}
                      >
                        {/* Header */}
                        <div className="flex items-center justify-between mb-1">
                          <div className="flex items-center gap-1">
                            {log.type === "error" ? (
                              <Badge
                                variant="destructive"
                                className="text-xs gap-0.5"
                              >
                                <XCircle className="h-2.5 w-2.5" />
                                {t("error", "Error")}
                              </Badge>
                            ) : log.type === "done" ? (
                              <Badge className="bg-green-600 text-xs gap-0.5">
                                <CheckCircle2 className="h-2.5 w-2.5" />
                                {t("done", "Done")}
                              </Badge>
                            ) : log.type === "started" ? (
                              <Badge className="bg-blue-600 text-xs gap-0.5">
                                <CheckCircle2 className="h-2.5 w-2.5" />
                                {t("started", "Started")}
                              </Badge>
                            ) : (
                              <Badge
                                variant="secondary"
                                className="text-xs gap-0.5"
                              >
                                <Loader2 className="h-2.5 w-2.5" />
                                {t("progress", "Progress")}
                              </Badge>
                            )}
                          </div>
                          <span className="text-xs text-muted-foreground">
                            {log.timestamp.toLocaleTimeString()}
                          </span>
                        </div>

                        {/* Message */}
                        {log.message && (
                          <p className="text-xs font-medium mb-1">
                            {log.message}
                          </p>
                        )}

                        {/* Key-Values */}
                        {log.keyValues &&
                          Object.keys(log.keyValues).length > 0 && (
                            <div className="grid grid-cols-2 gap-1">
                              {Object.entries(log.keyValues).map(
                                ([key, value]) => (
                                  <div
                                    key={key}
                                    className="flex items-center justify-between bg-background/50 rounded px-1.5 py-0.5 text-xs"
                                  >
                                    <span className="text-muted-foreground">
                                      {key}:
                                    </span>
                                    <span className="font-semibold">
                                      {value}
                                    </span>
                                  </div>
                                ),
                              )}
                            </div>
                          )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </ScrollArea>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
