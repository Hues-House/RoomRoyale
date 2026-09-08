local Gesture = require("../../packages/RideRuntime/Gesture")
local runGestureTests = require("./Gesture.spec")

local result = runGestureTests(Gesture)
print(string.format("Gesture: %d scenarios passed", result.passed))

require("./CameraDirection.spec")

require("./PickupRules.spec")
