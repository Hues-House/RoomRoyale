[CmdletBinding()]
param()

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'PowerShell 7 or newer is required. Run this script with pwsh.'
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $repoRoot 'default.project.json'
$failures = [System.Collections.Generic.List[string]]::new()
$buildPath = Join-Path ([System.IO.Path]::GetTempPath()) ("RoomRoyale-source-check-" + [guid]::NewGuid().ToString() + '.rbxlx')

function Get-NormalizedSource {
    param([string]$Source)

    $normalized = $Source.Replace("`r`n", "`n").Replace("`r", "`n")
    return $normalized.TrimEnd([char[]]"`n") + "`n"
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

function Get-ItemName {
    param([System.Xml.XmlElement]$Item)

    $nameNode = $Item.SelectSingleNode("./Properties/string[@name='Name']")
    if ($null -ne $nameNode) {
        return $nameNode.InnerText
    }
    return $Item.GetAttribute('class')
}

function Get-ItemPath {
    param([System.Xml.XmlElement]$Item)

    $segments = [System.Collections.Generic.List[string]]::new()
    $current = $Item
    while ($null -ne $current -and $current.Name -eq 'Item') {
        if ($current.GetAttribute('class') -eq 'DataModel') {
            break
        }
        $segments.Insert(0, (Get-ItemName -Item $current))
        $parent = $current.ParentNode
        while ($null -ne $parent -and $parent.Name -ne 'Item') {
            $parent = $parent.ParentNode
        }
        $current = $parent
    }
    return $segments -join '.'
}

function Get-ExpectedScripts {
    $mappings = @(
        [pscustomobject]@{ Disk = 'src\ReplicatedStorage'; Studio = 'ReplicatedStorage' },
        [pscustomobject]@{ Disk = 'src\ServerScriptService'; Studio = 'ServerScriptService' },
        [pscustomobject]@{ Disk = 'src\ServerStorage'; Studio = 'ServerStorage' },
        [pscustomobject]@{ Disk = 'src\StarterGui'; Studio = 'StarterGui' },
        [pscustomobject]@{ Disk = 'src\StarterPlayer\StarterPlayerScripts'; Studio = 'StarterPlayer.StarterPlayerScripts' }
    )
    $scripts = @{}

    foreach ($mapping in $mappings) {
        $diskRoot = Join-Path $repoRoot $mapping.Disk
        if (-not (Test-Path -LiteralPath $diskRoot -PathType Container)) {
            continue
        }

        foreach ($file in Get-ChildItem -LiteralPath $diskRoot -Recurse -File -Filter '*.lua') {
            $relative = [System.IO.Path]::GetRelativePath($diskRoot, $file.FullName).Replace('\', '/')
            $segments = [System.Collections.Generic.List[string]]::new()
            foreach ($segment in ($relative -split '/')) {
                $segments.Add($segment)
            }
            $fileName = $segments[$segments.Count - 1]
            $segments.RemoveAt($segments.Count - 1)

            if ($fileName -match '\.server\.lua$') {
                $className = 'Script'
                $instanceName = $fileName -replace '\.server\.lua$', ''
            } elseif ($fileName -match '\.client\.lua$') {
                $className = 'LocalScript'
                $instanceName = $fileName -replace '\.client\.lua$', ''
            } else {
                $className = 'ModuleScript'
                $instanceName = $fileName -replace '\.lua$', ''
            }

            $isInit = $instanceName -eq 'init'
            if (-not $isInit) {
                $segments.Add($instanceName)
            }
            $suffix = $segments -join '.'
            $studioPath = if ($suffix) { "$($mapping.Studio).$suffix" } else { [string]$mapping.Studio }

            $metaPath = if ($isInit) {
                Join-Path $file.DirectoryName 'init.meta.json'
            } else {
                $file.FullName -replace '\.(server|client)\.lua$', '.meta.json'
            }
            $disabled = $false
            if ($className -ne 'ModuleScript' -and (Test-Path -LiteralPath $metaPath -PathType Leaf)) {
                $meta = Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json
                $disabled = $meta.properties.Disabled -eq $true
            }

            $source = Get-NormalizedSource -Source ([System.IO.File]::ReadAllText($file.FullName))
            if ($scripts.ContainsKey($studioPath)) {
                throw "Duplicate filesystem mapping for Studio path: $studioPath"
            }
            $scripts[$studioPath] = [pscustomobject]@{
                className = $className
                disabled = $disabled
                bytes = [System.Text.Encoding]::UTF8.GetByteCount($source)
                lines = [regex]::Matches($source, "`n").Count
                fnv1a32 = Get-Fnv1a32 -Text $source
            }
        }
    }
    return $scripts
}

$expectedScripts = Get-ExpectedScripts

try {
    & rojo build $projectPath --output $buildPath
    if ($LASTEXITCODE -ne 0) {
        throw "Rojo build failed with exit code $LASTEXITCODE"
    }

    [xml]$place = Get-Content -LiteralPath $buildPath -Raw
    $builtScripts = @{}

    foreach ($item in $place.SelectNodes("//Item[@class='Script' or @class='LocalScript' or @class='ModuleScript']")) {
        $path = Get-ItemPath -Item $item
        $sourceNode = $item.SelectSingleNode("./Properties/*[@name='Source']")
        $source = if ($null -eq $sourceNode) { "`n" } else { Get-NormalizedSource -Source $sourceNode.InnerText }
        $disabledNode = $item.SelectSingleNode("./Properties/bool[@name='Disabled']")
        $disabled = $null -ne $disabledNode -and $disabledNode.InnerText -eq 'true'

        if ($builtScripts.ContainsKey($path)) {
            $failures.Add("Duplicate built script path: $path")
            continue
        }

        $builtScripts[$path] = [pscustomobject]@{
            className = $item.GetAttribute('class')
            disabled = $disabled
            bytes = [System.Text.Encoding]::UTF8.GetByteCount($source)
            lines = [regex]::Matches($source, "`n").Count
            fnv1a32 = Get-Fnv1a32 -Text $source
        }
    }

    foreach ($path in $expectedScripts.Keys) {
        if (-not $builtScripts.ContainsKey($path)) {
            $failures.Add("Built place is missing script: $path")
            continue
        }

        $expected = $expectedScripts[$path]
        $actual = $builtScripts[$path]
        if ($actual.className -ne $expected.className) {
            $failures.Add("Class differs for $($path): expected $($expected.className), got $($actual.className)")
        }
        if ($actual.disabled -ne $expected.disabled) {
            $failures.Add("Disabled state differs for $($path): expected $($expected.disabled), got $($actual.disabled)")
        }
        if ($actual.bytes -ne $expected.bytes -or $actual.lines -ne $expected.lines -or $actual.fnv1a32 -ne $expected.fnv1a32) {
            $failures.Add("Built source differs for $($path): expected bytes=$($expected.bytes) lines=$($expected.lines) hash=$($expected.fnv1a32); got bytes=$($actual.bytes) lines=$($actual.lines) hash=$($actual.fnv1a32)")
        }
    }

    foreach ($path in $builtScripts.Keys) {
        if (-not $expectedScripts.ContainsKey($path)) {
            $failures.Add("Built place contains untracked script: $path")
        }
    }
} finally {
    if (Test-Path -LiteralPath $buildPath) {
        Remove-Item -LiteralPath $buildPath -Force
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "Rojo build verified: $($builtScripts.Count) script paths, classes, disabled states, and source hashes match the current filesystem."
