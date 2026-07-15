// import { useAppSelector, useAppDispatch } from "@/store";
// import { logout as logoutAction, setCredentials, type AuthUser } from "@/store/slices/authSlice";
// import { useNavigate } from "react-router-dom";
// import { useCallback } from "react";

// export function useAuth() {
//   const { token, user, isAuthenticated } = useAppSelector((state) => state.auth);
//   const dispatch = useAppDispatch();
//   const navigate = useNavigate();

//   const login = useCallback(
//     (token: string, user: AuthUser) => {
//       dispatch(setCredentials({ token, user }));
//     },
//     [dispatch]
//   );

//   const logout = useCallback(() => {
//     dispatch(logoutAction());
//     navigate("/login");
//   }, [dispatch, navigate]);

//   return { token, user, isAuthenticated, login, logout };
// }
