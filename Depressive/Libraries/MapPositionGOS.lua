local mapID = Game.mapID
local reverse
local walls, bushes, water
local NEXUS_BLITZ_MAP = 21

if mapID == HOWLING_ABYSS then
	local mapData = require 'MapPositionData_HA'
	walls, bushes, water = mapData[1], mapData[2], {}
	reverse = true
elseif mapID == SUMMONERS_RIFT then
	local mapData = require 'MapPositionData_SR'
	walls, bushes, water = mapData[1], mapData[2], mapData[3]
elseif mapID == NEXUS_BLITZ_MAP then
	local mapData = require 'MapPositionData_NB'
	walls, bushes, water = mapData[1], mapData[2], {}
else
	walls, bushes, water = {}, {}, {}
	print("No Map Data - Unsupported Map")
end

local modf = math.modf
MapPosition = {}

local function lineOfSight(A, B)
	local x0, x1, z0, z1 = A.x, B.x, A.z, B.z
	local sx,sz,dx,dz

	if x0 < x1 then
		sx = 1
		dx = x1 - x0
	else
		sx = -1
		dx = x0 - x1
	end

	if z0 < z1 then
		sz = 1
		dz = z1 - z0
	else
		sz = -1
		dz = z0 - z1
	end

	local err, e2 = dx - dz, nil

	if MapPosition:inWall({x = x0, z = z0}, true) then return false end

	while not (x0 == x1 and z0 == z1) do
		e2 = err + err

		if e2 > -dz then
			err = err - dz
			x0  = x0 + sx
		end

		if e2 < dx then
			err = err + dx
			z0  = z0 + sz
		end

		if MapPosition:inWall({x = x0, z = z0}, true) then return false end
	end

	return true
end

local function GetDistanceSqr(pos1, pos2)
	local pos2 = pos2 or myHero.pos
	local dx = pos1.x - pos2.x
	local dz = (pos1.z or pos1.y) - (pos2.z or pos2.y)
	return dx * dx + dz * dz
end


local function fetchLineIntersection(A, B)
	local x0, x1, z0, z1 = A.x, B.x, A.z, B.z
	local sx,sz,dx,dz

	if x0 < x1 then
		sx = 1
		dx = x1 - x0
	else
		sx = -1
		dx = x0 - x1
	end

	if z0 < z1 then
		sz = 1
		dz = z1 - z0
	else
		sz = -1
		dz = z0 - z1
	end

	local err, e2 = dx - dz, nil

	local pts = {}
	while not (x0 == x1 and z0 == z1) do
		e2 = err + err

		if e2 > -dz then
			err = err - dz
			x0  = x0 + sx
		end

		if e2 < dx then
			err = err + dx
			z0  = z0 + sz
		end

		if MapPosition:inWall({x = x0, z = z0}, true) then
			table.insert(pts, {x = x0, z = z0})
		end
	end

	local closestPoint = {}
	if(#pts > 0 ) then
		closestPoint = pts[1]
		for i = 1, #pts do
			local pt = pts[i]
			if(GetDistanceSqr(pt, A) <= GetDistanceSqr(closestPoint, A)) then
				closestPoint = pt
			end
		end
	end

	return closestPoint
end

function MapPosition:inWall(position, skipTranslation)
	local x = position.x or position.pos.x
	local y = position.z or position.pos.z or position.y or position.pos.y

	if not skipTranslation then
		x = modf(x * 0.03030303)
		y = modf(y * 0.03030303)
	end

	local w = walls[x]

	if reverse then
		return not w or not w[y]
	else
		return w and w[y]
	end
end

function MapPosition:inBush(position)
	local x = modf((position.x or position.pos.x) * .03030303)
	local y = modf((position.z or position.pos.z or position.y or position.pos.y) * .03030303)
	local b = bushes[x]
	
	return b and b[y]
end

function MapPosition:inRiver(position)
	local x = modf((position.x or position.pos.x) * .02)
	local y = modf((position.z or position.pos.z or position.y or position.pos.y) * .02)
	local w = water[x]

	return w and w[y]
end

function MapPosition:intersectsWall(lineOrPointA, pointB)
	local lineA = pointB and lineOrPointA or lineOrPointA.points[1]
	local lineB = pointB or lineOrPointA.points[2]
	local A, B = {}, {}

	A.x = modf(lineA.x * .03030303)
	A.z = modf((lineA.z or lineA.y) * .03030303)
	B.x = modf(lineB.x * .03030303)
	B.z = modf((lineB.z or lineB.y) * .03030303)

	return not lineOfSight(A, B)
end

function MapPosition:getIntersectionPoint3D(pointA, pointB)
	local lineA = pointB and pointA or pointA.points[1]
	local lineB = pointB or pointA.points[2]
	local yPos = ((pointA.y + pointB.y) / 2)
	local A, B = {}, {}

	A.x = modf(lineA.x * .03030303)
	A.z = modf((lineA.z or lineA.y) * .03030303)
	B.x = modf(lineB.x * .03030303)
	B.z = modf((lineB.z or lineB.y) * .03030303)
	
	local result = fetchLineIntersection(A, B)
	if(result.x and result.z) then
		result = Vector({x = result.x * 33, y = yPos, z = result.z * 33})
		return result
	end
	return nil
end

--Updated 13.14 by Hightail @ 24th July 2023