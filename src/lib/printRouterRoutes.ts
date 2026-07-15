import type { Router } from "express";

type AnyLayer = any;

function methodsFromRoute(route: any): string[] {
  const methods = route?.methods ?? {};
  return Object.keys(methods)
    .filter((m) => methods[m])
    .map((m) => m.toUpperCase());
}

function cleanPath(p: string) {
  return p.replace(/\/+/g, "/").replace(/\/$/, "") || "/";
}

function join(base: string, p: string) {
  return cleanPath(`${base}/${p}`);
}

export function printRouterRoutes(prefix: string, router: Router) {
  const stack: AnyLayer[] = (router as any)?.stack ?? [];
  const found: Array<{ methods: string; path: string }> = [];

  for (const layer of stack) {
    if (layer?.route?.path) {
      const p = join(prefix, layer.route.path);
      const methods = methodsFromRoute(layer.route).join(",");
      found.push({ methods, path: p });
    }
  }

  found.sort((a, b) => a.path.localeCompare(b.path) || a.methods.localeCompare(b.methods));

  for (const r of found) {
    console.log(`${r.methods.padEnd(10)} ${r.path}`);
  }
}
