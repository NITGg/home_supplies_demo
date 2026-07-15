"use client";
import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { getAdminSocket, getCourierSocket } from "@/lib/socket";
import axiosInstance from "@/lib/axios";
import { LogEntry, LogsResponse, UseLogsOptions } from "@/types/logs.types";
import { buildLogParams } from "@/lib/logs.helpers";

async function fetchLogs(
  params: Record<string, string | number>,
): Promise<LogsResponse> {
  const { data } = await axiosInstance.get<LogsResponse>("/logs", { params });
  return data;
}

export const useLogs = (props: UseLogsOptions) => {
  const [liveLogs, setLiveLogs] = useState<LogEntry[]>([]);
  const params = buildLogParams(props);

  const query = useQuery({
    queryKey: ["logs", params],
    queryFn: () => fetchLogs(params),
  });

  const fetchedLogs = query.data?.logs ?? [];
  const total = query.data?.totalLogs ?? 0;
  const totalPages = query.data?.totalPages ?? 1;

  useEffect(() => {
    setLiveLogs([]);
  }, [
    props.page,
    props.search,
    props.method,
    props.statusMin,
    props.statusMax,
    props.durationMin,
    props.durationMax,
    props.userId,
    props.createdFrom,
    props.createdFromTime,
    props.createdTo,
    props.createdToTime,
    props.sortField,
    props.sortDir,
  ]);

  useEffect(() => {
    const handleLog = (raw: LogEntry) => {
      console.log("new log", raw);
      if (props.service && raw.service !== props.service) return;

      const entry: LogEntry = {
        ...raw,
        created_at:
          typeof raw.created_at === "string"
            ? raw.created_at
            : new Date(raw.created_at).toISOString(),
      };

      if (props.page === 1) {
        setLiveLogs((prev) => [entry, ...prev].slice(0, 50));
      }
    };

    const sockets: Array<ReturnType<typeof getAdminSocket>> = [];

    switch (props.service) {
      case "ADMIN_CUSTOMER":
        sockets.push(getAdminSocket());
        break;

      case "COURIER":
        sockets.push(getCourierSocket());
        break;

      default:
        sockets.push(getAdminSocket(), getCourierSocket());
        break;
    }

    const validSockets = sockets.filter(
      (socket): socket is NonNullable<typeof socket> => Boolean(socket),
    );

    validSockets.forEach((socket) => {
      const attach = () => socket.on("log:new", handleLog);

      if (socket.connected) {
        attach();
      } else {
        socket.once("connect", attach);
      }
    });

    return () => {
      validSockets.forEach((socket) => {
        socket.off("log:new", handleLog);
      });
    };
  }, [props.page, props.service]);

  // Filter live logs to ensure they match current UI filters (method, status, etc.)
  const filteredLiveLogs = liveLogs.filter((log) => {
    if (props.method && log.method !== props.method) return false;
    if (props.statusMin && log.status_code < props.statusMin) return false;
    if (props.statusMax && log.status_code > props.statusMax) return false;
    if (props.service && log.service !== props.service) return false;
    if (props.userId && log.user_id !== props.userId) return false;
    // You can add keyword/search filtering here if needed
    return true;
  });
  // Create a Set of IDs currently in the live logs for O(1) lookup
  const liveLogIds = new Set(filteredLiveLogs.map((l) => l.id));

  // Only include fetched logs if their ID isn't already in the live list
  const logs =
    props.page === 1
      ? [
          ...filteredLiveLogs,
          ...fetchedLogs.filter((l) => !liveLogIds.has(l.id)),
        ]
      : fetchedLogs;
      
  return {
    logs,
    total,
    totalPages,
    liveLogs,
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    refetch: query.refetch,
  };
};
