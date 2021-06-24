local math_random = math.random

local minetest_settings = minetest.settings

-- get entity staticdata
function jm.mob:mob_staticdata()
	local tmp = {}

	for _,stat in pairs(self) do

		local t = type(stat)

		if  t ~= "function"
            and t ~= "nil"
            and t ~= "userdata"
            and _ ~= "_cmi_components"
            and _ ~= "step_hooks"
            and _ ~= "action"
        then
			tmp[_] = self[_]
		end
	end

	return minetest.serialize(tmp)
end


-- activate mob and reload settings
function jm.mob:activate(staticdata, def, dtime)
    self.step_hooks = {}
    self.on_step = self.step

	-- load entity variables
	local tmp = minetest.deserialize(staticdata)

	if tmp then
		for _,stat in pairs(tmp) do
			self[_] = stat
		end
	end

	if not self.health then
		self.health = math_random (def.hp_min, def.hp_max)
	end

	--clear animation
	self.current_animation = nil

	-- select random texture, set model and size
	if not self.base_texture then

		-- compatiblity with old simple mobs textures
		if type(def.textures[1]) == "string" then
			def.textures = {def.textures}
		end

		self.base_texture = def.textures[math_random(1, #def.textures)]
		self.base_mesh = def.mesh
		self.base_size = self.visual_size
		self.base_colbox = self.collisionbox
		self.base_selbox = self.selectionbox
	end

	-- set texture, model and size
	local textures = self.base_texture
	local mesh = self.base_mesh
	local vis_size = self.base_size
	local colbox = self.base_colbox
	local selbox = self.base_selbox

	if self.breath == nil then
		self.breath = self.breath_max
	end

	-- Armor groups
	-- immortal=1 because we use custom health
	-- handling (using "health" property)
	local armor
	if type(self.armor) == "table" then
		armor = table.copy(self.armor)
		armor.immortal = 1
	else
		armor = {immortal=1, fleshy = self.armor}
	end
	self.object:set_armor_groups(armor)
	self.old_y = self.object:get_pos().y
	self.old_health = self.health
    self.sounds = {}
	self.sounds.distance = self.sounds.distance or 10
	self.textures = textures
	self.mesh = mesh
	self.collisionbox = colbox
	self.selectionbox = selbox
	self.visual_size = vis_size
	self.standing_in = "ignore"
	self.standing_on = "ignore"
	self.jump_sound_cooloff = 0 -- used to prevent jump sound from being played too often in short time
	self.opinion_sound_cooloff = 0 -- used to prevent sound spam of particular sound types

	self.texture_mods = {}

	self.v_start = false
	self.timer = 0
	self.blinktimer = 0
	self.blinkstatus = false

	-- set anything changed above
	self.object:set_properties(self)
end
