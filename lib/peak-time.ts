import api from "./api";

export interface PeakTime {
  id: number;
  day: number;
  start_time: string;
  end_time: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface PeakTimesResponse {
  totalPeakTimes: number;
  totalPages: number;
  peakTimes: PeakTime[];
}

export async function fetchPeakTimes(params?: Record<string, string | number>) {
  const { page = 1, limit = 10, ...rest } = params || {};
  const skip = (Number(page) - 1) * Number(limit);
  const res = await api.get("/admin/peak-time/list-peak-times", {
    params: { limit, skip, ...rest },
  });
  return res.data?.data ?? res.data ?? { totalPeakTimes: 0, totalPages: 0, peakTimes: [] };
}

export async function fetchPeakTimeDetails(id: number) {
  try {
    const res = await api.get(`/admin/peak-time/peak-time-details/${id}`);
    return res.data?.peakTime ?? res.data?.data?.peakTime ?? res.data;
  } catch (error) {
    console.error('Error fetching peak time details:', error);
    throw error;
  }
}

export async function createPeakTime(data: {
  day: number;
  start_time: string;
  end_time: string;
}) {
  const res = await api.post("/admin/peak-time/create-peak-time", data);
  return res.data?.data ?? res.data ?? { totalPeakTimes: 0, totalPages: 0, peakTimes: [] };
}

export async function updatePeakTime(
  id: number,
  data: { day?: number; start_time?: string; end_time?: string },
) {
  const res = await api.put(`/admin/peak-time/update-peak-time/${id}`, data);
  return res.data?.data ?? res.data ?? { totalPeakTimes: 0, totalPages: 0, peakTimes: [] };
}

export async function deletePeakTime(id: number) {
  const res = await api.delete(`/admin/peak-time/delete-peak-time/${id}`);
  return res.data;
}
