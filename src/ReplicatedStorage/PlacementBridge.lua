-- ReplicatedStorage > PlacementBridge
-- Shared BindableEvents for LocalScript-to-LocalScript communication
-- Both PlacementController and StyleController require this module
-- so they share the exact same event instances.

local bridge = {}

bridge.SetItem   = Instance.new("BindableEvent")  -- StyleController fires, PlacementController listens
bridge.Toggle    = Instance.new("BindableEvent")  -- StyleController fires "toggle"/"confirm"/"cancel"

return bridge
