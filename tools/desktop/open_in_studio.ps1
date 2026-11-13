# Windows one-click: build the latest game and open it in Roblox Studio.
# Run from the repo folder:  powershell -ExecutionPolicy Bypass -File tools\desktop\open_in_studio.ps1
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$bin = Join-Path $env:LOCALAPPDATA 'StealRealityTools'
New-Item -ItemType Directory -Force -Path $bin | Out-Null
$rojo = Join-Path $bin 'rojo.exe'
if (!(Test-Path $rojo)) {
  $zip = Join-Path $bin 'rojo.zip'
  Invoke-WebRequest -Uri 'https://github.com/rojo-rbx/rojo/releases/download/v7.6.1/rojo-7.6.1-windows-x86_64.zip' -OutFile $zip
  if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne 'e1c9a78193c609720f3afb38057d3909ed483ecbf5e9e3541313ba0dcbc4f1f8') { throw 'Rojo hash mismatch' }
  Expand-Archive $zip -DestinationPath $bin -Force
}
git -C $root pull --ff-only
$place = Join-Path $root 'build\StealReality.rbxl'
New-Item -ItemType Directory -Force -Path (Split-Path $place) | Out-Null
& $rojo build (Join-Path $root 'default.project.json') -o $place
Write-Host "Built $place  sha256=$((Get-FileHash $place).Hash)"
Start-Process $place   # .rbxl opens in Roblox Studio
Write-Host 'In Studio: press Play. To create the private test experience: File > Publish to Roblox As > Create new experience (stays private).'
