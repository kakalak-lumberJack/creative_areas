local storage = minetest.get_mod_storage()
local cr_areas = minetest.deserialize(storage:get_string("cr_areas")) or {}
---------------
-- Functions
---------------
-- Add creative area to list.
local function make_cr_area(name, areaID)
	local id = tonumber(areaID)
	if areas.areas[id] ~= nil then
		if cr_areas ~= {} then
			for i = 1, #cr_areas do
				if cr_areas[i] == id then
					return minetest.chat_send_player(name, "Area " ..id.." is already a creative area.")
				end
			end
		end	
		table.insert(cr_areas, id)
		storage:set_string("cr_areas", minetest.serialize(cr_areas))
		minetest.chat_send_player(name, "Area added to Creative Areas!")
	else minetest.chat_send_player(name, "Not a valid area ID")	 
	end
end
--Removes Creative Area
local function rm_cr_area(name, areaID)
	local id = tonumber(areaID) 
	for i = 1, #cr_areas do
		if cr_areas[i] == id then
			table.remove(cr_areas, i)
			storage:set_string("cr_areas", minetest.serialize(cr_areas))
			return minetest.chat_send_player(name, "Creative area removed!")
		end
	end
	return minetest.chat_send_player(name, "Not a creative area ID")
end
-- Checks players location against listed creative areas.
function check_cr_area(player)
	local pos = player:get_pos()
	local area_at_pos = areas:getAreasAtPos(pos)
	local status = false
	if cr_areas ~= {} then
		for i = 1, #cr_areas do
			local areaID = cr_areas[i]
			-- Clean up creative areas which are have been deleted from Areas mod
			if areas.areas[areaID] == nil then 
				table.remove(cr_areas, i)
				storage:set_string("cr_areas", minetest.serialize(cr_areas))
			end 
			-- Compare Areas which  player are in with Creative Area. Grant/revoke creative priv accordingly."
			for _, in_area in pairs(area_at_pos) do
				if in_area["pos1"] == areas.areas[areaID]["pos1"] --make sure the areas are not just the same name.
				 and in_area["name"] == areas.areas[areaID]["name"] then
					status = true
				end
			end
		end
	end
	return status
end
--------------------
-- Chat Commands
-------------------
minetest.register_chatcommand("creative_area", {
	description = "Sets area to grant players creative priv while inside it",
	params = "<AreaID>",
	privs = {privs = true},
	func = function(name, param)
		make_cr_area(name, param)
	end
})

minetest.register_chatcommand("rm_creative_area", {
	description = "Revokes area from list of creative areas",
	params = "<AreaID>",
	privs = {privs = true},
	func = function(name, param)
		rm_cr_area(name, param)
	end
})
	
minetest.register_chatcommand("ls_creative_areas", {
	description = "List creative areas and IDs",
	params = "",
	func = function(name, params)
		local list = ""
		if cr_areas ~= {} then
			for i = 1, #cr_areas do
				local id = tonumber(cr_areas[i])
				local area_name = areas.areas[ id ]["name"]
				list = list .. " " .. area_name .. " (ID="..id..")"
			end
			minetest.chat_send_player(name, "Creative Area (ID): "..list)
		else minetest.chat_send_player(name, "No creative areas found")
		end
	end
})
-------------------------------------------------
-- Check location and Grant/revoke creative priv
-------------------------------------------------
local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer >= math.random(1,3) then 
		for _, player in ipairs(minetest.get_connected_players()) do
			local pname = player:get_player_name()
			local privs = minetest.get_player_privs(pname)	
			local inv = minetest.get_inventory({type="player", name=pname})
			if minetest.get_player_privs(pname).privs == nil then --Players with the "privs" priv will not have privileges effected.
				if 	check_cr_area(player) == true then
					if not minetest.check_player_privs(pname, {creative = true}) then
						privs.creative = true
						minetest.set_player_privs(pname, privs)
						if not minetest.get_modpath("unified_inventory") then
							local context = {page = sfinv.get_homepage_name(player)}--minetest.get_inventory{{type="detached", name="creative_"..pname}}--{page = sfinv.pages["creative_"..pname]}						
							sfinv.set_player_inventory_formspec(player, context)
						end
						--unified_inventory.get_formspec(player, page)
						local invlist = inv:get_list("main")
						inv:set_list("saved", invlist)
						local list = ""
						for i = 1, #invlist do
							list = list .." "..dump(invlist[i]) 
						end	
						--write_file(inv_file,)
						minetest.chat_send_player(pname, "You are in creative area.")
						
					end
				else
					if minetest.check_player_privs(pname, {creative=true}) then
						privs.creative = nil
						minetest.set_player_privs(pname, privs)
						local saved = inv:get_list("saved")
						if saved ~= nil then
							inv:set_list("main", saved)
						end	
						if not minetest.get_modpath("unified_inventory") then
							local context = {page = sfinv.get_homepage_name(player)}
							sfinv.set_player_inventory_formspec(player, context)
						end
						--unified_inventory.get_formspec(player, page)
						minetest.chat_send_player(pname, "You have left creative area.")
					end
				end
			end
		end
		timer = 0
	end
end)
