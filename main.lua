local MIR = RegisterMod("Mark Impossible Rooms", 1)
function MIR:Log(msg)
	-- Uncomment to enable logging
	--Isaac.ConsoleOutput(msg)
end

-- Adds the "impossible room" sprite.
-- Actually doesn't work, in-game it's displayed as an empty texture, don't tell anyone!
MIR.ImpossibleRoomSpriteSmall = Sprite()
MIR.ImpossibleRoomSpriteSmall:Load("gfx/ui/custom_minimap1.anm2", true)
MIR.ImpossibleRoomSpriteLarge = Sprite()
MIR.ImpossibleRoomSpriteLarge:Load("gfx/ui/custom_minimap2.anm2", true)
if MinimapAPI then
	MinimapAPI:AddRoomShape(
		"ImpossibleRoom",
		{
			RoomUnvisited = {
				sprite = MIR.ImpossibleRoomSpriteSmall,
				anim = "gfx/ui/custom_minimap1.anm2",
				frame = 0
			},
			RoomVisited = {
				sprite = MIR.ImpossibleRoomSpriteSmall,
				anim = "gfx/ui/custom_minimap1.anm2",
				frame = 0
			},
			RoomCurrent = {
				sprite = MIR.ImpossibleRoomSpriteSmall,
				anim = "gfx/ui/custom_minimap1.anm2",
				frame = 0
			},
			RoomSemivisited = {
				sprite = MIR.ImpossibleRoomSpriteSmall,
				anim = "gfx/ui/custom_minimap1.anm2",
				frame = 0
			}
		},
		{
			RoomUnvisited = {
				sprite = MIR.ImpossibleRoomSpriteLarge,
				anim = "gfx/ui/custom_minimap2.anm2",
				frame = 0
			},
			RoomVisited = {
				sprite = MIR.ImpossibleRoomSpriteLarge,
				anim = "gfx/ui/custom_minimap2.anm2",
				frame = 0
			},
			RoomCurrent = {
				sprite = MIR.ImpossibleRoomSpriteLarge,
				anim = "gfx/ui/custom_minimap2.anm2",
				frame = 0
			},
			RoomSemivisited = {
				sprite = MIR.ImpossibleRoomSpriteLarge,
				anim = "gfx/ui/custom_minimap2.anm2",
				frame = 0
			}
		},
		Vector(0, 0),
		Vector(1, 1),
		{Vector(0, 0)},
		{Vector(0, 0)},
		Vector(0, 0),
		{Vector(0, 0)},
		Vector(0, 0),
		{Vector(-1, 0), Vector(0, -1), Vector(1, 0), Vector(0, 1)}
	)
end

MIR.DoorTable = {
	-- Lists location and doorslots of adjacent rooms depending on room shape
	-- https://wofsauge.github.io/IsaacDocs/rep/enums/RoomShape.html

	-- 1x1
	{{-1, 0}, {0, -1}, {1, 0}, {0, 1}, nil, nil, nil, nil},
	-- 1x1 horizontal corridor
	{{-1, 0}, {0, -1}, {1, 0}, {0, 1}, nil, nil, nil, nil},
	-- 1x1 vertical corridor
	{{-1, 0}, {0, -1}, {1, 0}, {0, 1}, nil, nil, nil, nil},
	-- 2x1 vertical
	{{-1, 0}, {0, -1}, {1, 0}, {0, 2}, {-1, 1}, nil, {1, 1}, nil},
	-- 2x1 vertical corridor
	{{-1, 0}, {0, -1}, {1, 0}, {0, 2}, {-1, 1}, nil, {1, 1}, nil},
	-- 2x1 horizontal
	{{-1, 0}, {0, -1}, {2, 0}, {0, 1}, nil, {1, -1}, nil, {1, 1}},
	-- 2x1 horizontal corridor
	{{-1, 0}, {0, -1}, {2, 0}, {0, 1}, nil, {1, -1}, nil, {1, 1}},
	-- 2x2
	{{-1, 0}, {0, -1}, {2, 0}, {0, 2}, {-1, 1}, {1, -1}, {2, 1}, {1, 2}},
	-- lower right L shape
    {{-1, 0}, {-1, 0}, {1, 0}, {-1, 2}, {-2, 1}, {0, -1}, {1, 1}, {0, 2}},
	-- lower left L shape
    {{-1, 0}, {0, -1}, {1, 0}, {0, 2}, {-1, 1}, {1, 0}, {2, 1}, {1, 2}},
	-- upper right L shape
	{{-1, 0}, {0, -1}, {2, 0}, {0, 1}, {0, 1}, {1, -1}, {2, 1}, {1, 2}},
	-- upper left L shape
	{{-1, 0}, {0, -1}, {2, 0}, {0, 2}, {-1, 1}, {1, -1}, {1, 1}, {1, 1}}
}
MIR.AddWhenOtherVisibleCache = {}
MIR.LastFloorCacheCleared = nil






function MIR:MarkImpossibleRooms()
	local stage = Game():GetLevel():GetStage()
	local room = MinimapAPI:GetCurrentRoom()
	local pos = room.Position -- vector
	local shape = room.Shape
	local validDoors = room.Descriptor.Data.Doors -- bitmap of what entrances are valid
	local neighbors = MIR:GetNeighbors(pos, shape)

	-- POST_NEW_ROOM is called before POST_NEW_LEVEL, meaning this function executes before
	-- the cache is cleared at the start of a floor
	-- This is a workaround by checking manually instead of using a callback
	if MIR.LastFloorCacheCleared ~= stage then
		MIR.AddWhenOtherVisibleCache = {}
		MIR.LastFloorCacheCleared = stage
	end

	MIR:Log("\nShape: "..shape..", bitmap: "..validDoors..", coords: "..pos.X..", "..pos.Y.."\nNeighbors:")
	for _,v in ipairs(neighbors) do MIR:Log(" {"..v.X..", "..v.Y.."}") end
	MIR:Log("\nChecking rooms...")

	-- Get invalid entrances to neighboring rooms
	for n=0,7 do
		if validDoors & 1 << n == 0 then
			local delta = MIR.DoorTable[shape][n+1]
			if delta then
				MIR:AddRoom(Vector(pos.X + delta[1], pos.Y + delta[2]))
			end
		end
	end

	MIR:AddFromCache()

	-- Loop through all adjacent rooms (neighbors)
	for _,neighbor in ipairs(neighbors) do 
	if MinimapAPI:IsPositionFree(neighbor) then

		-- Check the neighbor's neighbors (nNeighbors)
		for _,nNeighbor in ipairs(MIR:GetNeighbors(neighbor, RoomShape.ROOMSHAPE_1x1)) do
		local nNeighborRoom = MinimapAPI:GetRoomAtPosition(nNeighbor)
		if nNeighborRoom then

			local impossible = false
			-- Does the neighbor's neighbor invalidate the neighbor itself?
			-- boss room
			if nNeighborRoom.Type == RoomType.ROOM_BOSS then
				impossible = true
			-- vertical corridor
			elseif nNeighborRoom.Type == RoomType.ROOMSHAPE_IV or nNeighborRoom.Type == RoomType.ROOMSHAPE_IIV then
				if nNeighbor.X == neighbor.X then
					impossible = true
				end
			-- horizontal corridor
			elseif nNeighborRoom.Type == RoomType.ROOMSHAPE_IH or nNeighborRoom.Type == RoomType.ROOMSHAPE_IIH then
				if nNeighbor.Y == neighbor.Y then
					impossible = true
				end
			end

			if impossible then
				if nNeighborRoom:IsIconVisible() then
					MIR:AddRoom(neighbor)
				else
					MIR:Log("\nCached: {"..neighbor.X..", "..neighbor.Y.."}, {"..nNeighbor.X..", "..nNeighbor.Y.."}")
					table.insert(MIR.AddWhenOtherVisibleCache, {neighbor, nNeighbor})
				end
			end

		end
		end

		-- Check if the neighbor is outside the floor grid (13x13)
		if neighbor.X < 0 or neighbor.Y < 0 or neighbor.X > 12 or neighbor.Y > 12 then
			MIR:AddRoom(neighbor)
		end

	end
	end

	MIR:Log("\nFinished checking rooms\n")
end

-- Called when entering a room AND when clearing a room (because otherwise it sometimes doesn't work)
function MIR:AddFromCache()
	for _,pair in ipairs(MIR.AddWhenOtherVisibleCache) do
		MIR:Log("\nChecking cached: {"..pair[1].X..", "..pair[1].Y.."}, {"..pair[2].X..", "..pair[2].Y.."}")
		if MinimapAPI:GetRoomAtPosition(pair[2]):IsIconVisible() then
			MIR:AddRoom(pair[1])
		end
	end
end

-- MinimapAPI already has GetAdjacentRooms(), but this returns coordinate vectors instead of room objects
function MIR:GetNeighbors(pos, shape)
	local neighbors = {}
	for _,v in ipairs(MIR.DoorTable[shape]) do
		if v then
			table.insert(neighbors, Vector(pos.X + v[1], pos.Y + v[2]))
		end
	end
	return neighbors
end

function MIR:AddRoom(pos)
	local stage = Game():GetLevel():GetStage()
	local room = Game():GetRoom()

	if not MinimapAPI:IsPositionFree(pos)
	or (stage == LevelStage.STAGE2_2 and room:IsMirrorWorld()) -- knife piece 2
	or stage == LevelStage.STAGE8 then -- home
		return
	end

	MinimapAPI:AddRoom({
		ID = pos.X.."-"..pos.Y,
		Position = pos,
		Shape = "ImpossibleRoom",
		Type = 1,
		DisplayFlags = 5,
		Descriptor = {
			Data = {
				Doors = 0
			},
			DisplayFlags = 5,
		}
	})
	MIR:Log("\nAdded {"..pos.X..", "..pos.Y.."}")
end

if MinimapAPI then
	MIR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, MIR.MarkImpossibleRooms)
	MIR:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, MIR.AddFromCache)
end