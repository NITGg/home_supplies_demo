"use client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Toaster } from "react-hot-toast";
import { useState } from "react";
import { GoogleOAuthProvider } from "@react-oauth/google";
import { LanguageProvider } from "@/contexts/LanguageContext";

export default function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: { queries: { retry: 1, staleTime: 30_000 } },
  }));

  return (
    <LanguageProvider>
      <GoogleOAuthProvider clientId={process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID ?? ""}>
        <QueryClientProvider client={queryClient}>
          {children}
          <Toaster position="top-right" toastOptions={{ duration: 3000 }} />
        </QueryClientProvider>
      </GoogleOAuthProvider>
    </LanguageProvider>
  );
}
