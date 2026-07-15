import Sidebar from "@/components/layout/Sidebar";
import RoleGuard from "@/components/layout/RoleGuard";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex h-screen overflow-hidden">
      <Sidebar />
      <main className="flex-1 overflow-y-auto bg-gray-50">
        <RoleGuard>{children}</RoleGuard>
      </main>
    </div>
  );
}
