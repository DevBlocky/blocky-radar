local radar = {
	sType = "mph",

	enable = false,
	frozen = false,
	inPolice = false,

	rotX = 90.0,
	rotY = 180.0,
	dist = 30.0,

	markerStart = 0,

	lastSpeed = 0.0, -- in m/s
	fastSpeed = 0.0, -- in m/s

	patrolS = 0.0, -- in m/s
	minFast = 22.352, -- in m/s
	increment = 2.2352 -- the amount of change for each fast speed increment, in m/s
}

-- funcs
local function drawNotification(text)
	SetNotificationTextEntry("STRING")
	AddTextComponentString(text)
	DrawNotification(false, false)
end
function pointOnSphere(rotX, rotY, radius)
	local x = radius * math.cos(math.rad(rotX)) * math.cos(math.rad(rotY))
	local y = radius * math.sin(math.rad(rotY))
	local z = radius * math.sin(math.rad(rotX)) * math.cos(math.rad(rotY))
	return vector3(x, -z, y)
end
local function getRadarCoords()
	local ped = GetPlayerPed(-1)
	local vehicle = GetVehiclePedIsIn(ped)

	local offset = pointOnSphere(radar.rotX, radar.rotY, radar.dist)
	return DoesEntityExist(vehicle) and
		GetOffsetFromEntityInWorldCoords(vehicle, offset.x, offset.y, offset.z) or
		nil
end
local function findRadarVehicle()
	local ped = GetPlayerPed(-1)
	local vehicle = GetVehiclePedIsIn(ped)

	local coordsFrom = GetEntityCoords(vehicle)
	local coordsTo = getRadarCoords()

	local raycast = StartShapeTestRay(coordsFrom, coordsTo, 2, vehicle)
	local _, _, _, _, entity = GetShapeTestResult(raycast)

	return DoesEntityExist(entity) and (GetEntityType(entity) == 2 and entity or nil) or nil
end
local function display(toggle)
	radar.enable = toggle
	SetNuiFocus(toggle, toggle)
end
local function inPolice()
	local ped = GetPlayerPed(-1) -- getting ped
	local veh = GetVehiclePedIsIn(ped)
	if DoesEntityExist(veh) then
		return (GetVehicleClass(veh) == 18)
	end
	return false
end

local function init()
	local function onButtonLoop()
		radar.inPolice = inPolice()
		if not radar.inPolice then -- checking if the ped is in a police vehicle
			return -- disabling controls if not in ped vehicle
		end

		if (IsControlPressed(0, 36) or IsDisabledControlPressed(0, 36)) and (IsControlJustPressed(0, 244) or IsDisabledControlJustPressed(0, 244)) then
			display(true)
		end
	end
	-- button listen thread
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(0) -- prevent crash
			onButtonLoop()
		end
	end)

	-- marker thread
	Citizen.CreateThread(function()
		while true do
			while GetTimeDifference(GetGameTimer(), radar.markerStart) < 2000 do
				local sCoords = GetEntityCoords(GetVehiclePedIsIn(GetPlayerPed(-1)))
				local eCoords = getRadarCoords()
				DrawLine(sCoords, eCoords, 255, 0, 0, 255)
				local empty = vector3(0.0, 0.0, 0.0)
				DrawMarker(0, eCoords, empty, empty, 1.0, 1.0, 1.0, 255, 0, 0, 255, false, false, 2, false, nil, nil, false)

				Citizen.Wait(0)
			end
			Citizen.Wait(150)
		end
	end)

	local function getPatrolSpeed(vehicle)
		local speed = GetEntitySpeed(vehicle)
		radar.patrolS = speed
	end
	local playSound = true
	local function calcRadar()
		local entity = findRadarVehicle()
		if entity == nil then -- checking if entity exists
			playSound = true
			return
		end
		local speed = GetEntitySpeed(entity) -- getting entity speed
		if speed < 1.0 then -- checking if the vehicle is moving
			return
		end
		radar.lastSpeed = speed -- setting front radar last speed

		if speed >= radar.minFast then -- faster than general fast speed
			if speed >= radar.fastSpeed then -- faster than the last fast speed
				radar.fastSpeed = speed
				if playSound then
					PlaySoundFrontend(-1, 'OTHER_TEXT', 'HUD_AWARDS')
					playSound = false
				end
			end
		end
	end
	local function onCarLoop()
		local ped = GetPlayerPed(-1) -- getting ped
		radar.inPolice = inPolice()
		if radar.enable and radar.inPolice then -- checking if radar enabled
			local vehicle = GetVehiclePedIsIn(ped, false)
			getPatrolSpeed(vehicle)
			calcRadar()
		end
	end
	-- car listen thread
	Citizen.CreateThread(function()
		while true do
			onCarLoop()
			if radar.enable then
				Citizen.Wait(5)
			else
				Citizen.Wait(250)
			end
		end
	end)

	local function onQueryLoop()
		SendNUIMessage({context = "send_info", info = radar})
	end
	-- ui query thread
	Citizen.CreateThread(function()
		SendNUIMessage({context = "resource", resource = GetCurrentResourceName()}) -- sends over the resource name

		while true do
			onQueryLoop()
			if radar.enable then
				Citizen.Wait(20)
			else
				Citizen.Wait(250)
			end
		end
	end)
end

RegisterNUICallback("radar", function(data, cb)
	if data.exit then
		SetNuiFocus(false, false)
	elseif data.hide then
		display(false)
	elseif data.rotX then
		radar.rotX = radar.rotX + data.offset
		radar.markerStart = GetGameTimer()
	elseif data.rotY then
		radar.rotY = radar.rotY + data.offset
		radar.markerStart = GetGameTimer()
	elseif data.setFastSpeed then
		local speed = data.fastSpeed
		radar.minFast = speed
	elseif data.changeSpeedType then
		radar.sType = data.sType
		drawNotification("Set speed type to ~b~"..radar.sType)
	elseif data.reset then
		radar.lastSpeed = 0.0
		radar.fastSpeed = 0.0
		drawNotification("Radar has been ~b~reset")
	elseif data.freezeRadar then
		radar.frozen = not radar.frozen
		if radar.frozen then
			drawNotification("Radar freeze is now ~g~enabled")
		else
			drawNotification("Radar freeze is now ~r~disabled")
		end
	end
end)

RegisterCommand("rnui", function()
	SetNuiFocus(false, false)
end)

Citizen.CreateThread(function()
	Wait(100) -- wait for NUI to load
	init() -- initializing
end)
