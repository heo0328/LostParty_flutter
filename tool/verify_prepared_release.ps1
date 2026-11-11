[CmdletBinding()]
param([Parameter(Mandatory)][string]$Directory)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'web_bundle.ps1')
$record = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot 'docs/releases/v2.1.0-artifacts.json') | ConvertFrom-Json
if ($record.tag -ne 'v2.1.0' -or $record.version -ne '2.1.0+6' -or
    $record.repository -ne 'heo0328/LostParty_flutter') { throw 'Unexpected release identity.' }
$version = Get-Content -Encoding UTF8 (Join-Path $projectRoot 'pubspec.yaml') | Where-Object { $_ -match '^version:' }
if ($version.Trim() -ne 'version: 2.1.0+6') { throw 'Pubspec version differs.' }
$notes = Join-Path $projectRoot 'docs/releases/v2.1.0.md'
if ((Get-FileHash -LiteralPath $notes -Algorithm SHA256).Hash.ToLowerInvariant() -ne $record.notes_sha256) {
    throw 'Release notes differ from the approved text.'
}
foreach ($artifact in $record.artifacts) {
    & git -C $projectRoot diff --exit-code $artifact.source HEAD -- lib test pubspec.yaml pubspec.lock android web ios linux macos windows
    if ($LASTEXITCODE -ne 0) { throw 'Application source differs from the accepted artifact.' }
}
$expected = @{}
foreach ($artifact in $record.artifacts) {
    foreach ($file in $artifact.files.PSObject.Properties) {
        if ($file.Name -cne [IO.Path]::GetFileName($file.Name) -or $expected.ContainsKey($file.Name)) {
            throw 'Invalid or duplicate release filename.'
        }
        $expected[$file.Name] = $file.Value
    }
}
$root = (Resolve-Path -LiteralPath $Directory).Path
$items = @(Get-ChildItem -Force -LiteralPath $root)
if ($items.Count -ne $expected.Count) { throw 'Release asset list differs.' }
foreach ($item in $items) {
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        !(@($expected.Keys) -ccontains $item.Name) -or
        (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expected[$item.Name]) {
        throw "Release asset differs: $($item.Name)"
    }
}
$apk = 'lostparty-2.1.0-6-android.apk'
if ((Get-Content -Raw -LiteralPath (Join-Path $root "$apk.sha256")).Trim() -cne "$($expected[$apk])  $apk") {
    throw 'APK checksum filename/hash differs.'
}
$web = 'lostparty-v2.1.0-web.zip'
$manifest = Test-WebBundle -Archive (Join-Path $root $web) -Manifest (Join-Path $root 'release-manifest.json') -Checksum (Join-Path $root "$web.sha256")
if ($manifest.source_commit -ne $record.artifacts[1].source -or $manifest.version -ne $record.version) {
    throw 'Web manifest provenance differs.'
}
Write-Output 'Accepted release: all 5 original asset bytes, notes, app sources and web manifest verified.'
