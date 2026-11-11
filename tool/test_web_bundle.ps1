$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'web_bundle.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem
$utf8 = New-Object Text.UTF8Encoding($false)
$root = Join-Path (Split-Path $PSScriptRoot -Parent) ('.dart_tool/web-bundle-tests/' + [Guid]::NewGuid().ToString('N'))
$source = Join-Path $root 'source'
$site = Join-Path $source 'site'
New-Item -ItemType Directory -Path $site -Force | Out-Null
$files = @('index.html','flutter_bootstrap.js','main.dart.js','sqlite3.wasm','drift_worker.js','assets/catalog.json')
foreach ($file in $files) {
    $target = Join-Path $site $file
    New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
    [IO.File]::WriteAllText($target, "fixture $file", $utf8)
}
$manifest = Join-Path $source 'release-manifest.json'
$metadata = [ordered]@{
    schema_version = 1; version = '2.1.0+6'; source_commit = ('a' * 40)
    source_dirty = $false; candidate_only = $false; build_mode = 'release'
    backend_origin = 'https://lostparty.duckdns.org'; site_directory = 'site'; service_worker = 'disabled'
    files = @($files | ForEach-Object {
        $path = Join-Path $site $_
        [ordered]@{path=$_;bytes=(Get-Item -LiteralPath $path).Length;sha256=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
    })
}
[IO.File]::WriteAllText($manifest, ($metadata | ConvertTo-Json -Depth 5), $utf8)
$valid = Join-Path $root 'valid/lostparty-v2.1.0-web.zip'
New-Item -ItemType Directory -Path (Split-Path $valid -Parent) | Out-Null
New-WebBundleZip -Directory $source -Archive $valid
function Set-Checksum([string]$Zip) {
    [IO.File]::WriteAllText("$Zip.sha256", "$((Get-FileHash -LiteralPath $Zip).Hash.ToLowerInvariant())  $([IO.Path]::GetFileName($Zip))`n", $utf8)
}
Set-Checksum $valid
$null = Test-WebBundle -Archive $valid -Manifest $manifest -Checksum "$valid.sha256"
$zip = [IO.Compression.ZipFile]::OpenRead($valid)
try {
    if (@($zip.Entries | Where-Object {$_.FullName.Contains('\')}).Count) { throw 'Exporter wrote Windows paths.' }
} finally { $zip.Dispose() }
Write-Output 'PASS: POSIX ZIP + complete file hashes + identical manifests'
$tests = 1
function Assert-Rejected([string]$Name, [scriptblock]$Mutate, [string]$Expected) {
    $directory = Join-Path $root $Name
    New-Item -ItemType Directory -Path $directory | Out-Null
    $archive = Join-Path $directory 'lostparty-v2.1.0-web.zip'
    $outer = Join-Path $directory 'release-manifest.json'
    Copy-Item -LiteralPath $valid -Destination $archive
    Copy-Item -LiteralPath $manifest -Destination $outer
    & $Mutate $archive $outer
    Set-Checksum $archive
    try {
        $null = Test-WebBundle -Archive $archive -Manifest $outer -Checksum "$archive.sha256"
    } catch {
        if ($_.Exception.Message -notlike "*$Expected*") { throw }
        Write-Output "PASS: reject $Name"
        $script:tests++
        return
    }
    throw "Accepted invalid bundle: $Name"
}
function Add-Entry([string]$Archive, [string]$Name, [bool]$Symlink = $false) {
    $zip = [IO.Compression.ZipFile]::Open($Archive, [IO.Compression.ZipArchiveMode]::Update)
    try {
        $entry = $zip.CreateEntry($Name)
        if ($Symlink) { $entry.ExternalAttributes = -1577123840 }
        $stream = $entry.Open()
        try { $bytes = $utf8.GetBytes('untrusted'); $stream.Write($bytes,0,$bytes.Length) }
        finally { $stream.Dispose() }
    } finally { $zip.Dispose() }
}
Assert-Rejected 'traversal' {param($a,$m) Add-Entry $a '../outside'} 'Unsafe bundle path'
Assert-Rejected 'backslash' {param($a,$m) Add-Entry $a 'site\outside'} 'Unsafe bundle path'
Assert-Rejected 'absolute' {param($a,$m) Add-Entry $a '/outside'} 'Unsafe bundle path'
Assert-Rejected 'duplicate' {param($a,$m) Add-Entry $a 'site/index.html'} 'Duplicate ZIP entry'
Assert-Rejected 'case-collision' {param($a,$m) Add-Entry $a 'site/INDEX.html'} 'Duplicate ZIP entry'
Assert-Rejected 'unlisted-file' {param($a,$m) Add-Entry $a 'site/extra.js'} 'Asset differs'
Assert-Rejected 'symlink' {param($a,$m) Add-Entry $a 'site/link' $true} 'symlinks'
Assert-Rejected 'outer-manifest-change' {param($a,$m) [IO.File]::AppendAllText($m, ' ')} 'manifest differ'
Assert-Rejected 'file-corruption' {
    param($a,$m)
    $zip = [IO.Compression.ZipFile]::Open($a,[IO.Compression.ZipArchiveMode]::Update)
    try {
        $stream = $zip.GetEntry('site/index.html').Open()
        try {$stream.SetLength(0);$stream.WriteByte(0)} finally {$stream.Dispose()}
    } finally {$zip.Dispose()}
} 'Asset differs'
Assert-Rejected 'candidate' {
    param($a,$m)
    $text = [IO.File]::ReadAllText($m).Replace('"candidate_only":  false','"candidate_only":  true').Replace('"candidate_only": false','"candidate_only": true')
    [IO.File]::WriteAllText($m,$text,$utf8)
} 'not deployable'
$wrongChecksum = Join-Path $root 'wrong.sha256'
[IO.File]::WriteAllText($wrongChecksum, ('0' * 64) + '  lostparty-v2.1.0-web.zip', $utf8)
try {
    $null = Test-WebBundle -Archive $valid -Manifest $manifest -Checksum $wrongChecksum
    throw 'Accepted checksum mismatch'
} catch {
    if ($_.Exception.Message -notlike '*checksum does not match*') { throw }
    $tests++
    Write-Output 'PASS: reject checksum mismatch'
}
Write-Output "All $tests bundle boundary checks passed. Fixtures: $root"
