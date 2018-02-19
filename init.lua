local cr_areas_file = minetest.get_worldpath().."/creative_areas.dat"
local cr_areas = {}
---------------
-- Functions
---------------
function load_file(fname)
	local file, err = io.open(fname, "r")
	if not err then
		local tbl = minetest.deserialize(file:read())
		return tbl
	else minetest.log("ERROR [creative_areas] "..err)
	end
end

function write_file(fname, tbl)
	local entry = minetest.serialize(tbl)
	local file, err = io.open(fname, "w")
	if not err then
		file:write(entry); file:flush(); file:close()
	else minetest.log("ERROR [creative_areas] "..err)
	end
end
--Adds creative area to list.
function make_cr_area(name, areaID)
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
		write_file(cr_areas_file, cr_areas)
		minetest.chat_send_player(name, "Area added to Creative Areas!")	
	else minetest.chat_send_player(name, "Not a valid area ID")	 
	end
end
--Removes Creative Area
function rm_cr_area(name, areaID)
	local id = tonumber(areaID) 
	for i = 1, #cr_areas do
		if cr_areas[i] == id then
			table.remove(cr_areas, i)
			write_file(cr_areas_file, cr_areas)
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
	if #cr_areas >= 1 then
		for i = 1, #cr_areas do
			local areaID = cr_areas[i]
			-- Clean up creative areas which are have been deleted from Areas mod
			if areas.areas[areaID] == nil then 
				table.remove(cr_areas, i)
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
---------------------
--Initialize mod
-------------------
if cr_areas_file ~= nil then
	cr_areas = load_file(cr_areas_file)
end

-- Chat Commands
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

-- Check location and Grant/revoke creative priv
local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer >= math.random(1,3) then 
		for _, player in ipairs(minetest.get_connected_players()) do
			local pname = player:get_player_name()
			local privs = minetest.get_player_privs(pname)			
			--if minetest.get_player_privs(pname).privs == nil then --Players with the "privs" priv will not have privileges effected.
				if 	check_cr_area(player) == true then
					if not minetest.check_player_privs(pname, {creative = true}) then
						privs.creative = true
						minetest.set_player_privs(pname, privs)
						local context = {page = sfinv.get_homepage_name(player)}--minetest.get_inventory{{type="detached", name="creative_"..pname}}--{page = sfinv.pages["creative_"..pname]}
						sfinv.set_player_inventory_formspec(player, context)
						minetest.chat_send_player(pname, "You are in creative area.")
					end
				else
					if minetest.check_player_privs(pname, {creative=true}) then
						privs.creative = nil
						minetest.set_player_privs(pname, privs)
						local context = {page = sfinv.get_homepage_name(player)}
						sfinv.set_player_inventory_formspec(player, context)
						minetest.chat_send_player(pname, "You have left creative area.")
					end
				end
			--end
		end
		timer = 0
	end
end)
