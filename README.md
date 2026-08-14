# Motorola Edge 60 XT2505-4 → ROM Global RETBR (XT2505-3) · Android 16

Cambio seguro de ROM en el **Motorola Edge 60 XT2505-4** (variante China/RETCN) a la
**ROM global RETBR de Brasil (Android 16)** para reactivar las **actualizaciones OTA**.
Procedimiento probado con éxito (66/66 pasos de flash OK) y documentado con antecedentes.

> ⚠️ **LEE TODO ANTES DE EMPEZAR.** Flashear firmware es riesgoso: puede brickear el
> teléfono. El procedimiento documentado aquí se ejecutó con éxito, pero la responsabilidad
> del resultado es de quien lo ejecuta.

---

## 📋 Resumen del dispositivo

| Dato | Valor |
|---|---|
| Modelo | Motorola Edge 60 (XT2505-4, variante CN) |
| Codename | `scout` (`scout_g_sys`) |
| Plataforma | MT6878 (**Dimensity 7400**, 2.6 GHz) |
| Build original | `V2VC35.33-132-4` (Android 15) · canal `retcn` |
| Bootloader | MBM-3.1-scout-904faf · `flashing_unlocked` (de fábrica, **sin desbloquear**) |
| Baseband | `MT6878M_NR17.RC.MP.V18.6.3.P30.02.202R` |
| **ROM instalada** | **RETBR Android 16 `W1VCS36H.14-20-19-7`** · canal `retbr` |

---

## ⚠️ Advertencias críticas

1. **Garantía anulada** — el desbloqueo del bootloader + flash marca `iswarrantyvoid: yes`.
2. **Datos personales borrados** — el flash ejecuta `erase userdata`. Respalda tus datos
   (Google y/o MTP) antes.
3. **IMEI/calibración intactos** — el flash NO toca `nvram`, `md_sec`, `utags`, `proinfo`,
   `cid`, `frp`, `seccfg`, `persist`, `protect1/2`.
4. **NO reloquear el bootloader después** — riesgo real de brick en esta plataforma
   (ver sección [Relock](#-relock--no-cerrar-el-bootloader)).
5. **Nombre mostrado "Edge 60 Fusion"** después del flash: **normal**. El firmware `scout`
   es compartido entre XT2503-4 (Edge 60 Fusion) y XT2505 (Edge 60) — paquetes idénticos
   en lolinet. Es cosmético y no afecta el funcionamiento.

---

## 🔗 Links de firmware

### ROM 1 — RETEU Android 15 (RESPALDO / ROLLBACK)
Es la **misma build que trae el XT2505-4 de fábrica** (`V2VC35.33-132-4`). Úsala para
volver al estado original si algo sale mal.

```
https://mirrors.lolinet.com/firmware/lenomola/2025/scout/official/RETEU/XT2505-1_SCOUT_RETEU_15_V2VC35.33-132-4.zip
```
- Tamaño: 5.902.248.359 bytes (5.5 GB)

### ROM 3 — RETBR Android 16 (OBJETIVO / INSTALADA)
Build `W1VCS36H.14-20-19-7` (julio 2026), publicada por stockrom.net. Descarga vía
Google Drive (file id `1ucrNLrLcZtY8QXzkrg84Rj8cxfU4wMOX`):

- Página: https://www.stockrom.net/2026/07/xt2505-3-retbr-os16-w1vcs36h-14-20-19-7.html
- Tamaño: 6.389.637.018 bytes (5.95 GB)

> Verifica siempre que el tamaño del archivo descargado coincida con el publicado.

---

## 📜 Antecedentes documentados de éxito

| Antecedente | Resultado |
|---|---|
| **4PDA hilo Edge 60** (showtopic=1104228), post #406 (Neon_1, nov 2025) | Usuario XT2505-4 flasheó `XT2505-1 RETEU 132-4`, canal `retru` → **recibió OTA** (132-4-1 y 134-2). Confirmado por baikal0912: *"Si la ROM no coincidiera con el modelo, ¿cómo cargaría, funcionaría y recibiría actualizaciones?"* |
| **4PDA hilo Edge 60 Pro** (showtopic=1106498, misma plataforma MTK 2025) | Flash Android 16 + canal configurado → OTA inmediatas tras reboot. Nota: canal `reteu` NO se aplica en estas unidades; usar `retru` o `retbr`. |
| **Firmware scout compartido** | XT2503-4 (Fusion) y XT2505 (Edge 60) usan el **mismo paquete** en lolinet (tamaños idénticos) → por eso el teléfono muestra "Edge 60 Fusion" tras el flash (cosmético, post p=139726339). |

---

## 🛠 Requisitos

- PC con **Windows** (PowerShell) y **25 GB libres**
- **platform-tools oficial**: https://developer.android.com/tools/releases/platform-tools
  (se asume en `C:\adb\platform-tools`; ajusta la variable `$PlatformTools` en los scripts)
- Teléfono con **bootloader desbloqueado** (el XT2505-4 viene `flashing_unlocked` de fábrica — no se ejecuta ningún unlock en este procedimiento)
- Cable USB original con transferencia de datos
- Batería ≥ 70%

---

## 🚀 Instrucciones paso a paso

### Paso 1 — Verifica tu teléfono (ADB)

Con el teléfono encendido y depuración USB activada
(Ajustes → Acerca del teléfono → toca "Número de compilación" 7 veces → Sistema →
Opciones de desarrollador → Depuración USB):

```powershell
C:\adb\platform-tools\adb.exe devices -l
C:\adb\platform-tools\adb.exe shell "cat /sys/devices/system/cpu/cpu4/cpufreq/cpuinfo_max_freq; getprop ro.board.platform; getprop ro.build.display.id; getprop ro.carrier"
```

**Esperado (este caso):** `2600000` (Dimensity 7400), `mt6878`, `V2VC35.33-132-4`, `retcn`.
Alternativa: ejecuta `scripts/verify_device.ps1`.

### Paso 2 — Verifica el estado del bootloader

**Este procedimiento NO desbloquea el bootloader.** El XT2505-4 (variante China)
viene con el bootloader **desbloqueado de fábrica** (`securestate: flashing_unlocked`
— verificado en vivo en el primer `getvar all`, sin ejecutar ningún comando de unlock).

```powershell
C:\adb\platform-tools\adb.exe reboot bootloader
C:\adb\platform-tools\fastboot.exe getvar securestate # debe decir: flashing_unlocked
```

> ### Si tu unidad viene bloqueada (`oem_locked`) — desbloqueo oficial actual
>
> Motorola ya no usa `fastboot oem unlock` a secas (comando de dispositivos antiguos).
> En los MBM-3.1 modernos el desbloqueo oficial es por **unlock code**:
>
> ```powershell
> # 1. Obtén el unlock data del dispositivo (en modo fastboot)
> C:\adb\platform-tools\fastboot.exe oem get_unlock_data
>
> # 2. Copia el código de salida en UNA sola línea (quita los prefijos "(bootloader)")
> #    Ej. 3A95975700879246#5A5932324447544E3344006D6F746F2067200000#024D44FE...  (formato real)
>
> # 3. Pégalo en la página oficial de Motorola y solicita el código:
> #    https://en-us.support.motorola.com/app/standalone/bootloader/unlock-your-device-b
> #    (Si el CID de tu unidad no califica, la página responderá
> #    "Your device does not qualify for bootloader unlocking" y no habrá código.)
>
> # 4. Motorola te envía el unlock key por email. Úsalo así:
> C:\adb\platform-tools\fastboot.exe flashing unlock <UNLOCK_KEY>
> #    (en algunos modelos: fastboot oem unlock <UNLOCK_KEY>)
>
> # 5. Confirma en pantalla y verifica:
> C:\adb\platform-tools\fastboot.exe getvar securestate   # ahora: flashing_unlocked
> ```
>
> ⚠️ Desbloquear **borra todo** el teléfono y marca `iswarrantyvoid: yes`.
> Y una vez con ROM global instalada, **no vuelvas a bloquearlo** (ver sección Relock).

### Paso 3 — Descarga los dos firmwares

```powershell
# ROM 1 (respaldo) — desde lolinet
curl.exe -L -o "C:\Edge60_Firmware\XT2505-1_RETEU_15_V2VC35.33-132-4.zip" "https://mirrors.lolinet.com/firmware/lenomola/2025/scout/official/RETEU/XT2505-1_SCOUT_RETEU_15_V2VC35.33-132-4.zip"

# ROM 3 (objetivo) — desde Google Drive (link de stockrom.net)
curl.exe -L -o "C:\Edge60_Firmware\XT2505-3_RETBR_16_W1VCS36H.14-20-19-7.zip" "<link directo del Drive>"
```

Verifica los tamaños: ROM 1 = **5.902.248.359 bytes** · ROM 3 = **6.389.637.018 bytes**.

### Paso 4 — Verifica los flashfile.xml (ambas ROMs deben tener la misma estructura)

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead("C:\Edge60_Firmware\XT2505-1_RETEU_15_V2VC35.33-132-4.zip")
[System.IO.Compression.ZipFileExtensions]::ExtractToFile(($zip.Entries | Where-Object { $_.Name -eq "flashfile.xml" }), "C:\Edge60_Firmware\flashfile_ROM1.xml", $true)
$zip.Dispose()
$zip = [System.IO.Compression.ZipFile]::OpenRead("C:\Edge60_Firmware\XT2505-3_RETBR_16_W1VCS36H.14-20-19-7.zip")
[System.IO.Compression.ZipFileExtensions]::ExtractToFile(($zip.Entries | Where-Object { $_.Name -eq "flashfile.xml" }), "C:\Edge60_Firmware\flashfile_ROM3.xml", $true)
$zip.Dispose()
```

### Paso 5 — Extrae la ROM 3 y verifica MD5 (57/57)

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
$dest = "C:\Edge60_Firmware\flash3"
New-Item -ItemType Directory -Path $dest -Force | Out-Null
$zip = [System.IO.Compression.ZipFile]::OpenRead("C:\Edge60_Firmware\XT2505-3_RETBR_16_W1VCS36H.14-20-19-7.zip")
foreach ($e in $zip.Entries) { [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, (Join-Path $dest $e.Name), $true) }
$zip.Dispose()

# Compara cada MD5 contra el flashfile.xml — deben coincidir TODOS (57/57)
Get-FileHash "C:\Edge60_Firmware\flash3\*" -Algorithm MD5 | Select-Object Hash, Path
```

**Si algún MD5 NO coincide: ROM corrupta → redescarga. NUNCA flashees con MD5 fallido.**
Alternativa: ejecuta `scripts/install_rom3.ps1` (hace extracción + MD5 + flash + canal).

### Paso 6 — Flash de la ROM 3 (66 pasos, orden exacto del flashfile.xml)

El script `scripts/install_rom3.ps1` replica el orden exacto y se detiene ante el
primer error. Orden de las particiones:

```
gpt → preloader → lk_a → tee_a → mcupm_a → pi_img_a → sspm_a → dtbo_a → logo_a
→ [erase nvdata] → spmfw_a → scp_a → vbmeta_a → vbmeta_system_a → modem_a → dpm_a
→ gz_a → mcf_ota_a → ccu_a → vcp_a → gpueb_a → apusys_a → connsys_bt/gnss/wifi
→ efuseBackup → init_boot_a → boot_a → vendor_boot_a → super (29 chunks)
→ [erase userdata] → [erase metadata] → [erase debug_token]
```

Comandos manuales equivalentes (por si prefieres uno en uno):

```powershell
$fb = "C:\adb\platform-tools\fastboot.exe"
Set-Location "C:\Edge60_Firmware\flash3"
& $fb flash gpt gpt_main0.bin
& $fb flash preloader preloader_scout.bin
& $fb flash lk_a lk_a.img
& $fb flash tee_a tee_a.img
& $fb flash mcupm_a mcupm_a.img
& $fb flash pi_img_a pi_img_a.img
& $fb flash sspm_a sspm_a.img
& $fb flash dtbo_a dtbo_a.img
& $fb flash logo_a logo_a.img
& $fb erase nvdata
& $fb flash spmfw_a spmfw_a.img
& $fb flash scp_a scp_a.img
& $fb flash vbmeta_a vbmeta_a.img
& $fb flash vbmeta_system_a vbmeta_system_a.img
& $fb flash modem_a modem_a.img
& $fb flash dpm_a dpm_a.img
& $fb flash gz_a gz_a.img
& $fb flash mcf_ota_a mcf_ota_a.img
& $fb flash ccu_a ccu_a.img
& $fb flash vcp_a vcp_a.img
& $fb flash gpueb_a gpueb_a.img
& $fb flash apusys_a apusys_a.img
& $fb flash connsys_bt_a connsys_bt_a.bin
& $fb flash connsys_gnss_a connsys_gnss_a.bin
& $fb flash connsys_wifi_a connsys_wifi_a.bin
& $fb flash efuseBackup efuse_backup.img
& $fb flash init_boot_a init_boot_a.img
& $fb flash boot_a boot_a.img
& $fb flash vendor_boot_a vendor_boot_a.img
# super: 29 chunks super.img_sparsechunk.0 ... super.img_sparsechunk.28
& $fb flash super super.img_sparsechunk.0   # repetir para cada chunk (0-28)
& $fb erase userdata
& $fb erase metadata
& $fb erase debug_token
```

> ⚠️ Si un paso falla: **NO reinicies**. Repite el paso fallido. Si falla repetido,
> restaura la ROM 1 (rollback) con el mismo procedimiento.

### Paso 7 — Configura el canal de actualizaciones (Brasil)

```powershell
C:\adb\platform-tools\fastboot.exe oem config carrier retbr
# Resultado esperado: OK / finished
```

> El canal define de dónde llegan las OTA. `retru` y `retbr` funcionan en estas
> unidades; `reteu` NO se aplica (documentado en 4PDA).

### Paso 8 — Reinicia y verifica

```powershell
C:\adb\platform-tools\fastboot.exe reboot
```

Esperado (documentado):
1. Warning de bootloader desbloqueado → normal, inofensivo
2. Primer arranque: varios minutos (optimización de apps)
3. Android 16 con **señal y WiFi funcionando**
4. Restaura tu info desde la cuenta Google
5. Puede mostrar "Edge 60 Fusion" → cosmético (ver advertencias)

### Paso 9 — Verificación final (ADB)

```powershell
C:\adb\platform-tools\adb.exe devices -l
C:\adb\platform-tools\adb.exe shell getprop ro.build.version.release   # 16
C:\adb\platform-tools\adb.exe shell getprop ro.build.display.id        # W1VCS36H.14-20-19-7
C:\adb\platform-tools\adb.exe shell getprop ro.carrier                 # retbr
```

---

## 🔒 Relock — NO cerrar el bootloader

| Opción | Consecuencia documentada |
|---|---|
| **Relock (`fastboot oem lock`)** | ⚠️ **Brick "No valid OS"** — antecedente Edge 60 Pro (XDA, nov 2025, misma plataforma MTK 2025). Recuperación SOLO con ROM nativa RETCN + bootloader bloqueado. BROM deshabilitado por eFuse en MTK 2024-2025 → **sin rescate por mtkclient**. |
| **Dejar abierto (RECOMENDADO)** | ✅ Funciona perfecto. Solo el warning de bootloader al encender (cosmético). Recibe OTA normalmente. |

**El bootloader debe quedar ABIERTO.** No intentes cerrarlo.

---

## ↩️ Rollback (volver al estado original)

La **ROM 1 (RETEU Android 15)** es idéntica a la build de fábrica del XT2505-4.
Procedimiento idéntico al Paso 6 pero con las imágenes extraídas de la ROM 1
(`scripts/backup_rom1.ps1` incluye la descarga y verificación). Después del flash,
reconfigura el canal:

```powershell
C:\adb\platform-tools\fastboot.exe oem config carrier retcn
```

---

## 📁 Estructura del repo

```
├── README.md                    ← este instructivo
└── scripts/
    ├── backup_rom1.ps1          ← descarga + verifica la ROM 1 (rollback)
    ├── install_rom3.ps1         ← extrae + verifica MD5 + flash 66 pasos + canal retbr
    └── verify_device.ps1        ← diagnóstico ADB/fastboot pre-flash
```

> Los firmwares (~11.5 GB en total) **no se almacenan en este repo** — se referencian
> los links oficiales de arriba. Descárgalos con los scripts.

---

## 📝 Nota legal

Este repositorio es una guía técnica independiente. Motorola, Edge 60, Edge 60 Fusion,
Dimensity y MTK son marcas de sus respectivos dueños. El uso del firmware oficial es
bajo tu propio riesgo.
