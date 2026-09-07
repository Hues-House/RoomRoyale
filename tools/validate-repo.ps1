[CmdletBinding()]
param(
    [switch]$SkipRojo
)

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'PowerShell 7 or newer is required. Run this script with pwsh.'
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Require-File {
    param([string]$RelativePath)

    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing required file: $RelativePath")
    }
}

@(
    'AGENTS.md',
    'README.md',
    'CONTEXT.md',
    'default.project.json',
    '.editorconfig',
    '.gitignore',
    'docs/README.md',
    'docs/game_systems.md',
    'docs/ui_system.md',
    'docs/public-beta-readiness-audit-2026-08-30.md',
    '.scratch/README.md'
) | ForEach-Object { Require-File $_ }

$issueDirectory = Join-Path $repoRoot '.scratch\issues'
if (-not (Test-Path -LiteralPath $issueDirectory -PathType Container)) {
    $failures.Add('Missing issue directory: .scratch/issues')
} else {
    $issueFiles = @(Get-ChildItem -LiteralPath $issueDirectory -Filter '*.md' -File)
    if ($issueFiles.Count -eq 0) {
        $failures.Add('The local issue backlog is empty: .scratch/issues')
    }

    foreach ($issueFile in $issueFiles) {
        $content = Get-Content -LiteralPath $issueFile.FullName -Raw
        $frontmatterMatch = [regex]::Match($content, '(?s)\A---\r?\n(?<metadata>.*?)\r?\n---')
        if (-not $frontmatterMatch.Success) {
            $failures.Add("Issue has no frontmatter: $($issueFile.Name)")
            continue
        }

        $metadata = $frontmatterMatch.Groups['metadata'].Value
        foreach ($field in @('title', 'status', 'priority', 'source')) {
            if ($metadata -notmatch "(?m)^${field}:\s*\S") {
                $failures.Add("Issue is missing '$field': $($issueFile.Name)")
            }
        }
    }
}

$gitignore = Join-Path $repoRoot '.gitignore'
if (Test-Path -LiteralPath $gitignore -PathType Leaf) {
    $gitignoreContent = Get-Content -LiteralPath $gitignore -Raw
    foreach ($pattern in @('/_gdd_extract/', '/rbxlx_extract/', '/rbxlx_extract_updated/', '/build/')) {
        if ($gitignoreContent -notmatch [regex]::Escape($pattern)) {
            $failures.Add(".gitignore does not exclude $pattern")
        }
    }
}

if (-not $SkipRojo) {
    $rojoCommand = Get-Command rojo -ErrorAction SilentlyContinue
    if ($null -eq $rojoCommand) {
        $failures.Add('Rojo is not available on PATH. Install Rojo or rerun with -SkipRojo.')
    } else {
        $projectFile = Join-Path $repoRoot 'default.project.json'
        $buildFile = Join-Path ([System.IO.Path]::GetTempPath()) ("RoomRoyale-" + [guid]::NewGuid().ToString() + '.rbxlx')
        try {
            & $rojoCommand.Source build $projectFile --output $buildFile
            if ($LASTEXITCODE -ne 0) {
                $failures.Add("Rojo build failed with exit code $LASTEXITCODE")
            } elseif (-not (Test-Path -LiteralPath $buildFile -PathType Leaf)) {
                $failures.Add('Rojo reported success but did not create a place file.')
            }
        } catch {
            $failures.Add("Rojo build failed: $($_.Exception.Message)")
        } finally {
            if (Test-Path -LiteralPath $buildFile) {
                Remove-Item -LiteralPath $buildFile -Force
            }
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

$issueCount = @(Get-ChildItem -LiteralPath $issueDirectory -Filter '*.md' -File).Count
Write-Output "Repository validation passed. Checked $issueCount local issues and the Rojo project configuration."
