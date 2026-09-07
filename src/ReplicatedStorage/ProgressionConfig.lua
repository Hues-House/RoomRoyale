local RunService = game:GetService("RunService")

local ProgressionConfig = {
	CurrencyName = "Style Bucks",
	DataStoreName = "PlayerProgression_v1",
	AutoSaveSeconds = 90,
	StartingCurrency = 400,
	RoundCompletionCurrency = 35,
	RoundCompletionXP = 30,
	RankCurrencyBonus = {
		[1] = 40,
		[2] = 24,
		[3] = 14,
	},
	RankXPBonus = {
		[1] = 42,
		[2] = 26,
		[3] = 16,
	},
	ScoreCurrencyFactor = 0.35,
	ScoreXPFactor = 1.55,
	ThemeAffinityCurrency = 5,
	ThemeAffinityXP = 12,
	RarityCurrency = 8,
	RarityXP = 16,
	WinBonusCurrency = 12,
	WinBonusXP = 18,
	PickupValues = { 1, 1, 2, 2, 3, 4 },
	PickupCountBase = 16,
	PickupCountPerPlayer = 4,
	PickupCountCap = 30,
	StoreRotationSize = 6,
	ExclusiveRotationSize = 2,
	MaxCollectionEntries = 20,
	AllowStudioRobuxPreview = RunService:IsStudio(),
}

function ProgressionConfig.GetXPForLevel(level: number): number
	if level <= 1 then
		return 0
	end

	local total = 0
	for current = 1, level - 1 do
		total += 100 + ((current - 1) * 55) + math.floor(((current - 1) ^ 1.25) * 18)
	end
	return total
end

function ProgressionConfig.GetLevelFromXP(totalXP: number): number
	local xp = math.max(0, math.floor(totalXP or 0))
	local level = 1
	while level < 200 and xp >= ProgressionConfig.GetXPForLevel(level + 1) do
		level += 1
	end
	return level
end

function ProgressionConfig.GetLevelProgress(totalXP: number)
	local xp = math.max(0, math.floor(totalXP or 0))
	local level = ProgressionConfig.GetLevelFromXP(xp)
	local levelFloor = ProgressionConfig.GetXPForLevel(level)
	local nextLevelXP = ProgressionConfig.GetXPForLevel(level + 1)
	return {
		level = level,
		xp = xp,
		xpIntoLevel = xp - levelFloor,
		xpForNextLevel = math.max(1, nextLevelXP - levelFloor),
		nextLevelXP = nextLevelXP,
	}
end

function ProgressionConfig.GetPickupCount(playerCount: number): number
	local count = ProgressionConfig.PickupCountBase + (math.max(1, playerCount) - 1) * ProgressionConfig.PickupCountPerPlayer
	return math.clamp(count, ProgressionConfig.PickupCountBase, ProgressionConfig.PickupCountCap)
end

function ProgressionConfig.BuildRoundRewards(scoreEntry, rank: number, participantCount: number)
	local totalScore = math.max(0, math.floor(tonumber(scoreEntry and scoreEntry.total) or 0))
	local mechanicalBreakdown = scoreEntry and scoreEntry.mechanicalBreakdown or nil
	local themeAffinity = math.max(0, math.floor(tonumber(mechanicalBreakdown and mechanicalBreakdown.themeAffinityScore) or 0))
	local rarityScore = math.max(0, math.floor(tonumber(mechanicalBreakdown and mechanicalBreakdown.rarityScore) or 0))

	local currency = ProgressionConfig.RoundCompletionCurrency
		+ math.floor(totalScore * ProgressionConfig.ScoreCurrencyFactor)
		+ (themeAffinity * ProgressionConfig.ThemeAffinityCurrency)
		+ (rarityScore * ProgressionConfig.RarityCurrency)
		+ (ProgressionConfig.RankCurrencyBonus[rank] or 0)

	local xp = ProgressionConfig.RoundCompletionXP
		+ math.floor(totalScore * ProgressionConfig.ScoreXPFactor)
		+ (themeAffinity * ProgressionConfig.ThemeAffinityXP)
		+ (rarityScore * ProgressionConfig.RarityXP)
		+ (ProgressionConfig.RankXPBonus[rank] or 0)

	if rank == 1 then
		currency += ProgressionConfig.WinBonusCurrency
		xp += ProgressionConfig.WinBonusXP
	end

	if participantCount >= 4 and rank <= math.max(1, math.ceil(participantCount / 2)) then
		currency += 6
		xp += 8
	end

	return {
		currency = math.max(0, currency),
		xp = math.max(0, xp),
		totalScore = totalScore,
		rank = rank,
		themeAffinity = themeAffinity,
		rarityScore = rarityScore,
	}
end

return ProgressionConfig
