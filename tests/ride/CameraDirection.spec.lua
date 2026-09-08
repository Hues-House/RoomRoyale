local Camera = require("../../packages/RideRuntime/CameraDirection")
local function near(a,b) assert(math.abs(a-b)<1e-7,tostring(a).." ~= "..tostring(b)) end
for n=0,7 do
	local a=n*math.pi/4
	local x,z=math.sin(a),-math.cos(a)
	local r=Camera.resolve(0,-1,x,z,x,z,0.18)
	near(r.throttle,1);near(r.steer,0)
	local rest=Camera.resolve(0,0,x,z,0,-1,0.18)
	near(rest.throttle,0);near(rest.steer,0)
	local reverse=Camera.resolve(0,1,x,z,x,z,0.18)
	near(reverse.throttle,-1);near(reverse.steer,0)
end
local right=Camera.resolve(0,-1,1,0,0,-1,0.18)
assert(right.throttle>0 and right.steer>0)
local left=Camera.resolve(-1,0,0,-1,0,-1,0.18)
assert(left.throttle>0 and left.steer<0)
local counter=Camera.resolve(0,-1,0,-1,1,0,0.18)
assert(counter.steer<0)
local reverseTurn=Camera.resolve(0,1,1,0,0,-1,0.18)
assert(reverseTurn.throttle<0 and reverseTurn.steer<0)
local tiny=Camera.resolve(0.1,-0.1,0,-1,0,-1,0.18)
near(tiny.throttle,0);near(tiny.steer,0)
local analog=Camera.resolve(0,-0.5,0,-1,0,-1,0.18)
assert(analog.throttle>0 and analog.throttle<0.5)
local steep=Camera.resolve(0,-1,0,-0.0000001,0,-1,0.18)
near(steep.throttle,1);near(steep.steer,0)
local diagonal=Camera.resolve(1,-1,0,-1,math.sqrt(0.5),-math.sqrt(0.5),0.18)
near(diagonal.throttle,1);near(diagonal.steer,0)
for _, x in {0,0.5,0.999,1,1.001} do
 assert(Camera.resolve(x,1,0,-1,0,-1,0.18).throttle<0)
end
local inclined=Camera.resolve(0,-1,0,0,0,-0.3,0.18)
near(inclined.throttle,1);near(inclined.steer,0)
print("Camera direction: cardinal, diagonal, rest, reverse, countersteer, analog and pitch checks passed")
return true
