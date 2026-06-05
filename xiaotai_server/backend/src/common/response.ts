export interface ApiResponse<T> {
  code: number;
  data: T;
  message: string;
}

export interface ApiErrorDetail {
  field?: string;
  reason: string;
}

export interface ApiErrorResponse {
  code: number;
  data: null;
  message: string;
  details?: ApiErrorDetail[];
  requestId?: string;
}
