import { LOG_SERVICES, LogFilters } from "@/types/logs.types";

const HTTP_METHODS = ["GET", "POST", "PUT", "PATCH", "DELETE"] as const;

interface UserOption {
  id: number;
  full_name: string;
}

interface LogsFilterBarProps {
  filters: LogFilters;
  allUserIds: UserOption[];
  setFilter: <K extends keyof LogFilters>(key: K, value: LogFilters[K]) => void;
}

export function LogsFilterBar({
  filters,
  allUserIds,
  setFilter,
}: Readonly<LogsFilterBarProps>) {
  return (
    <div className="flex flex-wrap items-end gap-3 pt-1">
      {/* Service */}
      <div className="flex flex-col gap-1">
        <label htmlFor="filter-service" className="text-xs text-gray-500">
          Service
        </label>

        <select
          id="filter-service"
          value={filters.service}
          onChange={(e) =>
            setFilter("service", e.target.value as LogFilters["service"])
          }
          className="input w-auto text-sm"
        >
          <option value="">All services</option>

          {LOG_SERVICES.map((service) => (
            <option key={service} value={service}>
              {service}
            </option>
          ))}
        </select>
      </div>
      {/* Method */}
      <div className="flex flex-col gap-1">
        <label htmlFor="filter-method" className="text-xs text-gray-500">
          Method
        </label>
        <select
          id="filter-method"
          value={filters.method}
          onChange={(e) => setFilter("method", e.target.value)}
          className="input w-auto text-sm"
        >
          <option value="">All</option>
          {HTTP_METHODS.map((m) => (
            <option key={m} value={m}>
              {m}
            </option>
          ))}
        </select>
      </div>

      <div className="h-8 w-px bg-gray-200 self-end mb-1" />

      {/* Status range */}
      <div className="flex flex-col gap-1">
        <label htmlFor="filter-status-min" className="text-xs text-gray-500">
          Status
        </label>
        <div className="flex items-center gap-1.5">
          <input
            id="filter-status-min"
            type="number"
            min={100}
            max={599}
            placeholder="min"
            value={filters.statusMin}
            onChange={(e) =>
              setFilter(
                "statusMin",
                e.target.value === "" ? "" : Number(e.target.value),
              )
            }
            className="input w-20 text-sm"
            aria-label="Status minimum"
          />
          <span className="text-xs text-gray-400">–</span>
          <input
            id="filter-status-max"
            type="number"
            min={100}
            max={599}
            placeholder="max"
            value={filters.statusMax}
            onChange={(e) =>
              setFilter(
                "statusMax",
                e.target.value === "" ? "" : Number(e.target.value),
              )
            }
            className="input w-20 text-sm"
            aria-label="Status maximum"
          />
        </div>
      </div>

      <div className="h-8 w-px bg-gray-200 self-end mb-1" />

      {/* Duration range */}
      <div className="flex flex-col gap-1">
        <label htmlFor="filter-duration-min" className="text-xs text-gray-500">
          Duration (ms)
        </label>
        <div className="flex items-center gap-1.5">
          <input
            id="filter-duration-min"
            type="number"
            min={0}
            placeholder="min"
            value={filters.durationMin}
            onChange={(e) =>
              setFilter(
                "durationMin",
                e.target.value === "" ? "" : Number(e.target.value),
              )
            }
            className="input w-20 text-sm"
            aria-label="Duration minimum"
          />
          <span className="text-xs text-gray-400">–</span>
          <input
            id="filter-duration-max"
            type="number"
            min={0}
            placeholder="max"
            value={filters.durationMax}
            onChange={(e) =>
              setFilter(
                "durationMax",
                e.target.value === "" ? "" : Number(e.target.value),
              )
            }
            className="input w-20 text-sm"
            aria-label="Duration maximum"
          />
        </div>
      </div>

      <div className="h-8 w-px bg-gray-200 self-end mb-1" />

      {/* User */}
      <div className="flex flex-col gap-1">
        <label htmlFor="filter-user" className="text-xs text-gray-500">
          User
        </label>
        <select
          id="filter-user"
          value={filters.userId}
          onChange={(e) =>
            setFilter(
              "userId",
              e.target.value === "" ? "" : Number(e.target.value),
            )
          }
          className="input w-auto text-sm"
        >
          <option value="">All users</option>
          {allUserIds.map((u) => (
            <option key={u.id} value={u.id}>
              #{u.id} — {u.full_name}
            </option>
          ))}
        </select>
      </div>

      <div className="h-8 w-px bg-gray-200 self-end mb-1" />

      {/* Created at — date + optional time */}
      <div className="flex flex-col gap-1">
        <label htmlFor="filter-created-from" className="text-xs text-gray-500">
          Created
        </label>
        <div className="flex flex-wrap items-center gap-2">
          <div className="flex items-center gap-1.5">
            <input
              id="filter-created-from"
              type="date"
              value={filters.createdFrom}
              onChange={(e) => setFilter("createdFrom", e.target.value)}
              className="input text-sm"
              aria-label="Created from date"
            />
            <input
              id="filter-created-from-time"
              type="time"
              value={filters.createdFromTime}
              onChange={(e) => setFilter("createdFromTime", e.target.value)}
              className="input w-28 text-sm"
              aria-label="Created from time"
              disabled={!filters.createdFrom}
            />
          </div>
          <span className="text-xs text-gray-400">–</span>
          <div className="flex items-center gap-1.5">
            <input
              id="filter-created-to"
              type="date"
              value={filters.createdTo}
              onChange={(e) => setFilter("createdTo", e.target.value)}
              className="input text-sm"
              aria-label="Created to date"
            />
            <input
              id="filter-created-to-time"
              type="time"
              value={filters.createdToTime}
              onChange={(e) => setFilter("createdToTime", e.target.value)}
              className="input w-28 text-sm"
              aria-label="Created to time"
              disabled={!filters.createdTo}
            />
          </div>
        </div>
      </div>
    </div>
  );
}
