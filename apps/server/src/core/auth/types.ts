export interface JwtPayload {
  sub: string;        // userId
  email: string;
  sessionId: string;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}
