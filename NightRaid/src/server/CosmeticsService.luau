--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticsConfig"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local CosmeticsService = {}

local function applyMaskToCharacter(character: Model, maskId: string?)
    local existingMask = character:FindFirstChild("EquippedMaskVisual")
    if existingMask then existingMask:Destroy() end

    if not maskId then return end
    local item = CosmeticsConfig.GetItem(maskId)
    if not item or item.Category ~= "Mask" then return end

    local head = character:FindFirstChild("Head") :: BasePart?
    if not head then return end

    local maskModel = Instance.new("Model")
    maskModel.Name = "EquippedMaskVisual"

    local basePart = Instance.new("Part")
    basePart.Name = "MaskBase"
    basePart.Size = Vector3.new(1.3, 1.3, 1.1)
    basePart.CFrame = head.CFrame * CFrame.new(0, 0, -0.2)
    basePart.Color = item.Color or Color3.fromRGB(30, 30, 30)
    basePart.Material = Enum.Material.SmoothPlastic
    basePart.CanCollide = false
    basePart.CastShadow = false
    basePart.Parent = maskModel

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = head
    weld.Part1 = basePart
    weld.Parent = basePart

    -- Если у маски есть неоновые акценты (глаза, клыки, ПНВ)
    if item.NeonColor then
        local neonAccent = Instance.new("Part")
        neonAccent.Name = "NeonGlow"
        neonAccent.Size = Vector3.new(1.0, 0.3, 0.4)
        neonAccent.CFrame = basePart.CFrame * CFrame.new(0, 0.1, -0.5)
        neonAccent.Color = item.NeonColor
        neonAccent.Material = Enum.Material.Neon
        neonAccent.CanCollide = false
        neonAccent.CastShadow = false
        neonAccent.Parent = maskModel

        local accentWeld = Instance.new("WeldConstraint")
        accentWeld.Part0 = basePart
        accentWeld.Part1 = neonAccent
        accentWeld.Parent = neonAccent
    end

    maskModel.Parent = character
end

function CosmeticsService.ApplyCosmetics(player: Player)
    local char = player.Character
    if not char then return end

    local cos = DataService.GetCosmetics(player)
    applyMaskToCharacter(char, cos.EquippedMask)
end

function CosmeticsService.Init()
    Remotes.BuyCosmetic.OnServerEvent:Connect(function(player: Player, itemId: any)
        if Remotes.CurrentPhase.Value ~= "LobbyPhase" then return end
        if type(itemId) ~= "string" then return end

        local item = CosmeticsConfig.GetItem(itemId)
        if not item then return end

        local cos = DataService.GetCosmetics(player)
        if cos.Owned[item.Id] then return end

        local leaderstats = player:FindFirstChild("leaderstats")
        local cash = leaderstats and leaderstats:FindFirstChild("Cash") :: IntValue?
        if not cash or cash.Value < item.Cost then return end

        cash.Value -= item.Cost
        cos.Owned[item.Id] = true

        if item.Category == "Mask" then
            cos.EquippedMask = item.Id
        elseif item.Category == "Grapple" then
            cos.EquippedGrapple = item.Id
        end

        DataService.SetCosmetics(player, cos)
        DataService.SavePlayerData(player)

        CosmeticsService.ApplyCosmetics(player)
        Remotes.CosmeticsUpdated:FireClient(player, cos)
    end)

    Remotes.EquipCosmetic.OnServerEvent:Connect(function(player: Player, itemId: any)
        if Remotes.CurrentPhase.Value ~= "LobbyPhase" then return end
        if type(itemId) ~= "string" then return end

        local cos = DataService.GetCosmetics(player)
        if not cos.Owned[itemId] then return end

        local item = CosmeticsConfig.GetItem(itemId)
        if not item then return end

        if item.Category == "Mask" then
            if cos.EquippedMask == itemId then
                cos.EquippedMask = nil -- Снять маску
            else
                cos.EquippedMask = itemId
            end
        elseif item.Category == "Grapple" then
            cos.EquippedGrapple = itemId
        end

        DataService.SetCosmetics(player, cos)
        CosmeticsService.ApplyCosmetics(player)
        Remotes.CosmeticsUpdated:FireClient(player, cos)
    end)
end

return CosmeticsService
