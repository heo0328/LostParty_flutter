# Drift web runtime assets

Purpose: record vendored runtime provenance for the existing Drift databases. This is not a browser acceptance report.

- Drift: 2.34.3; drift_flutter: 0.3.1; sqlite3 Dart package: 3.5.1 (pubspec.lock unchanged).
- Official release: https://github.com/simolus3/drift/releases/tag/drift-2.34.3
- Setup: https://drift.simonbinder.eu/platforms/web/
- Retrieved 2026-11-11; each local SHA-256 matched the GitHub release asset digest.

| File | Official download | SHA-256 |
|---|---|---|
| drift_worker.js | https://github.com/simolus3/drift/releases/download/drift-2.34.3/drift_worker.js | 4db0469de8ceabad8d5cd3d920614486ba587e100e39523f36f704a3aec5f26c |
| sqlite3.wasm | https://github.com/simolus3/drift/releases/download/drift-2.34.3/sqlite3.wasm | 41cf968998241465d8b1dfffb1eb60dd10c35de5022a3647e14174ea3af84143 |

Keep both assets aligned with the locked Drift release. Serve WASM as application/wasm. Native DB names, schema and injected executors are unchanged. Browser storage is separate from Android and scoped to the browser profile and site origin. In-memory fallback is rejected; successful opening still requires a refresh/relaunch persistence check.

Local Chrome test (normal window, one tab):

```powershell
flutter run -d chrome --web-hostname localhost --web-port 3000 --dart-define=BACKEND_BASE_URL=http://localhost:8000
```

Use http://localhost:3000 consistently. Start the dev Backend on port 8000 for public reads. No COOP/COEP headers are required for this initial desktop trial; record the selected storage mode from the debug console. Do not disable browser security to bypass CORS.

User checks: first screen/four tabs/settings; guest key save and restore without exposing its value; guest roster lookup and card restore after refresh/browser relaunch; public recruitment query. Distinguish Backend CORS from direct Lost Ark API CORS, storage failure and response parsing. Google web login is now wired to the official GIS button under Issue49; actual Google/Backend/member-read acceptance is pending. Android still uses its existing MethodChannel. Mobile/multiple tabs/private mode, production hosting and member flows are not accepted by these build checks.
