--!strict

local CameraDirection = {}

-- Scalar horizontal coordinates keep this resolver independent of engine objects.
function CameraDirection.resolve(x: number, z: number, cameraX: number, cameraZ: number,
	forwardX: number, forwardZ: number, deadzone: number)
	local magnitude = math.sqrt(x * x + z * z)
	if magnitude <= deadzone then return { throttle = 0, steer = 0 } end
	local forwardLength = math.sqrt(forwardX * forwardX + forwardZ * forwardZ)
	if forwardLength < 0.001 then forwardX, forwardZ = 0, -1
	else forwardX, forwardZ = forwardX / forwardLength, forwardZ / forwardLength end
	local cameraLength = math.sqrt(cameraX * cameraX + cameraZ * cameraZ)
	if cameraLength < 0.001 then cameraX, cameraZ = forwardX, forwardZ
	else cameraX, cameraZ = cameraX / cameraLength, cameraZ / cameraLength end
	local desiredX = (-cameraZ * x - cameraX * z) / magnitude
	local desiredZ = (cameraX * x - cameraZ * z) / magnitude
	local reverse = z > 0
	local sign = if reverse then -1 else 1
	local dot = math.clamp((forwardX * desiredX + forwardZ * desiredZ) * sign, -1, 1)
	local cross = (forwardX * desiredZ - forwardZ * desiredX) * sign
	local angle = math.atan2(cross, dot)
	local amount = math.min(1, (magnitude - deadzone) / (1 - deadzone))
	-- Keep a small drive force during a tight turn so the cart can turn from rest.
	return {
		throttle = sign * amount * math.max(0.3, dot),
		steer = math.clamp(angle / (math.pi / 3), -1, 1) * sign,
	}
end

return CameraDirection
