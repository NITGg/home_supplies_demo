import axiosInstance from "../lib/axios";
import { AboutAppResponse, UpdateAboutAppPayload } from "../types/aboutApp";

export const aboutAppService = {
  getAboutApp: async (): Promise<AboutAppResponse> => {
    const response = await axiosInstance.get<AboutAppResponse>("/about-app");
    return response.data;
  },

  updateAboutApp: async (payload: UpdateAboutAppPayload): Promise<void> => {
    await axiosInstance.put("/about-app", payload);
  },
};
