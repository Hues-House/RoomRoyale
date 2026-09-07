[CmdletBinding()]
param()

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'PowerShell 7 or newer is required. Run this script with pwsh.'
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'docs\studio-source-manifest.json'
$capturePath = Join-Path $repoRoot 'docs\studio-source-capture-2026-09-06.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$capture = Get-Content -LiteralPath $capturePath -Raw | ConvertFrom-Json
$failures = [System.Collections.Generic.List[string]]::new()

function Get-NormalizedSource {
    param([string]$Path)

    $source = [System.IO.File]::ReadAllText($Path)
    $source = $source.Replace("`r`n", "`n").Replace("`r", "`n")
    return $source.TrimEnd([char[]]"`n") + "`n"
}

function Get-Fnv1a32 {
    param([string]$Text)

    [uint32]$hash = 2166136261
    foreach ($byte in [System.Text.Encoding]::UTF8.GetBytes($Text)) {
        $hash = [uint32]($hash -bxor [uint32]$byte)
        $hash = [uint32](([uint64]$hash * [uint64]16777619) % [uint64]4294967296)
    }
    return $hash.ToString('x8')
}

function Compare-CapturedFields {
    param([object]$ManifestEntry, [object]$CaptureEntry, [string]$Label)

    foreach ($field in @('path', 'className', 'disabled', 'bytes', 'lines', 'fnv1a32')) {
        if ($ManifestEntry.$field -ne $CaptureEntry.$field) {
            $failures.Add("Captured $field differs for ${Label}: manifest '$($ManifestEntry.$field)', Studio '$($CaptureEntry.$field)'")
        }
    }
}

if ($capture.studio.placeId -ne 86511797738570 -or $capture.studio.mode -ne 'Edit') {
    $failures.Add('Studio capture must identify test PlaceId 86511797738570 in Edit mode')
}
if ($capture.counts.total -ne 57 -or $capture.counts.managed -ne 50 -or $capture.counts.excluded -ne 7) {
    $failures.Add('Studio capture counts must be 57 total, 50 managed, and 7 excluded')
}
if ($capture.postImportReread.managedChecked -ne 50 -or $capture.postImportReread.mismatches -ne 0) {
    $failures.Add('Studio capture must record a clean post-import reread of all 50 managed scripts')
}

$captureByPath = @{}
$captureByDebugId = @{}
$captureIdentities = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($entry in $capture.scripts) {
    $identity = "$($entry.path)#$($entry.pathOrdinal)"
    if (-not $captureIdentities.Add($identity)) {
        $failures.Add("Duplicate Studio capture identity: $identity")
    }
    if ($captureByDebugId.ContainsKey([string]$entry.debugId)) {
        $failures.Add("Duplicate Studio debugId: $($entry.debugId)")
    } else {
        $captureByDebugId[[string]$entry.debugId] = $entry
    }
    if (-not [bool]$entry.excluded) {
        if ($captureByPath.ContainsKey([string]$entry.path)) {
            $failures.Add("Duplicate managed Studio path: $($entry.path)")
        } else {
            $captureByPath[[string]$entry.path] = $entry
        }
    }
}

$expectedFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($script in $manifest.scripts) {
    $relativeFile = [string]$script.file
    [void]$expectedFiles.Add($relativeFile.Replace('\', '/'))
    $fullPath = Join-Path $repoRoot $relativeFile

    if (-not $captureByPath.ContainsKey([string]$script.path)) {
        $failures.Add("Managed manifest path is absent from Studio capture: $($script.path)")
    } else {
        Compare-CapturedFields -ManifestEntry $script -CaptureEntry $captureByPath[[string]$script.path] -Label ([string]$script.path)
    }

    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        $failures.Add("Missing imported source: $relativeFile")
        continue
    }

    $source = Get-NormalizedSource -Path $fullPath
    $bytes = [System.Text.Encoding]::UTF8.GetByteCount($source)
    $lines = [regex]::Matches($source, "`n").Count
    $hash = Get-Fnv1a32 -Text $source

    if ($bytes -ne [int]$script.bytes) {
        $failures.Add("Byte count differs for ${relativeFile}: expected $($script.bytes), got $bytes")
    }
    if ($lines -ne [int]$script.lines) {
        $failures.Add("Line count differs for ${relativeFile}: expected $($script.lines), got $lines")
    }
    if ($hash -ne [string]$script.fnv1a32) {
        $failures.Add("Source hash differs for ${relativeFile}: expected $($script.fnv1a32), got $hash")
    }

    if ([bool]$script.disabled) {
        $metaRelative = $relativeFile -replace '\.(server|client)\.lua$', '.meta.json'
        $metaPath = Join-Path $repoRoot $metaRelative
        if (-not (Test-Path -LiteralPath $metaPath -PathType Leaf)) {
            $failures.Add("Missing Disabled metadata for $relativeFile")
        } else {
            $meta = Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json
            if ($meta.properties.Disabled -ne $true) {
                $failures.Add("Disabled metadata is not true for $relativeFile")
            }
        }
    }
}

foreach ($excluded in $manifest.excluded) {
    $label = "$($excluded.path)#$($excluded.pathOrdinal)"
    if ([string]::IsNullOrWhiteSpace([string]$excluded.debugId) -or
        [string]::IsNullOrWhiteSpace([string]$excluded.reason) -or
        $excluded.pathOrdinal -lt 1 -or
        $excluded.lines -lt 1 -or
        $excluded.bytes -lt 0 -or
        $excluded.fnv1a32 -notmatch '^[0-9a-f]{8}$' -or
        $excluded.className -ne 'Script' -or
        $excluded.disabled -ne $true) {
        $failures.Add("Excluded manifest entry is incomplete: $label")
        continue
    }
    if (-not $captureByDebugId.ContainsKey([string]$excluded.debugId)) {
        $failures.Add("Excluded entry is absent from Studio capture: $label")
        continue
    }
    $captured = $captureByDebugId[[string]$excluded.debugId]
    if (-not [bool]$captured.excluded -or $captured.pathOrdinal -ne $excluded.pathOrdinal) {
        $failures.Add("Excluded Studio identity differs for $label")
    }
    Compare-CapturedFields -ManifestEntry $excluded -CaptureEntry $captured -Label $label
}

$srcRoot = Join-Path $repoRoot 'src'
foreach ($file in Get-ChildItem -LiteralPath $srcRoot -Recurse -File -Filter '*.lua') {
    $relative = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName).Replace('\', '/')
    if (-not $expectedFiles.Contains($relative)) {
        $failures.Add("Untracked Lua source in Rojo tree: $relative")
    }
}

if ($manifest.scripts.Count -ne 50) {
    $failures.Add("Manifest must contain 50 managed scripts, found $($manifest.scripts.Count)")
}
if ($manifest.excluded.Count -ne 7) {
    $failures.Add("Manifest must record 7 excluded archive scripts, found $($manifest.excluded.Count)")
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'Studio source baseline verified: 50 managed scripts and 7 excluded archive scripts match the durable Edit-mode capture.'
