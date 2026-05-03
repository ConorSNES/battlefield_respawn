-- net strings
util.AddNetworkString( "bfres_showUI" )
util.AddNetworkString( "bfres_hideUI" )

util.AddNetworkString( "bfres_requestSpawns" )
util.AddNetworkString( "bfres_handleSpawns" )

util.AddNetworkString( "bfres_respawnIndex" )
util.AddNetworkString( "bfres_respawnNow" )

function GetSpawns()
	-- This code is from the player.lua file in the base gamemode- it should obtain all possible spawnpoints
	local o

	-- HL2 Maps
	o = ents.FindByClass( "info_player_start" )
	o = table.Add( o, ents.FindByClass( "info_player_deathmatch" ) )
	o = table.Add( o, ents.FindByClass( "info_player_combine" ) )
	o = table.Add( o, ents.FindByClass( "info_player_rebel" ) )

	-- CS Maps
	o = table.Add( o, ents.FindByClass( "info_player_counterterrorist" ) )
	o = table.Add( o, ents.FindByClass( "info_player_terrorist" ) )

	-- DOD Maps
	o = table.Add( o, ents.FindByClass( "info_player_axis" ) )
	o = table.Add( o, ents.FindByClass( "info_player_allies" ) )

	-- (Old) GMod Maps
	o = table.Add( o, ents.FindByClass( "gmod_player_start" ) )

	-- TF Maps
	o = table.Add( o, ents.FindByClass( "info_player_teamspawn" ) )

	-- INS Maps
	o = table.Add( o, ents.FindByClass( "ins_spawnpoint" ) )

	-- AOC Maps
	o = table.Add( o, ents.FindByClass( "aoc_spawnpoint" ) )

	-- Dystopia Maps
	o = table.Add( o, ents.FindByClass( "dys_spawn_point" ) )

	-- PVKII Maps
	o = table.Add( o, ents.FindByClass( "info_player_pirate" ) )
	o = table.Add( o, ents.FindByClass( "info_player_viking" ) )
	o = table.Add( o, ents.FindByClass( "info_player_knight" ) )

	-- DIPRIP Maps
	o = table.Add( o, ents.FindByClass( "diprip_start_team_blue" ) )
	o = table.Add( o, ents.FindByClass( "diprip_start_team_red" ) )

	-- OB Maps
	o = table.Add( o, ents.FindByClass( "info_player_red" ) )
	o = table.Add( o, ents.FindByClass( "info_player_blue" ) )

	-- SYN Maps
	o = table.Add( o, ents.FindByClass( "info_player_coop" ) )

	-- ZPS Maps
	o = table.Add( o, ents.FindByClass( "info_player_human" ) )
	o = table.Add( o, ents.FindByClass( "info_player_zombie" ) )

	-- ZM Maps
	o = table.Add( o, ents.FindByClass( "info_player_zombiemaster" ) )

	-- FOF Maps
	o = table.Add( o, ents.FindByClass( "info_player_fof" ) )
	o = table.Add( o, ents.FindByClass( "info_player_desperado" ) )
	o = table.Add( o, ents.FindByClass( "info_player_vigilante" ) )

	-- L4D Maps
	o = table.Add( o, ents.FindByClass( "info_survivor_rescue" ) )

	return o
end

-- locals
local g = {} -- Stored table of user's selected spawnlocation
local spawns = {}
function spawns:fetch()
	if spawns._inner == nil then
		spawns:force_reload()
	elseif #(spawns._inner) > 0 and spawns._inner[0] == NULL then -- fix for NULL entity bug
		spawns:force_reload() -- I understand this seems redundant with the previous branch. However, using "or" would result in a nil error.
	end
	return spawns._inner
end
function spawns:force_reload()
	spawns._inner = GetSpawns()
	print("Reloaded inner spawns! Discovered " .. #(spawns._inner) .. "!!")
end
function spawns:force_fetch()
	spawns:force_reload()
	return spawns._inner
end

---@diagnostic disable-next-line: param-type-mismatch
local AllowSelect = CreateConVar( "bfres_allowselect", "1", bit.bor(FCVAR_REPLICATED, FCVAR_NOTIFY), "Allow/Disallow selection of spawn point using bfres window", 0, 1)
---@diagnostic disable-next-line: param-type-mismatch
local AllowSpawnTeleport = CreateConVar( "bfres_allowspawnteleport", "0", bit.bor(FCVAR_REPLICATED, FCVAR_NOTIFY), "Allow \"teleporting to spawn\" (respawning still alive players to spawnpoints)" )

-- net request wrappers

local function DoRaiseClientRespawnOverlay( ply )
	net.Start("bfres_showUI")
	net.Send(ply)
end

local function DoHideClientRespawnOverlay( ply )
	net.Start("bfres_hideUI")
	net.Send(ply)
end

-- perform first (and only, fingers crossed) load of world spawns upon entity load
hook.Add( "InitPostEntity", "bfres_initspawns", function()
	spawns:force_reload()
end )

-- raise the respawn overlay when the player dies
hook.Add( "DoPlayerDeath", "bfres_ondeath", function( ply )
	if ply == NULL then return end

	if AllowSelect:GetBool() then
		-- the overlay should not be shown if selection is not allowed at the moment
		DoRaiseClientRespawnOverlay(ply)
	end
end )

-- use custom selected spawnpoint, or random if none is defined
hook.Add( "PlayerSelectSpawn", "bfres_selectspawn", function( ply )
	local spawns_now = spawns:fetch()
	if AllowSelect:GetBool() and g[ply:AccountID()] ~= nil and g[ply:AccountID()] ~= 0 then
		if not spawns_now[ g[ply:AccountID()] ]:IsValid() then
			spawns_now = spawns:force_fetch()
		end
		return spawns_now[ g[ply:AccountID()] ]
	end
	DoHideClientRespawnOverlay(ply)
end )

-- disable spawnpoint selection if this is not sandbox
hook.Add( "PostGamemodeLoaded", "bfres_isUsed", function()
	-- alright, trying again
	if engine.ActiveGamemode() ~= "sandbox" then
		print("Battlefield respawn disabled serverside as gamemode is " .. engine.ActiveGamemode())
		AllowSelect:SetBool(false)
	end
end )

-- disable respawning on pressing the usual keys (this is handled by respawnNow instead)
hook.Add( "PlayerDeathThink", "bfres_respawnbind_disable", function (ply)
	if AllowSelect:GetBool() and (ply:KeyPressed( IN_ATTACK ) or ply:KeyPressed( IN_ATTACK2 ) or ply:KeyPressed( IN_JUMP )) then
		return false
	end
end )

net.Receive( "bfres_requestSpawns", function( len, ply )
	local spawns_now = spawns:fetch()
	-- Try again to get a log of all spawns if there are none currently here
	if #spawns_now <= 0 then
		spawns_now = spawns:force_fetch()
	end

	print("[bfres] Providing " .. #spawns_now .. " spawnpoints for " .. ply:Nick())

	-- Manage net
	net.Start("bfres_handleSpawns")

	-- Get the vectors for the spawns bc the spawns don't exist on the client
	-- also min/max for hammer editor is 15 bit (2^15), unless you cracked it or something idk
	for k, v in ipairs( spawns_now ) do
		--if net.BytesLeft() and net.BytesLeft() < 31 then break end -- fix for memoryfull
		local pos = v:GetPos()
		net.WriteInt( math.floor(pos.x), 15)
		net.WriteInt( math.floor(pos.y), 15)
	end

	net.Send( ply )
end )

net.Receive( "bfres_respawnIndex", function( len, ply )
	if !AllowSelect:GetBool() then error("A client attempted to set their respawn point while bfres_allowselect is false!") end
	if len < 8 then error("A client sent bfres_respawnIndex without payload!") end
	
	local d = net.ReadUInt( 8 )
	g[ply:AccountID()] = d
end )

net.Receive( "bfres_respawnNow", function( len, ply )
	if (not ply:Alive()) or AllowSpawnTeleport:GetBool() then	-- whoopsies (issue 1, teleportation exploit)
		ply:Spawn()
	else
		print("[bfres] Rejected " .. ply:Nick() .. "'s respawn attempt")
	end
end )

