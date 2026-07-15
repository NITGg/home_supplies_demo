import { NextRequest, NextResponse } from "next/server";

const COURIER_API = process.env.NEXT_PUBLIC_COURIER_API_URL ?? "http://localhost:3003/api/v1/courier";

async function proxy(req: NextRequest, { params }: { params: Promise<{ path: string[] }> }) {
  const { path } = await params;
  const url = `${COURIER_API}/${path.join("/")}${req.nextUrl.search}`;

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
    console.error("[Courier Proxy Error]:", error);
    return NextResponse.json(
      { message: "Courier API connection failed", error: error.message },
      { status: 502 }
    );
  }
}

export const GET = proxy;
export const POST = proxy;
export const PUT = proxy;
export const PATCH = proxy;
export const DELETE = proxy;
