"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { forwardRef, useMemo } from "react";
import { cn } from "@/lib/utils";

interface NavLinkProps extends React.ComponentPropsWithoutRef<typeof Link> {
  activeClassName?: string;
  // Note: isPending isn't natively supported in Next.js Link styling 
  // the same way, but we'll keep the prop for compatibility.
  pendingClassName?: string;
  exact?: boolean;
}

const NavLink = forwardRef<HTMLAnchorElement, NavLinkProps>(
  ({ className, activeClassName, pendingClassName, href, exact, ...props }, ref) => {
    const pathname = usePathname();

    const isActive = useMemo(() => {
      const hrefString = typeof href === "string" ? href : href.pathname || "";
      
      if (exact) {
        return pathname === hrefString;
      }
      
      // Matches the base path (e.g., /users matches /users/1)
      // but ensures / doesn't match everything unless exact is true
      if (hrefString === "/") {
        return pathname === "/";
      }
      
      return pathname.startsWith(hrefString);
    }, [pathname, href, exact]);

    return (
      <Link
        ref={ref}
        href={href}
        className={cn(
          className,
          isActive && activeClassName
        )}
        {...props}
      />
    );
  }
);

NavLink.displayName = "NavLink";

export { NavLink };