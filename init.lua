-- mods/fairplay/init.lua
-- =================
-- See README.md for licensing and other information.

local steps = 0.3 --Higher number = Less lag, but not so fast detection for fly & noclip. Recommended: 0.3
local enable_check_fly = true --Check for flying without fly privileges. On detect: Kick player
local enable_check_noclip = true --Check for noclip without noclip privileges. On detect: Kick player
local enable_check_fast_in_water = true--Check if the player is faster in water than normal. On detect: Kick player
local enable_check_range_pvp = true --Check if range is higher than allowed one, when a player hit another one. On detect: Ignore punching
local enable_check_range_dig = true --Check if range is higher than allowed one, when digging a block. On detect: Ignore digging
local enable_check_range_place = true --Check if range is higher than allowed one, when placing a block. On detect: Ignore placing
local enable_check_through_block_pvp = true --Check if the hitting player is with his head inside a block. On detect: Ignore punching
local enable_check_through_block_dig = true --Check if a block is between players eyes an where he want to dig the other block. On detect: Ignore digging
local enable_check_in_air_place = true --Check if the player places a block while pointing at air. On detect: Ignore placing
local globalRange

if (type(minetest.settings) ~= "nil" and minetest.settings:get("creative_mode") or minetest.setting_get("creative_mode")) == "true" then
	globalRange = 10
end

--Range & through block attack

if enable_check_range_pvp or enable_check_through_block_pvp then
	minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
		if not hitter:is_player() or not player:is_player() then
			return
		end
		local pos_hitter = hitter:getpos()--Head: y + 1.624999
		local pos_player = player:getpos()
		if enable_check_range_pvp then
			local range = globalRange or 4
			local in_hand = hitter:get_wielded_item()
			if in_hand:get_definition() and in_hand:get_definition().range then
				range = in_hand:get_definition().range
			end
			range = range * 1.1
			if vector.distance(pos_player, pos_hitter) > range then
				return true
			end
		end
		if enable_check_through_block_pvp then--Can't hit if the larger upper part of the player is inside a block
			pos_hitter = vector.round(vector.add(pos_hitter, {x = 0, y = 1.5, z = 0}))
			local node = minetest.get_node(pos_hitter)
			local nodetbl = minetest.registered_nodes[node and node.name or ""]
			if nodetbl and nodetbl.drawtype ~= "liquid" and nodetbl.selection_box and nodetbl.selection_box.type == "regular" and node.name ~= "air" then
				return true
			end
		end
	end)
end

--Range & through block dig

if enable_check_range_dig or enable_check_through_block_dig then
	local old_node_dig = minetest.node_dig
	function minetest.node_dig(pos, node, digger)
		if not digger or not digger:is_player() then
			return old_node_dig(pos, node, digger)
		end
		local pos_player = digger:getpos()
		if enable_check_range_dig then
			local range = globalRange or 5
			local in_hand = digger:get_wielded_item()
			if in_hand:get_definition() and in_hand:get_definition().range then
				range = in_hand:get_definition().range
			end
			range = range * 1.1
			if vector.distance(pos, pos_player) > range then
				return
			end
		end
		if enable_check_through_block_dig then
			pos_player = vector.add(pos_player, {x = 0, y = 1.624999, z = 0})
			local los, pos_los = minetest.line_of_sight(pos_player, pos)
			local nodetbl = minetest.registered_nodes[minetest.get_node(pos_los).name]
			if not vector.equals(pos, pos_los) and nodetbl and nodetbl.drawtype ~= "liquid" and nodetbl.selection_box and nodetbl.selection_box.type == "regular" then
				return
			end
		end
		return old_node_dig(pos, node, digger)
	end
end

--Range & in air place

if enable_check_range_place or enable_check_in_air_place then
	local old_node_place = minetest.item_place
	function minetest.item_place(itemstack, placer, pointed_thing, param2)
		if not placer:is_player() then
			return old_node_place(itemstack, placer, pointed_thing, param2)
		end
		local pos_player = placer:getpos()
		if enable_check_range_place then
			local range = globalRange or 4
			local in_hand = placer:get_wielded_item()
			if in_hand:get_definition() and in_hand:get_definition().range then
				range = in_hand:get_definition().range
			end
			range = range * 1.1
			if vector.distance(pos_player, pointed_thing.above) > range and vector.distance(pos_player, pointed_thing.under) > range then
				return
			end
		end
		if enable_check_in_air_place then
			if minetest.get_node(pointed_thing.above).name == "air" and minetest.get_node(pointed_thing.under).name == "air" then
				return
			end
		end
		return old_node_place(itemstack, placer, pointed_thing, param2)
	end
end

--Fly check

local check_fly
local fly = {}

if enable_check_fly then
	check_fly = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return
		end
		local privs = minetest.get_player_privs(name)
		if privs.fly or (default and default.player_attached and default.player_attached[name]) or (player_api and player_api.player_attached and player_api.player_attached[name]) then--Don't trigger with fly priv or when player is attached
			return
		end
		if player:get_physics_override().speed > 1 then
			privs.fast = true
		end
		local velocity = player:get_player_velocity()
		local pos = vector.round(player:getpos())
		if not fly[name] then
			fly[name] = {}
		end
		if #minetest.find_nodes_in_area({x = pos.x - 2, y = pos.y - 2, z = pos.z - 2}, {x = pos.x + 2, y = pos.y + 2, z = pos.z + 2}, {"air"}) == 125 and
			 not (velocity.x == 0 and velocity.y == 0 and velocity.z == 0) and--Player has movement
			 (not fly[name][1] and true or not vector.equals(fly[name][1].pos, pos)) and--Player changed position
			 (not fly[name][1] and true or pos.y >= fly[name][1].pos.y) and--Player isn't falling
			 (not fly[name][1] and true or vector.equals(fly[name][1].velocity, velocity)) and--Player has same movement
			 (not fly[name][2] and true or not vector.equals(fly[name][2].pos, pos)) and--Player changed position
			 (not fly[name][2] and true or pos.y >= fly[name][2].pos.y) and--Player isn't falling
			 (not fly[name][2] and true or vector.equals(fly[name][2].velocity, velocity)) then--Player has same movement
			table.insert(fly[name], {velocity = velocity, pos = pos})
			
			if (privs.fast and fly[name][3]) or (not privs.fast and fly[name][2]) then
				minetest.kick_player(name, "Anticheat: Please disable your fly cheat")
				fly[name] = nil
			end
		else
			fly[name] = {}
		end
	end
end

--Noclip check

local check_noclip
local noclip = {}

if enable_check_noclip then
	check_noclip = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return
		end
		local privs = minetest.get_player_privs(name)
		if (privs.fly and privs.noclip) or (default and default.player_attached and default.player_attached[name]) or (player_api and player_api.player_attached and player_api.player_attached[name]) then--Don't trigger with fly & noclip priv, because both needed to use noclip or when player is attached
			return
		end
		local pos = vector.round(player:getpos())
		if not noclip[name] then
			noclip[name] = {}
		end
		local node, node2 = minetest.get_node(pos), minetest.get_node(vector.add(pos, {x = 0, y = 1, z = 0}))
		if not node or not node2 then
			return
		end
		node, node2 = minetest.registered_nodes[node.name], minetest.registered_nodes[node2.name]
		if node and node2 and--Tables exists
			 (node.drawtype == "normal" or node2.drawtype == "normal") and--Don't trigger if block is a liquid, air or has a nodebox
			 (node.walkable ~= false or node2.walkable ~= false) and--Don't trigger if player can walk inside block
		   (not node.node_box or node.node_box.type == "regular") and--Don't trigger if not normal nodebox
			 (not node2.node_box or node2.node_box.type == "regular") and
			 (not node.collision_box or node.collision_box.type == "regular") and--Don't trigger if not normal collisionbox
			 (not node2.collision_box or node2.collision_box.type == "regular") then
			table.insert(noclip[name], pos)
			
			if noclip[name][2] and not vector.equals(noclip[name][1], noclip[name][2]) then
				minetest.kick_player(name, "Anticheat: Please disable your noclip cheat")
				noclip[name] = nil
			elseif noclip[name][2] then
				table.remove(noclip[name], 1)
			end
		else
			noclip[name] = {}
		end
	end
end

--Water check

local check_water
local water = {}

if enable_check_fast_in_water then
	check_water = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return
		end
		local privs = minetest.get_player_privs(name)
		local physics = player:get_physics_override()
		if privs.fast or physics.speed ~= 1 or physics.jump ~= 1 or (default and default.player_attached and default.player_attached[name]) or (player_api and player_api.player_attached and player_api.player_attached[name]) then--Don't trigger with fast priv or when player has higher speed/jump or when player is attached
			return
		end
		local pos = vector.round(player:getpos())
		local node = minetest.get_node(pos)
		if not node then
			return
		end
		node = minetest.registered_nodes[node.name]
		if not node or node.drawtype ~= "liquid" then--Check if node is liquid
			return
		end
		local velocity = player:get_player_velocity()
		if math.abs(velocity.x) > 3.8 or math.abs(velocity.z) > 3.8 then
			if not water[name] then
				water[name] = true
			else
				minetest.kick_player(name, "Anticheat: Please disable your faster in water cheat")
				water[name] = nil
			end
		end
	end
end

--Main routine for fly, noclip & water check

if enable_check_fly or enable_check_noclip or enable_check_fast_in_water then
	local function check()
		for _, player in ipairs(minetest.get_connected_players()) do
			local name = player:get_player_name()
			if enable_check_fly then
				check_fly(name)
			end
			if enable_check_noclip then
				check_noclip(name)
			end
			if enable_check_fast_in_water then
				check_water(name)
			end
		end
		return minetest.after(steps, check)
	end

	check()
end

minetest.register_on_leaveplayer(function(player)
		local name = player:get_player_name()
		fly[name] = nil
		noclip[name] = nil
		water[name] = nil
end)
