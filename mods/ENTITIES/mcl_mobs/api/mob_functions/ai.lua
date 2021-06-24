--------------------------------------------------------------------------------
----- Mob AI code

local random = math.random
local HALF_PI = math.pi / 2


-- Mob logic has three stages. First, we execute all the necessary per-step
-- checks, such as applying environmental damage, checking for death, etc. After
-- this, the mob enters the "thinking-acting" phase where it decides what to do next.
-- This is largely dependent on the state variable. Finally, we apply physics to
-- the mob, which includes jumping, gravity, mob packing, and interaction with
-- liquids.

-- The first stage is accomplished by maintaining a table of hooks to execute
-- every step in the main loop. There is no guaranteed call order for hooks.
-- Hooks may remove themselves when they are no longer needed (for instance, the
-- despawn check hook is removed if the mob becomes persistent). This makes
-- hooks useful for setting temporary timers.

-- The second stage revolves around two concepts: the state and the action. The
-- state decides the overarching algorithm the mob uses to "think" (e.g.
-- "wander" or "panic"). The action is a fine-tuned and concrete description of
-- the current activity, containing information such as "walk toward location
-- X", "follow entity Y", or "jump".

-- The code executed for each state may be provided at mob creation. Additional
-- custom states may also be defined. Custom actions may also be defined, but
-- these should rarely be necessary since most mob behavior can be covered by
-- attacking, moving from place to place, and following. Add a few more prebuilt
-- actions and that should cover just about everything.

-- For physics, we compute a net force being exerted on an entity based on the
-- other entities it collides with (i.e. mob packing behavior), plus gravity,
-- plus explosions, plus liquids, plus movement. This is used to compute the
-- velocity of the mob.

-- custom hooks: on_activate on_die on_spawn on_detonate on_blast on_ignite
-- on_burn on_drown on_receive on_breed on_tame on_grow_up on_rightclick

-- mob variables:
-- stunned, stun_time
-- health, old_health
-- can_burn, burning, burn_time, burn_damage
-- can_drown, drowning, drown_time, drown_damage
-- burns_in_sun
-- owner
-- think function
-- state/task

-- poison the mob
--function mobs.poison(mob,...)

function jm.mob:add_hook(hook)
    table.insert(self.step_hooks, hook)
end

function jm.mob:remove_hook(hook_id)
    table.remove(self.step_hooks, hook_id)
end


function jm.mob:kill()
    self.dead = true
    -- should play a death animation
end

-- stun the mob for stun_time ticks
function jm.mob:stun(stun_time)
    stun_time = stun_time or 10
    if self.stunned then
        self.stun_time = math.max(self.stun_time, stun_time)
    else
        self.stunned = true
        self.stun_time = stun_time
        self:add_stun_hook()
    end
end

-- hook used to decrement the stun timer
function jm.mob:add_stun_hook(mob)
    local hook = function(hook_id)
        self.stun_time = stun_time - 1
        if self.stun_time <= 0 then
            stunned = false
        end
        -- this accounts for the case that the stunned status was changed by
        -- another function
        if stunned == false then
            self:remove_hook(hook_id)
        end
    end
    self:add_hook(hook)
end

-- light the mob on fire for burn_time ticks
function jm.mob:ignite(burn_time)
    burn_time = burn_time or 160
    --self.burn_time = self.burn_time or 0
    if self.burning then
        -- just reset the timer
        self.burn_time = math.max(burn_time, self.burn_time or 0)
    else
        self.burning = true
        self.burn_time = burn_time
        -- do the animation
        mcl_burning.set_on_fire(self.object, burn_time*20)

        -- this is the hook to count decrement the burn timer
        local hook = function(hook_id)
            self.burn_time = self.burn_time - 1
            if self.burn_time <= 0 then
                self.burning = false
            end
            -- this accounts for the case that the burning status was changed by
            -- another function
            if self.burning == false then
                mcl_burning.extinguish(self.object)
                self:remove_hook(hook_id)
            end
        end
        self:add_hook(hook)
    end
end

-- adds a hook that causes the mob to catch fire in sunlight
function jm.mob:add_sunburn_hook(burn_time)
    burn_time = burn_time or 160
    local hook = function(hook_id)
        local pos = self.pos
        pos.y = pos.y + 0.1
        local cur_light = minetest.get_node_light(pos)
        local day_light = minetest.get_node_light(pos, 0.5)
        if cur_light > 12 and day_light == 15 then
            self:ignite(burn_time)
        end
    end
    self:add_hook(hook)
end

-- FIXME: add parameters here to control burning, drowning (damage + rate)

-- TODO: add code to call custom hooks for burning/drowning

function jm.mob:add_burn_dmg_hook(amount)
    amount = amount or 1
    local hook = function(hook_id)
        if self.burning then
            self.burn_dmg_timer = self.burn_dmg_timer - 1
            if self.burn_dmg_timer <= 0 then
                self.health = self.health - amount
                self.burn_dmg_timer = 20
            end
        end
    end
    self.burn_dmg_timer = 0
    self:add_hook(hook)
end

-- The hook to inflict drowning damage.
function jm.mob:add_drown_dmg_hook()
    local hook = function(hook_id)
        local pos = self.pos
		pos.y = pos.y + self.eye_height

		local node = minetest_get_node(pos).name

		if minetest_get_item_group(node, "water") ~= 0 then
			self.breath = self.breath - dtime

			--reset breath when drowning
			if self.breath <= 0 then
				self.health = self.health - 4
				self.breath = 1
                self:stun()
			end

		elseif self.breath < self.breath_max then
			self.breath = self.breath + dtime
			--clean timer reset
			if self.breath > self.breath_max then
				self.breath = self.breath_max
			end
        end
    end
    --self.breath_max = 
    self.breath = self.breath_max
    self:add_hook(hook)
end

-- This is the hook to despawn non-persistent jm.mob: Deletes itself if persistent
-- is set.
function jm.mob:add_despawn_hook()
    local hook = function(id)
        if self.persistent then
            self:remove_hook(hook_id)
        else
            -- FIXME: Fish should despawn in a smaller, 64-block radius for
            -- compatibility with Minecraft.

            local _,dist = self:nearest_player()
            -- nil distance indicates no players on server

            -- Beyond 32 blocks, mobs have a 1/800 chance of despawning each tick.
            -- Beyond 128 blocks, they despawn instantly.
            if (not dist)
                or dist > 128
                or (dist > 32 and random(800) == 1)
            then
                self:kill()
            end
        end
    end
    self:add_hook(hook)
end

 -- This is the hook to grow babies into adults. Default: 24000 ticks
function jm.mob:add_grow_up_hook(grow_up_time)
    self.grow_up_timer = grow_up_time or 24000
    local hook = function(hook_id)
        self.grow_up_timer = self.grow_up_timer - 1
        if self.baby_timer <= 0 then
            -- we've grown up :')
            -- FIXME: write grow up code here

            -- delete this hook so it isn't called again
            self:remove_hook(hook_id)
        end
    end
    self:add_hook(hook)
end

-- FIXME: rewrite this
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

-- step function
function jm.mob:step(dtime)
	-- FIXME: this probably shouldn't be here?
	--do not continue if non-existent
	if (not self) or (not self.object) or (not self.object:get_luaentity()) then
		self.object:remove()
		return false
	end

    -- Setting this once here allows it to be used throughout the hooks and
    -- state management behavior.
    self.pos = self.object:get_pos()

    -- Run mob hooks.
    for hook_id,hook in ipairs(self.step_hooks) do
        hook(hook_id, dtime)
    end

	--do death logic (animation, poof, explosion, etc)
	if self.dead then
		self:death_logic(dtime)
		return
	end

    -- TODO: make this into a hook
	--jm.mob:random_sound_handling(self,dtime)

    -- Execute hooks. These handle the following:
    -- - fire and drowning damage
    -- - death
    -- - state switching
    -- - despawning
    -- - babies growing
    -- - state switching
    -- - custom per-step behavior

    -- Hooks may delete themselves when a certain objective is met (i.e. the
    -- baby hook and the despawning hook both delete themselves when they are no
    -- longer needed).
	
	-- Check for damage after running the hooks
	if self.old_health and self.health < self.old_health then
		-- FIXME: the next line should be handled in animation code. I'll add a
		-- new variable called hurt_animation or something
		--color modifier which coincides with the pause_timer
		self.object:set_texture_mod("^[colorize:red:120")

		if self.health > 0 then
			mobs.play_sound(self,"damage")
		else
			self:kill()
			mobs.play_sound(self,"death")
			return
		end
	end
	self.old_health = self.health

    -- decide on anaction
    --self:decide_state()

    -- perform the action
    self.action:act(self)
end
