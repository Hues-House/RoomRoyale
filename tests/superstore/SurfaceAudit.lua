local Audit={}

function Audit.run(world)
	local names={UpperPaving=true,WoodFloor=true,GardenPromenade=true,CheckoutApproach=true,CheckoutInlay=true,TopLanding=true,BoardingApron=true}
	local floors={}
	for _,p in world:GetDescendants() do
		if p:IsA("BasePart") and (names[p.Name] or p.Name:match("^Exit_") or p.Name:match("^Belt_")) and p.CFrame.UpVector.Y>0.9999 then
			local r,b=p.CFrame.RightVector,p.CFrame.LookVector
			table.insert(floors,{part=p,top=p.Position.Y+p.Size.Y/2,x=(math.abs(r.X)*p.Size.X+math.abs(b.X)*p.Size.Z)/2,z=(math.abs(r.Z)*p.Size.X+math.abs(b.Z)*p.Size.Z)/2})
		end
	end
	local conflicts={}
	for i,a in floors do
		for j=i+1,#floors do
			local b=floors[j]
			local dx=math.min(a.part.Position.X+a.x,b.part.Position.X+b.x)-math.max(a.part.Position.X-a.x,b.part.Position.X-b.x)
			local dz=math.min(a.part.Position.Z+a.z,b.part.Position.Z+b.z)-math.max(a.part.Position.Z-a.z,b.part.Position.Z-b.z)
			if dx>0.1 and dz>0.1 and math.abs(a.top-b.top)<0.035 and a.part.Color~=b.part.Color then
				table.insert(conflicts,{a=a.part:GetFullName(),b=b.part:GetFullName(),separation=math.abs(a.top-b.top),area=dx*dz})
			end
		end
	end
	return {floorCount=#floors,conflicts=conflicts}
end

return Audit
