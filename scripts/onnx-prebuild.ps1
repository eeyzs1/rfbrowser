#!/usr/bin/env pwsh
# =============================================================================
# onnx-prebuild.ps1 — Pre-extract ONNX Runtime for flutter_onnxruntime plugin
# =============================================================================
#
# Why this script exists:
# The `flutter_onnxruntime` plugin's CMakeLists.txt downloads ONNX Runtime
# (~70 MB zip) from GitHub Releases at configure time and extracts it to:
#   build/windows/x64/plugins/flutter_onnxruntime/onnxruntime/onnxruntime-win-x64-1.22.0/
#
# In restricted/offline build environments the download can fail silently and
# CMake then aborts with:
#   "ONNX Runtime extraction directory doesn't exist: ..."
#
# This script does the download+extract up-front. Once the marker file
#   onnxruntime-win-x64-1.22.0/include/onnxruntime_cxx_api.h
# exists, the plugin's CMakeLists.txt will skip its own download step and
# the build can proceed offline.
#
# Re-run this script if you run `flutter clean` and the build directory is
# wiped.
#
# Usage (from project root):
#   pwsh scripts/onnx-prebuild.ps1
#
# Exit codes:
#   0  - already prepared or preparation succeeded
#   1  - download failed
#   2  - extraction failed
#   3  - marker file missing after preparation
# =============================================================================

$ErrorActionPreference = 'Stop'

$ProjectRoot   = Split-Path -Parent $PSScriptRoot
$BuildDir      = Join-Path $ProjectRoot 'build\windows\x64'
$PluginDir     = Join-Path $BuildDir 'plugins\flutter_onnxruntime\onnxruntime'
$ExtractRoot   = Join-Path $PluginDir 'onnxruntime-win-x64-1.22.0'
$MarkerFile    = Join-Path $ExtractRoot 'include\onnxruntime_cxx_api.h'
$ZipFile       = Join-Path $env:TEMP 'onnxruntime-win-x64-1.22.0.zip'
$DownloadUrl   = 'https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-win-x64-1.22.0.zip'

function Write-Status($msg) {
    Write-Host "[onnx-prebuild] $msg" -ForegroundColor Cyan
}

function Write-Ok($msg) {
    Write-Host "[onnx-prebuild] $msg" -ForegroundColor Green
}

function Write-Warn($msg) {
    Write-Host "[onnx-prebuild] $msg" -ForegroundColor Yellow
}

# 1. If marker file already exists, nothing to do.
if (Test-Path $MarkerFile) {
    Write-Ok "Already prepared: $MarkerFile"
    exit 0
}

# 2. Create destination directory tree.
Write-Status "Preparing directory: $PluginDir"
New-Item -ItemType Directory -Force -Path $PluginDir | Out-Null

# 3. Download the archive (curl handles redirects + resume better than
#    Invoke-WebRequest in this environment).
if (-not (Test-Path $ZipFile)) {
    Write-Status "Downloading ONNX Runtime from GitHub Releases..."
    Write-Status "  URL: $DownloadUrl"
    Write-Status "  Destination: $ZipFile"
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        & curl.exe -L -o $ZipFile --retry 3 --retry-delay 5 $DownloadUrl
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "curl failed (exit $LASTEXITCODE). Falling back to Invoke-WebRequest..."
            Remove-Item $ZipFile -Force -ErrorAction SilentlyContinue
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipFile -TimeoutSec 300
        }
    } else {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipFile -TimeoutSec 300
    }
} else {
    Write-Status "Reusing existing zip: $ZipFile"
}

if (-not (Test-Path $ZipFile) -or (Get-Item $ZipFile).Length -lt 50MB) {
    Write-Warn "Download failed or file looks too small (< 50MB)."
    Write-Warn "Please verify network connectivity to github.com and retry."
    exit 1
}

# 4. Extract.
Write-Status "Extracting archive..."
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $PluginDir)
} catch {
    Write-Warn "Extraction failed: $_"
    exit 2
}

# 5. Verify marker.
if (-not (Test-Path $MarkerFile)) {
    Write-Warn "Marker file missing after extraction: $MarkerFile"
    Write-Warn "Archive may be corrupt; please delete $ZipFile and retry."
    exit 3
}

# 6. Clean up the zip.
Remove-Item $ZipFile -Force -ErrorAction SilentlyContinue

Write-Ok "ONNX Runtime pre-extracted successfully."
Write-Ok "  Path: $ExtractRoot"
Write-Ok "  Marker: $MarkerFile"
Write-Status "You can now run: flutter build windows"
exit 0
