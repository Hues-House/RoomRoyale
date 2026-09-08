[CmdletBinding()]
param(
    [switch]$BuildOnly,
    [string]$LuauDirectory = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
& (Join-Path $repo 'authoring/superstore/Build-Superstore.ps1') -LuauDirectory $LuauDirectory
if ($BuildOnly) { return }
$versions = Join-Path $env:LOCALAPPDATA 'Roblox/Versions'
$studio = Get-ChildItem -LiteralPath $versions -Filter RobloxStudioBeta.exe -File -Recurse |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $studio) { throw 'Install Roblox Studio before opening the playtest.' }
$place = Join-Path $repo 'build/superstore/RoomRoyale-Hillside-v4.rbxlx'
Start-Process -FilePath $studio.FullName -ArgumentList ('"' + $place + '"')
Write-Output 'Opened Hillside v4. Press Play, then use Try the skate park for movement practice.'
