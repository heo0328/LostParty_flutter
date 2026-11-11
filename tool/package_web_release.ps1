[CmdletBinding()]
param([switch]$AllowDirty)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$utf8 = New-Object System.Text.UTF8Encoding($false)
. (Join-Path $PSScriptRoot 'web_bundle.ps1')
Push-Location $projectRoot
try {
    $versionLine = Get-Content -Encoding UTF8 pubspec.yaml | Where-Object { $_ -match '^version:' }
    if ($versionLine -notmatch '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$') {
        throw 'Invalid pubspec version.'
    }
    $version = $Matches[1]
    $buildNumber = $Matches[2]
    $source = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot identify Git source.' }
    $dirty = @(& git status --porcelain=v1 --untracked-files=all)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect Git state.' }
    if ($dirty.Count -gt 0 -and !$AllowDirty) {
        Write-Output 'Release source differs from its commit (paths only):'
        $dirty | Write-Output
        & git diff --stat
        throw 'Commit the complete release source first. -AllowDirty creates a review candidate only.'
    }
    $api = 'https://lostparty.duckdns.org'
    & flutter build web --release --no-source-maps --no-web-resources-cdn --no-wasm-dry-run "--dart-define=BACKEND_BASE_URL=$api"
    if ($LASTEXITCODE -ne 0) { throw 'Release web build failed.' }

    # Fail closed on changes during the build; never label an unrelated tree clean.
    $after = @(& git status --porcelain=v1 --untracked-files=all)
    if ((& git rev-parse HEAD).Trim() -ne $source -or ($dirty -join "`n") -ne ($after -join "`n")) {
        throw 'Git state changed during the build. Review and build again.'
    }
    $bootstrap = Get-Content -Raw -Encoding UTF8 build/web/flutter_bootstrap.js
    if ($bootstrap -match 'serviceWorkerVersion\s*:\s*["''][^"'']+["'']') {
        throw 'A service worker is registered. Review update behaviour before packaging.'
    }
    $id = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
    $label = if ($dirty.Count) { 'candidate' } else { 'release' }
    $destination = Join-Path $projectRoot "build/web-releases/$version-$buildNumber-$label-$id"
    $bundleRoot = Join-Path $destination 'bundle'
    $site = Join-Path $bundleRoot 'site'
    New-Item -ItemType Directory -Path $site | Out-Null
    $webRoot = (Resolve-Path build/web).Path
    foreach ($file in Get-ChildItem -LiteralPath $webRoot -File -Recurse) {
        if ($file.Name -match '\.(map|symbols|md)$' -or $file.Name -in @('flutter_service_worker.js', '.last_build_id')) { continue }
        $relative = $file.FullName.Substring($webRoot.Length + 1)
        $target = Join-Path $site $relative
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target
    }
    foreach ($required in @('index.html', 'flutter_bootstrap.js', 'main.dart.js', 'sqlite3.wasm', 'drift_worker.js')) {
        if (!(Test-Path -LiteralPath (Join-Path $site $required))) { throw "Missing asset: $required" }
    }
    $assets = @(Get-ChildItem -LiteralPath $site -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{
            path = $_.FullName.Substring($site.Length + 1).Replace('\', '/')
            bytes = $_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    })
    $manifest = [ordered]@{
        schema_version = 1
        version = "$version+$buildNumber"
        source_commit = $source
        source_dirty = [bool]$dirty.Count
        candidate_only = [bool]$dirty.Count
        dirty_status = $dirty
        backend_origin = $api
        created_at = [DateTime]::UtcNow.ToString('o')
        build_mode = 'release'
        service_worker = 'disabled'
        site_directory = 'site'
        files = $assets
    }
    [IO.File]::WriteAllText((Join-Path $destination 'release-manifest.json'), ($manifest | ConvertTo-Json -Depth 6) + "`n", $utf8)
    Copy-Item -LiteralPath (Join-Path $destination 'release-manifest.json') -Destination (Join-Path $bundleRoot 'release-manifest.json')
    $archive = Join-Path $destination "lostparty-v$version-web.zip"
    New-WebBundleZip -Directory $bundleRoot -Archive $archive
    $archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText("$archive.sha256", "$archiveHash  $([IO.Path]::GetFileName($archive))`n", $utf8)
    $null = Test-WebBundle -Archive $archive -Manifest (Join-Path $destination 'release-manifest.json') -Checksum "$archive.sha256" -AllowCandidate:$AllowDirty
    if ($env:GITHUB_OUTPUT) {
        $artifactName = "lostparty-web-$version-$buildNumber-$($source.Substring(0,12))"
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "artifact_name=$artifactName"
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "bundle_directory=$destination"
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "source_commit=$source"
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "zip_sha256=$archiveHash"
    }
    Write-Output "Bundle: $archive"
    Write-Output "SHA256: $archiveHash"
    Write-Output "Candidate only: $([bool]$dirty.Count)"
} finally {
    Pop-Location
}
