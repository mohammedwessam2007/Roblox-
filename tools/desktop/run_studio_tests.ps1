# Windows one-click: run the engine test suite inside REAL Roblox Studio and save the output.
# Run from the repo folder:  powershell -ExecutionPolicy Bypass -File tools\desktop\run_studio_tests.ps1
# Free tools only (hash-pinned): Rojo 7.6.1 and run-in-roblox 0.3.0. Nothing is published or uploaded.
# Output: reports\STUDIO_TEST_OUTPUT.txt (commit it, or tell Claude it exists).
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$bin = Join-Path $env:LOCALAPPDATA 'StealRealityTools'
New-Item -ItemType Directory -Force -Path $bin | Out-Null

$studio = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Roblox\Versions\*\RobloxStudioBeta.exe') -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
if (!$studio) { Write-Host 'Roblox Studio not found. Install it (free): https://create.roblox.com/docs/studio/setup'; exit 2 }
$studioVersion = (Get-Item $studio.FullName).VersionInfo.ProductVersion
$studioFolder = Split-Path (Split-Path $studio.FullName) -Leaf

function Get-Pinned($url, $zipName, $sha, $exe) {
  $target = Join-Path $bin $exe
  if (!(Test-Path $target)) {
    $zip = Join-Path $bin $zipName
    Invoke-WebRequest -Uri $url -OutFile $zip
    if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne $sha) { throw "$zipName hash mismatch" }
    Expand-Archive $zip -DestinationPath $bin -Force
  }
  return $target
}
$rojo = Get-Pinned 'https://github.com/rojo-rbx/rojo/releases/download/v7.6.1/rojo-7.6.1-windows-x86_64.zip' 'rojo.zip' 'E1C9A78193C609720F3AFB38057D3909ED483ECBF5E9E3541313BA0DCBC4F1F8' 'rojo.exe'
$rir = Get-Pinned 'https://github.com/rojo-rbx/run-in-roblox/releases/download/v0.3.0/run-in-roblox-0.3.0-win64.zip' 'run-in-roblox.zip' '590738BF134C0A1D3D6F865089BEC8288FE7B7EC388471780F1F48B22D12440F' 'run-in-roblox.exe'

git -C $root pull --ff-only
$place = Join-Path $root 'build\StealRealityTest.rbxl'
New-Item -ItemType Directory -Force -Path (Split-Path $place) | Out-Null
& $rojo build (Join-Path $root 'test.project.json') -o $place
$out = Join-Path $root 'reports\STUDIO_TEST_OUTPUT.txt'
$header = @(
  "date_utc: $((Get-Date).ToUniversalTime().ToString('s'))Z",
  "os: $([System.Environment]::OSVersion.VersionString)",
  "studio: $studioFolder ($studioVersion)",
  "place_sha256: $((Get-FileHash $place).Hash)",
  "command: run-in-roblox --place build\StealRealityTest.rbxl --script tools\studio\studio_engine_tests.luau",
  '---'
)
$header | Set-Content -Encoding utf8 $out
Write-Host 'Launching Studio via run-in-roblox (Studio must be signed in)...'
& $rir --place $place --script (Join-Path $root 'tools\studio\studio_engine_tests.luau') 2>&1 | Tee-Object -FilePath $out -Append
"exit_code: $LASTEXITCODE" | Add-Content $out
Write-Host "Saved $out"
Select-String -Path $out -Pattern 'ENGINE_TESTS:|^FAIL ' | ForEach-Object { $_.Line }
Write-Host 'If no ENGINE_TESTS line appeared: open build\StealRealityTest.rbxl in Studio, Test > Run, then paste'
Write-Host 'tools\studio\studio_engine_tests.luau into the server Command Bar and copy the Output into that file.'
