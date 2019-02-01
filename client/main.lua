ESX = nil

PlayerData = {}

Citizen.CreateThread(function()
    while ESX == nil do
        Citizen.Wait(10)

        TriggerEvent("esx:getSharedObject", function(response)
            ESX = response
        end)
    end

    if ESX.IsPlayerLoaded() then
		PlayerData = ESX.GetPlayerData()

		RemoveVehicles()

		Citizen.Wait(500)

		LoadSellPlace()

		SpawnVehicles()
    end
end)

RegisterNetEvent("esx:playerLoaded")
AddEventHandler("esx:playerLoaded", function(response)
	PlayerData = response
	
	LoadSellPlace()

	SpawnVehicles()
end)

RegisterNetEvent("esx-qalle-sellvehicles:refreshVehicles")
AddEventHandler("esx-qalle-sellvehicles:refreshVehicles", function()
	RemoveVehicles()

	Citizen.Wait(500)

	SpawnVehicles()
end)

function LoadSellPlace()
	Citizen.CreateThread(function()

		local SellPos = Config.SellPosition

		local Blip = AddBlipForCoord(SellPos["x"], SellPos["y"], SellPos["z"])
		SetBlipSprite (Blip, 147)
		SetBlipDisplay(Blip, 4)
		SetBlipScale  (Blip, 0.8)
		SetBlipColour (Blip, 52)
		SetBlipAsShortRange(Blip, true)
		BeginTextCommandSetBlipName("STRING")
		AddTextComponentString("Used Cars")
		EndTextCommandSetBlipName(Blip)

		while true do
			local sleepThread = 500

			local ped = PlayerPedId()
			local pedCoords = GetEntityCoords(ped)

			local dstCheck = GetDistanceBetweenCoords(pedCoords, SellPos["x"], SellPos["y"], SellPos["z"], true)

			if dstCheck <= 10.0 then
				sleepThread = 5

				if dstCheck <= 4.2 then
					ESX.Game.Utils.DrawText3D(SellPos, "[E] Open Menu", 0.4)
					if IsControlJustPressed(0, 38) then
						if IsPedInAnyVehicle(ped, false) then
							OpenSellMenu(GetVehiclePedIsUsing(ped))
						else
							ESX.ShowNotification("You must sit in a ~g~vehicle")
						end
					end
				end
			end

			for i = 1, #Config.VehiclePositions, 1 do
				if Config.VehiclePositions[i]["entityId"] ~= nil then
					local pedCoords = GetEntityCoords(ped)
					local vehCoords = GetEntityCoords(Config.VehiclePositions[i]["entityId"])

					local dstCheck = GetDistanceBetweenCoords(pedCoords, vehCoords, true)

					if dstCheck <= 2.0 then
						sleepThread = 5

						ESX.Game.Utils.DrawText3D(vehCoords, "[E] " .. Config.VehiclePositions[i]["price"] .. ":-", 0.4)

						if IsControlJustPressed(0, 38) then
							if IsPedInVehicle(ped, Config.VehiclePositions[i]["entityId"], false) then
								OpenSellMenu(Config.VehiclePositions[i]["entityId"], Config.VehiclePositions[i]["price"], true, Config.VehiclePositions[i]["owner"])
							else
								ESX.ShowNotification("You must sit in the ~g~vehicle~s~!")
							end
						end
					end
				end
			end

			Citizen.Wait(sleepThread)
		end
	end)
end

function OpenSellMenu(veh, price, buyVehicle, owner)
	local elements = {}

	if not buyVehicle then
		if price ~= nil then
			table.insert(elements, { ["label"] = "Change Price - " .. price .. " :-", ["value"] = "price" })
			table.insert(elements, { ["label"] = "Put out for sale", ["value"] = "sell" })
		else
			table.insert(elements, { ["label"] = "Set Price - :-", ["value"] = "price" })
		end
	else
		table.insert(elements, { ["label"] = "Buy " .. price .. " - :-", ["value"] = "buy" })

		if owner then
			table.insert(elements, { ["label"] = "Remove Vehicle", ["value"] = "remove" })
		end
	end

	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'sell_veh',
		{
			title    = "Vehicle Menu",
			align    = 'top-right',
			elements = elements
		},
	function(data, menu)
		local action = data.current.value

		if action == "price" then
			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'sell_veh_price',
				{
					title = "Vehicle Price"
				},
			function(data2, menu2)

				local vehPrice = tonumber(data2.value)

				menu2.close()
				menu.close()

				OpenSellMenu(veh, vehPrice)
			end, function(data2, menu2)
				menu2.close()
			end)
		elseif action == "sell" then
			local vehProps = ESX.Game.GetVehicleProperties(veh)

			ESX.TriggerServerCallback("esx-qalle-sellvehicles:isVehicleValid", function(valid)

				if valid then
					DeleteVehicle(veh)
					ESX.ShowNotification("You put out the ~g~vehicle~s~ for sale - " .. price .. " :-")
					menu.close()
				else
					ESX.ShowNotification("You must ~r~own~s~ the ~g~vehicle!~s~ / it's ~r~already~s~ " .. #Config.VehiclePositions .. " vehicles for sale!")
				end
	
			end, vehProps, price)
		elseif action == "buy" then
			ESX.TriggerServerCallback("esx-qalle-sellvehicles:buyVehicle", function(isPurchasable, totalMoney)
				if isPurchasable then
					DeleteVehicle(veh)
					ESX.ShowNotification("You ~g~bought~s~ the vehicle for " .. price .. " :-")
					menu.close()
				else
					ESX.ShowNotification("You ~r~don't~s~ have enough cash, it's missing " .. price - totalMoney .. " :-")
				end
			end, ESX.Game.GetVehicleProperties(veh), price)
		elseif action == "remove" then
			ESX.TriggerServerCallback("esx-qalle-sellvehicles:buyVehicle", function(isPurchasable, totalMoney)
				if isPurchasable then
					DeleteVehicle(veh)
					ESX.ShowNotification("You ~g~removed~s~ the vehicle")
					menu.close()
				end
			end, ESX.Game.GetVehicleProperties(veh), 0)
		end
		
	end, function(data, menu)
		menu.close()
	end)
end

function RemoveVehicles()
	local VehPos = Config.VehiclePositions

	for i = 1, #VehPos, 1 do
		local veh, distance = ESX.Game.GetClosestVehicle(VehPos[i])

		if DoesEntityExist(veh) and distance <= 1.0 then
			DeleteEntity(veh)
		end
	end
end

function SpawnVehicles()
	local VehPos = Config.VehiclePositions

	ESX.TriggerServerCallback("esx-qalle-sellvehicles:retrieveVehicles", function(vehicles)
		for i = 1, #vehicles, 1 do

			local vehicleProps = vehicles[i]["vehProps"]

			LoadModel(vehicleProps["model"])

			VehPos[i]["entityId"] = CreateVehicle(vehicleProps["model"], VehPos[i]["x"], VehPos[i]["y"], VehPos[i]["z"] - 0.975, VehPos[i]["h"], false)
			VehPos[i]["price"] = vehicles[i]["price"]
			VehPos[i]["owner"] = vehicles[i]["owner"]

			ESX.Game.SetVehicleProperties(VehPos[i]["entityId"], vehicleProps)

			FreezeEntityPosition(VehPos[i]["entityId"], true)

			SetEntityAsMissionEntity(VehPos[i]["entityId"], true, true)
			SetModelAsNoLongerNeeded(vehicleProps["model"])
		end
	end)

end

LoadModel = function(model)
	while not HasModelLoaded(model) do
		RequestModel(model)

		Citizen.Wait(1)
	end
end
