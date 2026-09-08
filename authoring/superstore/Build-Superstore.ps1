[CmdletBinding()]
param(
    [string]$Output = 'build/superstore/RoomRoyale-Hillside-v4.rbxlx',
    [string]$LuauDirectory = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$luauTools = & (Join-Path $repo 'tools/Resolve-Luau.ps1') -LuauDirectory $LuauDirectory
Push-Location $repo
try {
    & $luauTools.Luau tests/ride/run.lua
    if ($LASTEXITCODE -ne 0) { throw 'Ride behavior checks failed.' }
    & $luauTools.Luau tests/ride/ShoppingSession.spec.lua
    if ($LASTEXITCODE -ne 0) { throw 'Shopping session checks failed.' }
    $scripts = @(Get-ChildItem packages/RideRuntime,prototype/cart-lab,prototype/superstore,tests/ride,tests/superstore -Filter '*.lua' -File)
    & $luauTools.Compiler --null @($scripts.FullName)
    if ($LASTEXITCODE -ne 0) { throw 'Superstore Luau compilation failed.' }
    New-Item -ItemType Directory -Force build/superstore | Out-Null
    & rojo build superstore.project.json --output $Output
    if ($LASTEXITCODE -ne 0) { throw 'Superstore Rojo build failed.' }
} finally {
    Pop-Location
}
