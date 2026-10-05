$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$rawDir = Join-Path $root "data\raw"
$outFile = Join-Path $root "data\venues.json"

$weekOrder = @("Sun","Mon","Tue","Wed","Thu","Fri","Sat")

# ---------- region / city map ----------
$cityRegion = @{
  "Crossroads"              = "Downtown & Midtown KC"
  "River Market"             = "Downtown & Midtown KC"
  "Power & Light District"   = "Downtown & Midtown KC"
  "Westport"                 = "Downtown & Midtown KC"
  "Midtown"                  = "Downtown & Midtown KC"
  "Country Club Plaza"       = "Downtown & Midtown KC"
  "Brookside"                = "Downtown & Midtown KC"
  "Waldo"                    = "Downtown & Midtown KC"
  "West Bottoms"             = "Downtown & Midtown KC"
  "Columbus Park"            = "Downtown & Midtown KC"
  "18th & Vine"              = "Downtown & Midtown KC"
  "Union Hill"               = "Downtown & Midtown KC"
  "Northeast KC"             = "Downtown & Midtown KC"
  "Village West"             = "Wyandotte County & Border"
  "Downtown KCK"             = "Wyandotte County & Border"
  "Argentine"                = "Wyandotte County & Border"
  "Strawberry Hill"          = "Wyandotte County & Border"
  "Westwood"                 = "Wyandotte County & Border"
  "Roeland Park"             = "Wyandotte County & Border"
  "North Kansas City"        = "Northland"
  "Zona Rosa"                = "Northland"
  "Gladstone"                = "Northland"
  "Liberty"                  = "Northland"
  "Parkville"                = "Northland"
  "Overland Park"            = "Overland Park & Leawood"
  "Leawood"                  = "Overland Park & Leawood"
  "Prairie Village"          = "Overland Park & Leawood"
  "Mission"                  = "Overland Park & Leawood"
  "Lenexa"                   = "Southern & Eastern Suburbs"
  "Olathe"                   = "Southern & Eastern Suburbs"
  "Shawnee"                  = "Southern & Eastern Suburbs"
  "Merriam"                  = "Southern & Eastern Suburbs"
  "Gardner"                  = "Southern & Eastern Suburbs"
  "Lee's Summit"             = "Southern & Eastern Suburbs"
  "Blue Springs"             = "Southern & Eastern Suburbs"
  "Independence"             = "Southern & Eastern Suburbs"
  "Raytown"                  = "Southern & Eastern Suburbs"
  "Grandview"                = "Southern & Eastern Suburbs"
  "Martin City"              = "Southern & Eastern Suburbs"
  "South Kansas City"        = "Southern & Eastern Suburbs"
}

function Get-Region($city) {
  if ($cityRegion.ContainsKey($city)) { return $cityRegion[$city] }
  return "Southern & Eastern Suburbs"
}

# ---------- cuisine normalization ----------
function Normalize-Cuisine($raw) {
  $s = $raw.ToLower()
  if ($s -match "japanese|sushi") { return "Sushi & Japanese" }
  if ($s -match "thai") { return "Thai" }
  if ($s -match "mexican|tex-mex") { return "Mexican" }
  if ($s -match "pizza") { return "Pizza" }
  if ($s -match "italian") { return "Italian" }
  if ($s -match "steak" -and $s -match "seafood|oyster") { return "Steakhouse & Seafood" }
  if ($s -match "bbq") { return "BBQ" }
  if ($s -match "steak") { return "Steakhouse" }
  if ($s -match "seafood|oyster") { return "Seafood" }
  if ($s -match "mediterranean|tapas") { return "Mediterranean" }
  if ($s -match "french") { return "French" }
  if ($s -match "southern") { return "Southern" }
  if ($s -match "austrian|german|european") { return "European" }
  if ($s -match "wine bar|wine dive|winery") { return "Wine Bar" }
  if ($s -match "distill") { return "Distillery" }
  if ($s -match "brewery") { return "Brewery" }
  if ($s -match "cocktail") { return "Cocktail Bar" }
  if ($s -match "sports bar") { return "Sports Bar" }
  if ($s -match "dive bar") { return "Dive Bar" }
  if ($s -match "gastropub|pub|tavern") { return "Gastropub" }
  if ($s -match "asian|taiwanese|ramen") { return "Asian Fusion" }
  return "American"
}

# ---------- day parsing ----------
function Expand-Days($raw) {
  if ($raw -match "(?i)daily|other days|all week") { return $weekOrder }
  $clean = $raw -replace '\([^)]*\)', ''
  $pattern = '(?i)\b(Sun|Mon|Tue|Wed|Thu|Fri|Sat)[a-z]*\b(\s*-\s*\b(Sun|Mon|Tue|Wed|Thu|Fri|Sat)[a-z]*\b)?'
  $matches = [regex]::Matches($clean, $pattern)
  $set = New-Object System.Collections.Generic.List[string]
  foreach ($m in $matches) {
    $start = $m.Groups[1].Value.Substring(0,3)
    $start = (Get-Culture).TextInfo.ToTitleCase($start.ToLower())
    $startIdx = [array]::IndexOf($weekOrder, $start)
    if ($m.Groups[3].Success) {
      $end = $m.Groups[3].Value.Substring(0,3)
      $end = (Get-Culture).TextInfo.ToTitleCase($end.ToLower())
      $endIdx = [array]::IndexOf($weekOrder, $end)
      if ($endIdx -ge $startIdx) {
        for ($i = $startIdx; $i -le $endIdx; $i++) { if (-not $set.Contains($weekOrder[$i])) { $set.Add($weekOrder[$i]) } }
      } else {
        for ($i = $startIdx; $i -le 6; $i++) { if (-not $set.Contains($weekOrder[$i])) { $set.Add($weekOrder[$i]) } }
        for ($i = 0; $i -le $endIdx; $i++) { if (-not $set.Contains($weekOrder[$i])) { $set.Add($weekOrder[$i]) } }
      }
    } else {
      if (-not $set.Contains($start)) { $set.Add($start) }
    }
  }
  if ($set.Count -eq 0) { return @("Mon","Tue","Wed","Thu","Fri") }
  # return in week order
  return $weekOrder | Where-Object { $set.Contains($_) }
}

# ---------- hour parsing ----------
function Convert-To24($hourStr, $minStr, $meridiem) {
  $h = [int]$hourStr
  $m = 0
  if ($minStr) { $m = [int]$minStr }
  if ($meridiem -eq "pm" -and $h -ne 12) { $h += 12 }
  if ($meridiem -eq "am" -and $h -eq 12) { $h = 0 }
  return $h + ($m / 60.0)
}

function Parse-Hours($raw) {
  $rangePattern = '(?i)(\d{1,2})(:(\d{2}))?\s*(am|pm)?\s*-\s*(\d{1,2})(:(\d{2}))?\s*(am|pm)'
  $m = [regex]::Match($raw, $rangePattern)
  if ($m.Success) {
    $endMeridiem = $m.Groups[8].Value.ToLower()
    $startMeridiem = $m.Groups[4].Value.ToLower()
    if (-not $startMeridiem) { $startMeridiem = $endMeridiem }
    $start = Convert-To24 $m.Groups[1].Value $m.Groups[3].Value $startMeridiem
    $end = Convert-To24 $m.Groups[5].Value $m.Groups[7].Value $endMeridiem
    return @{ start = $start; end = $end }
  }
  if ($raw -match "(?i)all day") {
    return @{ start = 0; end = 23.99 }
  }
  $untilPattern = '(?i)(?:to|until)\s*(\d{1,2})(:(\d{2}))?\s*(am|pm)'
  $m2 = [regex]::Match($raw, $untilPattern)
  if ($m2.Success) {
    $end = Convert-To24 $m2.Groups[1].Value $m2.Groups[3].Value $m2.Groups[4].Value.ToLower()
    return @{ start = 15; end = $end }
  }
  return @{ start = 15; end = 18 }
}

function Format-HoursDisplay($raw) {
  $d = $raw -replace '(?i)(\d)(am|pm)', '$1 $2'
  $d = [regex]::Replace($d, '(?i)\bam\b', 'AM')
  $d = [regex]::Replace($d, '(?i)\bpm\b', 'PM')
  return $d.Trim()
}

function Split-Deals($raw) {
  if (-not $raw) { return @() }
  $parts = $raw -split ';\s*' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
  return @($parts)
}

# ---------- manual JSON emission (ConvertTo-Json collapses 1-element arrays) ----------
function Json-Escape($s) {
  if ($null -eq $s) { return "" }
  $s = $s -replace '\\', '\\\\'
  $s = $s -replace '"', '\"'
  $s = $s -replace "`r`n", '\n'
  $s = $s -replace "`n", '\n'
  $s = $s -replace "`t", '\t'
  return $s
}
function Json-StrArray($arr) {
  $escaped = @($arr) | ForEach-Object { '"' + (Json-Escape $_) + '"' }
  return "[" + ($escaped -join ",") + "]"
}

# ---------- main ----------
$id = 1
$lines = New-Object System.Collections.Generic.List[string]

$rawFiles = Get-ChildItem -Path $rawDir -Filter "*.json"
foreach ($file in $rawFiles) {
  Write-Host "Processing $($file.Name)..."
  $items = Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($it in $items) {
    $city = $it.neighborhood
    $region = Get-Region $city
    $cuisine = Normalize-Cuisine $it.cuisine
    $days = @(Expand-Days $it.days)
    $hoursParsed = Parse-Hours $it.hours
    $hoursDisplay = Format-HoursDisplay $it.hours
    $deals = @(Split-Deals $it.deals)
    $start = [math]::Round($hoursParsed.start, 2)
    $end = [math]::Round($hoursParsed.end, 2)

    $obj = "    {`n" +
      "        `"id`": `"v$id`",`n" +
      "        `"name`": `"$(Json-Escape $it.name)`",`n" +
      "        `"address`": `"$(Json-Escape $it.address)`",`n" +
      "        `"city`": `"$(Json-Escape $city)`",`n" +
      "        `"region`": `"$(Json-Escape $region)`",`n" +
      "        `"cuisine`": `"$(Json-Escape $cuisine)`",`n" +
      "        `"days`": $(Json-StrArray $days),`n" +
      "        `"startHour`": $start,`n" +
      "        `"endHour`": $end,`n" +
      "        `"hoursDisplay`": `"$(Json-Escape $hoursDisplay)`",`n" +
      "        `"deals`": $(Json-StrArray $deals),`n" +
      "        `"source`": `"$(Json-Escape $it.source)`"`n" +
      "    }"
    $lines.Add($obj)
    $id++
  }
}

Write-Host "Total venues: $($lines.Count)"
$json = "[`n" + ($lines -join ",`n") + "`n]`n"
[System.IO.File]::WriteAllText($outFile, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Wrote $outFile"
