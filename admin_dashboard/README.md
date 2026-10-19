# CaRide Admin Dashboard

React (TypeScript) web console for platform operations. Mobile rider/driver apps remain Flutter; this app is **web-only** (Vite + React).

## Scripts

```bash
npm install
npm run dev      # local dev server
npm run build    # production bundle to dist/
npm run preview  # serve production build locally
```

## Design

Styles use CSS variables aligned with the Flutter `design_system` package (primary green `#16A34A`, spacing scale, light/dark via `[data-theme="dark"]` on `<html>`). Use the **Theme** control in the sidebar to toggle.

## Routes

| Path        | Screen                          |
| ----------- | -------------------------------- |
| `/login`    | Mock sign-in                     |
| `/dashboard`| Overview / KPI cards             |
| `/users`    | User list & flags                |
| `/rides`    | Ride monitoring                  |
| `/finance`  | Commission & wallet (mock)       |
| `/fraud`    | Fraud queue                      |

Authentication is in-memory (mock). Replace `AuthContext` with your backend when integrating.
