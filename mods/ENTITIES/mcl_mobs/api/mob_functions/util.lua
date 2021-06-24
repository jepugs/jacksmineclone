-- This is used for the new despawn behavior. Returns player,distance. Uses
-- Euclidean distance. Returns nil if no players are connected.
function jm.mob:nearest_player()
	local pos = self.object:get_pos()
	local players = minetest.get_connected_players()
	if #players == 0 then
		return nil, nil
	end

	-- initial max is the first player
	local max_player = players[1]
	local max_dist = vector.distance(pos,max_player:get_pos())
	for _,player in pairs(players) do
		local d = vector.distance(pos,player:get_pos())
		if d > max_dist then
			max_player = player
			max_dist = d
		end
	end
	return max_player,max_dist
end
