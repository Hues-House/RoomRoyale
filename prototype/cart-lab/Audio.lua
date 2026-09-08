--!strict
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")

local Audio = {}
local clips = {
	pop = "rbxassetid://6586979979",
	spring = "rbxassetid://2772396665",
	whoosh = "rbxassetid://9120709477",
	chime = "rbxassetid://99980076888596",
	wood = "rbxassetid://9126267420",
	wheels = "rbxassetid://9113426478",
}
local cues = {
	pickup = {clip="pop", volume=0.25, pitch=1.0, gap=0.09},
	pack = {clip="wood", volume=0.2, pitch=1, gap=0.08},
	checkoutSuck = {clip="whoosh", volume=0.18, pitch=0.88, gap=0.11},
	checkoutComplete = {clip="chime", volume=0.32, pitch=1, gap=0.8},
	poof = {clip="pop", volume=0.22, pitch=0.7, gap=0.3},
	land = {clip="wheels", volume=0.12, pitch=1.1, gap=0.25},
	chargeReady = {clip="chime", volume=0.12, pitch=1.3, gap=0.3},
	driftReady = {clip="pop", volume=0.12, pitch=1.4, gap=0.25},
	boost = {clip="whoosh", volume=0.2, pitch=1.2, gap=0.3},
	dive = {clip="whoosh", volume=0.15, pitch=0.8, gap=0.3},
	crash = {clip="spring", volume=0.24, pitch=0.72, gap=0.6},
	full = {clip="pop", volume=0.15, pitch=0.55, gap=0.5},
}
local lastPlayed: {[string]: number} = {}
local voices: {Sound} = {}
local group = Instance.new("SoundGroup")
group.Name = "CartEffects"
group.Volume = 0.75
group.Parent = SoundService

function Audio.play(cue: string, parent: Instance?, options: {pitch: number?, volume: number?}?): Sound?
	local definition = cues[cue]
	if not definition then return nil end
	local now = os.clock()
	if now - (lastPlayed[cue] or -math.huge) < definition.gap then return nil end
	lastPlayed[cue] = now
	for i = #voices, 1, -1 do
		if not voices[i].Parent then table.remove(voices, i) end
	end
	if #voices >= 8 then table.remove(voices, 1):Destroy() end
	local sound = Instance.new("Sound")
	sound.Name = "CartAudio_" .. cue
	sound.SoundId = clips[definition.clip]
	sound.Volume = options and options.volume or definition.volume
	sound.PlaybackSpeed = options and options.pitch or definition.pitch
	sound.SoundGroup = group
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance, sound.RollOffMaxDistance = 8, 65
	sound.Parent = parent or SoundService
	sound.Ended:Once(function() sound:Destroy() end)
	table.insert(voices, sound)
	sound:Play()
	Debris:AddItem(sound, 5)
	return sound
end

function Audio.preload()
	task.spawn(function()
		local assets = {}
		for _, asset in clips do
			local sound = Instance.new("Sound")
			sound.SoundId = asset
			table.insert(assets, sound)
		end
		local failures = 0
		local ok = pcall(function()
			ContentProvider:PreloadAsync(assets, function(_, status)
				if status ~= Enum.AssetFetchStatus.Success then failures += 1 end
			end)
		end)
		for _, sound in assets do sound:Destroy() end
		group:SetAttribute("PreloadSucceeded", ok and failures == 0)
		group:SetAttribute("FailedAssets", failures)
	end)
end

return Audio
