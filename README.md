# Task Tracker Dashboard

This folder contains a static HTML dashboard for reviewing task volume by shop and task.

The dashboard is now set up for GitHub Pages hosting with Google Sheets as the daily data source.

## Files people should use

- `index.html` is the GitHub Pages entry point.
- `task-tracker-dashboard.html` is the same dashboard with the original filename.
- `google-sheets-config.js` is where the Google Sheets CSV URL goes.
- `task-tracker-data.json` is the fallback data file if the Google Sheet URL is blank or unavailable.
- `codex_task_tracker.csv` is the raw export used to refresh the fallback JSON.
- `refresh-task-tracker.ps1` rebuilds the fallback JSON from the CSV.
- `open-task-tracker.ps1` refreshes the dashboard and opens it in the default browser.
- `open-task-tracker.cmd` and `refresh-task-tracker.cmd` are double-click friendly launchers for Windows.
- `daily-update-dashboard.cmd` is the easiest daily updater. Drag the latest CSV onto it, or double-click it after replacing `codex_task_tracker.csv`.

`call-volume-dashboard.html` is the working source file. `task-traker-dashboard.html` is kept as a legacy copy for the older misspelled filename.

## Google Sheets setup

1. Create a Google Sheet with the same columns as `codex_task_tracker.csv`.
2. Paste or import the current CSV data into that sheet.
3. In Google Sheets, use **File > Share > Publish to web**.
4. Publish the sheet as CSV.
5. Copy the published CSV link.
6. Paste that link into `google-sheets-config.js`:

```javascript
window.TASK_TRACKER_GOOGLE_SHEET_CSV_URL = "https://docs.google.com/spreadsheets/d/e/.../pub?gid=0&single=true&output=csv";
```

Daily workflow after that: update the Google Sheet. The hosted dashboard fetches the current sheet data when someone opens or refreshes the page.

You can test a sheet link without editing the config file by opening the dashboard with a URL-encoded `sheetCsv` value:

```text
index.html?sheetCsv=https%3A%2F%2Fdocs.google.com%2Fspreadsheets%2Fd%2Fe%2F...%2Fpub%3Fgid%3D0%26single%3Dtrue%26output%3Dcsv
```

## GitHub Pages setup

1. Create a GitHub repository for this dashboard.
2. Upload at least these files:

```text
index.html
task-tracker-dashboard.html
google-sheets-config.js
task-tracker-data.json
.nojekyll
```

3. In the repository, go to **Settings > Pages**.
4. Set the source to deploy from the main branch root.
5. Share the GitHub Pages URL with coworkers.

## Open the dashboard locally

For GitHub Pages, use `index.html`. For older local workflows, run:

```powershell
.\open-task-tracker.ps1
```

For the simplest Windows launch, double-click:

```text
open-task-tracker.cmd
```

If PowerShell blocks scripts on this computer, use:

```powershell
powershell -ExecutionPolicy Bypass -File .\open-task-tracker.ps1
```

## Refresh the fallback JSON

This is only needed if you want `task-tracker-data.json` to match a local CSV export. The Google Sheet is the main daily data source.

Fallback refresh workflow:

1. Export the latest task tracker CSV.
2. Drag that CSV file onto `daily-update-dashboard.cmd`.
3. The script copies it to `codex_task_tracker.csv`, refreshes the dashboard, and opens `task-tracker-dashboard.html`.

Alternative workflow:

1. Replace `codex_task_tracker.csv` with the latest CSV export.
2. Double-click `daily-update-dashboard.cmd`.

PowerShell refresh command:

```powershell
.\refresh-task-tracker.ps1
```

For the simplest Windows refresh, double-click:

```text
refresh-task-tracker.cmd
```

If PowerShell blocks scripts on this computer, use:

```powershell
powershell -ExecutionPolicy Bypass -File .\refresh-task-tracker.ps1
```

The script updates:

- `call-volume-dashboard.html`
- `index.html`
- `task-tracker-dashboard.html`
- `task-traker-dashboard.html`
- `task-tracker-data.json`

## Preview the all-shop alert

To force the all-shop alert to appear for layout review, open:

```text
task-tracker-dashboard.html?previewAllShopAlert=1
```

Without that query string, the alert only appears when more than 75% of shops are down more than 15%.

## Sharing

For GitHub Pages, share the repository Pages URL. For a shared-drive fallback rollout, place these files in the shared folder:

- `index.html`
- `task-tracker-dashboard.html`
- `google-sheets-config.js`
- `task-tracker-data.json`
- `codex_task_tracker.csv`
- `refresh-task-tracker.ps1`
- `open-task-tracker.ps1`
- `refresh-task-tracker.cmd`
- `open-task-tracker.cmd`
- `daily-update-dashboard.cmd`

Users who only need to view the hosted dashboard only need the GitHub Pages link.
