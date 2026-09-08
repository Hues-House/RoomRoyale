[CmdletBinding()]
param(
    [string]$LuauDirectory = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$buildDirectory = Join-Path $repoRoot 'build'
New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null

$luauTools = & (Join-Path $PSScriptRoot 'Resolve-Luau.ps1') -LuauDirectory $LuauDirectory

Push-Location $repoRoot
try {
    & $luauTools.Luau tests/ride/run.lua
    if ($LASTEXITCODE -ne 0) { throw 'Ride behavior checks failed.' }
    $scripts = @(Get-ChildItem packages/RideRuntime,prototype/cart-lab,tests/ride -Filter '*.lua' -File -Recurse)
    & $luauTools.Compiler --null @($scripts.FullName)
    if ($LASTEXITCODE -ne 0) { throw 'Luau compilation failed.' }
    & rojo build cart-lab.project.json --output (Join-Path $buildDirectory 'RoomRoyale-CartLab.rbxlx')
    if ($LASTEXITCODE -ne 0) { throw 'Cart lab Rojo build failed.' }
} finally {
    Pop-Location
}
Write-Output 'Built build/RoomRoyale-CartLab.rbxlx. This project does not include the production round scripts or DataStores.'
