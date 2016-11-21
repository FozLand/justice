-----------------
-- Justice Mod --
-----------------

local load_time_start = os.clock()


------------
-- Config --
------------

local revoke_privs = {'shout', 'interact', 'home'}
local safe_zones = {}
local pvp_zones = {
	{x_min = 524, x_max = 602, y_min = 0, y_max = 76, z_min = 349, z_max = 468}
}
local release_pos = {x = 117, y = 2, z = -19}
local cells = {
	--{pos = {x = -5, y = 21, z = -4}, occupied = false},

	{pos = {x = 139, y = 2, z = -17}, occupied = false},
	{pos = {x = 139, y = 2, z = -25}, occupied = false},
	{pos = {x = 135, y = 2, z = -17}, occupied = false},
	{pos = {x = 135, y = 2, z = -25}, occupied = false},
	{pos = {x = 131, y = 2, z = -17}, occupied = false},
	{pos = {x = 131, y = 2, z = -25}, occupied = false},
	{pos = {x = 127, y = 2, z = -17}, occupied = false},
	{pos = {x = 127, y = 2, z = -25}, occupied = false},

	{pos = {x = 139, y = 7, z = -17}, occupied = false},
	{pos = {x = 139, y = 7, z = -25}, occupied = false},
	{pos = {x = 135, y = 7, z = -17}, occupied = false},
	{pos = {x = 135, y = 7, z = -25}, occupied = false},
	{pos = {x = 131, y = 7, z = -17}, occupied = false},
	{pos = {x = 131, y = 7, z = -25}, occupied = false},
	{pos = {x = 127, y = 7, z = -17}, occupied = false},
	{pos = {x = 127, y = 7, z = -25}, occupied = false},
}

local hud_ids = {}
local hud_def = {
	name = 'Prison Sentence',
	hud_elem_type = 'text',
	position = {x=0.5, y=0.75},
	scale = {x=1000, y=1000},
	text = 'Time served: 0/?',
	number = 0xFF0000,
	alignment = {x=0, y=0},
	offset = {x=0, y=0},
}

local MAX_SENTENCE = 900 -- 15 minutes

---------------------
-- Data Management --
---------------------

local data_file = core.get_worldpath() .. 'justice/data.mt'
local data = {}

local function load_data_file()
	local file = io.open(data_file, "r")
	if file then
		data = core.deserialize(file:read("*all"))
		file:close()
	end
end

local function write_data_file()
	local file = io.open(data_file, 'w')
	if file then
		file:write(core.serialize(data))
		file:close()
	end
end

-- Save the data when the server shutdown.
core.register_on_shutdown(function()
	-- TODO deactivate players
	write_data_file()
end)

load_data_file()
data.records = data.records or {}
data.inmates = data.inmates or {}
data.inmates.active   = data.inmates.active   or {}
data.inmates.inactive = data.inmates.inactive or {}

-- There are no logged in players when the server starts, so deactivate all
-- inmates when the server first starts up. This should be been handled during
-- shutdown, but the server may have not have stopped gracefully.
for name,inmate in pairs(data.inmates.active) do
	data.inmates.inactive[name] = {
		name = inmate.name,
		sentence    = inmate.sentence or 60,
		time_served = inmate.time_served or 0,
		--cell_number = nil, -- does nothing
	}
end
data.inmates.active = {}
write_data_file()


----------------------
-- Helper Functions --
----------------------

local function round(number)
	-- Round numbers to the nearest integer. Numbers exactly between
	-- two integers (ending in .5) are rounded away from zero.
	if number >= 0.5 then
		return math.floor(number + 0.5)
	else
		return math.ceil(number - 0.5)
	end
end

local function find_free_pos_near(pos)
	local x, y, z, r = pos.x, pos.y, pos.z, 1
	for j = y-0, y+r do
		for i = x-r, x+r do
			for k = z-r, z+r do
				local p1 = {x=i, y=j,   z=k}
				local p2 = {x=i, y=j+1, z=k}
				local n1 = core.get_node(p1)
				local n2 = core.get_node(p2)
				local walkable
				if not core.registered_nodes[n1.name].walkable and
				   not core.registered_nodes[n2.name].walkable then
					return p1, true
				end
			end
		end
	end
	return pos, false
end

local function find_free_cell()
	for i, cell in ipairs(cells) do
		if not cell.occupied then
			return i, cell
		end
	end
	return 1, cells[1]
end

local function in_safe_zone(pos)
	local x, y, z = pos.x, pos.y, pos.z
	for _, zone in ipairs(safe_zones) do
		if zone.x_min <= x and x <= zone.x_max and
		   zone.y_min <= y and y <= zone.y_max and
		   zone.z_min <= z and z <= zone.z_max then
			return true
		end
	end

	for _, zone in ipairs(pvp_zones) do
		if zone.x_min <= x and x <= zone.x_max and
		   zone.y_min <= y and y <= zone.y_max and
		   zone.z_min <= z and z <= zone.z_max then
			return false
		end
	end

	return true
end

local function hud_string(inmate)
	return 'Time Served: ' ..
		tostring(round(inmate.time_served)) .. '/' ..
		tostring(round(inmate.sentence)) .. '(s)'
end

local function add_hud(inmate)
	local player = core.get_player_by_name(inmate.name)
	local def = hud_def
	def.text = hud_string(inmate)
	hud_ids[inmate.name] = player:hud_add(def)
end

local function drop_hud(inmate)
	local player = core.get_player_by_name(inmate.name)
	player:hud_remove(hud_ids[inmate.name])
	hud_ids[inmate.name] = nil
end

local function update_hud(inmate)
	if hud_ids[inmate.name] then
		local player = core.get_player_by_name(inmate.name)
		--player:hud_change(tonumber(hud_ids[inmate.name]), 'text', status)
		player:hud_change(hud_ids[inmate.name], 'text', hud_string(inmate))
	else
		core.log('warning','Justice mod missing hud id for player ' ..
			inmate.name .. '.')
		add_hud(inmate)
	end
end

local function revoke(name)
	local privs = core.get_player_privs(name)
	if not privs then
		core.log('warning', 'Unable to revoke ' .. name .. '\'s privileges.')
		return false
	end

	for _,priv in ipairs(revoke_privs) do
    privs[priv] = nil
  end

	core.set_player_privs(name, privs)
	return true
end

local function grant(name)
	local privs = core.get_player_privs(name)
	if not privs then
		core.log('warning', 'Unable to restore ' .. name .. '\'s privileges.')
		return false
	end

	for _,priv in ipairs(revoke_privs) do
    privs[priv] = true
  end

	core.set_player_privs(name, privs)
	return true
end

local function confine(inmate)
	local player = core.get_player_by_name(inmate.name)

	if not player then
		core.log('warning', 'Unable to confine ' .. inmate.name .. ' to prison.')
		return false
	end

	local cell_number, cell = find_free_cell()
	inmate.cell_number = cell_number
	cell.occupied = true
	player:setpos(cell.pos)

	add_hud(inmate)

	core.sound_play("teleport", {
		to_player = inmate.name,
		gain = 0.1
	})

	return true
end

local function release(inmate)
	local player = core.get_player_by_name(inmate.name)

	if not player then
		core.log('warning', 'Unable to release ' .. inmate.name .. ' from prison.')
		return false
	end

	cells[inmate.cell_number].occupied = false
	player:setpos(find_free_pos_near(release_pos))

	drop_hud(inmate)

	core.sound_play("teleport", {
		to_player = inmate.name,
		gain = 0.1
	})

	return true
end


---------
-- API --
---------
justice = {}

function justice.sentence(judge, player_name, seconds, cause)
	seconds = math.min(seconds, MAX_SENTENCE)

	-- Update the players criminal record.
	local record = {
		date = os.date('%Y-%m-%d %X'),
		judge = judge,
		duration = seconds,
		cause = cause,
	}
	if not data.records[player_name] then
		data.records[player_name] = {}
	end
	table.insert(data.records[player_name], record)

	-- Update the players sentence, confine and revoke as necessary.
	local inmate = {}
	if data.inmates.active[player_name] then
		inmate = data.inmates.active[player_name]
		inmate.sentence = math.min(inmate.sentence + seconds, MAX_SENTENCE)
	else
		inmate = {
			name = player_name,
			sentence = seconds,
			time_served = 0,
		}
		if confine(inmate) and revoke(inmate.name) then
			data.inmates.active[player_name] = inmate
			write_data_file()
		else
			local notice = 'Sentencing ' .. player_name .. ' failed.'
			core.chat_send_player(judge, notice)
			core.log('warning', notice)
			return
		end
	end

	core.log('action', judge .. ' sentenced ' .. inmate.name .. ' to ' ..
		tostring(seconds) .. ' seconds in prison for ' .. cause .. '.')
	core.chat_send_all(inmate.name ..	' has been found guilty of ' .. cause ..
		' and has been sentenced to prison for ' .. tostring(seconds) ..
		' seconds.')
	local formspec = 'size[8,9]'..
		'textarea[0.3,0.25;8,9;court;= The Court of FozLand =;'..
		'\nYou have been tried and found you guilty of ' .. cause .. '. \n\n' ..
		'You are hereby sentenced to prison for ' .. tostring(seconds) ..
		' seconds. \n\nYour privileges have been reduced while you serve your ' ..
		' sentence. Please review the rules at /news if you have any questions]'..
		'button_exit[5.5,8.4;2.5,1;exit;I Understand]'
	core.show_formspec(inmate.name, "Conviction", formspec)
end

function justice.discharge(judge, player_name)

	local inmate = data.inmates.active[player_name]

	if inmate and release(inmate) and grant(inmate.name) then
		local notice = inmate.name ..	' has completed their sentence. They have' ..
			' been released from prison and their privileges have been restored.'
		core.log('action', notice)
		core.chat_send_all(notice)

		data.inmates.active[player_name] = nil
		write_data_file()
	else
		local notice = 'Paroling ' .. player_name .. ' failed.'
		core.chat_send_player(judge, notice)
		core.log('warning', notice)
	end
end


--------------------
-- User Interface --
--------------------

core.register_privilege(
	'judge',
	'Allows player to sentence others to prison.'
)

core.register_chatcommand('convict', {
	params = '<name> <seconds> <reason>',
	description = 'Revokes a players interact and shout privileges and ' ..
		'confines them to prison for the specified number of seconds.',
	privs = {judge=true},
	func = function(judge_name, param)
		local player_name, seconds, cause =
			string.match(param, '^([^ ]+) (%d+) (.+)$')
		if not player_name or not seconds or not cause then
			return false, 'Invalid parameters (see /help convict)'
		elseif not core.auth_table[player_name] then
			return false, 'Player ' .. player_name .. ' does not exist.'
		end
		justice.sentence(judge_name, player_name, tonumber(seconds), cause)
	end,
})

core.register_chatcommand('parole', {
	params = '<name>',
	description = 'Release a convict from prison and restore their privileges.',
	privs = {judge=true},
	func = function(judge, param)
		local player_name = string.match(param, '^([^ ]+)$')
		if not player_name then
			return false, 'Invalid parameters (see /help parole)'
		elseif not core.auth_table[player_name] then
			return false, 'Player ' .. player_name .. ' does not exist.'
		end
		justice.discharge(judge, player_name)
	end,
})

core.register_chatcommand('records', {
	params = '<name>',
	description = 'Display a players criminal record.',
	privs = {shout=true},
	func = function(player, param)
		local player_name = string.match(param, '^([^ ]+)$')
		if not player_name then
			return false, 'Invalid parameters (see /help records)'
		elseif not core.auth_table[player_name] then
			return false, 'Player ' .. player_name .. ' does not exist.'
		end
		local list = 'Criminal records for ' .. player_name .. ':\n'
		if data.records[player_name] then
			list = list .. string.format('%22s %9s %6s  %s\n',
				'Date', 'Judge', 'Length', 'Reason')
			for i, record in ipairs(data.records[player_name]) do
				list = list .. string.format('%22s %9s %3s (s) %s\n',
					record.date, record.judge, record.duration, record.cause)
			end
			core.chat_send_player(player, list)
		else
			core.chat_send_player(player, player_name .. ' has no criminal record.')
		end
	end,
})

core.register_chatcommand('inmates', {
	description = 'Lists the active inmates.',
	privs = {shout=true},
	func = function(player)
		local list = 'Currently active (logged-in) inmates:\n'
		list = list .. string.format('%4s %15s %11s\n',
				'Cell', 'Player Name', 'Time Served')
		
		for name, inmate in pairs(data.inmates.active) do
		list = list .. string.format('%4s %15s %3d/%3d (s)\n',
			inmate.cell_number, inmate.name, inmate.time_served, inmate.sentence)
		end
		core.chat_send_player(player, list)
	end,
})


----------
-- Core --
----------

-- Detect unsanctioned violence and punish the perpetrators.
core.register_on_punchplayer(
	function(victim, hitter, time_from_last_punch, tool_capabilities, dir, damage)
		if victim == hitter then
			return
		end

		local hp = victim:get_hp()
		if hp > 0 and in_safe_zone(victim:getpos()) then
			if damage >= hp then
				justice.sentence('The court', hitter:get_player_name(), 240, 'murder')
			elseif time_from_last_punch < 2 then
				justice.sentence('The court', hitter:get_player_name(), 30, 'assault')
			-- Shooter guns set time_from_last_punch to nil. For some reason this is
			-- converted to 1000000 by minetest. I should problaby just do a check 
			-- of get_wielded_item() to include swords and whatnot but for now this
			-- fixes #2
			elseif time_from_last_punch == 1000000 then
				justice.sentence('The court', hitter:get_player_name(), 60, 'assault with a deadly weapon')
			end
		end
	end
)

-- Let inmates who die in custody respawn in a prison cell.
core.register_on_respawnplayer(function(player)
	local name = player:get_player_name()
	if data.inmates.active[name] then
		local inmate = data.inmates.active[name]
		local cell = cells[inmate.cell_number]
		player:setpos(cell.pos)
	end
	--return true -- Disable regular player placement.
end)

-- Move inmate players who log out, to the inactive inmates table.
core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	if data.inmates.active[name] then
		-- Mark the inmates cell as unoccupied.
		local inmate = data.inmates.active[name]
		cells[inmate.cell_number].occupied = false

		-- Move the inmate to the inactive list.
		data.inmates.inactive[name] = inmate
		data.inmates.active[name]   = nil
		write_data_file()

		drop_hud(inmate)
	end
end)

-- Move inmate players to the active inmates table when they log in.
core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	if data.inmates.inactive[name] then
		-- Find an unoccupied cell for the inmate.
		local inmate = data.inmates.inactive[name]
		local cell_number, cell = find_free_cell()
		inmate.cell_number = cell_number
		cell.occupied = true
		player:setpos(cell.pos)
		
		-- Move the inmate to the active list.
		data.inmates.active[name]   = inmate
		data.inmates.inactive[name] = nil
		write_data_file()

		add_hud(inmate)
	end
end)

-- Track time served for active (logged-in) inmates.
local time = 0
local count = 0
core.register_globalstep(function(dtime)
	time = time + dtime
	if time > 1 then -- about every second
		for name, inmate in pairs(data.inmates.active) do
			local player = core.get_player_by_name(name)

			-- Check for escapees, return them to prison and double their sentence.
			local p1 = cells[inmate.cell_number].pos
			local p2 = player:getpos()
			if vector.distance(p1,p2) > 5 then
				justice.sentence('The court', name, tonumber(inmate.sentence/2),
					 'attempting to escape from prison')
				player:setpos(p1)
			end

			-- Check for inmates with completed sentences and discharge them.
			inmate.time_served = inmate.time_served + time
			if inmate.time_served >= inmate.sentence then
				justice.discharge('The court', name)
			else -- Update the HUD timer.
				update_hud(inmate)
			end
		end
		time = 0

		--[[
		-- save data every 5 minutes in case of a server crash
		count = count + 1
		if count > 300 then
			write_data_file()
		end
		--]]
	end
end)


core.log(
	'action',
	string.format(
		'['..core.get_current_modname()..'] loaded in %.3fs',
		os.clock() - load_time_start
	)
)
