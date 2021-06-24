-- an action is the smallest unit of mob behavior. The think function should
-- decide on an action.
jm_action = {}

-- create a new action
function jm_action:mk_action(act, contents)
	local o = contents or {}
	o.done = false
	o.act = act
	setmetatable(o, jm_action)
	return o
end

function jm_action:act(mob)
	-- if the action already finished, then do nothing
	if not self.done then
		self:act(mob)
	end
end

-- create an action which will call act every tick until the timer expires

-- all times are in ticks
function jm_action:mk_timed_action(act, time, contents)
	local function timed_act(action, mob)
		if action.timer == 0 then
			action.done = true
		else
			action.timer = action.timer - 1
			act(action, mob)
		end
	end
	return jm_action:mk_action(nil, timed_act, contents)
end

-- Creates an action that walks in a direction for timeout ticks.
function jm_action:mk_walk_action(dir, timeout)
	local function act(action, mob)
		mobs.set_mob_animation(mob, 'walk')
		-- TODO: write walking code
		print('i\'m walking here')
	end

	if timeout then
		return jm_action:mk_timed_action(act, timeout)
	end
	return jm_action:mk_action(act)
end

print('hey')
