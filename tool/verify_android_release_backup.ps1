# Interactive only: never pass passwords on a command line or print them.
[CmdletBinding()]
param([string]$JavaHome, [switch]$UpdateGitHubSecrets)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$original = Join-Path $projectRoot 'android/keystores/lostparty-release-2026.jks'
$alias = 'lostparty-release'
$repository = 'heo0328/LostParty_flutter'
$javaBin = Join-Path $JavaHome 'bin'
foreach ($tool in @('keytool.exe','jar.exe','jarsigner.exe')) {
    if (!(Test-Path -LiteralPath (Join-Path $javaBin $tool))) { throw "Missing Java tool: $tool" }
}
if (!(Test-Path -LiteralPath $original)) { throw 'Original release key is missing.' }
Write-Host 'Enter the FULL PATH to your independent BACKUP copy, not the original.'
$backupInput = (Read-Host 'Backup JKS path').Trim().Trim('"')
$backup = (Resolve-Path -LiteralPath $backupInput).Path
if ([string]::Equals($backup, $original, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The original is not an independent backup.'
}
$originalHash = (Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash
if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $originalHash) {
    throw 'Backup differs from original. No secrets were changed.'
}
Write-Host 'File hashes match. Enter passwords below; no password is logged.'
$storePassword = Read-Host 'Keystore password' -AsSecureString
$keyPassword = Read-Host 'Key password (Enter if same as keystore password)' -AsSecureString
if ($keyPassword.Length -eq 0) { $keyPassword = $storePassword }
function Unprotect-ForChildProcess([Security.SecureString]$Value) {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}
$checkRoot = Join-Path $projectRoot ('.dart_tool/release-key-check/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $checkRoot -Force | Out-Null
$publicReport = Join-Path $projectRoot '.dart_tool/release-key-verification.json'
if (Test-Path -LiteralPath $publicReport) { throw 'A verification record already exists. Review it before repeating.' }
try {
    $env:LOSTPARTY_SIGNING_STORE_PASSWORD = Unprotect-ForChildProcess $storePassword
    $env:LOSTPARTY_SIGNING_KEY_PASSWORD = Unprotect-ForChildProcess $keyPassword
    $certificateFile = Join-Path $checkRoot 'certificate.der'
    & (Join-Path $javaBin 'keytool.exe') -exportcert -keystore $backup -alias $alias -storepass:env LOSTPARTY_SIGNING_STORE_PASSWORD -file $certificateFile
    if ($LASTEXITCODE -ne 0) { throw 'Cannot open backup keystore/alias.' }
    $marker = Join-Path $checkRoot 'verification.txt'
    [IO.File]::WriteAllText($marker, 'LOSTPARTY backup private-key access check')
    $jarFile = Join-Path $checkRoot 'verification.jar'
    & (Join-Path $javaBin 'jar.exe') --create --file $jarFile -C $checkRoot verification.txt
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create signing probe.' }
    & (Join-Path $javaBin 'jarsigner.exe') -keystore $backup -storepass:env LOSTPARTY_SIGNING_STORE_PASSWORD -keypass:env LOSTPARTY_SIGNING_KEY_PASSWORD $jarFile $alias
    if ($LASTEXITCODE -ne 0) { throw 'Backup private key cannot sign. No secrets were changed.' }
    & (Join-Path $javaBin 'jarsigner.exe') -verify $jarFile
    if ($LASTEXITCODE -ne 0) { throw 'Backup signature verification failed.' }
    $certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($certificateFile)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { $certificateSha256 = ([BitConverter]::ToString($sha256.ComputeHash($certificate.RawData))).Replace('-', '').ToLowerInvariant() }
    finally { $sha256.Dispose() }
    $certificateSha1 = $certificate.GetCertHashString().ToLowerInvariant()
    $certificate.Dispose()
    $report = [ordered]@{
        verified_at = [DateTime]::UtcNow.ToString('o')
        key_file = 'lostparty-release-2026.jks'
        alias = $alias
        backup_matches_original = $true
        backup_store_access = $true
        backup_private_key_sign_verify = $true
        certificate_sha1 = $certificateSha1
        certificate_sha256 = $certificateSha256
        github_secrets_updated = $false
    }
    if ($UpdateGitHubSecrets) {
        $origin = (& git -C $projectRoot remote get-url origin).Trim()
        if ($origin -ne 'https://github.com/heo0328/LostParty_flutter.git') { throw 'Unexpected GitHub repository.' }
        Write-Host "Updating the 4 Android signing secrets in $repository. No build or publication will run."
        $values = [ordered]@{
            ANDROID_KEYSTORE_BASE64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($original))
            ANDROID_KEYSTORE_PASSWORD = $env:LOSTPARTY_SIGNING_STORE_PASSWORD
            ANDROID_KEY_ALIAS = $alias
            ANDROID_KEY_PASSWORD = $env:LOSTPARTY_SIGNING_KEY_PASSWORD
        }
        foreach ($name in $values.Keys) {
            $values[$name] | & gh secret set $name --repo $repository
            if ($LASTEXITCODE -ne 0) { throw "Secret update failed at $name. Stop and report the name only; updates may be partial." }
        }
        $values.Clear()
        $report.github_secrets_updated = $true
    }
    [IO.File]::WriteAllText($publicReport, ($report | ConvertTo-Json) + "`n", (New-Object Text.UTF8Encoding($false)))
    Write-Host 'Backup and private-key access verified. Public fingerprints:'
    Write-Host "SHA-1: $certificateSha1"
    Write-Host "SHA-256: $certificateSha256"
    Write-Host 'Public-only verification record saved. No APK has been published.'
} finally {
    Remove-Item Env:LOSTPARTY_SIGNING_STORE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:LOSTPARTY_SIGNING_KEY_PASSWORD -ErrorAction SilentlyContinue
    if ($values) { $values.Clear() }
    $storePassword.Dispose()
    if (![object]::ReferenceEquals($storePassword, $keyPassword)) { $keyPassword.Dispose() }
}
