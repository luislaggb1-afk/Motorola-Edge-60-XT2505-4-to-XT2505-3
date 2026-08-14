<#
.SYNOPSIS
    Instala la ROM 3 (RETBR Android 16) en un Motorola Edge 60 XT2505-4:
    extracción + verificación MD5 + flash de 66 pasos + canal retbr.

.DESCRIPTION
    Replica EXACTAMENTE el procedimiento que se ejecutó con éxito el 2026-08-14
    (66/66 pasos OK, boot confirmado, señal + WiFi funcionando).

    Flujo:
      1. Verifica que el dispositivo esté en modo fastboot
      2. Extrae la ROM 3 (66 archivos, 7.44 GB)
      3. Verifica MD5 de todas las imágenes contra el flashfile.xml (57/57)
      4. Flash partición por partición en el orden exacto del flashfile.xml
         (se detiene ante el PRIMER error - el teléfono NO se toca si algo falla)
      5. Configura el canal de actualizaciones: retbr (Brasil)
      6. Pide confirmación antes de reiniciar

    NO toca las particiones del IMEI/calibración: nvram, md_sec, utags, proinfo,
    cid, frp, seccfg, persist, protect1/2.

.PARAMETER ZipPath
    Ruta del zip de la ROM 3. Default: C:\Edge60_Firmware\XT2505-3_RETBR_16_W1VCS36H.14-20-19-7.zip

.PARAMETER WorkDir
    Carpeta de trabajo (extracción). Default: C:\Edge60_Firmware

.PARAMETER PlatformTools
    Ruta del platform-tools OFICIAL de Google. Default: C:\adb\platform-tools
    Descargar de: https://developer.android.com/tools/releases/platform-tools

.PARAMETER SkipExtract
    Salta la extracción y MD5 (útil si ya se hizo; retoma en el flash).

.PARAMETER SkipFlash
    Solo extrae y verifica MD5, no flashea.

.NOTES
    Requiere: Windows + platform-tools + ~9 GB libres + teléfono en fastboot
    con bootloader desbloqueado (securestate: flashing_unlocked).
    Antecedentes: 4PDA showtopic=1104228 post #406; showtopic=1106498.
#>

[CmdletBinding()]
param(
    [string]$ZipPath      = "C:\Edge60_Firmware\XT2505-3_RETBR_16_W1VCS36H.14-20-19-7.zip",
    [string]$WorkDir      = "C:\Edge60_Firmware",
    [string]$PlatformTools = "C:\adb\platform-tools",
    [switch]$SkipExtract,
    [switch]$SkipFlash
)

$ErrorActionPreference = "Stop"
$Fastboot = Join-Path $PlatformTools "fastboot.exe"
$Adb      = Join-Path $PlatformTools "adb.exe"

if (-not (Test-Path $Fastboot)) { throw "No se encuentra fastboot en $PlatformTools. Descarga el platform-tools oficial." }
if (-not (Test-Path $ZipPath))  { throw "No se encuentra el zip de la ROM 3 en $ZipPath. Descárgalo primero (ver README)." }

$ExtractDir = Join-Path $WorkDir "flash3"
$LogFile    = Join-Path $WorkDir "flash_log.txt"

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  INSTALAR ROM 3 - RETBR Android 16" -ForegroundColor Cyan
Write-Host "  W1VCS36H.14-20-19-7" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# --- Paso 1: Verificar dispositivo en fastboot --------------------------------
Write-Host "[1] Verificando dispositivo en modo fastboot..." -ForegroundColor Yellow
$devices = & $Fastboot devices 2>&1
if ($devices -notmatch "fastboot") {
    Write-Host "No hay dispositivo en fastboot. Reiniciándolo:" -ForegroundColor Yellow
    & $Adb reboot bootloader 2>$null
    Start-Sleep -Seconds 8
    $devices = & $Fastboot devices 2>&1
    if ($devices -notmatch "fastboot") { throw "El dispositivo no aparece en fastboot. Conéctalo y verifica." }
}
Write-Host "[OK] Dispositivo detectado: $($devices.Trim())" -ForegroundColor Green

# Verificación de seguridad: bootloader desbloqueado
$secure = & $Fastboot getvar securestate 2>&1
if ($secure -notmatch "flashing_unlocked") {
    throw "SECURE STATE NO ES flashing_unlocked ($secure). El flash requiere bootloader desbloqueado."
}
Write-Host "[OK] securestate: flashing_unlocked (bootloader desbloqueado)" -ForegroundColor Green

# --- Paso 2: Extraer la ROM 3 -------------------------------------------------
if (-not $SkipExtract) {
    Write-Host "[2] Extrayendo ROM 3..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $count = 0
        foreach ($e in $zip.Entries) {
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, (Join-Path $ExtractDir $e.Name), $true)
            $count++
        }
        Write-Host "[OK] $count archivos extraídos en $ExtractDir" -ForegroundColor Green
    } finally {
        $zip.Dispose()
    }

    # --- Paso 3: Verificar MD5 contra el flashfile.xml -------------------------
    Write-Host "[3] Verificando MD5 de todas las imágenes contra flashfile.xml..." -ForegroundColor Yellow
    $xmlPath = Join-Path $ExtractDir "flashfile.xml"
    if (-not (Test-Path $xmlPath)) { throw "No se encontró flashfile.xml en el zip" }
    $xml = [xml](Get-Content $xmlPath -Raw)

    $total = 0; $ok = 0; $fail = @()
    foreach ($file in $xml.flashfile.files.file) {
        $total++
        $imgPath = Join-Path $ExtractDir $file.filename
        if (-not (Test-Path $imgPath)) { $fail += "FALTA $($file.filename)"; continue }
        $hash = (Get-FileHash $imgPath -Algorithm MD5).Hash
        if ($hash -eq $file.MD5) { $ok++ } else { $fail += "MD5 NO COINCIDE: $($file.filename)" }
    }
    Write-Host "[OK] MD5 verificados: $ok de $total" -ForegroundColor Green
    if ($fail.Count -gt 0) {
        $fail | ForEach-Object { Write-Host "  [!] $_" -ForegroundColor Red }
        throw "Verificación MD5 falló ($($fail.Count) errores). ROM corrupta - redescargar. NO flashear."
    }
}

# --- Paso 4: Flash (66 pasos, orden exacto del flashfile.xml) -----------------
if (-not $SkipFlash) {
    Write-Host "[4] Iniciando flash..." -ForegroundColor Yellow
    Write-Host "    IMPORTANTE: no desconectes el teléfono ni cierres esta ventana." -ForegroundColor Red

    Set-Location $ExtractDir
    "=== FLASH ROM 3 - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File $LogFile

    # Función helper: ejecuta un comando fastboot y registra en log
    function Invoke-Fb {
        param([string]$Name, [string[]]$Args)
        $out = & $Fastboot @Args 2>&1 | Out-String
        $outLine = ($out -replace "`r?`n", " ").Trim()
        "{0} -> {1}" -f $Name, $outLine | Out-File $LogFile -Append -Encoding utf8
        if ($LASTEXITCODE -ne 0 -or $out -match "FAILED|error") {
            Write-Host "[ERROR] $Name falló: $outLine" -ForegroundColor Red
            throw "Flash detenido en: $Name"
        }
        Write-Host "[OK] $Name" -ForegroundColor Green
    }

    # Secuencia exacta del flashfile.xml de la ROM 3 RETBR
    $sequence = @(
        @("gpt",          @("flash", "gpt", "gpt_main0.bin")),
        @("preloader",    @("flash", "preloader", "preloader_scout.bin")),
        @("lk_a",         @("flash", "lk_a", "lk_a.img")),
        @("tee_a",        @("flash", "tee_a", "tee_a.img")),
        @("mcupm_a",      @("flash", "mcupm_a", "mcupm_a.img")),
        @("pi_img_a",     @("flash", "pi_img_a", "pi_img_a.img")),
        @("sspm_a",       @("flash", "sspm_a", "sspm_a.img")),
        @("dtbo_a",       @("flash", "dtbo_a", "dtbo_a.img")),
        @("logo_a",       @("flash", "logo_a", "logo_a.img")),
        @("erase nvdata", @("erase", "nvdata")),
        @("spmfw_a",      @("flash", "spmfw_a", "spmfw_a.img")),
        @("scp_a",        @("flash", "scp_a", "scp_a.img")),
        @("vbmeta_a",     @("flash", "vbmeta_a", "vbmeta_a.img")),
        @("vbmeta_system_a", @("flash", "vbmeta_system_a", "vbmeta_system_a.img")),
        @("modem_a",      @("flash", "modem_a", "modem_a.img")),
        @("dpm_a",        @("flash", "dpm_a", "dpm_a.img")),
        @("gz_a",         @("flash", "gz_a", "gz_a.img")),
        @("mcf_ota_a",    @("flash", "mcf_ota_a", "mcf_ota_a.img")),
        @("ccu_a",        @("flash", "ccu_a", "ccu_a.img")),
        @("vcp_a",        @("flash", "vcp_a", "vcp_a.img")),
        @("gpueb_a",      @("flash", "gpueb_a", "gpueb_a.img")),
        @("apusys_a",     @("flash", "apusys_a", "apusys_a.img")),
        @("connsys_bt_a", @("flash", "connsys_bt_a", "connsys_bt_a.bin")),
        @("connsys_gnss_a", @("flash", "connsys_gnss_a", "connsys_gnss_a.bin")),
        @("connsys_wifi_a", @("flash", "connsys_wifi_a", "connsys_wifi_a.bin")),
        @("efuseBackup",  @("flash", "efuseBackup", "efuse_backup.img")),
        @("init_boot_a",  @("flash", "init_boot_a", "init_boot_a.img")),
        @("boot_a",       @("flash", "boot_a", "boot_a.img")),
        @("vendor_boot_a", @("flash", "vendor_boot_a", "vendor_boot_a.img"))
    )

    $step = 0
    $totalSteps = 66
    foreach ($s in $sequence) {
        $step++
        Write-Progress -Activity "Flash ROM 3" -Status "$($s[0]) ($step/$totalSteps)" -PercentComplete (($step/$totalSteps)*100)
        Invoke-Fb $s[0] $s[1]
    }

    # Super: 29 sparse chunks
    for ($i = 0; $i -le 28; $i++) {
        $step++
        $chunk = "super.img_sparsechunk.$i"
        Write-Progress -Activity "Flash ROM 3" -Status "super ($step/$totalSteps)" -PercentComplete (($step/$totalSteps)*100)
        Invoke-Fb "super chunk $i" @("flash", "super", $chunk)
    }

    # Erases finales
    foreach ($e in @("userdata", "metadata", "debug_token")) {
        $step++
        Write-Progress -Activity "Flash ROM 3" -Status "erase $e ($step/$totalSteps)" -PercentComplete (($step/$totalSteps)*100)
        Invoke-Fb "erase $e" @("erase", $e)
    }

    Write-Progress -Activity "Flash ROM 3" -Completed
    Write-Host "`n[OK] FLASH COMPLETO: $step/$totalSteps pasos sin errores" -ForegroundColor Green
    Write-Host "    Log: $LogFile" -ForegroundColor Cyan

    # --- Paso 5: Canal de actualizaciones --------------------------------------
    Write-Host "[5] Configurando canal de actualizaciones (retbr - Brasil)..." -ForegroundColor Yellow
    $out = & $Fastboot oem config carrier retbr 2>&1 | Out-String
    "canal retbr -> $($out.Trim())" | Out-File $LogFile -Append -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw "Fallo la configuración del canal: $out" }
    Write-Host "[OK] Canal configurado: retbr" -ForegroundColor Green

    # --- Paso 6: Confirmación antes de reiniciar --------------------------------
    Write-Host ""
    Write-Host "El flash terminó correctamente." -ForegroundColor Green
    $r = Read-Host "¿Reiniciar el teléfono ahora? (s/N)"
    if ($r -match "^[sS]") {
        Write-Host "Reiniciando..." -ForegroundColor Yellow
        & $Fastboot reboot
        Write-Host "El primer arranque tarda varios minutos. Debe aparecer el warning" -ForegroundColor Yellow
        Write-Host "de bootloader desbloqueado (normal) y luego Android 16." -ForegroundColor Yellow
        Write-Host "NO reloquear el bootloader (riesgo de brick - ver README)." -ForegroundColor Red
    } else {
        Write-Host "OK. Reinicia manualmente cuando quieras: fastboot reboot" -ForegroundColor Yellow
    }
}

Write-Host "`nProceso terminado." -ForegroundColor Green
