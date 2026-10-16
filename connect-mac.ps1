# Abre TigerVNC conectado a la Mac de GitHub (busca su IP en Tailscale).
# La primera vez pide la contrasena VNC y la guarda en tu perfil (fuera del repo).
# Uso:  connect-mac.ps1               (rapido, menos colores)
#       connect-mac.ps1 -Calidad alta (colores completos, mas lento)
param([ValidateSet("rapida", "alta")][string]$Calidad = "rapida")
$ts = "C:\Program Files\Tailscale\tailscale.exe"
$viewer = "C:\Program Files\TigerVNC\vncviewer.exe"
$passwdFile = Join-Path $env:USERPROFILE ".vnc\mac-testing.passwd"

function Reverse-Bits([byte]$b) {
  $r = 0
  for ($i = 0; $i -lt 8; $i++) { if ($b -band (1 -shl $i)) { $r = $r -bor (1 -shl (7 - $i)) } }
  [byte]$r
}

# Archivo de contrasena en formato TigerVNC (DES con la llave fija de VNC)
if (-not (Test-Path $passwdFile)) {
  $secure = Read-Host "Contrasena VNC (secret VNC_PASSWORD)" -AsSecureString
  $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
  $data = New-Object byte[] 8
  $pb = [Text.Encoding]::ASCII.GetBytes($plain)
  [Array]::Copy($pb, $data, [Math]::Min(8, $pb.Length))
  $key = [byte[]](23, 82, 107, 6, 35, 78, 88, 7) | ForEach-Object { Reverse-Bits $_ }
  $des = [System.Security.Cryptography.DES]::Create()
  $des.Mode = "ECB"; $des.Padding = "None"
  $enc = $des.CreateEncryptor([byte[]]$key, (New-Object byte[] 8)).TransformFinalBlock($data, 0, 8)
  New-Item -ItemType Directory -Force (Split-Path $passwdFile) | Out-Null
  [IO.File]::WriteAllBytes($passwdFile, $enc)
}

$s = & $ts status --json | ConvertFrom-Json
$mac = $s.Peer.PSObject.Properties.Value | Where-Object { $_.HostName -like "gh-mac*" -and $_.Online } | Select-Object -First 1
if (-not $mac) { throw "No hay ninguna Mac encendida en tu Tailscale. Corre .\start-mac.ps1 primero." }
$ip = $mac.TailscaleIPs[0]

Write-Host "Conectando a la Mac en $ip ..."
# VncAuth: forzamos el metodo de contrasena VNC (la Mac ofrece metodos de Apple que TigerVNC no maneja)
# ZRLE + menos colores: mucho menos trafico. Usa -Calidad alta si necesitas ver colores exactos.
$quality = if ($Calidad -eq "alta") { @("-AutoSelect=1") } else { @("-AutoSelect=0", "-PreferredEncoding=ZRLE", "-FullColor=0", "-LowColorLevel=2") }
& $viewer "-SecurityTypes=VncAuth" "-PasswordFile=$passwdFile" @quality "${ip}::5900"
