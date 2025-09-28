local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Animals = ServerStorage.Animals

local function onPlayerAdded(player: Player)
    local character = Animals.Lion.Default:Clone()
    character.Name = player.Name
    character.Parent = workspace
    character:PivotTo(workspace.SpawnLocation:GetPivot() + Vector3.new(0,5,0))
    
    player.Character = character
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end