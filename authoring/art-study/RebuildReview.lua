-- Run through the Studio authoring plugin in Edit mode, after installing source data.
-- Ordinary runtime scripts cannot use these APIs while the experience toggle is disabled.
local source = game:GetService("ServerStorage"):WaitForChild("RoomRoyaleMeshStudySource")
local importer = require(source:WaitForChild("ImportReview"))
local root = importer.Root()
for _, child in root:GetChildren() do
	if child.Name:match("^rr_") then child:Destroy() end
end
local data = source:WaitForChild("Meshes"):GetChildren()
table.sort(data, function(a, b) return a.Name < b.Name end)
for _, module in data do
	importer.Mesh(require(module))
end
root:SetAttribute("ReviewStatus", "Edit-only mesh preview")
