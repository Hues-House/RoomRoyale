[CmdletBinding()]
param([string]$LuauDirectory = '')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LuauToolsInDirectory {
    param([string]$Directory)

    $resolved = @{}
    foreach ($name in @('luau', 'luau-compile')) {
        foreach ($fileName in @("$name.exe", $name)) {
            $candidate = Join-Path $Directory $fileName
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $resolved[$name] = (Resolve-Path -LiteralPath $candidate).Path
                break
            }
        }
        if (-not $resolved.ContainsKey($name)) { return $null }
    }
    return [pscustomobject]@{ Luau = $resolved['luau']; Compiler = $resolved['luau-compile'] }
}

if ($LuauDirectory -ne '') {
    $resolvedTools = Get-LuauToolsInDirectory -Directory $LuauDirectory
    if (-not $resolvedTools) {
        throw "LuauDirectory '$LuauDirectory' must contain both luau and luau-compile CLI executables. See docs/cart-lab.md."
    }
    return $resolvedTools
}

$luauCommand = Get-Command luau -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$compilerCommand = Get-Command luau-compile -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($luauCommand -and $compilerCommand) {
    return [pscustomobject]@{ Luau = $luauCommand.Source; Compiler = $compilerCommand.Source }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$resolvedTools = Get-LuauToolsInDirectory -Directory (Join-Path $repoRoot '.scratch/generated/luau')
if ($resolvedTools) { return $resolvedTools }

throw 'Install the official Luau CLI tools and add luau and luau-compile to PATH, or pass -LuauDirectory pointing to their directory. See docs/cart-lab.md.'
