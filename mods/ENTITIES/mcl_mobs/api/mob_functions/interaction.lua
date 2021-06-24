local minetest_after      = minetest.after
local minetest_sound_play = minetest.sound_play
local minetest_dir_to_yaw = minetest.dir_to_yaw

local math = math
local vector = vector

local MAX_MOB_NAME_LENGTH = 30

local mod_hunger = minetest.get_modpath("mcl_hunger")

mobs.feed_tame = function(self)
    return nil
end

-- Code to execute before custom on_rightclick handling
local function on_rightclick_prefix(self, clicker)
	local item = clicker:get_wielded_item()

	-- Name mob with nametag
	if not self.ignores_nametag and item:get_name() == "mcl_mobs:nametag" then

		local tag = item:get_meta():get_string("name")
		if tag ~= "" then
			if string.len(tag) > MAX_MOB_NAME_LENGTH then
				tag = string.sub(tag, 1, MAX_MOB_NAME_LENGTH)
			end
			self.nametag = tag

			mobs.update_tag(self)

			if not mobs.is_creative(clicker:get_player_name()) then
				item:take_item()
				clicker:set_wielded_item(item)
			end

 			self.persistent = true

			return true
		end

	end
	return false
end

-- I have no idea what this does
mobs.create_mob_on_rightclick = function(on_rightclick)
	return function(self, clicker)
		--don't allow rightclicking dead mobs
		if self.health <= 0 then
			return
		end
		local stop = on_rightclick_prefix(self, clicker)
		if (not stop) and (on_rightclick) then
			on_rightclick(self, clicker)
		end
	end
end


-- deal damage and effects when mob punched
mobs.mob_punch = function(self, hitter, tflp, tool_capabilities, dir)
	--don't do anything if the mob is already dead
	if self.health <= 0 then
		return
	end

	-- error checking when mod profiling is enabled
	local is_player = hitter:is_player()

	-- punch interval
	local weapon = hitter:get_wielded_item()

	--local punch_interval = 1.4

	-- exhaust attacker
	if mod_hunger and is_player then
		mcl_hunger.exhaust(hitter:get_player_name(), mcl_hunger.EXHAUST_ATTACK)
	end

	-- constant 4 damage (for now)
	local damage = 4

	-- only play hit sound and show blood effects if damage is 1 or over; lower to 0.1 to ensure armor works appropriately.
	if damage >= 0.1 then

		minetest_sound_play("default_punch", {
			object = self.object,
			max_hear_distance = 16
		}, true)

		-- do damage
		self.health = self.health - damage


		--0.4 seconds until you can hurt the mob again
		self.pause_timer = 0.4

		--don't do knockback from a rider
		for _,obj in pairs(self.object:get_children()) do
			if obj == hitter then
				return
			end
		end

		-- knock back effect
		local velocity = self.object:get_velocity()

		--2d direction
		local pos1 = self.object:get_pos()
		pos1.y = 0
		local pos2 = hitter:get_pos()
		pos2.y = 0

		local dir = vector.direction(pos2,pos1)

		local up = 3

		-- if already in air then dont go up anymore when hit
		if velocity.y ~= 0 then
			up = 0
		end

		--0.75 for perfect distance to not be too easy, and not be too hard
		local multiplier = 0.75

		-- check if tool already has specific knockback value
		local knockback_enchant = mcl_enchanting.get_enchantment(hitter:get_wielded_item(), "knockback")
		if knockback_enchant and knockback_enchant > 0 then
			multiplier = knockback_enchant + 1 --(starts from 1, 1 would be no change)
		end

		--do this to sure you can punch a mob back when
		--it's coming for you
		if self.hostile then
			multiplier = multiplier + 2
		end
		dir = vector.multiply(dir,multiplier)
		dir.y = up
		--add the velocity
		-- self.object:add_velocity(dir)
	end
end

--do internal per mob projectile calculations
mobs.shoot_projectile = function(self)
	local pos1 = self.object:get_pos()
	--add mob eye height
	pos1.y = pos1.y + self.eye_height

	local pos2 = self.attacking:get_pos()
	--add player eye height
	pos2.y = pos2.y + self.attacking:get_properties().eye_height

	--get direction
	local dir = vector.direction(pos1,pos2)

	--call internal shoot_arrow function
	self.shoot_arrow(self,pos1,dir)
end

mobs.update_tag = function(self)
	self.object:set_properties({
		nametag = self.nametag,
	})
end
