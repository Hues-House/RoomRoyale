-- ServerScriptService > RoundThemeReplicator
-- Mirrors theme attributes from game → ReplicatedStorage so client scripts
-- can read them from either location.
-- Listens to game attribute changes set by RoundManager.chooseRoundThemes().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ThemeDatabase = require(ReplicatedStorage:WaitForChild("ThemeDatabase"))

local overallStyle = ThemeDatabase.GetAestheticTheme("overall_style")

local function mirrorToReplicated(name)
	local value = game:GetAttribute(name)
	if value ~= nil then
		ReplicatedStorage:SetAttribute(name, value)
	end
end

local function syncAllThemeAttributes()
	local themeId = game:GetAttribute("MechanicalThemeId")
	if type(themeId) ~= "string" or themeId == "" then
		return
	end

	local theme = ThemeDatabase.GetMechanicalTheme(themeId)
	if not theme then
		warn(string.format("[RoundThemeReplicator] Unknown mechanical theme id: %s", themeId))
		return
	end

	-- Mirror all round-theme attributes to ReplicatedStorage
	ReplicatedStorage:SetAttribute("RoundThemeId", theme.id)
	ReplicatedStorage:SetAttribute("RoundThemeLabel", theme.label)
	ReplicatedStorage:SetAttribute("RoundThemeHint", theme.hint or "")
	ReplicatedStorage:SetAttribute("RoundThemePrompt", theme.prompt or "")
	ReplicatedStorage:SetAttribute("MechanicalThemeId", theme.id)
	ReplicatedStorage:SetAttribute("MechanicalThemeLabel", theme.label)
	ReplicatedStorage:SetAttribute("MechanicalThemeHint", theme.hint or "")
	ReplicatedStorage:SetAttribute("AestheticThemeId", overallStyle and overallStyle.id or "overall_style")
	ReplicatedStorage:SetAttribute("AestheticThemeLabel", overallStyle and overallStyle.label or "Overall Style")
	ReplicatedStorage:SetAttribute("AestheticThemeHint", overallStyle and overallStyle.hint or "Judge the room on the whole vibe, not a second prompt.")

	print(string.format("[RoundThemeReplicator] Synced theme attrs for %s", theme.label))
end

-- RoundManager sets MechanicalThemeId on game in chooseRoundThemes().
-- Listen for that attribute change as the reliable trigger.
game:GetAttributeChangedSignal("MechanicalThemeId"):Connect(syncAllThemeAttributes)

-- Also mirror any individual attribute change RoundManager writes, so
-- ReplicatedStorage stays in sync even for partial updates.
for _, attrName in ipairs({
	"RoundThemeId", "RoundThemeLabel", "RoundThemeHint", "RoundThemePrompt",
	"MechanicalThemeId", "MechanicalThemeLabel", "MechanicalThemeHint",
	"AestheticThemeId", "AestheticThemeLabel", "AestheticThemeHint",
}) do
	game:GetAttributeChangedSignal(attrName):Connect(function()
		mirrorToReplicated(attrName)
	end)
end

-- Sync once on startup in case attributes are already set.
task.defer(syncAllThemeAttributes)

print("[RoundThemeReplicator] Loaded")
