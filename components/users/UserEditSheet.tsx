"use client";

import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Eye, EyeOff } from "lucide-react";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import {
  Form,
  FormField,
  FormItem,
  FormLabel,
  FormControl,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import type { User } from "@/types/user";
import axiosInstance from "@/lib/axios";
import { Switch } from "@/components/ui/switch";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

/**
 * Mock translation function
 */
const t = (key: string, fallback?: string) => fallback || key;

function normalizeEgPhone(raw: string): string {
  let p = raw.trim().replace(/[\s\-()]/g, "");
  if (!p) return p;
  if (p.startsWith("+20")) p = p.slice(3);
  else if (p.startsWith("0020")) p = p.slice(4);
  else if (p.startsWith("20")) p = p.slice(2);
  else if (p.startsWith("0")) p = p.slice(1);
  return `+20${p}`;
}

const userFormSchema = z.object({
  full_name: z.string().min(1, "nameRequired"),
  email: z.string().min(1, "emailRequired").email("emailInvalid"),
  phone: z.string().min(1, "phoneRequired"),
  password: z.string().optional(),
  gender: z.enum(["MALE", "FEMALE"]).default("MALE"),
  role_id: z.coerce.number().min(1),
  lang: z.enum(["EN", "AR"]).default("EN"),
  is_active: z.boolean().default(true),
});

type UserFormValues = z.infer<typeof userFormSchema>;

interface UserEditSheetProps {
  readonly user: User | null;
  readonly open: boolean;
  readonly onOpenChange: (open: boolean) => void;
  readonly onSuccess: () => void;
}

export function UserEditSheet({
  user,
  open,
  onOpenChange,
  onSuccess,
}: UserEditSheetProps) {
  const { toast } = useToast();
  // const [isUpdating, setIsUpdating] = useState(false);
  // const [isCreating, setIsCreating] = useState(false);
  const isEditing = !!user;
  const [showPassword, setShowPassword] = useState(false);

  const form = useForm<UserFormValues>({
    resolver: zodResolver(userFormSchema) as any,
    defaultValues: {
      full_name: "",
      email: "",
      phone: "",
      password: "",
      gender: "MALE",
      role_id: 2,
      lang: "EN",
      is_active: true,
    },
  });

  useEffect(() => {
    if (user && open) {
      const u = user as unknown as Record<string, unknown>;
      form.reset({
        full_name: (u.name as string) || (u.full_name as string) || "",
        email: (u.email as string) || "",
        phone: (u.phone as string) || "",
        password: "",
        gender: (u.gender as "MALE" | "FEMALE") || "MALE",
        role_id:
          typeof u.role === "object" && u.role !== null && "id" in u.role
            ? (u.role as { id?: number }).id || 2
            : (u.role_id as number) || 2,
        lang: (u.lang as "EN" | "AR") || "EN",
        is_active:
          u.is_active !== undefined
            ? Boolean(u.is_active)
            : u.status === "active",
      });
    } else if (!user && open) {
      form.reset({
        full_name: "",
        email: "",
        phone: "",
        password: "",
        gender: "MALE",
        role_id: 2,
        lang: "EN",
        is_active: true,
      });
    }
  }, [user, form, open]);

  const onSubmit = async (values: UserFormValues) => {
    try {
      // Logic for Laravel-style PUT spoofing with FormData
      const formData = new FormData();
      Object.entries(values).forEach(([key, value]) => {
        if (key === "password" && !value) return; // Don't send empty password
        const finalValue = key === "phone" ? normalizeEgPhone(value.toString()) : value.toString();
        formData.append(key, finalValue);
      });

      if (isEditing && user) {
        await axiosInstance.post(`/users/${user.id}?_method=PUT`, formData);
        toast({ title: t("userUpdated", "User updated successfully") });
      } else {
        await axiosInstance.post(`/users`, formData);
        toast({ title: t("userCreated", "User created successfully") });
      }

      onSuccess();
      onOpenChange(false);
    } catch (err: any) {
      toast({
        variant: "destructive",
        title: t("saveFailed", "Failed to save user"),
        description: err?.response?.data?.message,
      });
    }
  };

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-full sm:max-w-md overflow-y-auto">
        <SheetHeader>
          <SheetTitle>
            {isEditing
              ? t("editUser", "Edit User")
              : t("createUser", "Create User")}
          </SheetTitle>
        </SheetHeader>

        <Form {...form}>
          <form
            onSubmit={form.handleSubmit(onSubmit)}
            className="space-y-4 mt-6"
          >
            <FormField
              control={form.control}
              name="full_name"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>{t("name", "Full Name")}</FormLabel>
                  <FormControl>
                    <Input placeholder="John Doe" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="email"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>{t("email", "Email Address")}</FormLabel>
                  <FormControl>
                    <Input
                      type="email"
                      placeholder="john@example.com"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="phone"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>{t("phone", "Phone Number")}</FormLabel>
                  <FormControl>
                    <Input
                      placeholder="+123456789"
                      {...field}
                      onBlur={(e) => {
                        const val = e.target.value;
                        field.onChange(normalizeEgPhone(val));
                        field.onBlur();
                      }}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="password"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>
                    {t("password", "Password")}
                    {isEditing && (
                      <span className="ml-1 text-muted-foreground text-xs italic">
                        ({t("optionalIfEditing", "Leave blank to keep current")}
                        )
                      </span>
                    )}
                  </FormLabel>
                  <FormControl>
                    <div className="relative">
                      <Input
                        type={showPassword ? "text" : "password"}
                        className="pr-10"
                        {...field}
                      />
                      <button
                        type="button"
                        onClick={() => setShowPassword((p) => !p)}
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition"
                      >
                        {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                      </button>
                    </div>
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <div className="grid grid-cols-2 gap-4">
              <FormField
                control={form.control}
                name="gender"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>{t("gender", "Gender")}</FormLabel>
                    <Select onValueChange={field.onChange} value={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue
                            placeholder={t("selectGender", "Select")}
                          />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="MALE">
                          {t("male", "Male")}
                        </SelectItem>
                        <SelectItem value="FEMALE">
                          {t("female", "Female")}
                        </SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="lang"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>{t("language", "Language")}</FormLabel>
                    <Select onValueChange={field.onChange} value={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue
                            placeholder={t("selectLanguage", "Select")}
                          />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="EN">English</SelectItem>
                        <SelectItem value="AR">Arabic</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>

            <FormField
              control={form.control}
              name="role_id"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>{t("role", "User Role")}</FormLabel>
                  <Select
                    onValueChange={field.onChange}
                    value={field.value?.toString()}
                  >
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue
                          placeholder={t("selectRole", "Select Role")}
                        />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      <SelectItem value="1">Admin</SelectItem>
                      <SelectItem value="2">User</SelectItem>
                      <SelectItem value="3">Courier</SelectItem>
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="is_active"
              render={({ field }) => (
                <FormItem className="flex flex-row items-center justify-between rounded-lg border p-4 shadow-sm">
                  <div className="space-y-0.5">
                    <FormLabel className="text-base">
                      {t("activeStatus", "Active Account")}
                    </FormLabel>
                  </div>
                  <FormControl>
                    <Switch
                      checked={field.value}
                      onCheckedChange={field.onChange}
                    />
                  </FormControl>
                </FormItem>
              )}
            />

            <div className="flex gap-3 pt-6">
              <Button
                type="submit"
                className="flex-1"
                disabled={form.formState.isSubmitting}
              >
                {form.formState.isSubmitting
                  ? t("saving", "Saving...")
                  : t("save", "Save Changes")}
              </Button>
              <Button
                type="button"
                variant="outline"
                className="flex-1"
                onClick={() => onOpenChange(false)}
              >
                {t("cancel", "Cancel")}
              </Button>
            </div>
          </form>
        </Form>
      </SheetContent>
    </Sheet>
  );
}
