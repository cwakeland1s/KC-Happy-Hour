$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$venuesFile = Join-Path $root "data\venues.json"
$outDir = Join-Path $root "happy-hour"
$siteUrl = "https://kchappyhour.com"
$today = (Get-Date).ToString("yyyy-MM-dd")

if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
New-Item -ItemType Directory -Path $outDir | Out-Null

function HtmlEscape($s) {
  if ($null -eq $s) { return "" }
  $s = $s -replace '&', '&amp;'
  $s = $s -replace '<', '&lt;'
  $s = $s -replace '>', '&gt;'
  $s = $s -replace '"', '&quot;'
  return $s
}

function FormatDaysText($days) {
  $arr = @($days)
  if ($arr.Count -eq 7) { return "Every day" }
  $weekdays = @("Mon","Tue","Wed","Thu","Fri")
  $isWeekday = $arr.Count -eq 5
  foreach ($d in $weekdays) { if (-not ($arr -contains $d)) { $isWeekday = $false } }
  if ($isWeekday) { return "Monday through Friday" }
  return ($arr -join ", ")
}

$venues = Get-Content $venuesFile -Raw -Encoding UTF8 | ConvertFrom-Json
$sitemapUrls = New-Object System.Collections.Generic.List[string]
$sitemapUrls.Add("  <url><loc>$siteUrl/</loc><lastmod>$today</lastmod><changefreq>daily</changefreq><priority>1.0</priority></url>")

foreach ($v in $venues) {
  $pageDir = Join-Path $outDir $v.slug
  New-Item -ItemType Directory -Path $pageDir -Force | Out-Null

  $title = "Happy Hour at $($v.name) — $($v.city), KC Metro"
  $daysText = FormatDaysText $v.days
  $topDeal = if ($v.deals.Count -gt 0) { $v.deals[0] } else { "Ask your server for current specials" }
  $description = "$($v.name) in $($v.city) runs happy hour $daysText, $($v.hoursDisplay). $topDeal"
  if ($description.Length -gt 300) { $description = $description.Substring(0, 297) + "..." }

  $dealsHtml = ""
  foreach ($d in $v.deals) {
    $dealsHtml += "          <li>$(HtmlEscape $d)</li>`n"
  }
  if ($v.deals.Count -eq 0) {
    $dealsHtml = "          <li>Ask your server for current happy hour specials.</li>`n"
  }

  $pageUrl = "$siteUrl/happy-hour/$($v.slug)/"
  $jsonLd = @"
{
  "@context": "https://schema.org",
  "@type": "Restaurant",
  "name": "$($v.name -replace '"', '\"')",
  "servesCuisine": "$($v.cuisine -replace '"', '\"')",
  "address": {
    "@type": "PostalAddress",
    "streetAddress": "$($v.address -replace '"', '\"')"
  },
  "url": "$pageUrl"
}
"@

  $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$(HtmlEscape $title)</title>
<meta name="description" content="$(HtmlEscape $description)">
<link rel="canonical" href="$pageUrl">
<meta property="og:title" content="$(HtmlEscape $title)">
<meta property="og:description" content="$(HtmlEscape $description)">
<meta property="og:type" content="website">
<meta property="og:url" content="$pageUrl">
<link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🍹</text></svg>">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,400;0,9..144,600;0,9..144,700;1,9..144,500&family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/css/styles.css">
<script type="application/ld+json">
$jsonLd
</script>
</head>
<body>

<header class="site-header">
  <div class="header-inner">
    <a class="brand" href="/">
      <span class="brand-mark">🍹</span>
      <span class="brand-text">KC Happy Hour</span>
    </a>
  </div>
</header>

<main>
  <section class="results-section">
    <div class="results-inner" style="max-width: 720px;">

      <p style="margin-bottom: 18px;"><a href="/" style="color: var(--accent-strong); font-weight: 600; font-size: 14px;">&larr; All Kansas City happy hours</a></p>

      <article class="card" style="cursor: default;">
        <div class="card-top">
          <h1 class="card-name" style="font-size: 28px;">$(HtmlEscape $v.name)</h1>
        </div>
        <div class="card-tags">
          <span class="tag tag-city">$(HtmlEscape $v.city)</span>
          <span class="tag tag-cuisine">$(HtmlEscape $v.cuisine)</span>
        </div>

        <div class="detail-section">
          <div class="detail-label">Happy hour</div>
          <div class="detail-value">$(HtmlEscape $daysText) &middot; $(HtmlEscape $v.hoursDisplay)</div>
        </div>

        <div class="detail-section">
          <div class="detail-label">Deals</div>
          <ul class="detail-deals-list">
$dealsHtml          </ul>
        </div>

        <div class="detail-section">
          <div class="detail-label">Address</div>
          <div class="detail-value">$(HtmlEscape $v.address)</div>
        </div>

        $(if ($v.source) { "<a class=`"detail-source`" href=`"$(HtmlEscape $v.source)`" target=`"_blank`" rel=`"noopener noreferrer`">View source &rarr;</a>" })
      </article>

      <p style="margin-top: 28px; font-size: 13.5px; color: var(--text-faint);">Hours and deals change often — call ahead to confirm before you go. Part of <a href="/" style="color: var(--accent-strong); font-weight: 600;">KC Happy Hour</a>, a guide to happy hours across the Kansas City metro.</p>

    </div>
  </section>
</main>

<footer class="site-footer">
  <div class="footer-inner">
    <div class="footer-brand"><span class="brand-mark">🍹</span> KC Happy Hour</div>
    <p class="footer-note">Compiled from publicly listed restaurant &amp; bar specials across the Kansas City metro.</p>
  </div>
</footer>

</body>
</html>
"@

  [System.IO.File]::WriteAllText((Join-Path $pageDir "index.html"), $html, (New-Object System.Text.UTF8Encoding($false)))
  $sitemapUrls.Add("  <url><loc>$pageUrl</loc><lastmod>$today</lastmod><changefreq>weekly</changefreq><priority>0.7</priority></url>")
}

$sitemap = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<urlset xmlns=`"http://www.sitemaps.org/schemas/sitemap/0.9`">`n" + ($sitemapUrls -join "`n") + "`n</urlset>`n"
[System.IO.File]::WriteAllText((Join-Path $root "sitemap.xml"), $sitemap, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Generated $($venues.Count) venue pages in /happy-hour/ and sitemap.xml with $($sitemapUrls.Count) URLs."
