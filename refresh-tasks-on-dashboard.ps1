param(
  [string]$XlsxPath = ".\tasks_on_dashboard.xlsx",
  [string]$DataJsPath = ".\tasks-on-dashboard-data.js"
)

$ErrorActionPreference = "Stop"

function Resolve-InputPath($Path) {
  return (Resolve-Path -Path $Path).Path
}

function Get-CellColumn($CellReference) {
  return ([regex]::Match([string]$CellReference, "^[A-Z]+")).Value
}

function Get-SharedStrings($Zip) {
  $entry = $Zip.GetEntry("xl/sharedStrings.xml")
  if (-not $entry) {
    return @()
  }

  $reader = New-Object IO.StreamReader($entry.Open())
  try {
    [xml]$xml = $reader.ReadToEnd()
  } finally {
    $reader.Dispose()
  }

  return @($xml.sst.si | ForEach-Object {
    if ($_.t) {
      [string]$_.t
    } else {
      ($_.r | ForEach-Object { $_.t }) -join ""
    }
  })
}

function Get-CellValue($Cell, $SharedStrings) {
  $value = [string]$Cell.v
  if ($Cell.t -eq "s" -and $value -ne "") {
    return $SharedStrings[[int]$value]
  }
  return $value
}

$xlsx = Resolve-InputPath $XlsxPath
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($xlsx)

try {
  $sheetEntry = $zip.GetEntry("xl/worksheets/sheet1.xml")
  if (-not $sheetEntry) {
    throw "Could not find xl/worksheets/sheet1.xml in $xlsx"
  }

  $sharedStrings = Get-SharedStrings $zip
  $reader = New-Object IO.StreamReader($sheetEntry.Open())
  try {
    [xml]$sheetXml = $reader.ReadToEnd()
  } finally {
    $reader.Dispose()
  }

  $rows = @($sheetXml.worksheet.sheetData.row)
  if ($rows.Count -lt 2) {
    throw "Expected a header row and at least one shop row in $xlsx"
  }

  $headerCells = @{}
  foreach ($cell in $rows[0].c) {
    $headerCells[(Get-CellColumn $cell.r)] = Get-CellValue $cell $sharedStrings
  }

  $taskColumns = @($headerCells.GetEnumerator() |
    Where-Object { $_.Key -ne "A" -and ([string]$_.Value).Trim() } |
    Sort-Object Key |
    ForEach-Object {
      [pscustomobject]@{
        Column = $_.Key
        Task = ([string]$_.Value).Trim()
      }
    })

  $shops = @()
  foreach ($row in ($rows | Select-Object -Skip 1)) {
    $cells = @{}
    foreach ($cell in $row.c) {
      $cells[(Get-CellColumn $cell.r)] = Get-CellValue $cell $sharedStrings
    }

    $shop = ([string]$cells["A"]).Trim()
    if (-not $shop) {
      continue
    }

    $tasks = [ordered]@{}
    foreach ($taskColumn in $taskColumns) {
      $tasks[$taskColumn.Task] = if (([string]$cells[$taskColumn.Column]).Trim() -eq "1") { 1 } else { 0 }
    }

    $shops += [pscustomobject]@{
      shop = $shop
      tasks = $tasks
    }
  }

  $payload = [pscustomobject]@{
    source = Split-Path -Leaf $xlsx
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    tasks = @($taskColumns | ForEach-Object { $_.Task })
    shops = $shops
  }

  $json = $payload | ConvertTo-Json -Depth 8
  Set-Content -Path $DataJsPath -Value "window.TASKS_ON_DASHBOARD_DATA = $json;" -Encoding UTF8

  Write-Host "Updated task switch data from $xlsx."
  Write-Host "Shops: $($shops.Count)"
  Write-Host "Tasks: $($taskColumns.Count)"
  Write-Host "Wrote: $DataJsPath"
} finally {
  $zip.Dispose()
}
