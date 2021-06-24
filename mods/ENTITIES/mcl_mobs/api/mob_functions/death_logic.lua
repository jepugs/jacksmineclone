local random = math.random
local floor = math.floor
local mt_add_item = minetest.add_item
local mt_get_craft_result = minetest.get_craft_result
local HALF_PI     = math.pi / 2

function jm.mob:death_logic(dtime)
	-- FIXME: self should never be nil, and this check shouldn't be here. The
	-- correct approach is to not call this function with invalid input. I can't
	-- find anywhere where this happens though.

	--stop crashing game when object is nil
	if not self or not self.object or not self.object:get_luaentity() then
		return
	end

    self.death_animation_timer = self.death_animation_timer + dtime

	--stop mob from getting in the way of other mobs you're fighting
	if self.object:get_properties().pointable then
		self.object:set_properties({pointable = false})
	end

    --the final POOF of a mob despawning
    if self.death_animation_timer >= 1.25 then
        mobs.death_effect(self)
		-- FIXME: this should probably be handled elsewhere
        self.object:remove()

		return
    end

    --I'm sure there's a more efficient way to do this
    --but this is the easiest, easier to work with 1 variable synced
    --this is also not smooth
    local death_animation_roll = self.death_animation_timer * 2 -- * 2 to make it faster
    if death_animation_roll > 1 then
        death_animation_roll = 1
    end

    local rot = self.object:get_rotation() --(no pun intended)

    rot.z = death_animation_roll * HALF_PI

    self.object:set_rotation(rot)

    mobs.set_mob_animation(self,"stand", true)
end
