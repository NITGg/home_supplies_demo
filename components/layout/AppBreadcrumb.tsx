"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
// import { useTranslation } from "react-i18next";
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";

const routeLabelKeys: Record<string, string> = {
  "/": "overview",
  "/users": "users",
  "/settings": "settings",
  "/area-management": "areaManagement",
  "/area-management/areas": "areas",
  "/courier-offices": "Courier Office Management",
};

export function AppBreadcrumb() {
  // const { t } = useTranslation();
  const pathname = usePathname();

  // Temporary mock for translation
  const t = (key: string) => routeLabelKeys[key] || key;

  const segments = pathname === "/" ? [] : pathname.split("/").filter(Boolean);

  return (
    <Breadcrumb>
      <BreadcrumbList>
        <BreadcrumbItem>
          {segments.length === 0 ? (
            <BreadcrumbPage>{t("overview")}</BreadcrumbPage>
          ) : (
            <BreadcrumbLink asChild>
              <Link href="/">{t("home")}</Link>
            </BreadcrumbLink>
          )}
        </BreadcrumbItem>

        {segments.map((segment, idx) => {
          const path = "/" + segments.slice(0, idx + 1).join("/");
          const isLast = idx === segments.length - 1;
          const labelKey = routeLabelKeys[path] || segment;

          return (
            <span key={path} className="inline-flex items-center gap-1.5">
              <BreadcrumbSeparator />
              <BreadcrumbItem>
                {isLast ? (
                  <BreadcrumbPage className="capitalize">
                    {t(labelKey)}
                  </BreadcrumbPage>
                ) : (
                  <BreadcrumbLink asChild>
                    <Link href={path} className="capitalize">
                      {t(labelKey)}
                    </Link>
                  </BreadcrumbLink>
                )}
              </BreadcrumbItem>
            </span>
          );
        })}
      </BreadcrumbList>
    </Breadcrumb>
  );
}
