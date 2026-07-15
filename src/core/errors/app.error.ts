import { HttpStatusCode } from "../http/http.status.code";

export class AppError extends Error {
  public statusCode: number;

  constructor(statusCode: number, message: string, options?: ErrorOptions) {
    super(message, options);
    this.statusCode = statusCode;
  }
}

export class NotFoundError extends AppError {
  constructor(resource = "Resource") {
    super(HttpStatusCode.NOT_FOUND, `${resource} not found`);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = "Unauthorized") {
    super(HttpStatusCode.UNAUTHORIZED, message);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = "Forbidden — insufficient permissions") {
    super(HttpStatusCode.FORBIDDEN, message);
  }
}

export class BadRequestError extends AppError {
  constructor(message = "Bad request") {
    super(HttpStatusCode.BAD_REQUEST, message);
  }
}

export class ConflictError extends AppError {
  constructor(message = "Resource already exists") {
    super(HttpStatusCode.CONFLICT, message);
  }
}
