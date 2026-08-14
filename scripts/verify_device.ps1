<#
.SYNOPSIS
    Diagnóstico del Motorola Edge 60 XT2505-4 antes de flashear: verifica
    chipset, build, canal, slot y estado del bootloader.

.DESCRIPTION
    Confirma que el dispositivo es compatible con la ROM global RETBR antes de
    proceder. Verifica:
      - Que el chip sea MT6878 (Dimensity 7400) - compatible con estas ROMs
      - La build y canal actuales (para documentar el punto de partida)
      - Estado del bootloader (debe estar desbloqueado)

.PARAMETER PlatformTools
    Ruta del platform-tools OFICIAL. Default: C:\adb\platform-tools

.EXAMPLE
    .\verify_device.ps1

.NOTES
    Antecedente: verificación realizada en vivo el 2026-08-14.
    Resultado esperado en este caso:
      CPU max freq cpu4: 2600000  ->  Dimensity 7400
      ro.board.platform: mt6878
      ro.build.display.id: V2VC35.33-132-4 (Android 15, canal retcn)
#>

[CmdletBinding()]
param(
    [string]$PlatformTools = "C:\adb\platform-tools"
)

$ErrorActionPreference = "Stop"
$Adb      = Join-Path $PlatformTools "adb.exe"
$Fastboot = Join-Path $PlatformTools "fastboot.exe"

if (-not (Test-Path $Adb)) { throw "No se encuentra adb.exe en $PlatformTools" }

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  VERIFICACIÓN DEL DISPOSITIVO (pre-flash)" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# --- Modo Android (ADB) --------------------------------------------------------
Write-Host "[1] Verificando en modo Android (ADB)..." -ForegroundColor Yellow
$adbList = & $Adb devices 2>&1
if ($adbList -notmatch "\tdevice\b") {
    Write-Host "  No hay dispositivo en ADB. ¿Depuración USB activada?" -ForegroundColor Yellow
    Write-Host "  Ajustes -> Acerca del teléfono -> Número de compilación x7 ->" -ForegroundColor Yellow
    Write-Host "  Sistema -> Opciones de desarrollador -> Depuración USB" -ForegroundColor Yellow
    Write-Host "  (o si está en fastboot, continúa al paso 2)" -ForegroundColor Yellow
} else {
    Write-Host "[OK] Dispositivo detectado en ADB" -ForegroundColor Green
    $props = & $Adb shell "cat /sys/devices/system/cpu/cpu4/cpufreq/cpuinfo_max_freq; getprop ro.board.platform; getprop ro.build.display.id; getprop ro.build.version.release; getprop ro.carrier; getprop ro.boot.slot_suffix" 2>&1

    $freq     = $props[0]
    $platform = $props[1]
    $build    = $props[2]
    $release  = $props[3]
    $carrier  = $props[4]
    $slot     = $props[5]

    Write-Host "  CPU max freq (cpu4): $freq"
    Write-Host "  Plataforma:          $platform"
    Write-Host "  Build:               $build"
    Write-Host "  Android:             $release"
    Write-Host "  Canal (carrier):     $carrier"
    Write-Host "  Slot activo:         $slot"

    # --- Validación de compatibilidad -----------------------------------------
    if ($freq -eq "2600000") { Write-Host "  [OK] Dimensity 7400 - compatible con ROMs scout" -ForegroundColor Green }
    elseif ($freq -eq "2500000") { Write-Host "  [!] Dimensity 7300 - verificar compatibilidad de modem" -ForegroundColor Yellow }
    else { Write-Host "  [?] Frecuencia inesperada: $freq" -ForegroundColor Yellow }

    if ($platform -ne "mt6878") { Write-Host "  [!] Plataforma inesperada: $platform (esperado mt6878)" -ForegroundColor Yellow }
}

# --- Modo bootloader (fastboot) -------------------------------------------------
Write-Host "[2] Verificando en modo bootloader (fastboot)..." -ForegroundColor Yellow
Write-Host "  Si no está en fastboot, reinicia con: adb reboot bootloader" -ForegroundColor Yellow
Write-Host "  (o apaga y mantén Vol- + Power)" -ForegroundColor Yellow

$devices = & $Fastboot devices 2>&1
if ($devices -match "fastboot") {
    Write-Host "[OK] Dispositivo en fastboot: $($devices.Trim())" -ForegroundColor Green
    $secure = & $Fastboot getvar securestate 2>&1 | Out-String
    $slotv  = & $Fastboot getvar current-slot 2>&1 | Out-String
    Write-Host "  securestate: $($secure.Trim())"
    Write-Host "  current-slot: $($slotv.Trim())"

    if ($secure -match "flashing_unlocked") {
        Write-Host "  [OK] Bootloader desbloqueado - listo para flashear" -ForegroundColor Green
    } else {
        Write-Host "  [!] Bootloader NO desbloqueado. Necesitas: fastboot oem unlock" -ForegroundColor Red
        Write-Host "  [!] OJO: esto borra el teléfono y anula la garantía." -ForegroundColor Red
    }
} else {
    Write-Host "  No hay dispositivo en fastboot - conéctalo con el teléfono apagado" -ForegroundColor Yellow
    Write-Host "  manteniendo Vol- + Power, o desde ADB: adb reboot bootloader" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Si todo coincide con lo esperado, continúa con:" -ForegroundColor Cyan
Write-Host "  .\scripts\backup_rom1.ps1   (descargar respaldo)" -ForegroundColor Cyan
Write-Host "  .\scripts\install_rom3.ps1  (instalar ROM 3)" -ForegroundColor Cyan
