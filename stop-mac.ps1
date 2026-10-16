# Apaga la Mac y deja de exponer puertos de tu PC en Tailscale.
$ts = "C:\Program Files\Tailscale\tailscale.exe"
$repo = "jbernalDEV/mac-testing"

gh run list -R $repo -w mac-testing.yml --json databaseId,status --jq '.[] | select(.status != "completed") | .databaseId' |
  ForEach-Object { gh run cancel $_ -R $repo }

& $ts serve reset
Write-Host "Mac apagada y puertos cerrados."
