"use client";

import {
  useState,
  useMemo,
  Fragment,
  useCallback,
  useEffect,
  useRef,
} from "react";
import { getAdminSocket, getCourierSocket } from "@/lib/socket";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchUsers,
  fetchRoles,
  fetchBadgesByRoleId,
  fetchBadges,
  deleteUser,
  bulkDeleteUsers,
  fetchAllUserIds,
  type User,
  type UserBadge,
} from "@/lib/users";
import { fetchAssignedCourierIds, fetchOrders } from "@/lib/orders";
import {
  fetchGovernorates,
  fetchAreasByGovernorate,
  type Governorate,
  type Area,
} from "@/lib/governorates";
import { fetchCourierOffices } from "@/lib/courier-offices";
import { fetchVehicles, type Vehicle } from "@/lib/vehicles";
import UserForm from "@/components/users/UserForm";
import UserStatsCharts from "@/components/users/UserStatsCharts";
import CreateSupplierModal from "./CreateSupplierModal";
import CreateAccountModal from "./CreateAccountModal";
import CreateCourierModal from "./CreateCourierModal";
import EditAdminModal from "./EditAdminModal";
import EditSupplierModal from "./EditSupplierModal";
import EditCourierModal from "./EditCourierModal";
import {
  Pencil,
  Trash2,
  User as UserIcon,
  ChevronUp,
  ChevronDown,
  ChevronsUpDown,
  GripVertical,
  Shield,
  ShieldCheck,
  UserPlus,
  Truck,
  Store,
  CheckCircle,
  XCircle,
  Mail,
  Phone,
  Users,
  UserCheck,
  UserX,
  RefreshCw,
  MessageSquare,
  Eye,
  Filter,
  X,
} from "lucide-react";
import toast from "react-hot-toast";
import { cn } from "@/lib/utils";
import { useT } from "@/contexts/LanguageContext";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";
import { useColumnOrder } from "@/hooks/useColumnOrder";
import { useRouter } from "next/navigation";

const PAGE_SIZES = [5, 10, 50, 100, 500, 0] as const;
type SortField =
  | "id"
  | "full_name"
  | "email"
  | "phone"
  | "role"
  | "badge"
  | "gender"
  | "is_active"
  | "is_email_verified"
  | "is_phone_verified"
  | "created_at"
  | "updated_at"
  | "wallet_balance"   // client-side sort (all rows)
  | "order_count";     // client-side sort (all rows)
type SortDir = "asc" | "desc";

// Fields that are sorted client-side only (not sent to server)
const CLIENT_ONLY_SORT_FIELDS: SortField[] = ["wallet_balance", "order_count"];

const ALL_COLUMN_KEYS = [
  "id",
  "avatar",
  "full_name",
  "email",
  "phone",
  "referral_code",
  "gender",
  "badge",
  "role",
  "is_active",
  "online_status",
  "approval_status",
  "courier_availability",
  "is_email_verified",
  "is_phone_verified",
  "wallet_balance",
  "order_count",
  "created_at",
  "updated_at",
  "actions",
] as const;

function SortIcon({ active, dir }: { active: boolean; dir: SortDir }) {
  if (!active) return <ChevronsUpDown size={13} className="opacity-30" />;
  return dir === "asc" ? (
    <ChevronUp size={13} className="text-indigo-600" />
  ) : (
    <ChevronDown size={13} className="text-indigo-600" />
  );
}

function Avatar({ user }: { user: User }) {
  if (user.personal_photo) {
    return (
      <div className="w-9 h-9 rounded-full overflow-hidden border-2 border-gray-200 shrink-0">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={user.personal_photo}
          alt={user.full_name}
          className="w-full h-full object-cover"
        />
      </div>
    );
  }
  const initials = user.full_name
    .split(" ")
    .map((n) => n[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
  const colors = [
    "bg-indigo-100 text-indigo-700",
    "bg-purple-100 text-purple-700",
    "bg-pink-100 text-pink-700",
    "bg-blue-100 text-blue-700",
    "bg-green-100 text-green-700",
  ];
  const color = colors[user.id % colors.length];
  return (
    <div
      className={cn(
        "w-9 h-9 rounded-full flex items-center justify-center text-xs font-bold shrink-0",
        color,
      )}
    >
      {initials || <UserIcon size={14} />}
    </div>
  );
}

// ── Filter persistence helpers ────────────────────────────────────────────────
const FILTER_KEY = "users-page-filters";
function readStoredFilters(): Record<string, any> {
  if (typeof window === "undefined") return {};
  try { const r = sessionStorage.getItem(FILTER_KEY); return r ? JSON.parse(r) : {}; }
  catch { return {}; }
}

export default function UsersPage() {
  const qc = useQueryClient();
  const { t, lang } = useT();
  const router = useRouter();

  // Filters
  const [search, setSearch] = useState("");
  const [filterRole, setFilterRole] = useState("");
  const [filterStatus, setFilterStatus] = useState<"all" | "active" | "inactive">("all");
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState<number>(10);

  // Advanced Filters
  const [filterId, setFilterId] = useState("");
  const [filterGender, setFilterGender] = useState<"" | "MALE" | "FEMALE">("");
  const [filterBadge, setFilterBadge] = useState("");
  const [filterEmailVerified, setFilterEmailVerified] = useState<"" | "true" | "false">("");
  const [filterPhoneVerified, setFilterPhoneVerified] = useState<"" | "true" | "false">("");
  const [filterGovernorate, setFilterGovernorate] = useState("");
  const [filterArea, setFilterArea] = useState("");
  const [filterCourierOffice, setFilterCourierOffice] = useState("");

  // Courier-specific filters
  const [filterVehicleType, setFilterVehicleType] = useState("");
  const [filterVehiclePlate, setFilterVehiclePlate] = useState("");
  const [filterNationalId, setFilterNationalId] = useState("");
  const [filterOnlineStatus, setFilterOnlineStatus] = useState("");
  const [filterCourierAvailability, setFilterCourierAvailability] = useState("");
  const [filterApprovalStatus, setFilterApprovalStatus] = useState("");
  const [filterIsSettled, setFilterIsSettled] = useState<"" | "true" | "false">("");

  // ── Filter persistence: restore from sessionStorage on mount ────────────────
  const [filtersRestored, setFiltersRestored] = useState(false);
  useEffect(() => {
    const f = readStoredFilters();
    if (f.search       !== undefined) setSearch(f.search);
    if (f.filterRole   !== undefined) setFilterRole(f.filterRole);
    if (f.filterStatus !== undefined) setFilterStatus(f.filterStatus);
    if (f.page         !== undefined) setPage(f.page);
    if (f.pageSize     !== undefined) setPageSize(f.pageSize);
    if (f.filterId     !== undefined) setFilterId(f.filterId);
    if (f.filterGender !== undefined) setFilterGender(f.filterGender);
    if (f.filterBadge  !== undefined) setFilterBadge(f.filterBadge);
    if (f.filterEmailVerified  !== undefined) setFilterEmailVerified(f.filterEmailVerified);
    if (f.filterPhoneVerified  !== undefined) setFilterPhoneVerified(f.filterPhoneVerified);
    if (f.filterGovernorate    !== undefined) setFilterGovernorate(f.filterGovernorate);
    if (f.filterArea           !== undefined) setFilterArea(f.filterArea);
    if (f.filterCourierOffice  !== undefined) setFilterCourierOffice(f.filterCourierOffice);
    if (f.filterVehicleType    !== undefined) setFilterVehicleType(f.filterVehicleType);
    if (f.filterVehiclePlate   !== undefined) setFilterVehiclePlate(f.filterVehiclePlate);
    if (f.filterNationalId     !== undefined) setFilterNationalId(f.filterNationalId);
    if (f.filterOnlineStatus   !== undefined) setFilterOnlineStatus(f.filterOnlineStatus);
    if (f.filterCourierAvailability !== undefined) setFilterCourierAvailability(f.filterCourierAvailability);
    if (f.filterApprovalStatus !== undefined) setFilterApprovalStatus(f.filterApprovalStatus);
    if (f.filterIsSettled      !== undefined) setFilterIsSettled(f.filterIsSettled);
    if (f.showAdvancedFilters  !== undefined) setShowAdvancedFilters(f.showAdvancedFilters);
    if (f.createdFrom !== undefined) setCreatedFrom(f.createdFrom);
    if (f.createdTo   !== undefined) setCreatedTo(f.createdTo);
    if (f.updatedFrom !== undefined) setUpdatedFrom(f.updatedFrom);
    if (f.updatedTo   !== undefined) setUpdatedTo(f.updatedTo);
    if (f.sortField   !== undefined) setSortField(f.sortField);
    if (f.sortDir     !== undefined) setSortDir(f.sortDir);
    setFiltersRestored(true);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Courier availability tracking
  const [assignedCourierIds, setAssignedCourierIds] = useState<number[]>([]);
  const [isLoadingAvailability, setIsLoadingAvailability] = useState(false);

  // Online status filter state
  const [onlineUserIds, setOnlineUserIds] = useState<number[]>([]);
  const [onlineFilterData, setOnlineFilterData] = useState<User[] | null>(null);

  // ── WebSocket: track online users in real time ──────────────────────────────
  useEffect(() => {
    console.log(
      "🔌 [OnlineStatus] useEffect: initializing WebSocket tracking...",
    );

    // Collect online user IDs from both admin and courier sockets
    const onlineBySource = new Map<string, Set<number>>();
    onlineBySource.set("admin", new Set());
    onlineBySource.set("courier", new Set());

    const merge = () => {
      const all = new Set<number>();
      onlineBySource.forEach((ids) => ids.forEach((id) => all.add(id)));
      const arr = Array.from(all);
      console.log(
        "📊 [OnlineStatus] merge: total online users =",
        arr.length,
        "ids =",
        arr.slice(0, 20),
      );
      setOnlineUserIds(arr);
    };

    const normalizeId = (raw: unknown): number | null => {
      if (typeof raw === "number" && Number.isFinite(raw)) return raw;
      if (typeof raw === "string") {
        const n = Number(raw);
        return Number.isFinite(n) ? n : null;
      }
      return null;
    };

    const setupSocket = (
      socket: ReturnType<typeof getAdminSocket>,
      key: string,
    ) => {
      if (!socket) {
        console.warn(
          `⚠️ [OnlineStatus] setupSocket(${key}): socket is null — cannot track online users from this source`,
        );
        return;
      }

      console.log(
        `✅ [OnlineStatus] setupSocket(${key}): got socket, connected =`,
        socket.connected,
        "id =",
        socket.id,
      );

      const onConnect = () => {
        console.log(
          `🟢 [OnlineStatus] ${key} socket connected, emitting users:get_online_users...`,
        );
        socket.emit(
          "users:get_online_users",
          (res: { error?: string; users?: unknown[] }) => {
            console.log(
              `📥 [OnlineStatus] ${key} get_online_users response:`,
              JSON.stringify(res)?.slice(0, 500),
            );
            if (res?.error) {
              console.error(
                `❌ [OnlineStatus] ${key} get_online_users error:`,
                res.error,
              );
              return;
            }
            if (!res?.users) {
              console.warn(
                `⚠️ [OnlineStatus] ${key} get_online_users: no 'users' field in response. Full response:`,
                res,
              );
              return;
            }
            const ids = res.users
              .map(normalizeId)
              .filter((id): id is number => id !== null);
            console.log(
              `📋 [OnlineStatus] ${key} initial online users: ${ids.length} ids =`,
              ids.slice(0, 20),
            );
            onlineBySource.set(key, new Set(ids));
            merge();
          },
        );
      };

      const onUserOnline = (payload?: { userId?: unknown }) => {
        console.log(`🟢 [OnlineStatus] ${key} user:online event:`, payload);
        const id = normalizeId(payload?.userId);
        if (id === null) {
          console.warn(
            `⚠️ [OnlineStatus] ${key} user:online: could not normalize userId from`,
            payload,
          );
          return;
        }
        onlineBySource.get(key)!.add(id);
        merge();
      };

      const onUserOffline = (payload?: { userId?: unknown }) => {
        console.log(`🔴 [OnlineStatus] ${key} user:offline event:`, payload);
        const id = normalizeId(payload?.userId);
        if (id === null) {
          console.warn(
            `⚠️ [OnlineStatus] ${key} user:offline: could not normalize userId from`,
            payload,
          );
          return;
        }
        onlineBySource.get(key)!.delete(id);
        merge();
      };

      socket.on("connect", onConnect);
      socket.on("user:online", onUserOnline);
      socket.on("user:offline", onUserOffline);

      // Also listen for error events on the socket
      socket.on("error", (err: unknown) => {
        console.error(`❌ [OnlineStatus] ${key} socket error event:`, err);
      });

      // If already connected, request the initial list immediately
      if (socket.connected) {
        console.log(
          `⚡ [OnlineStatus] ${key} already connected, calling onConnect immediately`,
        );
        onConnect();
      } else {
        console.log(`⏳ [OnlineStatus] ${key} waiting for connect event...`);
      }

      return () => {
        console.log(
          `🧹 [OnlineStatus] cleanup: removing listeners from ${key}`,
        );
        socket.off("connect", onConnect);
        socket.off("user:online", onUserOnline);
        socket.off("user:offline", onUserOffline);
      };
    };

    const adminSock = getAdminSocket();
    const courierSock = getCourierSocket();
    console.log(
      "🔌 [OnlineStatus] adminSocket =",
      adminSock ? "exists" : "null",
      ", courierSocket =",
      courierSock ? "exists" : "null",
    );

    const cleanupAdmin = setupSocket(adminSock, "admin");
    const cleanupCourier = setupSocket(courierSock, "courier");

    return () => {
      console.log("🧹 [OnlineStatus] useEffect cleanup: disconnecting...");
      cleanupAdmin?.();
      cleanupCourier?.();
      setOnlineUserIds([]);
    };
  }, []);

  // Set for efficient O(1) lookups
  const assignedCourierIdsSet = useMemo(
    () => new Set(assignedCourierIds),
    [assignedCourierIds],
  );

  const [showAdvancedFilters, setShowAdvancedFilters] = useState(false);

  // Date filters
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");

  // Sort
  const [sortField, setSortField] = useState<SortField>("created_at");
  const [sortDir, setSortDir] = useState<SortDir>("desc");

  // ── Filter persistence: save to sessionStorage when filters change ──────────
  useEffect(() => {
    if (!filtersRestored) return;
    try {
      sessionStorage.setItem(FILTER_KEY, JSON.stringify({
        search, filterRole, filterStatus, page, pageSize,
        filterId, filterGender, filterBadge, filterEmailVerified, filterPhoneVerified,
        filterGovernorate, filterArea, filterCourierOffice,
        filterVehicleType, filterVehiclePlate, filterNationalId,
        filterOnlineStatus, filterCourierAvailability, filterApprovalStatus, filterIsSettled,
        showAdvancedFilters, createdFrom, createdTo, updatedFrom, updatedTo,
        sortField, sortDir,
      }));
    } catch {}
  }, [filtersRestored, search, filterRole, filterStatus, page, pageSize, filterId, filterGender, filterBadge, filterEmailVerified, filterPhoneVerified, filterGovernorate, filterArea, filterCourierOffice, filterVehicleType, filterVehiclePlate, filterNationalId, filterOnlineStatus, filterCourierAvailability, filterApprovalStatus, filterIsSettled, showAdvancedFilters, createdFrom, createdTo, updatedFrom, updatedTo, sortField, sortDir]); // eslint-disable-line react-hooks/exhaustive-deps

  // UI
  const [showForm, setShowForm] = useState(false);
  const [editUser, setEditUser] = useState<User | undefined>();
  const [deleteConfirm, setDeleteConfirm] = useState<number | null>(null);
  const [selected, setSelected] = useState<Set<number>>(new Set());
  const [isCreateSupplierOpen, setIsCreateSupplierOpen] = useState(false);
  const [isCreateCourierOpen, setIsCreateCourierOpen] = useState(false);
  const [editAdminUser, setEditAdminUser] = useState<User | null>(null);
  // Courier edit (tabbed: profile + documents)
  const [editCourier, setEditCourier] = useState<User | null>(null);
  // Supplier edit (tabbed: profile + documents)
  const [editSupplier, setEditSupplier] = useState<{
    id: number;
    name: string;
  } | null>(null);
  // Register/OTP account-creation modal (Admin / Customer)
  const [createAccount, setCreateAccount] = useState<{
    roleId: number;
    label: string;
  } | null>(null);
  // Locked role for Create Courier flow (undefined = free-form)
  const [createRolePreset, setCreateRolePreset] = useState<number | undefined>();

  // Column visibility
  const { visible, setVisible } = useColumnVisibility("cols:users", [
    ...ALL_COLUMN_KEYS,
  ]);

  // Column order (drag-and-drop reordering, persisted to localStorage)
  const [columnOrder, setColumnOrder] = useColumnOrder("order:users", ALL_COLUMN_KEYS);
  const [dragKey, setDragKey] = useState<string | null>(null);
  const [dragOverKey, setDragOverKey] = useState<string | null>(null);

  // When online filter or client-only sort is active, we need ALL users for client-side work
  const isOnlineFilterActive = !!filterOnlineStatus;
  const isAvailabilityFilterActive = !!filterCourierAvailability;
  const isClientSortActive = CLIENT_ONLY_SORT_FIELDS.includes(sortField);

  // Server params
  const serverParams = useMemo(() => {
    // wallet_balance and order_count are sorted client-side; fall back to created_at for server
    const serverSortField = isClientSortActive ? "created_at" : sortField;
    const needsAllRows = isOnlineFilterActive || isAvailabilityFilterActive || isClientSortActive;
    const p: Record<string, string | number> = {
      page: needsAllRows ? 1 : page,
      limit:
        needsAllRows
          ? 9999
          : pageSize === 0
            ? 9999
            : pageSize,
      sort: sortDir === "asc" ? serverSortField : `-${serverSortField}`,
      includes: "badge,courier,wallet,_count",
    };
    if (search) {
      p.keyword = search;
      p.items = "full_name,phone,email";
    }
    if (filterRole) p.role_id = filterRole;
    if (filterStatus === "active") p.is_active = "true";
    if (filterStatus === "inactive") p.is_active = "false";
    // Advanced filters
    if (filterId) p.id = filterId;
    if (filterGender) p.gender = filterGender;
    if (filterBadge) p.badge_id = filterBadge;
    if (filterEmailVerified) p.is_email_verified = filterEmailVerified;
    if (filterPhoneVerified) p.is_phone_verified = filterPhoneVerified;
    if (filterGovernorate)
      p["courier[selectedAreas][some][area][governorate_id]"] =
        filterGovernorate;
    if (filterArea) p["courier[selectedAreas][some][area][id]"] = filterArea;
    if (filterCourierOffice)
      p["courier[courier_office_id]"] = filterCourierOffice;

    // Courier-specific filters
    if (filterVehicleType) p["courier[vehicle_id]"] = filterVehicleType;
    if (filterVehiclePlate) {
      p.items = "courier.vehicle_plate";
      p.keyword = filterVehiclePlate;
    }
    if (filterNationalId) {
      p.items = "courier.national_id_number";
      p.keyword = filterNationalId;
    }
    // Courier approval status (server-side filter)
    if (filterApprovalStatus) p["courier[is_approved]"] = filterApprovalStatus;

    // Settlement status filter
    if (filterIsSettled) p.is_settled = filterIsSettled;

    // Online status is handled client-side via WebSocket, not server-side
    // filterOnlineStatus is deliberately excluded from server params
    // Courier availability is also client-side (uses order assignment data)

    if (createdFrom) p["created_at[gte]"] = createdFrom;
    if (createdTo) p["created_at[lte]"] = createdTo + "T23:59:59";
    if (updatedFrom) p["updated_at[gte]"] = updatedFrom;
    if (updatedTo) p["updated_at[lte]"] = updatedTo + "T23:59:59";
    return p;
  }, [
    isOnlineFilterActive || isAvailabilityFilterActive || isClientSortActive ? 1 : page,
    isOnlineFilterActive || isAvailabilityFilterActive || isClientSortActive ? 9999 : pageSize,
    search,
    filterRole,
    filterStatus,
    sortField,
    sortDir,
    filterId,
    filterGender,
    filterBadge,
    filterEmailVerified,
    filterPhoneVerified,
    filterGovernorate,
    filterArea,
    filterCourierOffice,
    filterVehicleType,
    filterVehiclePlate,
    filterNationalId,
    filterApprovalStatus,
    filterIsSettled,
    isOnlineFilterActive,
    isAvailabilityFilterActive,
    isClientSortActive,
    createdFrom,
    createdTo,
    updatedFrom,
    updatedTo,
  ]);

  // Queries
  const { data, isLoading, refetch } = useQuery({
    queryKey: ["users", serverParams],
    queryFn: () => fetchUsers(serverParams),
  });

  const { data: roles = [] } = useQuery({
    queryKey: ["roles"],
    queryFn: fetchRoles,
  });

  const { data: badges = [] } = useQuery({
    queryKey: ["badges"],
    queryFn: () => fetchBadges(),
  });

  const { data: governorates = [] } = useQuery({
    queryKey: ["governorates"],
    queryFn: () => fetchGovernorates().then((r) => r.governorates),
  });

  const { data: areas = [] } = useQuery({
    queryKey: ["areas", filterGovernorate],
    queryFn: () =>
      filterGovernorate
        ? fetchAreasByGovernorate(Number(filterGovernorate))
        : Promise.resolve([]),
    enabled: !!filterGovernorate,
  });

  const { data: courierOfficesData } = useQuery({
    queryKey: ["courier-offices"],
    queryFn: () => fetchCourierOffices({ limit: 1000 }),
  });
  const courierOffices = courierOfficesData?.couriers ?? [];

  const { data: vehiclesData } = useQuery({
    queryKey: ["vehicles"],
    queryFn: () => fetchVehicles({ limit: 1000 }),
  });
  const vehicles = vehiclesData?.vehicles ?? [];

  const { data: allUserIds = [] } = useQuery({
    queryKey: ["user-ids"],
    queryFn: fetchAllUserIds,
  });

  // Delivered orders — single bulk fetch to compute per-user delivered counts
  const { data: deliveredOrdersData } = useQuery({
    queryKey: ["delivered-orders-all"],
    // Use default includes — courier.id is the courier RECORD id (always present),
    // customer.id is the user id for the customer
    queryFn: () => fetchOrders({ status: "DELIVERED", limit: 9999 }),
    staleTime: 5 * 60 * 1000,
  });

  // Keyed by courier RECORD id (o.courier.id) — matched via u.courier?.id
  const deliveredCountByCourier = useMemo<Record<number, number>>(() => {
    const map: Record<number, number> = {};
    for (const o of deliveredOrdersData?.orders ?? []) {
      const cid = o.courier?.id;
      if (cid) map[cid] = (map[cid] ?? 0) + 1;
    }
    return map;
  }, [deliveredOrdersData]);

  // Keyed by customer user id (o.customer.id) — matched via u.id
  const deliveredCountByCustomer = useMemo<Record<number, number>>(() => {
    const map: Record<number, number> = {};
    for (const o of deliveredOrdersData?.orders ?? []) {
      const uid = o.customer?.id;
      if (uid) map[uid] = (map[uid] ?? 0) + 1;
    }
    return map;
  }, [deliveredOrdersData]);

  // Role lookup map
  const roleMap = useMemo(() => {
    const m: Record<number, string> = {};
    roles.forEach((r) => {
      m[r.id] = r.name;
    });
    return m;
  }, [roles]);

  // Dynamically find Courier Role ID (fallback to "2")
  const courierRoleId = useMemo(() => {
    const courierRole = roles.find(
      (r) => r.name.toLowerCase() === "courier" || r.name === "مندوب",
    );
    return courierRole ? String(courierRole.id) : "2";
  }, [roles]);

  // Dynamically find Customer Role ID (fallback to "3")
  const customerRoleId = useMemo(() => {
    const customerRole = roles.find(
      (r) => r.name.toLowerCase() === "customer" || r.name === "عميل",
    );
    return customerRole ? Number(customerRole.id) : 3;
  }, [roles]);

  // ── Courier Availability: fetch assigned courier IDs ──────────────────────
  useEffect(() => {
    if (!filterCourierAvailability || filterRole !== courierRoleId) {
      setAssignedCourierIds([]);
      setIsLoadingAvailability(false);
      return;
    }

    let isMounted = true;

    const fetchIds = async () => {
      setIsLoadingAvailability(true);
      try {
        const ids = await fetchAssignedCourierIds();
        if (isMounted) setAssignedCourierIds(ids);
      } catch (err) {
        console.error("Failed to fetch assigned couriers:", err);
        if (isMounted) setAssignedCourierIds([]);
      } finally {
        if (isMounted) setIsLoadingAvailability(false);
      }
    };

    fetchIds();
    return () => {
      isMounted = false;
    };
  }, [filterCourierAvailability, filterRole, courierRoleId]);

  // Auto-clear courier availability when role changes away from Courier
  useEffect(() => {
    if (filterRole !== courierRoleId && filterCourierAvailability !== "") {
      setFilterCourierAvailability("");
    }
  }, [filterRole, courierRoleId, filterCourierAvailability]);

  // Helper function to check if user is online
  const isUserOnline = useCallback(
    (userId: number): boolean => {
      return onlineUserIds.includes(userId);
    },
    [onlineUserIds],
  );

  // Online status display component
  const renderOnlineStatus = useCallback(
    (userId: number) => {
      const online = isUserOnline(userId);

      return (
        <span
          className={`flex justify-center items-center w-max px-2 py-1 rounded-full text-xs font-semibold ${
            online ? "bg-green-100 text-green-800" : "bg-gray-100 text-gray-800"
          }`}
        >
          {online ? t("common.active") : t("common.inactive")}
        </span>
      );
    },
    [isUserOnline, t],
  );

  // Client-side sort
  const sortedUsers = useMemo(() => {
    const list = [...(data?.users ?? [])];
    return list.sort((a, b) => {
      let av: string | number, bv: string | number;
      switch (sortField) {
        case "full_name":
          av = a.full_name.toLowerCase();
          bv = b.full_name.toLowerCase();
          break;
        case "email":
          av = (a.email || "").toLowerCase();
          bv = (b.email || "").toLowerCase();
          break;
        case "phone":
          av = a.phone;
          bv = b.phone;
          break;
        case "role":
          av = (roleMap[a.role_id] || "").toLowerCase();
          bv = (roleMap[b.role_id] || "").toLowerCase();
          break;
        case "is_active":
          av = a.is_active ? 1 : 0;
          bv = b.is_active ? 1 : 0;
          break;
        case "wallet_balance":
          av = a.wallet?.balance ?? 0;
          bv = b.wallet?.balance ?? 0;
          break;
        case "order_count":
          av = (a.courier != null ? deliveredCountByCourier[a.courier.id ?? -1] : deliveredCountByCustomer[a.id]) ?? 0;
          bv = (b.courier != null ? deliveredCountByCourier[b.courier.id ?? -1] : deliveredCountByCustomer[b.id]) ?? 0;
          break;
        default:
          av = new Date(a.created_at).getTime();
          bv = new Date(b.created_at).getTime();
          break;
      }
      if (av < bv) return sortDir === "asc" ? -1 : 1;
      if (av > bv) return sortDir === "asc" ? 1 : -1;
      return 0;
    });
  }, [data, sortField, sortDir, roleMap, deliveredCountByCourier, deliveredCountByCustomer]);

  // Client-side date and online status filtering
  const users = sortedUsers.filter((r) => {
    // Date filtering
    if (createdFrom && new Date(r.created_at) < new Date(createdFrom))
      return false;
    if (createdTo && new Date(r.created_at) > new Date(createdTo + "T23:59:59"))
      return false;
    if (
      updatedFrom &&
      r.updated_at &&
      new Date(r.updated_at) < new Date(updatedFrom)
    )
      return false;
    if (
      updatedTo &&
      r.updated_at &&
      new Date(r.updated_at) > new Date(updatedTo + "T23:59:59")
    )
      return false;

    // Online status filtering
    if (filterOnlineStatus) {
      const shouldBeOnline = filterOnlineStatus === "Online";
      if (isUserOnline(r.id) !== shouldBeOnline) {
        return false;
      }
    }

    // Courier availability filtering
    if (filterCourierAvailability) {
      if (filterCourierAvailability === "assigned") {
        if (!assignedCourierIdsSet.has(r.id)) return false;
      } else if (filterCourierAvailability === "free") {
        if (assignedCourierIdsSet.has(r.id)) return false;
      }
    }

    return true;
  });

  // Client-side pagination for client-filtered/sorted data
  const isClientFiltered = isOnlineFilterActive || isAvailabilityFilterActive || isClientSortActive;
  const displayedUsers = useMemo(() => {
    if (!isClientFiltered) return users;
    // Client-side pagination: slice the filtered list
    const effectivePageSize = pageSize === 0 ? users.length : pageSize;
    const start = (page - 1) * effectivePageSize;
    return users.slice(start, start + effectivePageSize);
  }, [users, isClientFiltered, page, pageSize]);

  // Stats
  const totalUsers = data?.totalUsers ?? 0;
  const displayTotal =
    isClientFiltered || createdFrom || createdTo || updatedFrom || updatedTo
      ? users.length
      : totalUsers;
  const activeCount = users.filter((u) => u.is_active).length;
  const deletedCount = users.filter((u) => u.deleted_at).length;

  // Mutations
  const deleteMutation = useMutation({
    mutationFn: (id: number) => deleteUser(id, true),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["users"] });
      toast.success(t("users.userArchived"));
      setDeleteConfirm(null);
    },
    onError: (err: any) =>
      toast.error(err.response?.data?.message || t("users.deleteError")),
  });

  const hardDeleteMutation = useMutation({
    mutationFn: (id: number) => deleteUser(id, false),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["users"] });
      toast.success(t("common.deleteForever") + " ✓");
      setDeleteConfirm(null);
    },
    onError: (err: any) =>
      toast.error(err.response?.data?.message || t("users.deleteError")),
  });

  const bulkDeleteMutation = useMutation({
    mutationFn: (ids: number[]) => bulkDeleteUsers(ids, false),
    onSuccess: (_, ids) => {
      qc.invalidateQueries({ queryKey: ["users"] });
      toast.success(`${ids.length} ${t("users.bulkDeleted")}`);
      setSelected(new Set());
    },
    onError: (err: any) =>
      toast.error(err.response?.data?.message || "Bulk delete failed"),
  });

  // Helpers
  function toggleSort(field: SortField) {
    if (sortField === field) setSortDir((d) => (d === "asc" ? "desc" : "asc"));
    else {
      setSortField(field);
      setSortDir("asc");
    }
  }

  function handleFilterChange(setter: (v: any) => void, value: any) {
    setter(value);
    setPage(1);
  }

  function handleRowClick(user: User) {
    const roleId = user.role_id;
    const roleName = roleMap[roleId]?.toLowerCase() || "";

    if (roleId === 3 || roleName.includes("customer")) {
      router.push(`/users/customers/${user.id}`);
    } else if (roleId === 2 || roleName.includes("courier")) {
      router.push(`/users/couriers/${user.id}`);
    } else if (roleId === 1 || roleName.includes("admin")) {
      router.push(`/users/admins/${user.id}`);
    } else if (roleName.includes("seller")) {
      router.push(`/users/sellers/${user.id}`);
    } else if (roleName.includes("supplier")) {
      router.push(`/users/suppliers/${user.id}`);
    } else {
      router.push(`/users/${user.id}?roleId=${user.role_id}`);
    }
  }

  // Customer rows reuse the admin modal but without the password field.
  // "Customer Support" is excluded (it keeps its password).
  function isCustomerRole(u: User) {
    const name = (roleMap[u.role_id] || u.role?.name || "").toLowerCase();
    return (
      u.role_id === 3 ||
      (name.includes("customer") && !name.includes("support"))
    );
  }

  // Admin, Seller, Customer Support, and Customer rows are all edited via EditAdminModal.
  function usesAdminModal(u: User) {
    const name = (roleMap[u.role_id] || u.role?.name || "").toLowerCase();
    return (
      u.role_id === 1 ||
      name.includes("seller") ||
      name.includes("support") ||
      isCustomerRole(u)
    );
  }

  function openEdit(u: User) {
    // Admins cannot be edited from this table.
    if (u.role_id === 1) {
      toast.error("Admins cannot be updated from here");
      return;
    }
    setCreateRolePreset(undefined);
    setEditUser(u);
    setShowForm(true);
  }
  function openCreateWithRole(roleId: number) {
    setEditUser(undefined);
    setCreateRolePreset(roleId);
    setShowForm(true);
  }
  function closeForm() {
    setShowForm(false);
    setEditUser(undefined);
    setCreateRolePreset(undefined);
  }

  function toggleSelect(id: number) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }
  function toggleSelectAll() {
    if (selected.size === users.length) setSelected(new Set());
    else setSelected(new Set(users.map((u) => u.id)));
  }

  const totalPages = isClientFiltered
    ? Math.max(
        1,
        Math.ceil(
          users.length / (pageSize === 0 ? users.length || 1 : pageSize),
        ),
      )
    : pageSize === 0
      ? 1
      : (data?.totalPages ?? 1);

  const ROLE_COLORS: Record<string, string> = {
    Admin: "bg-red-100 text-red-700",
    Customer: "bg-blue-100 text-blue-700",
    Courier: "bg-green-100 text-green-700",
    Supplier: "bg-orange-100 text-orange-700",
  };

  // ── Drag-and-drop column reorder ──────────────────────────────────────────
  function handleDrop(targetKey: string) {
    if (!dragKey || dragKey === targetKey) {
      setDragKey(null); setDragOverKey(null); return;
    }
    const next = [...columnOrder];
    const from = next.indexOf(dragKey);
    const to   = next.indexOf(targetKey);
    if (from === -1 || to === -1) { setDragKey(null); setDragOverKey(null); return; }
    next.splice(from, 1);
    next.splice(to, 0, dragKey);
    setColumnOrder(next);
    setDragKey(null);
    setDragOverKey(null);
  }

  // ── Per-column header label + cell renderer ──────────────────────────────
  type ColDef = {
    label: () => React.ReactNode;
    cell: (u: User) => React.ReactNode;
    sortField?: SortField;
    thClassName?: string;
    tdClassName?: string;
  };
  const colDefs: Record<string, ColDef> = {
    id: {
      label: () => "ID",
      sortField: "id",
      tdClassName: "text-gray-900",
      cell: (u) => <>{u.id}</>,
    },
    avatar: {
      label: () => t("common.image"),
      thClassName: "w-14",
      cell: (u) => <Avatar user={u} />,
    },
    full_name: {
      label: () => t("common.name"),
      sortField: "full_name",
      cell: (u) => (
        <div className="flex items-center gap-3">
          <span className="font-medium text-gray-900">{u.full_name}</span>
          {u.deleted_at && <span className="text-xs bg-gray-200 text-gray-600 px-2 py-0.5 rounded">{t("common.archived")}</span>}
        </div>
      ),
    },
    email: {
      label: () => t("users.email"),
      sortField: "email",
      cell: (u) => (
        <div className="flex items-center gap-2">
          <Mail size={14} className="text-gray-400" />
          <span className="text-gray-600">{u.email || "—"}</span>
        </div>
      ),
    },
    phone: {
      label: () => t("users.phone"),
      sortField: "phone",
      cell: (u) => (
        <div className="flex items-center gap-2">
          <Phone size={14} className="text-gray-400" />
          <span className="text-gray-600">{u.phone}</span>
        </div>
      ),
    },
    referral_code: {
      label: () => t("users.referralCode"),
      cell: (u) => <span className="text-gray-600">{u.referral_code || "—"}</span>,
    },
    gender: {
      label: () => t("users.gender"),
      cell: (u) => (
        <span className="text-gray-600">
          {u.gender === "MALE" ? t("filters.male") : u.gender === "FEMALE" ? t("filters.female") : "—"}
        </span>
      ),
    },
    badge: {
      label: () => t("users.badge"),
      cell: (u) => (
        <span className="text-gray-600">
          {u.badge ? (lang === "AR" ? u.badge.name_ar : u.badge.name) : "—"}
        </span>
      ),
    },
    role: {
      label: () => t("users.role"),
      sortField: "role",
      cell: (u) => (
        <div className="flex flex-wrap items-center gap-1">
          <span className={cn("inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium", ROLE_COLORS[roleMap[u.role_id]] || "bg-gray-100 text-gray-700")}>
            <Shield size={12} /> {roleMap[u.role_id] || u.role?.name || "—"}
          </span>
          {u.courier != null && (
            <span className={cn("inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium", u.courier.is_approved ? "bg-green-100 text-green-700" : "bg-amber-100 text-amber-700")}>
              {u.courier.is_approved ? t("common.approved") : t("common.notApproved")}
            </span>
          )}
        </div>
      ),
    },
    is_active: {
      label: () => t("common.status"),
      sortField: "is_active",
      cell: (u) => (
        <span className={cn("inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium", u.is_active ? "bg-green-100 text-green-700" : "bg-red-100 text-red-700")}>
          {u.is_active ? <CheckCircle size={10} /> : <XCircle size={10} />}
          {u.is_active ? t("common.active") : t("common.inactive")}
        </span>
      ),
    },
    online_status: {
      label: () => t("filters.onlineStatus"),
      cell: (u) => renderOnlineStatus(u.id),
    },
    approval_status: {
      label: () => t("filters.approvalStatus"),
      cell: (u) => u.courier != null ? (
        <span className={cn("inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-semibold", u.courier.is_approved ? "bg-green-100 text-green-800" : "bg-amber-100 text-amber-800")}>
          {u.courier.is_approved ? t("common.approved") : t("common.notApproved")}
        </span>
      ) : <span className="text-gray-400">—</span>,
    },
    courier_availability: {
      label: () => t("filters.courierAvailability"),
      cell: (u) => u.role_id === 2 ? (
        <span className={cn("flex justify-center items-center w-max px-2 py-1 rounded-full text-xs font-semibold", assignedCourierIdsSet.has(u.id) ? "bg-orange-100 text-orange-800" : "bg-blue-100 text-blue-800")}>
          {assignedCourierIdsSet.has(u.id) ? t("common.assigned") : t("common.free")}
        </span>
      ) : <span className="text-gray-400">—</span>,
    },
    is_email_verified: {
      label: () => t("users.emailVerified"),
      sortField: "is_email_verified",
      cell: (u) => (
        <span className={cn("inline-flex items-center gap-1 text-xs", u.is_email_verified ? "text-green-600" : "text-gray-400")}>
          {u.is_email_verified ? <CheckCircle size={14} /> : <XCircle size={14} />}
          {u.is_email_verified ? t("filters.verified") : t("filters.notVerified")}
        </span>
      ),
    },
    is_phone_verified: {
      label: () => t("users.phoneVerified"),
      sortField: "is_phone_verified",
      cell: (u) => (
        <span className={cn("inline-flex items-center gap-1 text-xs", u.is_phone_verified ? "text-green-600" : "text-gray-400")}>
          {u.is_phone_verified ? <CheckCircle size={14} /> : <XCircle size={14} />}
          {u.is_phone_verified ? t("filters.verified") : t("filters.notVerified")}
        </span>
      ),
    },
    wallet_balance: {
      label: () => t("users.walletBalance"),
      sortField: "wallet_balance",
      cell: (u) => u.wallet != null ? (
        <span className={cn("inline-flex items-center px-2 py-1 rounded-lg text-xs font-semibold tabular-nums", u.wallet.balance > 0 ? "bg-emerald-50 text-emerald-700" : u.wallet.balance < 0 ? "bg-red-50 text-red-700" : "bg-gray-100 text-gray-500")}>
          {u.wallet.balance.toFixed(2)}
        </span>
      ) : <span className="text-gray-400 text-xs">—</span>,
    },
    order_count: {
      label: () => t("users.orderCount"),
      sortField: "order_count",
      cell: (u) => {
        const count = u.courier != null
          ? deliveredCountByCourier[u.courier.id ?? -1]
          : deliveredCountByCustomer[u.id];
        return count != null ? (
          <span className="inline-flex items-center px-2 py-1 rounded-lg text-xs font-semibold tabular-nums bg-indigo-50 text-indigo-700">
            {count}
          </span>
        ) : <span className="text-gray-400 text-xs">—</span>;
      },
    },
    created_at: {
      label: () => t("users.joined"),
      sortField: "created_at",
      tdClassName: "text-gray-500",
      cell: (u) => <span>{new Date(u.created_at).toLocaleDateString()}</span>,
    },
    updated_at: {
      label: () => t("users.updated"),
      sortField: "updated_at",
      tdClassName: "text-gray-500",
      cell: (u) => <span>{u.updated_at ? new Date(u.updated_at).toLocaleDateString() : "—"}</span>,
    },
  };

  // Visible columns in user-defined order (actions always last, handled separately)
  const orderedVisible = columnOrder.filter((k) => k !== "actions" && visible.includes(k));
  const showActions = visible.includes("actions");

  // Column toggle options
  const columnOptions: ColumnOption[] = [
    { key: "id", label: "ID" },
    { key: "avatar", label: t("common.image") },
    { key: "full_name", label: t("common.name") },
    { key: "email", label: t("users.email") },
    { key: "phone", label: t("users.phone") },
    { key: "referral_code", label: t("users.referralCode") },
    { key: "gender", label: t("users.gender") },
    { key: "badge", label: t("users.badge") },
    { key: "role", label: t("users.role") },
    { key: "is_active", label: t("common.status") },
    { key: "online_status", label: t("filters.onlineStatus") },
    { key: "approval_status", label: t("filters.approvalStatus") },
    { key: "courier_availability", label: t("filters.courierAvailability") },
    { key: "is_email_verified", label: t("users.emailVerified") },
    { key: "is_phone_verified", label: t("users.phoneVerified") },
    { key: "wallet_balance", label: t("users.walletBalance") },
    { key: "order_count", label: t("users.orderCount") },
    { key: "created_at", label: t("users.joined") },
    { key: "updated_at", label: t("users.updated") },
    { key: "actions", label: t("common.actions"), alwaysVisible: true },
  ];

  return (
    <div className="p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">
            {t("users.title")}
          </h1>
          <p className="text-sm text-gray-500 mt-0.5">{t("users.subtitle")}</p>
        </div>
      </div>

      {/* Actions */}
      <div className="bg-white border border-gray-200 rounded-xl p-4">
        <h2 className="text-sm font-semibold text-gray-700 mb-3">
          {t("common.actions")}
        </h2>
        <div className="flex flex-wrap items-center gap-2">
          <button
            onClick={() => setCreateAccount({ roleId: 1, label: "Admin" })}
            className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2.5 rounded-xl text-sm font-medium transition"
          >
            <ShieldCheck size={16} /> Create Admin
          </button>
          <button
            onClick={() => setCreateAccount({ roleId: customerRoleId, label: "Customer" })}
            className="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2.5 rounded-xl text-sm font-medium transition"
          >
            <UserPlus size={16} /> Create Customer
          </button>
          <button
            onClick={() => setIsCreateCourierOpen(true)}
            className="flex items-center gap-2 bg-green-600 hover:bg-green-700 text-white px-4 py-2.5 rounded-xl text-sm font-medium transition"
          >
            <Truck size={16} /> Create Courier
          </button>
          <button
            onClick={() => setIsCreateSupplierOpen(true)}
            className="flex items-center gap-2 bg-orange-600 hover:bg-orange-700 text-white px-4 py-2.5 rounded-xl text-sm font-medium transition"
          >
            <Store size={16} /> Create Supplier
          </button>
        </div>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {[
          {
            label: t("users.total"),
            value: data?.totalUsers ?? 0,
            icon: Users,
            color: "bg-indigo-50 text-indigo-700",
            iconBg: "bg-indigo-100",
          },
          {
            label: t("users.active"),
            value: activeCount,
            icon: UserCheck,
            color: "bg-green-50 text-green-700",
            iconBg: "bg-green-100",
          },
          {
            label: t("users.inactive"),
            value: users.filter((u) => !u.is_active).length,
            icon: UserX,
            color: "bg-red-50 text-red-700",
            iconBg: "bg-red-100",
          },
          {
            label: t("users.archived"),
            value: deletedCount,
            icon: Trash2,
            color: "bg-gray-50 text-gray-600",
            iconBg: "bg-gray-200",
          },
        ].map(({ label, value, icon: Icon, color, iconBg }) => (
          <div
            key={label}
            className="bg-white rounded-xl border border-gray-200 p-4 flex items-center gap-3"
          >
            <div
              className={cn(
                "w-10 h-10 rounded-xl flex items-center justify-center shrink-0",
                iconBg,
              )}
            >
              <Icon size={18} className={color.split(" ")[1]} />
            </div>
            <div>
              <p className="text-xs text-gray-500">{label}</p>
              <p className={cn("text-2xl font-bold", color.split(" ")[1])}>
                {value}
              </p>
            </div>
          </div>
        ))}
      </div>

      {/* Advanced Filters Panel */}
      {showAdvancedFilters && (
        <div className="bg-white border border-gray-200 rounded-xl p-4 space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-semibold text-gray-700">
              {t("filters.advanced")}
            </h3>
            <button
              onClick={() => {
                setFilterRole("");
                setFilterId("");
                setFilterGender("");
                setFilterBadge("");
                setFilterEmailVerified("");
                setFilterPhoneVerified("");
                setFilterGovernorate("");
                setFilterArea("");
                setFilterCourierOffice("");
                setFilterVehicleType("");
                setFilterVehiclePlate("");
                setFilterNationalId("");
                setFilterOnlineStatus("");
                setFilterCourierAvailability("");
                setFilterApprovalStatus("");
                setFilterIsSettled("");
              }}
              className="text-xs text-indigo-600 hover:underline"
            >
              {t("filters.clearAll")}
            </button>
          </div>
          <div className="space-y-6">
            {/* Basic Filters Grid */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              <select
                value={filterGender}
                onChange={(e) =>
                  handleFilterChange(setFilterGender, e.target.value)
                }
                className="border border-gray-300 rounded-lg px-3 py-2 text-sm text-black bg-white"
              >
                <option value="">{t("filters.gender")}</option>
                <option value="MALE">{t("filters.male")}</option>
                <option value="FEMALE">{t("filters.female")}</option>
              </select>

              <select
                value={filterBadge}
                onChange={(e) =>
                  handleFilterChange(setFilterBadge, e.target.value)
                }
                className="border border-gray-300 rounded-lg px-3 py-2 text-sm text-black bg-white"
              >
                <option value="">{t("filters.selectBadge")}</option>
                {badges.map((b: UserBadge) => (
                  <option key={b.id} value={b.id}>
                    {b.name}
                  </option>
                ))}
              </select>

              <select
                value={filterEmailVerified}
                onChange={(e) =>
                  handleFilterChange(setFilterEmailVerified, e.target.value)
                }
                className="border border-gray-300 rounded-lg px-3 py-2 text-sm text-black bg-white"
              >
                <option value="">{t("filters.emailVerified")}</option>
                <option value="true">{t("filters.verified")}</option>
                <option value="false">{t("filters.notVerified")}</option>
              </select>

              <select
                value={filterPhoneVerified}
                onChange={(e) =>
                  handleFilterChange(setFilterPhoneVerified, e.target.value)
                }
                className="border border-gray-300 rounded-lg px-3 py-2 text-sm text-black bg-white"
              >
                <option value="">{t("filters.phoneVerified")}</option>
                <option value="true">{t("filters.verified")}</option>
                <option value="false">{t("filters.notVerified")}</option>
              </select>

              <select
                value={filterIsSettled}
                onChange={(e) =>
                  handleFilterChange(setFilterIsSettled, e.target.value)
                }
                className="border border-gray-300 rounded-lg px-3 py-2 text-sm text-black bg-white"
              >
                <option value="">Settlement Status</option>
                <option value="true">Settled</option>
                <option value="false">Not Settled</option>
              </select>

              <select
                value={filterGovernorate}
                onChange={(e) => {
                  handleFilterChange(setFilterGovernorate, e.target.value);
                  setFilterArea("");
                }}
                className="border border-gray-300 rounded-lg px-3 py-2 text-sm text-black bg-white"
              >
                <option value="">{t("filters.selectGovernorate")}</option>
                {governorates.map((g: Governorate) => (
                  <option key={g.id} value={g.id}>
                    {g.name}
                  </option>
                ))}
              </select>

              <select
                value={filterArea}
                onChange={(e) =>
                  handleFilterChange(setFilterArea, e.target.value)
                }
                disabled={!filterGovernorate}
                className={cn(
                  "border border-gray-300 rounded-lg px-3 py-2 text-sm text-black bg-white",
                  !filterGovernorate && "opacity-50 cursor-not-allowed",
                )}
              >
                <option value="">{t("filters.selectArea")}</option>
                {areas.map((a: Area) => (
                  <option key={a.id} value={a.id}>
                    {a.name}
                  </option>
                ))}
              </select>

              {/* Active Status Filter */}
              <select
                value={filterStatus}
                onChange={(e) =>
                  handleFilterChange(setFilterStatus, e.target.value)
                }
                className="border border-gray-200 rounded-lg px-3 py-2 text-sm text-black bg-white"
              >
                <option value="all">{t("filters.activeStatus")}</option>
                <option value="active">{t("common.active")}</option>
                <option value="inactive">{t("common.inactive")}</option>
              </select>

              <select
                value={filterCourierOffice}
                onChange={(e) =>
                  handleFilterChange(setFilterCourierOffice, e.target.value)
                }
                className="border border-gray-200 rounded-lg px-3 py-2 text-sm text-black bg-white"
              >
                <option value="">{t("filters.selectOffice")}</option>
                {courierOffices.map((o: any) => (
                  <option key={o.id} value={o.id}>
                    {o.name}
                  </option>
                ))}
              </select>
            </div>

            {/* Courier-specific Filters Grid */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {/* Vehicle Type Filter */}
              <select
                value={filterVehicleType}
                onChange={(e) =>
                  handleFilterChange(setFilterVehicleType, e.target.value)
                }
                className="border border-gray-200 rounded-lg px-3 py-2 text-sm text-black bg-white"
              >
                <option value="">{t("filters.vehicleType")}</option>
                {vehicles.map((v: Vehicle) => (
                  <option key={v.id} value={v.id}>
                    {lang === "AR" ? v.name_ar : v.name}
                  </option>
                ))}
              </select>

              {/* Vehicle Plate Filter */}
              <input
                type="text"
                value={filterVehiclePlate}
                onChange={(e) =>
                  handleFilterChange(setFilterVehiclePlate, e.target.value)
                }
                placeholder={t("filters.vehiclePlate")}
                className="border border-gray-200 rounded-lg px-3 py-2 text-sm text-black bg-white"
              />

              {/* National ID Filter */}
              <input
                type="text"
                value={filterNationalId}
                onChange={(e) =>
                  handleFilterChange(setFilterNationalId, e.target.value)
                }
                placeholder={t("filters.nationalId")}
                className="border border-gray-200 rounded-lg px-3 py-2 text-sm text-black bg-white"
              />

              {/* Courier Approval Filter */}
              <select
                value={filterApprovalStatus}
                onChange={(e) =>
                  handleFilterChange(setFilterApprovalStatus, e.target.value)
                }
                className="border border-gray-200 rounded-lg px-3 py-2 text-sm text-black bg-white"
              >
                <option value="">{t("filters.approvalStatus")}</option>
                <option value="true">{t("common.approved")}</option>
                <option value="false">{t("common.notApproved")}</option>
              </select>

              {/* Online Status Filter */}
              <select
                value={filterOnlineStatus}
                onChange={(e) =>
                  handleFilterChange(setFilterOnlineStatus, e.target.value)
                }
                className="border border-gray-200 rounded-lg px-3 py-2 text-sm text-black bg-white"
              >
                <option value="">{t("filters.onlineStatus")}</option>
                <option value="Online">{t("filters.online")}</option>
                <option value="Offline">{t("filters.offline")}</option>
              </select>

              {/* Courier Availability Filter */}
              <select
                value={filterCourierAvailability}
                onChange={(e) =>
                  handleFilterChange(
                    setFilterCourierAvailability,
                    e.target.value,
                  )
                }
                disabled={filterRole !== courierRoleId || isLoadingAvailability}
                className="border border-gray-200 rounded-lg px-3 py-2 text-sm text-black bg-white disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <option value="">{t("filters.courierAvailability")}</option>
                <option value="assigned">
                  {isLoadingAvailability ? "..." : t("common.assigned")}
                </option>
                <option value="free">{t("common.free")}</option>
              </select>
            </div>

            {/* Created Date Filter - Full Width Row */}
            <div className="border-t border-gray-200 pt-4">
              <DateRangeFilter
                from={createdFrom}
                to={createdTo}
                onFromChange={setCreatedFrom}
                onToChange={setCreatedTo}
                label={t("users.created")}
              />
            </div>

            {/* Updated Date Filter - Full Width Row */}
            <div className="border-t border-gray-200 pt-4">
              <DateRangeFilter
                from={updatedFrom}
                to={updatedTo}
                onFromChange={setUpdatedFrom}
                onToChange={setUpdatedTo}
                label={t("users.updated")}
              />
            </div>
          </div>
        </div>
      )}

      {/* Toolbar */}
      <TableToolbar
        total={displayTotal}
        totalLabel={t("users.user")}
        search={search}
        onSearch={(v) => {
          setSearch(v);
          setPage(1);
        }}
        searchPlaceholder={t("common.search") + "..."}
      >
        {/* Column Toggle - positioned right after search */}
        <ColumnToggle
          columns={columnOptions}
          visible={visible}
          onChange={setVisible}
        />

        {/* Role Filter */}
        <select
          value={filterRole}
          onChange={(e) => handleFilterChange(setFilterRole, e.target.value)}
          className="border border-gray-200 rounded-lg px-3 py-2 text-sm text-black bg-white"
        >
          <option value="">{t("users.allRoles")}</option>
          {roles.map((r) => (
            <option key={r.id} value={r.id}>
              {r.name}
            </option>
          ))}
        </select>

        {/* ID Filter */}
        <select
          value={filterId}
          onChange={(e) => handleFilterChange(setFilterId, e.target.value)}
          className="border border-gray-200 rounded-lg px-3 py-2 text-sm text-black bg-white"
        >
          <option value="">{t("filters.selectId")}</option>
          {allUserIds.map((u) => (
            <option key={u.id} value={u.id}>
              {u.id} - {u.full_name}
            </option>
          ))}
        </select>

        {/* Advanced filters toggle */}
        <button
          onClick={() => setShowAdvancedFilters((s) => !s)}
          className={cn(
            "flex items-center gap-2 px-3 py-2 rounded-lg text-sm border transition",
            showAdvancedFilters
              ? "bg-indigo-50 border-indigo-300 text-indigo-700"
              : "bg-white border-gray-300 text-gray-700 hover:bg-gray-50",
          )}
        >
          {showAdvancedFilters ? <X size={16} /> : <Filter size={16} />}
          {showAdvancedFilters
            ? t("filters.hideAdvanced")
            : t("filters.showAdvanced")}
        </button>
      </TableToolbar>

      {/* Bulk Actions */}
      {selected.size > 0 && (
        <div className="flex items-center justify-between bg-indigo-50 border border-indigo-200 rounded-lg p-3">
          <span className="text-sm text-indigo-900">
            {selected.size} {t("common.selected")}
          </span>
          <button
            onClick={() => bulkDeleteMutation.mutate(Array.from(selected))}
            disabled={bulkDeleteMutation.isPending}
            className="px-3 py-1.5 bg-red-600 hover:bg-red-700 text-white text-sm font-medium rounded-lg disabled:opacity-60 transition"
          >
            {t("common.bulkDelete")}
          </button>
        </div>
      )}

      {/* Table */}
      <div className="bg-white border border-gray-200 rounded-xl overflow-x-auto shadow-sm">
        <table className="w-full text-sm min-w-[1200px]">
          <thead className="bg-gray-50 border-b border-gray-200">
            <tr>
              <th className="px-4 py-3 w-10">
                <input
                  type="checkbox"
                  checked={selected.size === users.length && users.length > 0}
                  onChange={toggleSelectAll}
                  className="rounded border-gray-300"
                />
              </th>
              {/* ── Draggable column headers ─────────────────────────────── */}
              {orderedVisible.map((key) => {
                const def = colDefs[key];
                if (!def) return null;
                const isOver = dragOverKey === key && dragKey !== key;
                return (
                  <th
                    key={key}
                    draggable
                    onDragStart={() => setDragKey(key)}
                    onDragEnd={() => { setDragKey(null); setDragOverKey(null); }}
                    onDragOver={(e) => { e.preventDefault(); setDragOverKey(key); }}
                    onDrop={() => handleDrop(key)}
                    onDragLeave={(e) => {
                      if (!e.currentTarget.contains(e.relatedTarget as Node | null))
                        setDragOverKey(null);
                    }}
                    onClick={def.sortField ? () => toggleSort(def.sortField!) : undefined}
                    className={cn(
                      "px-4 py-3 text-left font-semibold text-gray-700 select-none transition-colors whitespace-nowrap",
                      def.sortField && "cursor-pointer",
                      def.thClassName,
                      dragKey === key && "opacity-40",
                      isOver && "bg-indigo-50 border-l-2 border-indigo-400",
                    )}
                  >
                    <div className="flex items-center gap-1.5">
                      <GripVertical size={13} className="shrink-0 text-gray-300 group-hover:text-gray-400 cursor-grab" />
                      {def.label()}
                      {def.sortField && <SortIcon active={sortField === def.sortField} dir={sortDir} />}
                    </div>
                  </th>
                );
              })}
              {/* Actions column — pinned to the right for easy access */}
              {showActions && (
                <th className="sticky right-0 z-20 bg-gray-50 px-4 py-3 text-right font-semibold text-gray-700 w-32 border-l border-gray-200">
                  {t("common.actions")}
                </th>
              )}
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {isLoading ? (
              <tr>
                <td
                  colSpan={ALL_COLUMN_KEYS.length}
                  className="px-4 py-12 text-center text-gray-500"
                >
                  <div className="flex items-center justify-center gap-2">
                    <RefreshCw size={18} className="animate-spin" />
                    {t("common.loading")}...
                  </div>
                </td>
              </tr>
            ) : displayedUsers.length === 0 ? (
              <tr>
                <td
                  colSpan={ALL_COLUMN_KEYS.length}
                  className="px-4 py-12 text-center text-gray-500"
                >
                  {t("users.noUsersFound")}
                </td>
              </tr>
            ) : (
              displayedUsers.map((u) => (
                <Fragment key={u.id}>
                  <tr
                    className={cn(
                      "bg-white hover:bg-gray-50 transition cursor-pointer",
                      u.deleted_at && "opacity-60 bg-gray-50",
                    )}
                    onClick={() => handleRowClick(u)}
                  >
                    <td
                      className="px-4 py-3"
                      onClick={(e) => e.stopPropagation()}
                    >
                      <input
                        type="checkbox"
                        checked={selected.has(u.id)}
                        onChange={() => toggleSelect(u.id)}
                        className="rounded border-gray-300"
                      />
                    </td>
                    {/* ── Data cells in user-defined column order ─────────── */}
                    {orderedVisible.map((key) => {
                      const def = colDefs[key];
                      if (!def) return null;
                      return (
                        <td key={key} className={cn("px-4 py-3", def.tdClassName)}>
                          {def.cell(u)}
                        </td>
                      );
                    })}
                    {/* Actions cell — pinned to the right for easy access */}
                    {showActions && (
                      <td
                        className="sticky right-0 z-10 bg-inherit border-l border-gray-200 px-4 py-3"
                        onClick={(e) => e.stopPropagation()}
                      >
                        <div className="flex items-center justify-end gap-1">
                          {/* View — routes to the role-specific detail page */}
                          <button
                            onClick={() => handleRowClick(u)}
                            className="p-1.5 hover:bg-indigo-50 rounded-lg text-indigo-600 transition"
                            title={`${t("common.view")} ${roleMap[u.role_id] || ""}`.trim()}
                          >
                            <Eye size={15} />
                          </button>
                          {/* Chat */}
                          <a
                            href={`/chat?userId=${u.id}`}
                            target="_blank"
                            rel="noreferrer"
                            className="p-1.5 hover:bg-indigo-50 rounded-lg text-indigo-500 transition"
                            title="Open chat"
                          >
                            <MessageSquare size={15} />
                          </a>
                          {/* Edit */}
                          {usesAdminModal(u) ? (
                            <button
                              onClick={() => setEditAdminUser(u)}
                              className="p-1.5 hover:bg-indigo-50 rounded-lg text-indigo-600 transition"
                              title={`${t("common.edit")} ${roleMap[u.role_id] || "Admin"}`.trim()}
                            >
                              <Pencil size={15} />
                            </button>
                          ) : u.role_id === 6 ||
                            (roleMap[u.role_id] || "")
                              .toLowerCase()
                              .includes("supplier") ? (
                            <button
                              onClick={() =>
                                setEditSupplier({ id: u.id, name: u.full_name })
                              }
                              className="p-1.5 hover:bg-indigo-50 rounded-lg text-indigo-600 transition"
                              title={`${t("common.edit")} ${roleMap[u.role_id] || "Supplier"}`.trim()}
                            >
                              <Pencil size={15} />
                            </button>
                          ) : u.role_id === 2 ||
                            (roleMap[u.role_id] || "")
                              .toLowerCase()
                              .includes("courier") ? (
                            <button
                              onClick={() => setEditCourier(u)}
                              className="p-1.5 hover:bg-indigo-50 rounded-lg text-indigo-600 transition"
                              title={`${t("common.edit")} ${roleMap[u.role_id] || "Courier"}`.trim()}
                            >
                              <Pencil size={15} />
                            </button>
                          ) : (
                            <button
                              onClick={() => openEdit(u)}
                              className="p-1.5 hover:bg-indigo-50 rounded-lg text-indigo-600 transition"
                              title={`${t("common.edit")} ${roleMap[u.role_id] || ""}`.trim()}
                            >
                              <Pencil size={15} />
                            </button>
                          )}
                          {deleteConfirm === u.id ? (
                            <div className="flex items-center gap-1 flex-wrap justify-end">
                              <span className="text-xs text-gray-500">
                                {t("common.sure")}
                              </span>
                              <button
                                onClick={() => deleteMutation.mutate(u.id)}
                                disabled={
                                  deleteMutation.isPending ||
                                  hardDeleteMutation.isPending
                                }
                                className="px-2 py-1 bg-amber-500 hover:bg-amber-600 text-white text-xs rounded-lg disabled:opacity-60"
                              >
                                {t("common.archive")}
                              </button>
                              <button
                                onClick={() => hardDeleteMutation.mutate(u.id)}
                                disabled={
                                  deleteMutation.isPending ||
                                  hardDeleteMutation.isPending
                                }
                                className="px-2 py-1 bg-red-600 hover:bg-red-700 text-white text-xs rounded-lg disabled:opacity-60"
                              >
                                {t("common.deleteForever")}
                              </button>
                              <button
                                onClick={() => setDeleteConfirm(null)}
                                className="px-2 py-1 border text-xs rounded-lg"
                              >
                                {t("common.cancel")}
                              </button>
                            </div>
                          ) : (
                            <button
                              onClick={() => setDeleteConfirm(u.id)}
                              className="p-1.5 hover:bg-red-50 rounded-lg text-red-500 transition"
                            >
                              <Trash2 size={15} />
                            </button>
                          )}
                        </div>
                      </td>
                    )}
                  </tr>
                </Fragment>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Rows-per-page + Pagination row */}
      <div className="flex items-center justify-between gap-4 flex-wrap">
        {/* Rows per page */}
        <div className="flex items-center gap-2">
          <span className="text-sm text-gray-500 whitespace-nowrap">{t("common.rowsPerPage")}:</span>
          <div className="flex items-center gap-1">
            {PAGE_SIZES.map((s) => (
              <button
                key={s}
                onClick={() => { setPageSize(s); setPage(1); }}
                className={cn(
                  "px-3 py-1.5 rounded-lg text-sm font-medium border transition",
                  pageSize === s
                    ? "bg-indigo-600 text-white border-indigo-600"
                    : "bg-white text-gray-600 border-gray-200 hover:border-indigo-300 hover:text-indigo-600",
                )}
              >
                {s === 0 ? t("common.all") : s}
              </button>
            ))}
          </div>
        </div>

        {/* Page navigation */}
        {pageSize !== 0 && (
          <TablePagination
            page={page}
            totalPages={totalPages}
            total={displayTotal}
            limit={pageSize}
            onPageChange={setPage}
          />
        )}
      </div>

      {showForm && (
        <UserForm
          user={editUser}
          onClose={closeForm}
          presetRoleId={createRolePreset}
          onUpdated={(data) =>
            console.log("[UsersPage] edit user response →", {
              userId: editUser?.id,
              data,
            })
          }
        />
      )}

      {isCreateSupplierOpen && (
        <CreateSupplierModal
          isOpen={isCreateSupplierOpen}
          onClose={() => setIsCreateSupplierOpen(false)}
        />
      )}

      {createAccount && (
        <CreateAccountModal
          isOpen={!!createAccount}
          roleId={createAccount.roleId}
          label={createAccount.label}
          onClose={() => setCreateAccount(null)}
        />
      )}

      {isCreateCourierOpen && (
        <CreateCourierModal
          isOpen={isCreateCourierOpen}
          onClose={() => setIsCreateCourierOpen(false)}
        />
      )}

      {editAdminUser && (
        <EditAdminModal
          isOpen={!!editAdminUser}
          user={editAdminUser}
          roleLabel={
            roleMap[editAdminUser.role_id] ||
            editAdminUser.role?.name ||
            "Admin"
          }
          showPasswordField={!isCustomerRole(editAdminUser)}
          onClose={() => setEditAdminUser(null)}
        />
      )}

      {editSupplier && (
        <EditSupplierModal
          userId={editSupplier.id}
          userName={editSupplier.name}
          onClose={() => setEditSupplier(null)}
        />
      )}

      {editCourier && (
        <EditCourierModal
          user={editCourier}
          onClose={() => setEditCourier(null)}
        />
      )}

      {/* ── Analytics Charts ───────────────────────────────────────────── */}
      <UserStatsCharts />
    </div>
  );
}
