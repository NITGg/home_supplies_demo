# Tawreedat Authentication API Documentation

This document describes the endpoints for the **Authentication** module of the Tawreedat API. It covers registration, login, multi-channel OTP verification, forget password recovery, and authenticated credential management.

A matching Postman Collection is available in the root folder: [tawreedat_auth_postman_collection.json](file:///d:/My%20work/NIT/Projects/Tawreedat/admin-prod/tawreedat_auth_postman_collection.json). You can import it directly into Postman.

---

## Table of Contents
1. [General Information](#general-information)
2. [Public Auth Flow](#1-public-auth-flow)
   - [Register User (`POST /register`)](#register-user-post-register)
   - [Login User (`POST /login`)](#login-user-post-login)
   - [Google Social Login (`POST /google/verify`)](#google-social-login-post-googleverify)
   - [Apple Social Login (`POST /apple/verify`)](#apple-social-login-post-appleverify)
   - [Issue Token for External App (`POST /token`)](#issue-token-for-external-app-post-token)
3. [Verification & OTP Flow](#2-verification--otp-flow)
   - [Request Account Verification OTP (`POST /request-verification`)](#request-account-verification-otp-post-request-verification)
   - [Verify Account OTP (`POST /verify-account`)](#verify-account-otp-post-verify-account)
4. [Forget Password Flow](#3-forget-password-flow)
   - [Forget Password - Request OTP (`POST /forget-password`)](#forget-password---request-otp-post-forget-password)
   - [Verify Reset Code & Reset Password (`POST /verify-forget-password`)](#verify-reset-code--reset-password-post-verify-forget-password)
5. [Authenticated Actions](#4-authenticated-actions)
   - [Get Profile / Verify Me (`GET /verify-me`)](#get-profile--verify-me-get-verify-me)
   - [Change Password (`POST /change-password`)](#change-password-post-change-password)
   - [Change Phone or Email Request (`POST /change-phone-email`)](#change-phone-or-email-request-post-change-phone-email)
   - [Verify Phone or Email Change (`POST /verify-old-new-phone-email`)](#verify-phone-or-email-change-post-verify-old-new-phone-email)
   - [Logout User (`POST /logout`)](#logout-user-post-logout)

---

## General Information

### Base URL
```text
{{baseUrl}}/api/v1/auth
```
*Local Default*: `http://localhost:5000/api/v1/auth`

### Common Headers
| Header Name | Type | Value | Description |
| :--- | :--- | :--- | :--- |
| `Content-Type` | String | `application/json` | Required for all `POST` requests. |
| `Accept-Language` | String | `en` or `ar` | Controls the language of return error/success messages. Default is `en`. |
| `Authorization` | String | `Bearer <token>` | Required for authenticated endpoints. |

---

## 1. Public Auth Flow

### Register User (`POST /register`)
Creates a new customer account. The account starts as **unverified**. Registration **does not** return a JWT token immediately. Instead, the user must verify their contact channel first (either the email or phone number provided). An OTP code will automatically be generated and sent.

- **Request Body:**
  ```json
  {
    "full_name": "John Doe",
    "email": "john.doe@example.com",
    "phone": "01012345678",
    "password": "securepassword123",
    "gender": "MALE"
  }
  ```
  > [!NOTE]
  > - At least one of `email` or `phone` is required.
  > - `phone` must be a valid Egyptian mobile number.
  > - `gender` is optional and can be `MALE` or `FEMALE`.

- **Success Response (201 Created):**
  ```json
  {
    "message": "Registered successfully",
    "user": {
      "id": 12,
      "full_name": "John Doe",
      "email": "john.doe@example.com",
      "phone": "01012345678",
      "is_active": true,
      "is_email_verified": false,
      "is_phone_verified": false
    },
    "via": "email"
  }
  ```

- **Error Response (400 Bad Request):**
  ```json
  {
    "message": "Email is already in use",
    "field": "email"
  }
  ```

---

### Login User (`POST /login`)
Logs in local accounts using email/phone and password credentials.

- **Request Body (Option A: Email):**
  ```json
  {
    "email": "john.doe@example.com",
    "password": "securepassword123"
  }
  ```
- **Request Body (Option B: Phone):**
  ```json
  {
    "phone": "01012345678",
    "password": "securepassword123"
  }
  ```

- **Success Response (200 OK):**
  ```json
  {
    "message": "Login successful",
    "token": "eyJhbGciOiJIUzI1NiIsIn...",
    "user": {
      "id": 12,
      "full_name": "John Doe",
      "email": "john.doe@example.com",
      "phone": "01012345678",
      "role": "Customer"
    }
  }
  ```

- **Error Response (403 Forbidden - Verification Gated):**
  If any added contact channel is unverified, login will fail.
  ```json
  {
    "message": "Account not verified",
    "code": "EMAIL_NOT_VERIFIED",
    "unverified": ["email"]
  }
  ```
  *Possible Codes*: `ACCOUNT_NOT_VERIFIED`, `EMAIL_NOT_VERIFIED`, `PHONE_NOT_VERIFIED`.

- **Error Response (404 Not Found / 400 Bad Request):**
  ```json
  {
    "message": "User not found"
  }
  ```

---

### Google Social Login (`POST /google/verify`)
Verifies Google ID Token and logs/registers the user.

- **Request Body:**
  ```json
  {
    "idToken": "google-id-token-here"
  }
  ```

- **Success Response (200 OK):**
  ```json
  {
    "message": "Login successful",
    "token": "eyJhbGciOiJIUzI1NiIsIn...",
    "user": {
      "id": 15,
      "full_name": "Jane Smith",
      "email": "jane.smith@gmail.com",
      "phone": null,
      "role": "Customer"
    },
    "isNew": true
  }
  ```

---

### Apple Social Login (`POST /apple/verify`)
Verifies Apple ID Token and logs/registers the user.

- **Request Body:**
  ```json
  {
    "idToken": "apple-id-token-here",
    "full_name": "Jane Smith",
    "nonce": "optional-nonce"
  }
  ```

- **Success Response (200 OK):**
  ```json
  {
    "message": "Login successful",
    "token": "eyJhbGciOiJIUzI1NiIsIn...",
    "user": {
      "id": 16,
      "full_name": "Jane Smith",
      "email": "jane.smith@apple.com",
      "phone": null,
      "role": "Customer"
    },
    "isNew": false
  }
  ```

---

### Issue Token for External App (`POST /token`)
Issues client credentials tokens for integrated external clients.

- **Request Body:**
  ```json
  {
    "client_id": "your-client-id",
    "client_secret": "your-client-secret"
  }
  ```

- **Success Response (200 OK):**
  ```json
  {
    "token": "external-app-jwt-token"
  }
  ```

---

## 2. Verification & OTP Flow

### Request Account Verification OTP (`POST /request-verification`)
Triggers verification OTP. Subject to a coarse rate-limiter and a strict **60-second cooldown per channel**.

- **Request Body:**
  ```json
  {
    "email": "john.doe@example.com"
  }
  ```
  *OR*
  ```json
  {
    "phone": "01012345678"
  }
  ```

- **Success Response (200 OK):**
  ```json
  {
    "message": "Verification code sent successfully",
    "via": "email"
  }
  ```

- **Error Response (429 Too Many Requests):**
  ```json
  {
    "message": "Please wait before resending OTP",
    "code": "OTP_COOLDOWN",
    "retryAfter": 45
  }
  ```

---

### Verify Account OTP (`POST /verify-account`)
Verifies the submitted code for a channel. If all channels (email/phone) are fully verified, it issues a session token immediately.

- **Request Body:**
  ```json
  {
    "email": "john.doe@example.com",
    "code": "1234"
  }
  ```
  *OR*
  ```json
  {
    "phone": "01012345678",
    "code": "1234"
  }
  ```

- **Success Response - Fully Verified (200 OK):**
  ```json
  {
    "message": "Account verified successfully",
    "verified": true,
    "via": "email",
    "fullyVerified": true,
    "token": "eyJhbGciOiJIUzI1NiIsIn..."
  }
  ```

- **Success Response - Part Verified (200 OK):**
  Returned if the user has both email and phone, but the other channel is still unverified.
  ```json
  {
    "message": "Email verified successfully",
    "verified": true,
    "via": "email",
    "fullyVerified": false,
    "unverified": ["phone"]
  }
  ```

---

## 3. Forget Password Flow

### Forget Password - Request OTP (`POST /forget-password`)
Starts the password reset flow. Accepts an identifier (email/phone). If the user has both email and phone, a channel hint can be specified.

- **Request Body:**
  ```json
  {
    "identifier": "john.doe@example.com",
    "channel": "email"
  }
  ```
  > [!NOTE]
  > `channel` is optional. Can be `"email"` or `"phone"`. If omitted and the user has both channels, it defaults to `"email"`.

- **Success Response (200 OK):**
  ```json
  {
    "message": "Password reset code sent",
    "via": "email"
  }
  ```

---

### Verify Reset Code & Reset Password (`POST /verify-forget-password`)
Validates the reset OTP and resets the password in a single request.

- **Request Body:**
  ```json
  {
    "code": "1234",
    "password": "newsecurepassword123"
  }
  ```

- **Success Response (200 OK):**
  ```json
  {
    "message": "Password reset successfully",
    "ok": true
  }
  ```

- **Error Response (400 Bad Request):**
  ```json
  {
    "message": "Password cannot be the same as your old password"
  }
  ```

---

## 4. Authenticated Actions
*All endpoints in this section require the header:*
`Authorization: Bearer <token>`

### Get Profile / Verify Me (`GET /verify-me`)
Retrieves the logged-in user profile details.

- **Success Response (200 OK):**
  ```json
  {
    "user": {
      "id": 12,
      "full_name": "John Doe",
      "email": "john.doe@example.com",
      "phone": "01012345678",
      "role": "Customer",
      "is_active": true
    }
  }
  ```

---

### Change Password (`POST /change-password`)
Changes the password for the current local account.

- **Request Body:**
  ```json
  {
    "old_password": "securepassword123",
    "new_password": "newsecurepassword123"
  }
  ```

- **Success Response (200 OK):**
  ```json
  {
    "message": "Password changed successfully",
    "ok": true
  }
  ```

---

### Change Phone or Email Request (`POST /change-phone-email`)
Sends an OTP to both the **old** and **new** contact values to verify ownership before applying the update.

- **Request Body:**
  ```json
  {
    "type": "email",
    "new_value": "new.email@example.com"
  }
  ```
  *OR*
  ```json
  {
    "type": "phone",
    "new_value": "01087654321"
  }
  ```

- **Success Response (200 OK):**
  ```json
  {
    "message": "Verification codes sent to both old and new contact info",
    "via_old": "email",
    "via_new": "email"
  }
  ```

---

### Verify Phone or Email Change (`POST /verify-old-new-phone-email`)
Verifies the OTPs sent to both the old and new contact values and applies the change.

- **Request Body:**
  ```json
  {
    "old_code": "1234",
    "new_code": "5678"
  }
  ```

- **Success Response (200 OK):**
  ```json
  {
    "message": "Phone/email updated successfully",
    "ok": true,
    "changed": "email"
  }
  ```

---

### Logout User (`POST /logout`)
Logs the user out and clears their FCM Token registration.

- **Success Response (200 OK):**
  ```json
  {
    "message": "Logout successful",
    "ok": true
  }
  ```
