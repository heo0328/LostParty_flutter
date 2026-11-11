# Shared by the exporter and its boundary checks. Does not extract ZIP files.
function Assert-WebBundlePath([string]$Path) {
    if (!$Path -or $Path.Contains('\') -or $Path.Contains(':') -or $Path.StartsWith('/') -or
        @($Path.Split('/') | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0) {
        throw "Unsafe bundle path: $Path"
    }
}

function Get-WebStreamHash([IO.Stream]$Stream) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($algorithm.ComputeHash($Stream))).Replace('-', '').ToLowerInvariant() }
    finally { $algorithm.Dispose() }
}

function New-WebBundleZip([string]$Directory, [string]$Archive) {
    Add-Type -AssemblyName System.IO.Compression
    $root = (Resolve-Path -LiteralPath $Directory).Path.TrimEnd([IO.Path]::DirectorySeparatorChar)
    $items = @(Get-ChildItem -LiteralPath $root -Recurse -Force)
    if (@($items | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) {
        throw 'Links are not allowed in a web bundle.'
    }
    $names = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $stream = [IO.File]::Open($Archive, [IO.FileMode]::CreateNew)
    $zip = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create, $false)
    try {
        foreach ($file in $items | Where-Object { !$_.PSIsContainer } | Sort-Object FullName) {
            $name = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
            Assert-WebBundlePath $name
            if (!$names.Add($name)) { throw "Duplicate bundle path: $name" }
            $entry = $zip.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
            $input = [IO.File]::OpenRead($file.FullName)
            $output = $entry.Open()
            try { $input.CopyTo($output) } finally { $input.Dispose(); $output.Dispose() }
        }
    } finally { $zip.Dispose(); $stream.Dispose() }
}

function Test-WebBundle([string]$Archive, [string]$Manifest, [string]$Checksum, [switch]$AllowCandidate) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $m = Get-Content -Raw -Encoding UTF8 -LiteralPath $Manifest | ConvertFrom-Json
    if ($m.schema_version -ne 1 -or $m.version -notmatch '^\d+\.\d+\.\d+\+\d+$' -or
        $m.source_commit -notmatch '^[0-9a-f]{40}$' -or $m.build_mode -ne 'release' -or
        $m.site_directory -ne 'site' -or $m.backend_origin -ne 'https://lostparty.duckdns.org' -or
        $m.service_worker -ne 'disabled' -or $m.source_dirty -isnot [bool] -or $m.candidate_only -isnot [bool]) {
        throw 'Invalid web release metadata.'
    }
    if (!$AllowCandidate -and ($m.source_dirty -or $m.candidate_only)) { throw 'Candidate bundle is not deployable.' }
    $expectedName = 'lostparty-v' + $m.version.Split('+')[0] + '-web.zip'
    $hash = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ([IO.Path]::GetFileName($Archive) -cne $expectedName -or
        (Get-Content -Raw -LiteralPath $Checksum).Trim() -cne "$hash  $expectedName") {
        throw 'Archive filename or checksum does not match.'
    }
    $files = @{}
    foreach ($file in $m.files) {
        Assert-WebBundlePath $file.path
        if ($files.ContainsKey($file.path) -or $file.sha256 -notmatch '^[0-9a-f]{64}$' -or $file.bytes -lt 0) {
            throw 'Invalid or duplicate manifest file.'
        }
        if ($file.path -match '\.(map|symbols|md)$' -or $file.path -eq 'flutter_service_worker.js') {
            throw 'Unexpected public asset.'
        }
        $files[$file.path] = $file
    }
    foreach ($required in @('index.html', 'flutter_bootstrap.js', 'main.dart.js', 'sqlite3.wasm', 'drift_worker.js')) {
        if (!$files.ContainsKey($required)) { throw "Missing asset: $required" }
    }
    $seen = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        foreach ($entry in $zip.Entries) {
            Assert-WebBundlePath $entry.FullName
            if (!$seen.Add($entry.FullName)) { throw 'Duplicate ZIP entry.' }
            $unixType = (($entry.ExternalAttributes -shr 16) -band 61440)
            if ($unixType -eq 40960) { throw 'ZIP symlinks are not allowed.' }
            $stream = $entry.Open()
            try { $entryHash = Get-WebStreamHash $stream } finally { $stream.Dispose() }
            if ($entry.FullName -ceq 'release-manifest.json') {
                if ($entryHash -ne (Get-FileHash -LiteralPath $Manifest -Algorithm SHA256).Hash.ToLowerInvariant()) {
                    throw 'Inner and outer manifest differ.'
                }
            } elseif ($entry.FullName.StartsWith('site/', [StringComparison]::Ordinal)) {
                $name = $entry.FullName.Substring(5)
                if (!$files.ContainsKey($name) -or $files[$name].path -cne $name -or
                    $files[$name].bytes -ne $entry.Length -or $files[$name].sha256 -cne $entryHash) {
                    throw "Asset differs from manifest: $name"
                }
            } else { throw 'Unexpected ZIP entry outside site/.' }
        }
        if (!$seen.Contains('release-manifest.json') -or $seen.Count -ne $files.Count + 1) {
            throw 'ZIP and manifest file lists differ.'
        }
    } finally { $zip.Dispose() }
    return $m
}
