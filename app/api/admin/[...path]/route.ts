import { NextRequest, NextResponse } from "next/server";

const ADMIN_API = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3002/api/v1";

async function proxy(req: NextRequest, { params }: { params: Promise<{ path: string[] }> }) {
  const { path } = await params;
  const url = `${ADMIN_API}/${path.join("/")}${req.nextUrl.search}`;

  const headers: Record<string, string> = {};
  req.headers.forEach((v, k) => {
    if (!["host", "connection", "content-length", "origin", "referer"].includes(k)) headers[k] = v;
  });

  const body = req.method !== "GET" && req.method !== "HEAD"
    ? await req.arrayBuffer()
    : undefined;

  try {
    const res = await fetch(url, { method: req.method, headers, body });

    const resHeaders = new Headers();
    res.headers.forEach((v, k) => {
      if (!["content-encoding", "transfer-encoding", "connection"].includes(k)) {
        resHeaders.set(k, v);
      }
    });

    return new NextResponse(res.body, { status: res.status, headers: resHeaders });
  } catch (error: any) {
    console.error(`[Admin Proxy] Failed to reach ${url}:`, error?.message ?? error);
    return NextResponse.json(
      { message: "Admin API unreachable", target: url, error: error?.message },
      { status: 502 }
    );
  }
}

export const GET = proxy;
export const POST = proxy;
export const PUT = proxy;
export const PATCH = proxy;
export const DELETE = proxy;
