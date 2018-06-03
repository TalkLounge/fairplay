-- mods/fairplay/init.lua
-- =================
-- See README.txt for licensing and other information.

local time = 0
local flytbl = {}
local old_node_dig = minetest.node_dig
local old_node_place = minetest.item_place

--Range Attack

minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
  if not hitter:is_player() or not player:is_player() then
    return
  end
	local pos = hitter:getpos()
	local head_pos = vector.add(pos, {x = 0, y = 1.624999, z = 0})
	local in_hand = player:get_wielded_item()
	local range = 4
	if in_hand:get_definition() and in_hand:get_definition().range then
		range = in_hand:get_definition().range
	end
	range = range * 1.1
	pos = player:getpos()
	local box = player:get_properties().collisionbox
	local minus = vector.add(pos, {x = box[1], y = box[2], z = box[3]})
	local plus = vector.add(pos, {x = box[4], y = box[5], z = box[6]})
	for i = 0, range, 0.1 do
		local look_pos = vector.add(head_pos, vector.multiply(dir, i))
		if minus.x < look_pos.x and plus.x > look_pos.x and minus.y < look_pos.y and plus.y > look_pos.y and minus.z < look_pos.z and plus.z > look_pos.z then
			return
		end
	end
	return true
end)

--Range & View Dig

function minetest.node_dig(pos, node, digger)
    if not digger:is_player() then
      return old_node_dig(pos, node, digger)
    end
    local dir = digger:get_look_dir()
    local player_pos = digger:getpos()
    local head_pos = vector.add(player_pos, {x = 0, y = 1.624999, z = 0})
    local in_hand = digger:get_wielded_item()
    local range = 4
    if in_hand:get_definition() and in_hand:get_definition().range then
      range = in_hand:get_definition().range
    end
		range = range * 1.1
		for i = 0, range, 0.1 do
			local look_pos = vector.add(head_pos, vector.multiply(dir, i))
			if vector.equals(vector.round(look_pos), pos) and minetest.registered_nodes[minetest.get_node(look_pos).name] and (not minetest.registered_nodes[minetest.get_node(look_pos).name].drawtype or minetest.registered_nodes[minetest.get_node(look_pos).name].drawtype ~= "airlike") then
				return old_node_dig(pos, node, digger)
			end
		end
end

--Range & View Place

function minetest.item_place(itemstack, placer, pointed_thing, param2)
    if not placer:is_player() then
      return old_node_place(itemstack, placer, pointed_thing, param2)
    end
		local dir = placer:get_look_dir()
    local player_pos = placer:getpos()
    local head_pos = vector.add(player_pos, {x = 0, y = 1.624999, z = 0})
    local in_hand = placer:get_wielded_item()
    local range = 4
    if in_hand:get_definition() and in_hand:get_definition().range then
      range = in_hand:get_definition().range
    end
		range = range * 1.1
		for i = 0, range, 0.1 do
			local look_pos = vector.add(head_pos, vector.multiply(dir, i))
			if vector.equals(vector.round(look_pos), pointed_thing.under) and minetest.registered_nodes[minetest.get_node(look_pos).name] and (not minetest.registered_nodes[minetest.get_node(look_pos).name].drawtype or minetest.registered_nodes[minetest.get_node(look_pos).name].drawtype ~= "airlike") then
				return old_node_place(itemstack, placer, pointed_thing, param2)
			end
		end
end

--Fly Detection

local function check_fly(name)
  local player = minetest.get_player_by_name(name)
  if not player then
    return
  end
  local pos = vector.round(player:getpos())
  local posbevor = pos
  local jump = player:get_physics_override().jump
  local speed = player:get_physics_override().speed
  if not minetest.get_player_privs(name).fly and #minetest.find_nodes_in_area({x = pos.x - (2 * speed), y = pos.y - (2 * jump), z = pos.z - (2 * speed)}, {x = pos.x + (2 * speed), y = pos.y, z = pos.z + (2 *speed}, {"air"}) == (1 + 2 * jump) * (1 + 4 * speed) * (1 + 4 * speed) and not ((default and default.player_attached and default.player_attached[name]) or (player_api and player_api.player_attached and player_api.player_attached[name])) then
    if not flytbl[name] then
      flytbl[name] = {}
    end
    if #flytbl[name] > 0 then
      posbevor = flytbl[name][#flytbl[name]]
    end
    if #flytbl[name] > 0 and ((posbevor.x == pos.x and posbevor.z == pos.z and posbevor.y == pos.y) or ((posbevor.y > pos.y + 1) and (vector.distance({x = posbevor.x, y = 0, z = posbevor.z}, {x = pos.x, y = 0, z = pos.z}) < 3))) then
      flytbl[name] = nil
      return
    end
    table.insert(flytbl[name], pos)
    if #flytbl[name] >= 3 then
      minetest.kick_player(name, "Autokick: Please disable your fly cheat")
      flytbl[name] = nil
      return
    end
    minetest.after(0.6, function()
        check_fly(name)
    end)
  else
    flytbl[name] = nil
  end
end

if minetest.get_modpath("xdecor") then
minetest.register_abm{
	nodenames = {"xdecor:trampoline"},
	interval = 1,
	chance = 1,
	action = function(pos)
    for _,obj in ipairs(minetest.get_objects_inside_radius(pos, 15)) do
      if obj:is_player() then
        for i = 0, 20 do
          minetest.after(i * 0.5, function()
              flytbl[obj:get_player_name()] = nil
          end)
        end
      end
    end
	end}
end

minetest.register_globalstep(function(dtime)
    time = time + dtime
    if time < 1 then
      return
    end
    time = 0
    for _, player in ipairs(minetest.get_connected_players()) do
      local name = player:get_player_name()
      check_fly(name)
    end
end)
