<#
.SYNOPSIS
  Run all Flutter integration tests with DLL and flutter_assets fix-up.

.DESCRIPTION
  `flutter test integration_test\` batch-runs all integration test files,
  but has two issues on Windows:
    1. Each rebuild does NOT copy plugin DLLs (sqlite3.dll,
       url_launcher_windows_plugin.dll, etc.) into runner\Debug\.
    2. `flutter test` does NOT copy `flutter_assets` or `icudtl.dat` to
       `runner\Debug\data\`. The app needs these files to run.

  Additionally, `flutter test` generates `build\flutter_assets\` with the
  TEST entry point, while `flutter build windows --debug` generates
  `flutter_assets` with the APP entry point (lib/main.dart). Using the wrong
  one causes the test to hang.

  This script works around these issues by:
    1. Running `flutter build windows --debug` once to ensure all DLLs exist.
    2. Copying DLLs and `icudtl.dat` to `runner\Debug\`.
    3. For each test file:
       a. Running `flutter test` once to BUILD and generate the correct
          `build\flutter_assets\` (this run will hang because
          `runner\Debug\data\flutter_assets\` is missing/wrong, so we kill
          it after the build is done).
       b. Copying `build\flutter_assets\*` to `runner\Debug\data\flutter_assets\`.
       c. Running `flutter test` again (this time it should pass).

.PARAMETER TestFile
  Run only the specified test file (e.g. integration_test/welcome_page_test.dart).

.EXAMPLE
  pwsh scripts/run-integration-tests.ps1

.EXAMPLE
  pwsh scripts/run-integration-tests.ps1 -TestFile integration_test/welcome_page_test.dart
#>
param(
    [string]$TestFile = ""
)

$ErrorActionPreference = 'Stop'

Write-Host "=== RFBrowser Integration Tests (with DLL + flutter_assets fix-up) ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Ensure all DLLs are built and available in build\windows\x64\
Write-Host "[setup] flutter build windows --debug (ensures all DLLs exist)" -ForegroundColor Cyan
$ErrorActionPreference = 'Continue'
flutter build windows --debug --no-pub 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "flutter build FAILED" -ForegroundColor Red
    exit 1
}
$ErrorActionPreference = 'Stop'

# Step 2: Copy all DLLs to runner\Debug (in case they were missing)
$srcDir = "build\windows\x64"
$installDir = "build\install"
$dstDir = "build\windows\x64\runner\Debug"
$dataDir = "$dstDir\data"

function Copy-DllsAndData {
    # Temporarily relax error preference so locked DLLs don't terminate the script.
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    # Helper: copy a file with retries (DLLs may be briefly locked by OS).
    $copyWithRetry = {
        param([string]$src, [string]$dst)
        for ($i = 0; $i -lt 5; $i++) {
            try {
                Copy-Item $src $dst -Force -ErrorAction Stop
                return $true
            } catch {
                Start-Sleep -Milliseconds 300
            }
        }
        return $false
    }

    # Copy DLLs from build\windows\x64\ (top-level, if any)
    Get-ChildItem "$srcDir\*.dll" -ErrorAction SilentlyContinue | ForEach-Object {
        & $copyWithRetry $_.FullName $dstDir | Out-Null
    }
    # Copy DLLs from build\install\ (CMAKE_INSTALL_PREFIX location)
    if (Test-Path $installDir) {
        Get-ChildItem "$installDir\*.dll" -ErrorAction SilentlyContinue | ForEach-Object {
            & $copyWithRetry $_.FullName $dstDir | Out-Null
        }
    }
    # Copy plugin DLLs from build\windows\x64\plugins\*\Debug\
    $pluginDlls = Get-ChildItem "$srcDir\plugins\*\Debug\*.dll" -ErrorAction SilentlyContinue
    if ($pluginDlls) {
        $pluginDlls | ForEach-Object { & $copyWithRetry $_.FullName $dstDir | Out-Null }
    }
    # Copy onnxruntime_providers_shared.dll
    $onnxShared = Get-ChildItem "$srcDir\plugins\flutter_onnxruntime\onnxruntime\*\lib\onnxruntime_providers_shared.dll" -ErrorAction SilentlyContinue
    if ($onnxShared) {
        & $copyWithRetry $onnxShared.FullName $dstDir | Out-Null
    }

    $ErrorActionPreference = $prevEAP
}

Copy-DllsAndData
Write-Host "[setup] Copied DLLs to $dstDir" -ForegroundColor Green

# Step 3: Copy icudtl.dat to runner\Debug\data\ (DO NOT copy flutter_assets from
# build\install\data\ because it has the wrong entry point - lib/main.dart)
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
if (Test-Path "$installDir\data\icudtl.dat") {
    Copy-Item "$installDir\data\icudtl.dat" $dataDir -Force
    Write-Host "[setup] Copied icudtl.dat to $dataDir" -ForegroundColor Green
} elseif (Test-Path "$srcDir\data\icudtl.dat") {
    Copy-Item "$srcDir\data\icudtl.dat" $dataDir -Force
    Write-Host "[setup] Copied icudtl.dat to $dataDir" -ForegroundColor Green
} else {
    Write-Host "[setup] WARNING: icudtl.dat not found!" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Determine which tests to run
$tests = if ($TestFile) {
    @($TestFile)
} else {
    Get-ChildItem "integration_test\*.dart" | ForEach-Object { "integration_test\$($_.Name)" }
}

# Step 5: Run each test file individually
$totalPassed = 0
$totalFailed = 0
$failedTests = @()
$testCount = 0

$buildFlutterAssets = "build\flutter_assets"
$dstFlutterAssets = "$dataDir\flutter_assets"

foreach ($t in $tests) {
    $testCount++
    $name = Split-Path $t -Leaf
    Write-Host "[$testCount/$($tests.Count)] Running: $name" -ForegroundColor Cyan

    # Kill any lingering rfbrowser process before running
    Get-Process -Name "rfbrowser" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800

    # Re-copy DLLs before each test (rebuild may have cleared them)
    Copy-DllsAndData

    # Step 5a: Run flutter test once to BUILD and generate build\flutter_assets\
    # This run will hang because runner\Debug\data\flutter_assets\ is missing/wrong.
    # We monitor build\flutter_assets\kernel_blob.bin and kill the process once it's updated.
    $kernelBlob = "$buildFlutterAssets\kernel_blob.bin"
    $oldTimestamp = $null
    if (Test-Path $kernelBlob) {
        $oldTimestamp = (Get-Item $kernelBlob).LastWriteTime
    }

    Write-Host "  [build] Generating flutter_assets..." -ForegroundColor Yellow
    $ErrorActionPreference = 'Continue'
    $buildProc = Start-Process -FilePath "flutter.bat" -ArgumentList "test", $t, "--no-pub" -PassThru -NoNewWindow
    $ErrorActionPreference = 'Stop'

    # Wait for kernel_blob.bin to be updated (timeout: 180 seconds)
    $timeout = 180
    $elapsed = 0
    $buildDone = $false
    while ($elapsed -lt $timeout) {
        Start-Sleep -Seconds 2
        $elapsed += 2
        if (Test-Path $kernelBlob) {
            $newTimestamp = (Get-Item $kernelBlob).LastWriteTime
            if ($oldTimestamp -eq $null -or $newTimestamp -gt $oldTimestamp) {
                $buildDone = $true
                break
            }
        }
    }

    # Kill the build process and any child processes
    Get-Process -Name "rfbrowser" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    if ($buildProc -and !$buildProc.HasExited) {
        try { $buildProc.Kill() } catch {}
    }
    # Kill any lingering dart.exe processes from this build
    Get-Process -Name "dart" -ErrorAction SilentlyContinue | Where-Object { $_.StartTime -gt (Get-Date).AddSeconds(-$timeout) } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800

    if (-not $buildDone) {
        Write-Host "  [build] ERROR: flutter_assets was not generated within $timeout seconds!" -ForegroundColor Red
        $totalFailed++
        $failedTests += $name
        continue
    }
    Write-Host "  [build] flutter_assets generated." -ForegroundColor Green

    # Step 5b: Copy build\flutter_assets\* to runner\Debug\data\flutter_assets\
    New-Item -ItemType Directory -Path $dstFlutterAssets -Force | Out-Null
    Copy-Item "$buildFlutterAssets\*" $dstFlutterAssets -Recurse -Force
    Write-Host "  [build] Copied flutter_assets to runner\Debug\data\flutter_assets\" -ForegroundColor Green

    # Re-copy DLLs (build may have cleared them)
    Copy-DllsAndData

    # Step 5c: Run flutter test again (this time it should pass)
    Write-Host "  [test] Running test..." -ForegroundColor Yellow
    $ErrorActionPreference = 'Continue'
    & flutter test $t --no-pub
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'

    # Kill any lingering processes
    Get-Process -Name "rfbrowser" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800

    # Re-copy DLLs after build (flutter test rebuild may have cleared them)
    Copy-DllsAndData

    # Check exit code (0 = pass, 1 = fail)
    if ($exitCode -eq 0) {
        $totalPassed++
        Write-Host "  PASSED" -ForegroundColor Green
    } elseif ($exitCode -eq 1) {
        $totalFailed++
        Write-Host "  FAILED (exit code 1)" -ForegroundColor Red
        $failedTests += $name
    } else {
        Write-Host "  ERROR (exit=$exitCode)" -ForegroundColor Red
        $totalFailed++
        $failedTests += $name
    }
}

# Summary
Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "  Files tested: $($tests.Count)"
Write-Host "  Tests passed: $totalPassed"
Write-Host "  Tests failed: $totalFailed"
if ($failedTests.Count -gt 0) {
    Write-Host "  Failed files: $($failedTests -join ', ')" -ForegroundColor Red
    exit 1
} else {
    Write-Host "  All integration tests passed!" -ForegroundColor Green
    exit 0
}
