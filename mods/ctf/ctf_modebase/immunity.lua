local RESPAWN_IMMUNITY_SECONDS = 5
-- The value is a table if it's respawn immunity and false if it's a custom immunity
local immune_players = {}
immune_bar = nil

function ctf_modebase.is_immune(player)
	return immune_players[PlayerName(player)] ~= nil
end

local old_get_skin = ctf_cosmetics.get_skin
ctf_cosmetics.get_skin = function(player, color)
	if ctf_modebase.is_immune(player) then
		return old_get_skin(player, color) .. "^[colorize:#fff:80^[multiply:#85beff"
	else
		return old_get_skin(player, color)
	end
end




function ctf_modebase.give_immunity(player, timer_type, duration)
	local pname = player:get_player_name()
	local old = immune_players[pname]

	if old then
		if old.timer then
			old.timer:cancel()
		end

		if old.particles then
			minetest.delete_particlespawner(old.particles, pname)
		end
	end

	if timer_type == "respawn" then
		immune_players[pname] = {
			timer = minetest.after(duration, ctf_modebase.remove_immunity, player),
		}
	elseif timer_type == "bandage" then
		immune_players[pname] = {
			timer = false,
		}

	end

	immune_players[pname].particles = minetest.add_particlespawner({
		time = respawn_timer or 0,
		amount = 8 * (respawn_timer or 1),
		collisiondetection = false,
		texture = "ctf_modebase_immune.png",
		glow = 10,
		attached = player,

		pos = vector.new(0, 1.2, 0),
		attract = {
			kind = "point",
			strength = 2,
			origin = vector.new(0, 1.2, 0),
			origin_attached = player,
			die_on_contact = true,
		},
		radius = {min = 0.8, max = 1.3, bias = 1},

		minexptime = 0.3,
		maxexptime = 0.3,
		minsize = 1,
		maxsize = 2,
	})
  	immune_players[pname].immune_hud = player:hud_add({
  	 	hud_elem_type = "image",
   	 	position = {x = 1, y = 0},
   	 	scale = {x = 2.25, y = 2.25},
  	 	text = "ctf_modebase_immune.png",
  	 	alignment = {x = 0, y = 0},
    	 	offset = {x = -60, y = 70},
   	 	number = 0xFFFFFF,
    	 	size = {x = 1, y = 1},
   	 	z_index = 100,
         	direction = 0,
         	orientation = {x = 0, y = 0, z = 0},
         	name = "ctf_modebase_immune.png",
         	player_name = player:get_player_name(),
	})

	immune_players[pname].hud_bg = player:hud_add({
  	 	hud_elem_type = "image",
   	 	position = {x = 1, y = 0},
   	 	scale = {x = 4, y = 4},
  	 	text = "ctf_background.png",
  	 	alignment = {x = 0, y = 0},
    	 	offset = {x = -60, y = 70},
   	 	number = 0xFFFFFF,
    	 	size = {x = 1, y = 1},
   	 	z_index = 99,
         	direction = 0,
         	orientation = {x = 0, y = 0, z = 0},
         	name = "ctf_background.png",
         	player_name = player:get_player_name(),
	})
	
	if statbar == nil then	
		statbar = player:hud_add({
    			hud_elem_type = "statbar",
    			position = {x = 1, y = 0},
    			size = {x = 24, y = 12},
    			text = "ctf_statbar.png",
			number = duration,
			direction = 0,
			offset = {x = -92.5, y = 100},
		})
	end

	
	-- Change the statbar to the remaining immune time
	
	function update_immune_icon(value, player, statbar)

			if value == nil then
				 player:hud_remove(statbar)
				 return 
			end
			
			function change_hud(value, player)
				player:hud_change(statbar, "number", value)
			end
			minetest.chat_send_all(value)

			change_hud(value, player)
			
			
			value = value - 1
				
			if value >= 0 then 
				minetest.after(1, update_immune_icon, value, player, statbar) 

			elseif value < 0 then
				ctf_modebase.remove_immunity(player)
				return
			end
	end
	
	update_immune_icon(duration, player, statbar)


	if old == nil then
		player_api.set_texture(player, 1, ctf_cosmetics.get_skin(player))
		player:set_properties({pointable = false})
		player:set_armor_groups({fleshy = 0})
	end
end

function ctf_modebase.remove_immunity(player)
	local pname = player:get_player_name()
	local old = immune_players[pname]

	if old == nil then return end

	if old.timer then
		old.timer:cancel()
	end

	if old.particles then
		minetest.delete_particlespawner(old.particles)
	end

	immune_players[pname] = nil

	if player_api.players[pname] then
		player_api.set_texture(player, 1, ctf_cosmetics.get_skin(player))
	end

	player:hud_remove(immune_players[pname].immune_hud) -- remove HUD
	player:hud_remove(immune_players[pname].hud_bg)
	player:hud_remove(statbar)
	statbar = nil

	player:set_properties({pointable = true})
	player:set_armor_groups({fleshy = 100})
end

-- Remove immunity and return true if it's respawn immunity, return false otherwise
function ctf_modebase.remove_respawn_immunity(player)
	local pname = player:get_player_name()
	local old = immune_players[pname]

	if old == nil then return true end
	if old.timer == false then return false end

	immune_players[pname] = nil

	old.timer:cancel()

	minetest.delete_particlespawner(old.particles, pname)

	if player_api.players[pname] then
		player_api.set_texture(player, 1, ctf_cosmetics.get_skin(player))
	end

	player:set_properties({pointable = true})
	player:set_armor_groups({fleshy = 100})
	
	player:hud_remove(immune_hud) -- remove HUD
	player:hud_remove(hud_bg)
	player:hud_remove(statbar)
	statbar = nil
	
	return true
end

ctf_teams.register_on_allocplayer(function(player)
	ctf_modebase.give_immunity(player, "respawn", RESPAWN_IMMUNITY_SECONDS)
end)

ctf_api.register_on_respawnplayer(function(player)
	ctf_modebase.give_immunity(player, "respawn", RESPAWN_IMMUNITY_SECONDS)
end)

minetest.register_on_dieplayer(function(player)
	ctf_modebase.remove_immunity(player)
	
	player:set_properties({pointable = false})
end)

minetest.register_on_leaveplayer(function(player)
	ctf_modebase.remove_immunity(player)
end)
