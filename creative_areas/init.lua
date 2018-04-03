local storage = minetest.get_mod_storage()
local cr_areas = minetest.deserialize(storage:get_string("cr_areas")) or {}
local privtbl = {["interact"] = false, ["fast"] = false, ["fly"] = false, 
["noclip"] = false, ["creative"] = false, ["teleport"] = false, ["worldedit"] = false}

---------------
-- Functions
---------------
-- Check for intersecting creative areas
function intersects_cr_area(areaID)
	local ID = areaID
	local newarea = areas.areas[ID]
	local np1, np2 = newarea["pos1"], newarea["pos2"]
	if cr_areas == {} then
		return false
	end
	for k, v in pairs(cr_areas) do
		local id = tonumber(k)
		local area = areas.areas[tonumber(id)]
		if area ~= nil then
			local p1, p2 = area["pos1"], area["pos2"]
			for cx = p1.x, p2.x do
				for cy = p1.y, p2.y do
					for cz = p1.z, p2.z do
						for nx = np1.x, np2.x do
							for ny = np1.y, np2.y do
								for nz = np1.z, np2.z do
									if cx == nx and cy == ny and cz == nz then
										return true
									end
								end
							end
						end
					end
				end
			end
		end
	end
	return false
end
-- Add creative area to list.
local function make_cr_area(name, areaID)
	local id = tonumber(areaID)
	local intersects = intersects_cr_area(id)
	if intersects == true then
		return minetest.chat_send_player(name, "This area interesects another creative area.")
	end
	if privs == nil then privs = privtbl end
	if areas.areas[id] ~= nil then
		id = tostring(id)
		if cr_areas ~= {} then
			if cr_areas[id] then
				cr_areas[id]["privs"] = privs
				return minetest.chat_send_player(name, "Creative Area " ..id.." updated")
			end
		end
		local cr_area = {}
		cr_area["privs"] = privs	
		cr_areas[id] = cr_area
		storage:set_string("cr_areas", minetest.serialize(cr_areas))
		minetest.chat_send_player(name, "Area added to Creative Areas!")
	else minetest.chat_send_player(name, "Not a valid area ID")	 
	end
end
--Removes Creative Area
local function rm_cr_area(name, ID)
	local id = tostring(ID)
	local i = 1
	if cr_areas[id] then
		for k,v in pairs(cr_areas) do
			if k == id then
				cr_areas[k] = nil
				storage:set_string("cr_areas", minetest.serialize(cr_areas))
				return minetest.chat_send_player(name, "Creative area removed!")
			end
		end
	else
		return minetest.chat_send_player(name, "Not a creative area ID")
	end
end
--Remove creative area which are no longer stored by areas mod
local function rm_nil_areas(areaID)
	if areas.areas[areaID] == nil then 
		cr_areas[tostring(areaID)] = nil
		storage:set_string("cr_areas", minetest.serialize(cr_areas))
	end 
end
-- Checks players location against listed creative areas.
local function check_cr_area(player)
	local pos = player:get_pos()
	local area_at_pos = areas:getAreasAtPos(pos)
	local status = false
	local ID = 0
	--if area_at_pos ~= {} then
		for k, v in pairs(cr_areas) do
			if tonumber(k) ~= nil then
			local areaID = tonumber(k)
--Compare Areas which  player are in with Creative Area. Grant/revoke creative priv accordingly."
				for _, in_area in pairs(area_at_pos) do
					if in_area["pos1"] == areas.areas[areaID]["pos1"] --make sure the areas are not just the same name.
					and in_area["name"] == areas.areas[areaID]["name"] then
						status = true
						ID = tostring(areaID)
					end
				end
			end
		end
	
	return status, ID
end
--------------------
-- Chat Commands
-------------------
minetest.register_chatcommand("creative_area", {
	description = "Sets area to grant players creative priv while inside it",
	params = "<AreaID> <Privs>",
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
				for k, v in pairs(cr_areas[i]) do
					if k == "id" then
						local id = tonumber(v)
						local area_name = areas.areas[id]["name"]
						list = list .. " " .. area_name .. " (ID="..id..")"
					end
				end
				minetest.chat_send_player(name, "Creative Area (ID): "..list)
			end
		else minetest.chat_send_player(name, "No creative areas found")
		end
	end
})
------------------------------------------------------------------------
-- Store players default privs on joining first time incase spawning in creative area.
------------------------------------------------------------------------
local function store_privs(player)
	local status = check_cr_area(player) 
	if status == false then
		pname = player:get_player_name()
		cr_areas[pname] = minetest.get_player_privs(pname)
		storage:set_string("cr_areas", minetest.serialize(cr_areas))
	end
end


minetest.register_on_newplayer(function(player)
	store_privs(player)
end)

minetest.register_on_leaveplayer(function(player)
	local status = check_cr_area(player)
	if status == false then
		pname = player:get_player_name()
		cr_areas[pname] = nil
		storage:set_string("cr_areas", minetest.serialize(cr_areas))
	end
end)
-------------------------------------------------
-- Check location and Grant/revoke indicated privs
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
				local status, id = check_cr_area(player) 					
				if status == true then
					if not cr_areas[pname] then
						store_privs(player)
					end
					for k, v in pairs(cr_areas[id]["privs"]) do
						if v == true then
						privs[k] = true
						end
					end
					minetest.set_player_privs(pname, privs)
					-- Reload inventory formspec
					if not minetest.get_modpath("unified_inventory") then
						local context = {page = sfinv.get_homepage_name(player)}--minetest.get_inventory{{type="detached", name="creative_"..pname}}--{page = sfinv.pages["creative_"..pname]}						
						sfinv.set_player_inventory_formspec(player, context)
					end
					-- Store inventory for restoration after leaving creative area
					local invlist = inv:get_list("main")
						inv:set_list("saved", invlist)
						local list = ""
						for i = 1, #invlist do
							list = list .." "..dump(invlist[i]) 
						end	
					--[[]if not minetest.check_player_privs(pname, {creative = true}) then
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
						
					end]]--
				elseif status == false then
					if cr_areas[pname] then
						minetest.set_player_privs(pname, cr_areas[pname])
					end
				end
						
					--[[]	if minetest.check_player_privs(pname, {creative=true}) then
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
]]--					
			end
		end
		timer = 0
	end
end)

----------------------------------
--Formspec for SVINV
----------------------------------

local function set_switches(area_id)
	local tbl = privtbl
	local id = tostring(area_id)
	local X, Y = 0.5, 5.5
	local j = 1
	local switches, state = "", ""
	local function form(t)
		local switches = ""
		for k, v in pairs(tbl) do
			local priv = k
			if v == true then
				state = "on"
			else state = "off"
			end
			switches = switches .. "label["..tostring(X)..","..tostring(Y-0.5)..";"..priv.."]"
		.."image_button["..tostring(X)..","..tostring(Y)..";0.8,0.5;switch_"..state..".png;"..priv..";]"
			if X < 5.75 then
			X=X+2
			else X = 0.5
			end
			if j == 4 or j == 8 then
				Y = Y + 1.25
			end
			if j < 12 then
				j = j+1
			elseif j >= 12 then break 
			end
		end
		return switches
	end
	if id ~= 0 then
		if cr_areas[id] then
			tbl = cr_areas[id]["privs"]
		end
	end
	local switches = form(tbl)
	return switches
end

local function toggle_switch(ID, priv)
	
end

sfinv.register_page("creative_areas:areas", {
	title = "Creative Areas",
	is_in_nav = function(self, player, context)
		local privs = minetest.get_player_privs(player:get_player_name())
		return privs.privs
	end,
	get = function(self, player, context)
		local status, areaid = check_cr_area(player)
		local privs = privtbl
		
		local formspec = {
			"label[1.75,1;Add or Remove a Creative Area]"
			.."label[0.5,2;Area ID]"
			.."field[2.5,2;1,1;areaid;;"..areaid.."]"
			
			.."label[0.5,4;Check privs to be granted in this area]"
			..set_switches(areaid)
			.."button[3.5,1.75;2,1;mkcrarea;Add]"
			.."button[5.5,1.75;2,1;rmcrarea;Remove]"
		}
		return sfinv.make_formspec(player, context, table.concat(formspec, ""), false)
	end,
	on_player_receive_fields = function(self, player, formname, fields)
		local tbl = {}
		if fields.rmcrarea and fields.areaid then 
			return rm_cr_area(player:get_player_name(), fields.areaid)
		elseif fields.mkcrarea and fields.areaid then
			return make_cr_area(player:get_player_name(), fields.areaid)
		elseif fields.areaid then
			local id = fields.areaid
			if cr_areas[id] ~= nil then  
				for k, v in pairs(cr_areas[id]["privs"]) do
					if fields[k] then
						minetest.chat_send_all(k)
						if v == false then
							cr_areas[id]["privs"][k] = true
						elseif v == true then 
							cr_areas[id]["privs"][k] = false
						end
						storage:set_string("cr_areas", minetest.serialize(cr_areas))
						sfinv.set_player_inventory_formspec(player)
					end
				end
			end
		end
	end
})
