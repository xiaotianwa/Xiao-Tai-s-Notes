export interface AuthUser {
  id: string;
  username: string;
  nickname: string;
  role: string;
  status: string;
}

export interface JwtPayload {
  sub: string;
  username: string;
  role: string;
}
