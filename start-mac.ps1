# Enciende una Mac en GitHub Actions conectada a tu PC via Tailscale.
# Uso:  .\start-mac.ps1                 (60 min, abre http://localhost:3000)
#       .\start-mac.ps1 -Minutes 30 -Url "http://localhost:3000/login"
param(
  [int]$Minutes = 60,
  [string]$Url = "http://localhost:3000"
)

$ErrorActionPreference = "Stop"
$ts = "C:\Program Files\Tailscale\tailscale.exe"
$repo = "jbernalDEV/mac-testing"
$ports = 3000, 3008, 3010, 4000, 8000, 8080

$ip = (& $ts ip -4 | Select-Object -First 1)
if (-not $ip) { throw "Tailscale no esta conectado. Abre Tailscale e inicia sesion." }

# Expone SOLO estos puertos y SOLO dentro de tu red Tailscale (puerto + 10000 -> 127.0.0.1:puerto)
foreach ($p in $ports) {
  & $ts serve --bg --tcp ($p + 10000) "tcp://127.0.0.1:$p" | Out-Null
}
Write-Host "Puertos expuestos en Tailscale ($ip): $($ports -join ', ')"

$listening = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
if (-not $listening) { Write-Warning "Nada escucha en :3000. Corre 'pnpm start' en caring_data_react." }

gh workflow run mac-testing.yml -R $repo -f pc=$ip -f url=$Url -f minutes=$Minutes
Start-Sleep -Seconds 5
$run = gh run list -R $repo -w mac-testing.yml -L 1 --json url --jq '.[0].url'

Write-Host ""
Write-Host "Mac encendiendose (~2-3 min). Progreso: $run"
Write-Host "Cuando el paso 'Habilitar VNC' termine, abre TigerVNC y conecta a:  gh-mac:5900"
Write-Host "Para apagar todo:  .\stop-mac.ps1"
