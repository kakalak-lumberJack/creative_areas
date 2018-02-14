local cr_areas_file = minetest.get_worldpath().."/creative_areas.dat"
local cr_areas = {}


--functions
function load_file(fname)
	local file, err = io.open(fname, "r")
	if not err then
		local tbl = minetest.deserialize(file:read())
		cr_areas = tbl
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

function make_cr_area(name, areaID)
	local id = tonumber(areaID)
	if areas.areas[id] ~= nil then
		table.insert(cr_areas, id)
		write_file(cr_areas_file, cr_areas)
		minetest.chat_send_player(name, "Area added to Creative Areas!")
	else minetest.chat_send_player(name, "Not a valid area ID")	 
	end
end

function check_cr_area(player)
	local pos = player:get_pos()
	local area_at_pos = areas:getAreasAtPos(pos)
	local status = false
	--minetest.chat_send_all(minetest.serialize(area_at_pos))
	if cr_areas ~= nil then
		for _, areaID in ipairs(cr_areas) do
			for _, in_area in ipairs(area_at_pos) do
				if in_area["pos1"] ~= nil 
				and in_area["pos1"] == areas.areas[areaID]["pos1"]
				and in_area["name"] == areas.areas[areaID]["name"] then
					status = true
				end
			end
		end
		return status
	end
end

--Initialize mod
minetest.register_privilege("teacher", "Give access to teacher features.")

if cr_areas_file ~= nil then
	load_file(cr_areas_file)
end

-- Chat Commands
minetest.register_chatcommand("creative_area", {
	description = "Sets area to grant players creative priv while inside it",
	params = "<AreaID>",
	privs = {teacher = true},
	func = function(name, param)
		make_cr_area(name, param)
	end
})


-- Check location and Grant/revoke creative priv
local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer >= 3 then
		for _, player in ipairs(minetest.get_connected_players()) do
			local pname = player:get_player_name()
			local privs = minetest.get_player_privs(pname)			
			if minetest.get_player_privs(pname).teacher == nil then 
				if 	check_cr_area(player) == true then
					privs.give = true
					minetest.set_player_privs(pname, privs)
				else
					privs.give = nil
					minetest.set_player_privs(pname, privs)
				end
			end
		end
		timer = 0
	end
end)


