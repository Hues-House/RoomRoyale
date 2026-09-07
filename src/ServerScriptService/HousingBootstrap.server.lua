-- ServerScriptService > HousingBootstrap
-- Initializes HousingService after ProgressionService is ready.
-- Must run after ProgressionBootstrap since it injects ProgressionService.

local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local HousingService     = require(script.Parent:WaitForChild("HousingService"))

-- ProgressionBootstrap calls ProgressionService.Init() which sets up DataStore
-- and player profile loading. We give it a tick to register before we start
-- housing so onPlayerAdded profile polls don't race.
task.defer(function()
	HousingService.Init(ProgressionService)
end)

print("[HousingBootstrap] Loaded")
