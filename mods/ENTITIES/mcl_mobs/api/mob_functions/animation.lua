local math = math
local vector = vector

local HALF_PI     = math.pi/2


local vector_direction = vector.direction
local vector_distance  = vector.distance
local vector_new       = vector.new

local minetest_dir_to_yaw = minetest.dir_to_yaw

-- set defined animation
mobs.set_mob_animation = function(self, anim, fixed_frame)

	if not self.animation or not anim then
		return
	end

	if self.state == "die" and anim ~= "die" and anim ~= "stand" then
		return
	end


	if (not self.animation[anim .. "_start"] or not self.animation[anim .. "_end"]) then
		return
	end

	--animations break if they are constantly set
	--so we put this return gate to check if it is
	--already at the animation we are trying to implement
	if self.current_animation == anim then
		return
	end

	local a_start = self.animation[anim .. "_start"]
	local a_end

	if fixed_frame then
		a_end = a_start
	else
		a_end = self.animation[anim .. "_end"]
	end

	self.object:set_animation({
		x = a_start,
		y = a_end},
		self.animation[anim .. "_speed"] or self.animation.speed_normal or 15,
		0, self.animation[anim .. "_loop"] ~= false)

	self.current_animation = anim
end




mobs.death_effect = function(pos, yaw, collisionbox, rotate)
	local min, max
	if collisionbox then
		min = {x=collisionbox[1], y=collisionbox[2], z=collisionbox[3]}
		max = {x=collisionbox[4], y=collisionbox[5], z=collisionbox[6]}
	else
		min = { x = -0.5, y = 0, z = -0.5 }
		max = { x = 0.5, y = 0.5, z = 0.5 }
	end
	if rotate then
		min = vector.rotate(min, {x=0, y=yaw, z=math.pi/2})
		max = vector.rotate(max, {x=0, y=yaw, z=math.pi/2})
		min, max = vector.sort(min, max)
		min = vector.multiply(min, 0.5)
		max = vector.multiply(max, 0.5)
	end

	minetest.add_particlespawner({
		amount = 50,
		time = 0.001,
		minpos = vector.add(pos, min),
		maxpos = vector.add(pos, max),
		minvel = vector_new(-5,-5,-5),
		maxvel = vector_new(5,5,5),
		minexptime = 1.1,
		maxexptime = 1.5,
		minsize = 1,
		maxsize = 2,
		collisiondetection = false,
		vertical = false,
		texture = "mcl_particles_mob_death.png^[colorize:#000000:255",
	})

	minetest.sound_play("mcl_mobs_mob_poof", {
		pos = pos,
		gain = 1.0,
		max_hear_distance = 8,
	}, true)
end
