param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Add-Type -AssemblyName System.Drawing

$brandingRoot = Join-Path $ProjectRoot 'assets\branding'
$fullIcon = Join-Path $brandingRoot 'lost_party_icon.png'
$backgroundIcon = Join-Path $brandingRoot 'lost_party_icon_background.png'
$foregroundIcon = Join-Path $brandingRoot 'lost_party_icon_foreground.png'
$monochromeIcon = Join-Path $brandingRoot 'lost_party_icon_monochrome.png'

function Export-ResizedPng {
    param(
        [Parameter(Mandatory)] [string]$Source,
        [Parameter(Mandatory)] [string]$Destination,
        [Parameter(Mandatory)] [int]$Size
    )

    $destinationDirectory = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null

    $sourceImage = [System.Drawing.Image]::FromFile($Source)
    try {
        $outputImage = [System.Drawing.Bitmap]::new(
            $Size,
            $Size,
            [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
        )
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($outputImage)
            try {
                $graphics.Clear([System.Drawing.Color]::Black)
                $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.DrawImage($sourceImage, 0, 0, $Size, $Size)
            }
            finally {
                $graphics.Dispose()
            }

            $outputImage.Save(
                $Destination,
                [System.Drawing.Imaging.ImageFormat]::Png
            )
        }
        finally {
            $outputImage.Dispose()
        }
    }
    finally {
        $sourceImage.Dispose()
    }
}

$androidIcons = @{
    'mipmap-mdpi\ic_launcher.png' = 48
    'mipmap-hdpi\ic_launcher.png' = 72
    'mipmap-xhdpi\ic_launcher.png' = 96
    'mipmap-xxhdpi\ic_launcher.png' = 144
    'mipmap-xxxhdpi\ic_launcher.png' = 192
}

$androidResourceRoot = Join-Path $ProjectRoot 'android\app\src\main\res'
foreach ($entry in $androidIcons.GetEnumerator()) {
    Export-ResizedPng `
        -Source $fullIcon `
        -Destination (Join-Path $androidResourceRoot $entry.Key) `
        -Size $entry.Value
}

$adaptiveIconRoot = Join-Path $androidResourceRoot 'drawable-nodpi'
New-Item -ItemType Directory -Force -Path $adaptiveIconRoot | Out-Null
Copy-Item $backgroundIcon (Join-Path $adaptiveIconRoot 'ic_launcher_background.png') -Force
Copy-Item $foregroundIcon (Join-Path $adaptiveIconRoot 'ic_launcher_foreground.png') -Force
Copy-Item $monochromeIcon (Join-Path $adaptiveIconRoot 'ic_launcher_monochrome.png') -Force

$iosIcons = @{
    'Icon-App-20x20@1x.png' = 20
    'Icon-App-20x20@2x.png' = 40
    'Icon-App-20x20@3x.png' = 60
    'Icon-App-29x29@1x.png' = 29
    'Icon-App-29x29@2x.png' = 58
    'Icon-App-29x29@3x.png' = 87
    'Icon-App-40x40@1x.png' = 40
    'Icon-App-40x40@2x.png' = 80
    'Icon-App-40x40@3x.png' = 120
    'Icon-App-60x60@2x.png' = 120
    'Icon-App-60x60@3x.png' = 180
    'Icon-App-76x76@1x.png' = 76
    'Icon-App-76x76@2x.png' = 152
    'Icon-App-83.5x83.5@2x.png' = 167
    'Icon-App-1024x1024@1x.png' = 1024
}

$iosIconRoot = Join-Path $ProjectRoot 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
foreach ($entry in $iosIcons.GetEnumerator()) {
    Export-ResizedPng `
        -Source $fullIcon `
        -Destination (Join-Path $iosIconRoot $entry.Key) `
        -Size $entry.Value
}

Write-Host 'Generated Android and iOS app icon resources.'
