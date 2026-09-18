param(
  [string]$CsvPath = ".\codex_task_tracker.csv",
  [string]$DataJsonPath = ".\task-tracker-data.json",
  [string]$TaskSwitchXlsxPath = ".\tasks_on_dashboard.xlsx",
  [string]$TaskSwitchDataJsPath = ".\tasks-on-dashboard-data.js"
)

$ErrorActionPreference = "Stop"

$ExcludedShops = @(
  "Redwood General Tire"
)

function Resolve-InputPath($Path) {
  return (Resolve-Path -Path $Path).Path
}

function Convert-TaskDate($DateText) {
  $trimmed = ([string]$DateText).Trim()
  $parsedDate = [datetime]::MinValue
  $numberStyle = [System.Globalization.NumberStyles]::Float
  $culture = [System.Globalization.CultureInfo]::InvariantCulture
  $serialDate = 0.0

  if ([datetime]::TryParse($trimmed, [ref]$parsedDate)) {
    return $parsedDate.Date
  }

  if ([double]::TryParse($trimmed, $numberStyle, $culture, [ref]$serialDate)) {
    return [datetime]::FromOADate($serialDate).Date
  }

  throw "Could not parse Date/Time Stamp value '$DateText'"
}

function Get-TaskRows($CsvPath) {
  Import-Csv -Path $CsvPath | ForEach-Object {
    $task = [string]$_."Task Association"
    $shop = [string]$_."Shop Name"
    $dateText = [string]$_."Date/Time Stamp"

    if (-not $task.Trim() -or -not $shop.Trim() -or -not $dateText.Trim()) {
      return
    }

    if ($ExcludedShops -contains $shop.Trim()) {
      return
    }

    [pscustomobject]@{
      Shop = $shop.Trim()
      Task = $task.Trim()
      Date = Convert-TaskDate $dateText
    }
  }
}

function Count-InWindow($Rows, [datetime]$StartDate, [datetime]$EndDate) {
  @($Rows | Where-Object { $_.Date -ge $StartDate -and $_.Date -le $EndDate }).Count
}

function Build-Payload($TaskRows) {
  $minDate = ($TaskRows | Measure-Object Date -Minimum).Minimum.Date
  $maxDate = ($TaskRows | Measure-Object Date -Maximum).Maximum.Date

  $weekWindows = @()
  $weekEnd = $maxDate
  while ($weekEnd -ge $minDate) {
    $weekStart = $weekEnd.AddDays(-6)
    if ($weekStart -lt $minDate) {
      $weekStart = $minDate
    }

    $weekWindows = ,([pscustomobject]@{
      Start = $weekStart
      End = $weekEnd
    }) + $weekWindows

    $weekEnd = $weekEnd.AddDays(-7)
  }

  $currentWindow = $weekWindows[-1]
  $previousWindow = if ($weekWindows.Count -ge 2) { $weekWindows[-2] } else { $null }
  $previousFourWindows = @()
  if ($weekWindows.Count -gt 1) {
    $firstPreviousIndex = [math]::Max(0, $weekWindows.Count - 5)
    $lastPreviousIndex = $weekWindows.Count - 2
    for ($i = $firstPreviousIndex; $i -le $lastPreviousIndex; $i++) {
      $previousFourWindows += $weekWindows[$i]
    }
  }

  $rows = foreach ($group in ($TaskRows | Group-Object Shop, Task)) {
    $first = $group.Group[0]
    $current = Count-InWindow $group.Group $currentWindow.Start $currentWindow.End
    $previous = if ($previousWindow) {
      Count-InWindow $group.Group $previousWindow.Start $previousWindow.End
    } else {
      0
    }
    $previousCounts = foreach ($window in $previousFourWindows) {
      Count-InWindow $group.Group $window.Start $window.End
    }
    $avg = if ($previousCounts.Count) { ($previousCounts | Measure-Object -Average).Average } else { 0 }
    $lastDate = ($group.Group | Measure-Object Date -Maximum).Maximum.Date
    $weekly = foreach ($window in $weekWindows) {
      [pscustomobject]@{
        label = $window.End.ToString("MMM d")
        startDate = $window.Start.ToString("yyyy-MM-dd")
        endDate = $window.End.ToString("yyyy-MM-dd")
        calls = Count-InWindow $group.Group $window.Start $window.End
      }
    }

    [pscustomobject]@{
      store = $first.Shop
      task = $first.Task
      current = $current
      previous = $previous
      previousFourWeekAvg = [math]::Round($avg, 2)
      daysSinceCall = ($maxDate - $lastDate).Days
      weekly = $weekly
    }
  }

  [pscustomobject]@{
    fromDate = $minDate.ToString("yyyy-MM-dd")
    asOfDate = $maxDate.ToString("yyyy-MM-dd")
    refreshedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    windowLabel = "Current CSV dates: $($minDate.ToString("MMM d, yyyy")) through $($maxDate.ToString("MMM d, yyyy"))"
    rows = @($rows)
  }
}

$csv = Resolve-InputPath $CsvPath

Write-Host "Reading CSV: $csv"
$taskRows = @(Get-TaskRows $csv)
if (-not $taskRows.Count) {
  throw "No task rows found in $csv"
}

Write-Host "Aggregating $($taskRows.Count) task rows..."
$payload = Build-Payload $taskRows
$payloadJson = $payload | ConvertTo-Json -Depth 8

Set-Content -Path $DataJsonPath -Value $payloadJson -Encoding UTF8

Write-Host "Updated data through $($payload.asOfDate)."
Write-Host "Shop-task rows: $($payload.rows.Count)"
Write-Host "Wrote: $DataJsonPath"

if (Test-Path -Path $TaskSwitchXlsxPath) {
  & "$PSScriptRoot\refresh-tasks-on-dashboard.ps1" -XlsxPath $TaskSwitchXlsxPath -DataJsPath $TaskSwitchDataJsPath
}
