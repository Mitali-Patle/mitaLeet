# mitaLeet

A realtime competitive coding operating system for private coding squads.

## Architecture

```
mitaleet/
├── apps/
│   ├── mobile/        Flutter (Android + iOS)
│   ├── server/        NestJS + PostgreSQL
│   └── extension/     Plasmo browser extension
└── packages/
    └── shared/        Shared TypeScript types
```

## Tech Stack

| Layer       | Technology                         |
|-------------|------------------------------------|
| Mobile      | Flutter + Dart + Riverpod          |
| Backend     | NestJS + TypeScript                |
| Database    | PostgreSQL + Prisma ORM            |
| Realtime    | Socket.IO                          |
| Auth        | Google OAuth + JWT                 |
| Push        | Firebase Cloud Messaging           |
| Extension   | Plasmo (Chromium)                  |

## Getting Started

### Prerequisites

- Flutter SDK >= 3.22
- Node.js >= 20
- PostgreSQL >= 16
- Docker (optional)

### Mobile App

```bash
cd apps/mobile
flutter pub get
flutter run
```

### Backend

```bash
cd apps/server
npm install
npx prisma generate
npx prisma migrate dev
npm run start:dev
```

### Browser Extension

```bash
cd apps/extension
npm install
npm run dev
```

## Design Language

Cyber-industrial aesthetic with matte black surfaces, metallic accents,
and developer-native typography (JetBrains Mono).
