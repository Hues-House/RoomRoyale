param(
    [string]$OutputPath = "build/InstallFurniture.luau"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceDirectory = Join-Path $repoRoot "authoring/furniture"
$sourceRows = @(Get-ChildItem -LiteralPath $sourceDirectory -Filter "*.lua" | Sort-Object Name | ForEach-Object {
    $sourceText = [IO.File]::ReadAllText($_.FullName).Replace("`r`n", "`n")
    if ($sourceText.Contains("]====]")) { throw "Source contains the installer long-string delimiter: $($_.Name)" }
    $sourceBytes = [Text.Encoding]::UTF8.GetBytes($sourceText)
    [PSCustomObject]@{
        Name = $_.BaseName
        Source = $sourceText
        Hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($sourceBytes)).ToLowerInvariant()
    }
})
$manifestText = ($sourceRows | ForEach-Object { "$($_.Name):$($_.Hash)" }) -join "`n"
$revision = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($manifestText))).ToLowerInvariant()
$lines = [Collections.Generic.List[string]]::new()
$lines.Add(@'
assert(game.PlaceId == 86511797738570, "This installer targets Room Royale - Test only")
assert(not game:GetService("RunService"):IsRunning(), "Install in Edit mode")
local storage = game:GetService("ServerStorage")
local expectedSources = {}
'@)
$lines.Add("local revision = ""$revision""")
foreach ($row in $sourceRows) {
    $lines.Add("expectedSources[""$($row.Name)""] = [====[$($row.Source)]====]")
}
$lines.Add(@'
local existing = storage:FindFirstChild("RoomRoyaleFurnitureAuthoring")
local function sourcesMatch(folder)
    if #folder:GetChildren() ~= 0 then
        local count = 0
        for name, source in pairs(expectedSources) do
            local module = folder:FindFirstChild(name)
            if not module or not module:IsA("ModuleScript") or module.Source:gsub("\r\n", "\n") ~= source then return false end
            count += 1
        end
        return #folder:GetChildren() == count
    end
    return false
end
if existing and existing:GetAttribute("SourceRevision") == revision and sourcesMatch(existing) then
    local verified = require(existing.VerifyGallery).Run(workspace.RoomRoyaleFurniturePilot)
    verified.bakedCount = require(existing.VerifyGallery).Baked(storage.RoomRoyaleFurnitureCandidates)
    verified.revision, verified.reused = revision, true
    return game:GetService("HttpService"):JSONEncode(verified)
end
local refs = storage:FindFirstChild("RoomRoyaleFurnitureReferences")
if not refs then
    refs = Instance.new("Folder")
    refs.Name, refs.Parent = "RoomRoyaleFurnitureReferences", storage
end
local staging = Instance.new("Folder")
staging.Name = "Pending_" .. revision:sub(1, 12)
staging:SetAttribute("AuthoringOnly", true)
staging.Parent = refs
local toolkit = Instance.new("Folder")
toolkit.Name = "RoomRoyaleFurnitureAuthoring"
toolkit:SetAttribute("AuthoringOnly", true)
toolkit:SetAttribute("RepositoryPath", "authoring/furniture")
toolkit:SetAttribute("SourceRevision", revision)
toolkit.Parent = staging
for name, source in pairs(expectedSources) do
    local module = Instance.new("ModuleScript")
    module.Name, module.Source, module.Parent = name, source, toolkit
end
local gallery = require(toolkit.CreateGallery).Build(staging, CFrame.new(600, 0, 400))
local verified = require(toolkit.VerifyGallery).Run(gallery)
local candidates = require(toolkit.BakeCatalog).Build(gallery, staging)
verified.bakedCount = require(toolkit.VerifyGallery).Baked(candidates)
local rooms = require(toolkit.CreateShowcase).Build(staging, candidates, CFrame.new(720, 0, 420))
local oldObjects = {
    { storage, "RoomRoyaleFurnitureAuthoring" },
    { storage, "RoomRoyaleFurnitureCandidates" },
    { workspace, "RoomRoyaleFurniturePilot" },
    { workspace, "RoomRoyaleFurnitureShowcase" },
}
for _, entry in ipairs(oldObjects) do
    local old = entry[1]:FindFirstChild(entry[2])
    assert(not old or old:GetAttribute("AuthoringOnly") or old:GetAttribute("RepositoryPath") == "authoring/furniture", "Refusing to archive an unrecognized object")
end
local checkpoint = Instance.new("Folder")
checkpoint.Name = "Before_" .. revision:sub(1, 12) .. "_" .. game:GetService("HttpService"):GenerateGUID(false)
checkpoint.Parent = refs
for _, entry in ipairs(oldObjects) do
    local old = entry[1]:FindFirstChild(entry[2])
    if old then old.Parent = checkpoint end
end
toolkit.Parent, candidates.Parent = storage, storage
gallery.Parent, rooms.Parent = workspace, workspace
staging:Destroy()
verified.revision, verified.reused, verified.checkpoint = revision, false, checkpoint:GetFullName()
return game:GetService("HttpService"):JSONEncode(verified)
'@)
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $repoRoot $OutputPath }
[IO.Directory]::CreateDirectory((Split-Path -Parent $resolvedOutput)) | Out-Null
[IO.File]::WriteAllText($resolvedOutput, ($lines -join "`n"), [Text.UTF8Encoding]::new($false))
Write-Output "Wrote $resolvedOutput"
Write-Output "Source revision: $revision"
