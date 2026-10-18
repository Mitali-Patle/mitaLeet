export interface JwtPayload {
  sub: string;        // userId
  email: string;
  sessionId: string;
  /** Set on browser-extension tokens, which may only call extension routes. */
  scope?: 'extension';
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}
