[CmdletBinding()]
param([string]$LuauDirectory = '')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$luauTools = & (Join-Path $repoRoot 'tools/Resolve-Luau.ps1') -LuauDirectory $LuauDirectory
$generatedDirectory = Join-Path $repoRoot '.scratch/generated'
New-Item -ItemType Directory -Path $generatedDirectory -Force | Out-Null
$source = Get-Content -LiteralPath (Join-Path $repoRoot 'prototype/cart-lab/Crashes.lua') -Raw
$runner = @'
local run = require("../../tests/ride/CrashReplay.spec")
local function loadCrashes(game, workspace, Vector3, Enum, OverlapParams)
'@ + "`n" + $source + "`n" + @'
end
run(loadCrashes)
'@
$runnerPath = Join-Path $generatedDirectory 'crash-replay.lua'
[System.IO.File]::WriteAllText($runnerPath, $runner, [System.Text.UTF8Encoding]::new($false))
& $luauTools.Luau $runnerPath
if ($LASTEXITCODE -ne 0) { throw 'Crash source replay failed.' }
