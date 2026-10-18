// Plasmo inlines PLASMO_PUBLIC_* variables at build time (.env.development / .env.production).
declare const process: { env: { PLASMO_PUBLIC_API_URL?: string } };
