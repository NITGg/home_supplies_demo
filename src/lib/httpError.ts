export class HttpError extends Error {
  status: number;
  code?: string;
  data?: any;

  constructor(status: number, message: string, code?: string, data?: any) {
    super(message);
    this.status = status;
    this.code = code;
    this.data = data;
  }
}
