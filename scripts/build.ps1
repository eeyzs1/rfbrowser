# build.ps1 - Cross-platform build script for RFBrowser.
#
# Usage:
#   pwsh scripts/build.ps1 -Platform windows           (default; release)
#   pwsh scripts/build.ps1 -Platform macos
#   pwsh scripts/build.ps1 -Platform linux
#   pwsh scripts/build.ps1 -Platform all               (all available platforms)
#   pwsh scripts/build.ps1 -Platform windows -Debug
#
# Output:
#   build/<platform>/...   - per-platform build artefacts
#   dist/                  - compressed archives ready for release

param(
    [ValidateSet("windows", "macos", "linux", "android", "all")]
    [string]$Platform = "windows",

    [switch]$Debug,
    [switch]$NoCompress
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path "$ScriptDir/.."
Set-Location $RepoRoot

$mode = if ($Debug) { "debug" } else { "release" }
$buildFlag = if ($Debug) { "--debug" } else { "--release" }
$arch = if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
        [System.Runtime.InteropServices.OSPlatform]::Windows)) {
    "x64" } elseif ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
        [System.Runtime.InteropServices.OSPlatform]::Linux)) {
    "x64" } else { "x64" }

function Build-Windows {
    Write-Host "[build] === Windows $mode ==="
    flutter build windows $buildFlag
    if (-not $NoCompress) {
        New-Item -ItemType Directory -Force -Path "dist" | Out-Null
        if (Test-Path "dist/windows") { Remove-Item -Recurse -Force "dist/windows" }
        Copy-Item -Recurse "build/windows/$arch/runner/Release" "dist/windows" `
            -ErrorAction SilentlyContinue
        Copy-Item -Recurse "build/windows/$arch/runner/Debug" "dist/windows" `
            -ErrorAction SilentlyContinue
        if (Test-Path "dist/windows") {
            Compress-Archive -Path "dist/windows/*" -DestinationPath "rfbrowser-windows.zip" -Force
            Write-Host "[build] → rfbrowser-windows.zip"
        } else {
            Write-Warning "[build] no Windows build output found"
        }
    }
}

function Build-Macos {
    Write-Host "[build] === macOS $mode ==="
    if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
            [System.Runtime.InteropServices.OSPlatform]::OSX)) {
        Write-Warning "[build] skipping macOS build (host is not macOS)"
        return
    }
    flutter build macos $buildFlag
    if (-not $NoCompress) {
        New-Item -ItemType Directory -Force -Path "dist" | Out-Null
        if (Test-Path "dist/macos") { Remove-Item -Recurse -Force "dist/macos" }
        Copy-Item -Recurse "build/macos/Build/Products/Release" "dist/macos" `
            -ErrorAction SilentlyContinue
        if (Test-Path "dist/macos") {
            Push-Location "dist"
            tar czf "../rfbrowser-macos.tar.gz" "macos"
            Pop-Location
            Write-Host "[build] → rfbrowser-macos.tar.gz"
        } else {
            Write-Warning "[build] no macOS build output found"
        }
    }
}

function Build-Linux {
    Write-Host "[build] === Linux $mode ==="
    flutter build linux $buildFlag
    if (-not $NoCompress) {
        New-Item -ItemType Directory -Force -Path "dist" | Out-Null
        if (Test-Path "dist/linux") { Remove-Item -Recurse -Force "dist/linux" }
        Copy-Item -Recurse "build/linux/$arch/release/$([IO.Path]::GetFileName('bundle'))" "dist/linux" `
            -ErrorAction SilentlyContinue
        if (Test-Path "dist/linux") {
            Push-Location "dist"
            tar czf "../rfbrowser-linux.tar.gz" "linux"
            Pop-Location
            Write-Host "[build] → rfbrowser-linux.tar.gz"
        } else {
            Write-Warning "[build] no Linux build output found"
        }
    }
}

function Build-Android {
    Write-Host "[build] === Android $mode ==="
    if (-not $env:ANDROID_HOME -and -not (Test-Path "android")) {
        Write-Warning "[build] skipping Android build (no android/ directory)"
        return
    }
    if ($Debug) {
        flutter build apk --debug
    } else {
        flutter build apk $buildFlag
    }
    if (-not $NoCompress) {
        $apk = "build/app/outputs/flutter-apk/app-$mode.apk"
        if (Test-Path $apk) {
            Copy-Item $apk "rfbrowser-android.apk" -Force
            Write-Host "[build] → rfbrowser-android.apk"
        } else {
            Write-Warning "[build] no Android APK at $apk"
        }
    }
}

Write-Host "[build] mode: $mode, target: $Platform"
Write-Host "[build] host: $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)"

switch ($Platform) {
    "windows" { Build-Windows }
    "macos"   { Build-Macos }
    "linux"   { Build-Linux }
    "android" { Build-Android }
    "all"     { Build-Windows; Build-Macos; Build-Linux; Build-Android }
}

Write-Host "[build] done"
