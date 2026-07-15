"use client"; // Required in Next.js for hooks like usePathname

import Link from "next/link";
import { usePathname } from "next/navigation";
/* 
  react-i18next is not standard in Next.js App Router. 
  Commenting out translation logic until you set up next-intl or similar.
*/
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
};

export function AppBreadcrumb() {
  // const { t } = useTranslation(); // Commented out for Next.js compatibility
  const pathname = usePathname();

  const segments = pathname === "/" ? [] : pathname.split("/").filter(Boolean);

  // Fallback translation helper since i18n is disabled
  const translate = (key: string) => key;

  return (
    <Breadcrumb>
      <BreadcrumbList>
        <BreadcrumbItem>
          {segments.length === 0 ? (
            <BreadcrumbPage>{translate("overview")}</BreadcrumbPage>
          ) : (
            <BreadcrumbLink asChild>
              <Link href="/">{translate("home")}</Link>
            </BreadcrumbLink>
          )}
        </BreadcrumbItem>

        {segments.map((segment: string, idx: number) => {
          const path = "/" + segments.slice(0, idx + 1).join("/");
          const isLast = idx === segments.length - 1;
          const labelKey = routeLabelKeys[path] || segment;

          return (
            <span key={path} className="inline-flex items-center gap-1.5">
              <BreadcrumbSeparator />
              <BreadcrumbItem>
                {isLast ? (
                  <BreadcrumbPage>{translate(labelKey)}</BreadcrumbPage>
                ) : (
                  <BreadcrumbLink asChild>
                    <Link href={path}>{translate(labelKey)}</Link>
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
