export interface PeakTime {
  id: number;
  day: number;
  start_time: string;
  end_time: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface PeakTimeFilter {
  day: string;
  start_time_gte: string;
  start_time_lte: string;
  end_time_gte: string;
  end_time_lte: string;
  is_active: string;
  created_atFrom: string;
  created_atTo: string;
  updated_atFrom: string;
  updated_atTo: string;
}

export interface PaginatedPeakTimesResponse {
  totalPeakTimes: number;
  totalPages: number;
  peakTimes: PeakTime[];
}

export interface CreatePeakTimePayload {
  day: number;
  start_time: string;
  end_time: string;
}

export interface UpdatePeakTimePayload {
  day?: number;
  start_time?: string;
  end_time?: string;
}
