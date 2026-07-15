import axios from "axios";

const axiosInstance = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL || "/api",
  timeout: 15000,
  headers: {
    "Content-Type": "application/json",
  },
});

// Request interceptor – inject auth token
axiosInstance.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem("token") || localStorage.getItem("auth_token");
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error),
);

// Response interceptor – handle 401
let isRedirectingTo401 = false;

axiosInstance.interceptors.response.use(
  (response) => response,
  (error) => {
    console.log(error);
    
    if (error.response?.status === 401 && !isRedirectingTo401) {
      // Check if this is a genuine auth failure (expired/invalid token)
      // vs a permission error on a specific endpoint
      const url = error.config?.url || "";
      const isPermissionError =
        url.includes("/admin/wallet/") ||
        url.includes("/admin/payment") ||
        url.includes("/admin/courier-office/");

      if (isPermissionError) {
        // Don't logout — just let the component handle it via catch block
        return Promise.reject(error);
      }

      // Genuine auth failure — logout and redirect
      if (window.location.pathname !== "/login" && window.location.pathname !== "/register") {
        isRedirectingTo401 = true;
        window.dispatchEvent(new Event("auth:unauthorized"));
        window.location.href = "/login";
      } else if (window.location.pathname === "/register") {
        // Clear auth state but stay on register page
        window.dispatchEvent(new Event("auth:unauthorized"));
      }
    }
    return Promise.reject(error);
  },
);

export default axiosInstance;
