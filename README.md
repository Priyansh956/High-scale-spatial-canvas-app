# Visualli — High-Scale Spatial Canvas App

A full-stack spatial canvas app supporting 10,000 objects on a 20,000×20,000
plane, with viewport-based data fetching, pan/zoom, tap-to-select, and
optimistic drag-to-move backed by real persistence.

- **Backend:** Node.js, Express, MongoDB (Atlas) with a `2d` spatial index
- **Frontend:** Flutter, `CustomPainter`-based canvas rendering
- **Infra:** Docker Compose (local dev), Render (backend hosting), GitHub Actions CI

**Live backend:** https://high-scale-spatial-canvas-app.onrender.com/api/health
*(free-tier instance — first request after inactivity may take up to a minute to wake up)*

## Features

- Pan and pinch-zoom across a 20,000×20,000 world-space plane
- Backend returns only the objects inside the current viewport (+ buffer),
  never the full 10k-object dataset in one response
- Debounced (250ms) viewport refetching as the user navigates, with
  stale-response protection via a fetch-generation counter
- Client-side quadtree for hit-testing and viewport-culled rendering
- Shape-aware tap-to-select with a visual highlight ring
- Optimistic drag-to-move: position updates instantly on-screen, persists
  via `PATCH` on release, and rolls back automatically if the request fails

## Project structure

```
visuallai/
├── .github/workflows/       # CI: flutter.yaml, node.yaml
├── backend/
│   ├── src/
│   │   ├── config/db.js             # Mongo connection
│   │   ├── models/SpatialObject.js  # schema + 2d index
│   │   ├── controllers/objectsController.js
│   │   ├── routes/objects.js
│   │   └── scripts/seed.js          # generates 10,000 objects
│   ├── index.js
│   ├── Dockerfile
│   └── package.json
├── frontend/spatial_canvas_app/
│   └── lib/
│       ├── main.dart
│       ├── models/spatial_object.dart
│       ├── services/api_service.dart
│       ├── canvas/
│       │   ├── canvas_painter.dart
│       │   ├── quad_tree.dart
│       │   └── viewport_controller.dart
│       └── screens/canvas_screen.dart
├── docker-compose.yml
├── README.md
└── ARCHITECTURE.md
```
## Architecture

See [`ARCHITECTURE.md`](./ARCHITECTURE.md) for the design write-up covering
backend filtering strategy, frontend rendering/network strategy, and
trade-offs encountered during the build.

## Prerequisites

- [Docker](https://www.docker.com/) + Docker Compose (for local backend)
- [Flutter SDK](https://flutter.dev/)
- Node.js 20+ (only needed to run the backend outside Docker)
- A MongoDB Atlas cluster (or local MongoDB) if you want to seed your own data

## Running the backend locally

```bash
docker compose up --build
```

This starts:
- **MongoDB** on `localhost:27017`
- **API server** on `http://localhost:4000`

Seed the database (10,000 objects):
```bash
docker exec -it visualli-api npm run seed
```

Verify:
```bash
curl http://localhost:4000/api/health
curl "http://localhost:4000/api/objects?minX=-1000&minY=-1000&maxX=1000&maxY=1000"
```

To stop:
```bash
docker compose down       # keeps data
docker compose down -v    # also wipes the Mongo volume
```

### Running the backend without Docker

```bash
cd backend
cp .env.example .env   # then set MONGO_URI to your local or Atlas connection string
npm install
npm run dev
npm run seed            # one-time, populates 10,000 objects
```

## Running the frontend (Flutter)

```bash
cd frontend/spatial_canvas_app
cp .env.example .env
```

Edit `.env` and set `API_BASE_URL` to wherever your backend is running:
- Local backend, Android emulator: `http://10.0.2.2:4000`
- Local backend, physical device: `http://<your-LAN-IP>:4000` (device and computer must be on the same network)
- Deployed backend: `https://high-scale-spatial-canvas-app.onrender.com`

Then:
```bash
flutter pub get
flutter run -d android   # or -d windows / -d chrome / -d ios
```

> **Note:** `.env` is gitignored — each environment (local Docker, physical
> device, deployed backend) needs its own value. `.env.example` documents the
> expected variable.

## Testing

```bash
# Backend
cd backend && npm test   # (if/when backend tests are added)

# Frontend
cd frontend/spatial_canvas_app
flutter analyze
flutter test
```

CI runs both `node.yaml` and `flutter.yaml` workflows on pull requests to `main`.

## Deployment

- **Backend:** Deployed on [Render](https://render.com) as a Docker web
  service, using the same `Dockerfile` as local development. Database is
  hosted on MongoDB Atlas.
- **Frontend:** Not deployed as a hosted app — run locally via `flutter run`,
  or build a release APK:
  ```bash
  flutter build apk --release
  ```

## Known limitations

- Render's free tier spins down after ~15 minutes of inactivity; the first
  request afterward can take up to a minute.
- Hover (as opposed to tap-to-select) is not implemented, since this is a
  touch-first app without a pointer device on mobile — see `ARCHITECTURE.md`
  for the reasoning.
