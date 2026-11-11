# Run interactively in the user's own terminal. Passwords are never arguments.
[CmdletBinding()]
param([string]$JavaHome = $env:JAVA_HOME)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$keyDirectory = Join-Path $projectRoot 'android/keystores'
$keyFile = Join-Path $keyDirectory 'lostparty-release-2026.jks'
if (Test-Path -LiteralPath $keyFile) { throw 'Key already exists. Never overwrite or regenerate it.' }
$ignored = & git -C $projectRoot check-ignore -- $keyFile
if ($LASTEXITCODE -ne 0) { throw 'Key path must be ignored by Git before generation.' }
$keytool = if ($JavaHome) { Join-Path $JavaHome 'bin/keytool.exe' } else { '' }
if (!$keytool -or !(Test-Path -LiteralPath $keytool)) {
    $command = Get-Command keytool -ErrorAction SilentlyContinue
    if (!$command) { throw 'Pass -JavaHome with the Java 21 directory.' }
    $keytool = $command.Source
}
Write-Host "New key: $keyFile"
Write-Host 'Alias: lostparty-release'
Write-Host 'Before publishing, keep this file AND passwords/alias in a separate secure backup.'
Write-Host 'Do not send passwords or key contents to chat, Git, Issues or CI artifacts.'
Write-Host 'Enter the passwords in keytool. Then copy the key to your independent backup and verify access.'
New-Item -ItemType Directory -Path $keyDirectory -Force | Out-Null
& $keytool -genkeypair -storetype JKS -keystore $keyFile -alias lostparty-release -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=LostParty, OU=Development, O=HeoWork0921'
if ($LASTEXITCODE -ne 0) { throw 'Key creation failed. Inspect the target before any retry.' }
Write-Host 'Key created. This does not confirm backup or authorize publication.'
& $keytool -list -v -keystore $keyFile -alias lostparty-release
if ($LASTEXITCODE -ne 0) { throw 'Cannot reopen the generated key.' }
