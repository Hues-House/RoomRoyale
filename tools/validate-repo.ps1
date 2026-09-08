[CmdletBinding()]
param([switch]$SkipRojo)
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Use PowerShell 7 or newer.' }
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
foreach ($relative in @('AGENTS.md','README.md','CONTEXT.md','default.project.json','superstore.project.json','.editorconfig','.gitignore','docs/README.md','docs/game_systems.md','docs/ui_system.md','docs/refinement-plan-2026-09-08.md','places/RoomRoyale-Test.rbxlx','places/RoomRoyale-Hillside.rbxlx')) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relative) -PathType Leaf)) { throw "Missing required file: $relative" }
}
function Test-ProjectPaths {
    param($Node, [string]$Project)
    if ($Node -is [System.Collections.IDictionary]) {
        foreach ($key in $Node.Keys) {
            if ($key -eq '$path' -and -not (Test-Path -LiteralPath (Join-Path $repoRoot $Node[$key]))) { throw "Missing mapped path in ${Project}: $($Node[$key])" }
            Test-ProjectPaths -Node $Node[$key] -Project $Project
        }
    } elseif ($Node -is [array]) {
        foreach ($child in $Node) { Test-ProjectPaths -Node $child -Project $Project }
    }
}
Get-ChildItem -LiteralPath $repoRoot -Filter '*.project.json' -File | ForEach-Object {
    Test-ProjectPaths -Node (Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json -AsHashtable) -Project $_.Name
}
if (-not $SkipRojo) { & (Join-Path $PSScriptRoot 'Verify-RojoBuild.ps1') }
Write-Output 'Repository validation passed: current entry points, saved places and all Rojo project paths exist.'
