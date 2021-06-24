-- Jack's Mineclone mobs rewrite

-- most of my code is the same as the main mineclone2 project, but I intend to
-- completely replace all the mob code. I've already done that, for the most
-- part.


-- jack's mineclone table. I use this so as to prevent namespace collisions
jm = jm or {}

-- mobs class
jm.mob = {}
jm.mob.__index = jm.mob

mobs = {}

-- lua locals - can grab from this to easily plop them into the api lua files

--localize minetest functions
local minetest_settings                     = minetest.settings
local minetest_get_objects_inside_radius    = minetest.get_objects_inside_radius
local minetest_get_modpath                  = minetest.get_modpath
local minetest_registered_nodes             = minetest.registered_nodes
local minetest_get_node                     = minetest.get_node
local minetest_registered_entities          = minetest.registered_entities
local minetest_add_item                     = minetest.add_item
local minetest_add_entity                   = minetest.add_entity

local math_random = math.random

-- Load main settings
local difficulty        = tonumber(minetest_settings:get("mob_difficulty")) or 1.0

-- Get translator
local S = minetest.get_translator(minetest.get_current_modname())

local api_path = minetest.get_modpath(minetest.get_current_modname()).."/api/mob_functions/"

--ignite all parts of the api
dofile(api_path .. "actions.lua")
dofile(api_path .. "ai.lua")
dofile(api_path .. "animation.lua")
dofile(api_path .. "util.lua")
dofile(api_path .. "sound_handling.lua")
dofile(api_path .. "death_logic.lua")
dofile(api_path .. "mob_effects.lua")

mobs.spawning_mobs = {}

-- get entity staticdata
function jm.mob:staticdata()
	local res = {}

    -- FIXME: right now, this just mindlessly copies everything. Maybe it shouldn't
	for k,v in pairs(self) do
		local t = type(v)

		if  t ~= "function"
            and t ~= "nil"
            and t ~= "userdata"
            and k ~= "step_hooks"
            and k ~= "action"
        then
			res[k] = v
		end
	end

	return minetest.serialize(tmp)
end


-- activate mob and reload settings
function jm.mob:activate(staticdata, def, dtime)
    self.step_hooks = {}
    self.on_step = self.step

	-- restore properties from staticdata
	local data = minetest.deserialize(staticdata)
	if data then
		for k,v in pairs(data) do
			self[k] = v
		end
	end

	if not self.health then
		self.health = math_random (def.hp_min, def.hp_max)
	end

    -- first time texture setup
	if not self.textures then
        -- this commented code block is from mineclone2:

		-- compatiblity with old simple mobs textures
		-- if type(def.textures[1]) == "string" then
		-- 	def.textures = {def.textures}
		-- end

		self.textures = def.textures[math_random(1, #def.textures)]
		self.mesh = def.mesh
	end

	self.old_health = self.health
    self.sounds = {}
	self.sounds.distance = self.sounds.distance or 10

	self.texture_mods = {}

	self.v_start = false
	self.timer = 0
	self.blinktimer = 0
	self.blinkstatus = false

	-- set anything changed above
	self.object:set_properties(self)
end


-- register mob entity
function jm.mob:register_mob(name, def)

	local collisionbox = def.collisionbox or {-0.25, -0.25, -0.25, 0.25, 0.25, 0.25}

    -- code from mineclone2
 
	-- Workaround for <https://github.com/minetest/minetest/issues/5966>:
	-- Increase upper Y limit to avoid mobs glitching through solid nodes.
	-- FIXME: Remove workaround if it's no longer needed.

	if collisionbox[5] < 0.79 then
		collisionbox[5] = 0.79
	end

	local function scale_difficulty(value, default, min, special)
		if (not value) or (value == default) or (value == special) then
			return default
		else
			return math.max(min, value * difficulty)
		end
	end

	local o = {
		description = def.description,
		name = name,
		type = def.type,
		rotate = def.rotate or 0, --  0=front, 90=side, 180=back, 270=side2
		hp_min = scale_difficulty(def.hp_min, 5, 1),
		hp_max = scale_difficulty(def.hp_max, 10, 1),
		xp_min = def.xp_min or 1,
		xp_max = def.xp_max or 5,
		breath_max = def.breath_max or 6,
		breathes_in_water = def.breathes_in_water or false,
		physical = true,
		collisionbox = collisionbox,
		collide_with_objects = def.collide_with_objects or false,
		selectionbox = def.selectionbox or collisionbox,
		visual = def.visual,
		visual_size = def.visual_size or {x = 1, y = 1},
		mesh = def.mesh,
		drops = def.drops or {},
		sounds = def.sounds or {},
		animation = def.animation,
		texture_list = def.textures,

		--j4i stuff
		yaw = 0,
		automatic_face_movement_dir = def.rotate or 0,  --  0=front, 90=side, 180=back, 270=side2
		automatic_face_movement_max_rotation_per_sec = 360, --degrees
		backface_culling = true,
		current_animation = "",
		death_animation_timer = 0,
		--end j4i stuff

		-- Jack's extensions
		step_hooks = { },
		default_state = def.default_state or 'wander',
		state_timer = nil,	-- tells how long to wait before reverting to the
                    		-- default state
		target = nil,						  -- target entity (to follow/attack)
		persistent = def.persistent or false, -- prevents despawn
		egg_timer = 1000,					  -- lay eggs

        burning = false,
		-- End of Jack's extensions

		on_step = function(self, dtime)
            self:step(dtime)
        end,
		on_punch = mobs.mob_punch,

		on_activate = function(self, staticdata, dtime)
            setmetatable(self, jm.mob)
            -- FIXME: remove this field
            self.death_animation_timer = 0
			self:activate(staticdata, def, dtime)
            -- FIXME: move hook setup to init code
            self:add_despawn_hook()
            self:add_burn_dmg_hook()
            self:add_sunburn_hook()
            -- FIXME: move action setup to logic code
            self.action = jm_action:mk_walk_action(100)
		end,

		get_staticdata = function(self)
			return self:staticdata()
		end,
	}
	minetest.register_entity(name, o)
end

-- Register spawn eggs

-- Note: This also introduces the “spawn_egg” group:
-- * spawn_egg=1: Spawn egg (generic mob, no metadata)
-- * spawn_egg=2: Spawn egg (captured/tamed mob, metadata)
function mobs:register_egg(mob, desc, background, addegg, no_creative)

	local grp = {spawn_egg = 1}

	-- do NOT add this egg to creative inventory (e.g. dungeon master)
	if no_creative == true then
		grp.not_in_creative_inventory = 1
	end

	local invimg = background

	if addegg == 1 then
		invimg = "mobs_chicken_egg.png^(" .. invimg ..
			"^[mask:mobs_chicken_egg_overlay.png)"
	end

	-- register old stackable mob egg
	minetest.register_craftitem(mob, {

		description = desc,
		inventory_image = invimg,
		groups = grp,

		_doc_items_longdesc = S("This allows you to place a single mob."),
		_doc_items_usagehelp = S("Just place it where you want the mob to appear. Animals will spawn tamed, unless you hold down the sneak key while placing. If you place this on a mob spawner, you change the mob it spawns."),

		on_place = function(itemstack, placer, pointed_thing)

			local pos = pointed_thing.above

			-- am I clicking on something with existing on_rightclick function?
			local under = minetest_get_node(pointed_thing.under)
			local def = minetest_registered_nodes[under.name]
			if def and def.on_rightclick then
				return def.on_rightclick(pointed_thing.under, under, placer, itemstack)
			end

			if pos
			--and within_limits(pos, 0)
			and not minetest.is_protected(pos, placer:get_player_name()) then

				local name = placer:get_player_name()
				local privs = minetest.get_player_privs(name)
				if mod_mobspawners and under.name == "mcl_mobspawners:spawner" then
					if minetest.is_protected(pointed_thing.under, name) then
						minetest.record_protection_violation(pointed_thing.under, name)
						return itemstack
					end
					if not privs.maphack then
						minetest.chat_send_player(name, S("You need the “maphack” privilege to change the mob spawner."))
						return itemstack
					end
					mcl_mobspawners.setup_spawner(pointed_thing.under, itemstack:get_name())
					if not mobs.is_creative(name) then
						itemstack:take_item()
					end
					return itemstack
				end

				if not minetest_registered_entities[mob] then
					return itemstack
				end

				if minetest_settings:get_bool("only_peaceful_mobs", false)
						and minetest_registered_entities[mob].type == "monster" then
					minetest.chat_send_player(name, S("Only peaceful mobs allowed!"))
					return itemstack
				end

				local mob = minetest_add_entity(pos, mob)
				-- minetest.log("action", "Mob spawned: "..name.." at "..minetest.pos_to_string(pos))
				-- local ent = mob:get_luaentity()

				-- -- if not in creative then take item
				-- if not mobs.is_creative(placer:get_player_name()) then
				-- 	itemstack:take_item()
				-- end
			end

			return itemstack
		end,
	})

end


