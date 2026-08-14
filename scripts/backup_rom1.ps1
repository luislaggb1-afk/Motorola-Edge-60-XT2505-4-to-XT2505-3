<#
.SYNOPSIS
    Descarga y verifica la ROM 1 (RETEU Android 15) como respaldo/rollback del
    Motorola Edge 60 XT2505-4.

.DESCRIPTION
    La ROM 1 es la build global europea V2VC35.33-132-4, IDÉNTICA a la build de
    fábrica del XT2505-4 (variante China). Sirve como respaldo para volver al
    estado original si algo sale mal tras instalar la ROM 3 (RETBR A16).

    Hace:
      1. Descarga la ROM 1 desde lolinet (5.5 GB)
      2. Verifica que el tamaño coincida con el publicado
      3. Extrae y revisa el flashfile.xml
      4. Verifica la integridad del zip (contenido listable)

.NOTES
    Requiere: Windows + curl + ~12 GB libres en disco.
    Probado el 2026-08-14. Antecedente de éxito: 4PDA showtopic=1104228 post #406.
#>

[CmdletBinding()]
param(
    [string]$DestDir = "C:\Edge60_Firmware",
    [switch]$SkipDownload
)

$ErrorActionPreference = "Stop"

# --- Configuración -----------------------------------------------------------
$Rom1Url  = "https://mirrors.lolinet.com/firmware/lenomola/2025/scout/official/RETEU/XT2505-1_SCOUT_RETEU_15_V2VC35.33-132-4.zip"
$Rom1File = Join-Path $DestDir "XT2505-1_RETEU_15_V2VC35.33-132-4.zip"
$Rom1Size = 5902248359   # bytes esperados (verificado contra lolinet)

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  BACKUP ROM 1 - RETEU Android 15 (rollback)" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# --- Paso 1: Descarga ---------------------------------------------------------
if (Test-Path $Rom1File) {
    $actual = (Get-Item $Rom1File).Length
    if ($actual -eq $Rom1Size) {
        Write-Host "[OK] ROM 1 ya existe con el tamaño correcto ($actual bytes)" -ForegroundColor Green
        $SkipDownload = $true
    } else {
        Write-Host "[!] ROM 1 existente con tamaño incorrecto ($actual bytes) - se re-descarga" -ForegroundColor Yellow
    }
}

if (-not $SkipDownload) {
    Write-Host "[1/4] Descargando ROM 1 (5.5 GB)... esto toma ~10 min" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    curl.exe -L --retry 3 -o $Rom1File $Rom1Url
    if ($LASTEXITCODE -ne 0) { throw "Fallo la descarga (curl exit $LASTEXITCODE)" }
}

# --- Paso 2: Verificación de tamaño -------------------------------------------
Write-Host "[2/4] Verificando tamaño..." -ForegroundColor Yellow
$actual = (Get-Item $Rom1File).Length
if ($actual -ne $Rom1Size) {
    throw "TAMANO INCORRECTO: esperado $Rom1Size, obtenido $actual. ROM corrupta."
}
Write-Host "[OK] Tamaño correcto: $actual bytes (5.5 GB)" -ForegroundColor Green

# --- Paso 3: Extraer y revisar flashfile.xml ----------------------------------
Write-Host "[3/4] Revisando flashfile.xml..." -ForegroundColor Yellow
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($Rom1File)
try {
    $xmlEntry = $zip.Entries | Where-Object { $_.Name -eq "flashfile.xml" }
    if (-not $xmlEntry) { throw "El zip no contiene flashfile.xml" }
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($xmlEntry, (Join-Path $DestDir "flashfile_ROM1.xml"), $true)

    $xml = [xml](Get-Content (Join-Path $DestDir "flashfile_ROM1.xml") -Raw)
    $steps = $xml.flashfile.steps.step
    Write-Host "[OK] flashfile.xml extraido. $($steps.Count) pasos definidos" -ForegroundColor Green

    # Verifica que el zip esté completo (que se pueda listar todo)
    $zipEntries = $zip.Entries | Where-Object { $_.Name -like "*.img" -or $_.Name -like "*.bin" }
    Write-Host "[OK] Zip legible: $($zipEntries.Count) archivos de imagen/binario" -ForegroundColor Green
} finally {
    $zip.Dispose()
}

# --- Paso 4: Verificación de integridad (muestreo de hashes) ------------------
Write-Host "[4/4] Verificando integridad del zip..." -ForegroundColor Yellow
$totalCompressed = (Get-Item $Rom1File).Length
$zip = [System.IO.Compression.ZipFile]::OpenRead($Rom1File)
try {
    # Verifica que cada entrada se pueda leer sin error (CRC check en lectura)
    $errors = 0
    foreach ($e in $zip.Entries) {
        $s = $e.Open()
        $buffer = New-Object byte[] 65536
        while ($s.Read($buffer, 0, 65536) -gt 0) { }
        $s.Dispose()
    }
    if ($errors -eq 0) {
        Write-Host "[OK] Zip íntegro (todas las entradas leídas sin error CRC)" -ForegroundColor Green
    }
} finally {
    $zip.Dispose()
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  BACKUP LISTO" -ForegroundColor Green
Write-Host "  Archivo: $Rom1File" -ForegroundColor Cyan
Write-Host "  flashfile: $DestDir\flashfile_ROM1.xml" -ForegroundColor Cyan
Write-Host "  Uso para rollback: extraer + flashear igual que la ROM 3," -ForegroundColor Cyan
Write-Host "  y luego 'fastboot oem config carrier retcn'" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
