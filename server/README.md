# whenrufree-server (optional)

The Flutter app is **local-first** and works fully without this server.
This Express service exists for the roadmap:

1. **Shared overlap API** — `POST /api/overlap` mirrors the in-app
   `AvailabilityService` in JS for any client that prefers REST.
2. **Graph token swap (reference stub)** — `POST /api/graph/refresh`
   sketches the server-side swap. NOTE: the app now uses direct OAuth PKCE
   (public client, no secret exists anywhere), so this endpoint is not
   needed for Microsoft 365 sync — it's kept as a reference for a future
   confidential-client setup.

## Run

```bash
cd server
npm install
npm start        # :3000
```

## API

- `GET /health` → `{ ok: true }`
- `POST /api/overlap` → ranked mutual free slots (see `src/index.js` for schema)
- `POST /api/graph/refresh` → `501` until Graph credentials are configured
