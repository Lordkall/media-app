param(
    [Parameter(Mandatory = $true)]
    [string]$ApkPath,

    [Parameter(Mandatory = $true)]
    [string]$KeystorePath,

    [string]$Alias = "LordKall",
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

if (-not $OutputPath) {
    $apk = Get-Item -LiteralPath $ApkPath
    $OutputPath = Join-Path $apk.DirectoryName ($apk.BaseName + "-signed.apk")
}

if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
    throw "No se encontró el APK: $ApkPath"
}
if (-not (Test-Path -LiteralPath $KeystorePath -PathType Leaf)) {
    throw "No se encontró el keystore: $KeystorePath"
}
if (-not $env:ANDROID_KEYSTORE_PASSWORD) {
    throw "Define ANDROID_KEYSTORE_PASSWORD antes de ejecutar el script."
}
if (-not $env:ANDROID_KEY_PASSWORD) {
    $env:ANDROID_KEY_PASSWORD = $env:ANDROID_KEYSTORE_PASSWORD
}

$sdk = $env:ANDROID_SDK_ROOT
if (-not $sdk) { $sdk = $env:ANDROID_HOME }
if (-not $sdk) { throw "Define ANDROID_SDK_ROOT o ANDROID_HOME con la ruta del Android SDK." }

$buildToolsRoot = Join-Path $sdk "build-tools"
$buildTools = Get-ChildItem -LiteralPath $buildToolsRoot -Directory |
    Sort-Object { try { [version]$_.Name } catch { [version]"0.0" } } |
    Select-Object -Last 1
if (-not $buildTools) { throw "No se encontraron Android SDK Build Tools en $buildToolsRoot" }

$apksigner = Join-Path $buildTools.FullName "apksigner.bat"
$zipalign = Join-Path $buildTools.FullName "zipalign.exe"
if (-not (Test-Path -LiteralPath $apksigner)) { throw "No se encontró apksigner en $apksigner" }
if (-not (Test-Path -LiteralPath $zipalign)) { throw "No se encontró zipalign en $zipalign" }

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
$tempAligned = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString() + "-aligned.apk")
try {
    & $zipalign -f -p 4 $ApkPath $tempAligned
    if ($LASTEXITCODE -ne 0) { throw "zipalign terminó con el código $LASTEXITCODE" }

    & $apksigner sign --ks $KeystorePath --ks-key-alias $Alias `
        --ks-pass env:ANDROID_KEYSTORE_PASSWORD `
        --key-pass env:ANDROID_KEY_PASSWORD `
        --out $OutputPath $tempAligned
    if ($LASTEXITCODE -ne 0) { throw "apksigner sign terminó con el código $LASTEXITCODE" }

    & $apksigner verify --verbose --print-certs $OutputPath
    if ($LASTEXITCODE -ne 0) { throw "La verificación de la firma APK falló." }
    Write-Host "APK firmado y verificado: $OutputPath"
}
finally {
    if (Test-Path -LiteralPath $tempAligned) {
        Remove-Item -LiteralPath $tempAligned -Force
    }
}
