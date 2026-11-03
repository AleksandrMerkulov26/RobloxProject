local LootLogic = {}

-- ========================================================
-- 1. ИНВЕНТАРЬ И СКОРОСТЬ
-- ========================================================

function LootLogic.CanAddItem(currentWeight: number, itemWeight: number, maxWeight: number): boolean
    return (currentWeight + itemWeight) <= maxWeight
end

function LootLogic.CalculateWalkSpeed(currentWeight: number, maxWeight: number, baseSpeed: number, minSpeed: number): number
    if maxWeight <= 0 then return minSpeed end
    local ratio = math.clamp(currentWeight / maxWeight, 0, 1)
    return math.clamp(baseSpeed - (ratio * (baseSpeed - minSpeed)), minSpeed, baseSpeed)
end

function LootLogic.CanAffordLoadout(playerCash: number, loadoutCost: number): (boolean, number)
    if playerCash >= loadoutCost then
        return true, playerCash - loadoutCost
    end
    return false, playerCash
end

function LootLogic.ProcessFallDamage(itemsTable, fallDistance: number, breakThreshold: number)
    local remaining = {}
    local broken = {}
    local totalWeight = 0
    local totalValue = 0

    for _, item in ipairs(itemsTable) do
        if item.Fragile and fallDistance > breakThreshold then
            table.insert(broken, item)
        else
            table.insert(remaining, item)
            totalWeight += item.Weight
            totalValue += item.Value
        end
    end

    return remaining, broken, totalWeight, totalValue
end

-- ========================================================
-- 2. СТЕЛС И ИИ ОХРАНЫ
-- ========================================================

function LootLogic.IsPlayerDetected(guardPos: Vector3, guardLookVector: Vector3, playerPos: Vector3, maxViewDist: number, fovDotThreshold: number, rearSenseDist: number): boolean
    local offset = playerPos - guardPos
    local dist = offset.Magnitude

    if dist > maxViewDist then
        return false
    end

    if dist <= rearSenseDist then
        return true
    end

    local dirToPlayer = offset.Unit
    local dot = guardLookVector:Dot(dirToPlayer)

    return dot >= fovDotThreshold
end

function LootLogic.IsNoiseAudible(guardPos: Vector3, noisePos: Vector3, noiseRadius: number): boolean
    return (guardPos - noisePos).Magnitude <= noiseRadius
end

function LootLogic.IsVisionBlockedBySmoke(smokePositions, guardPos: Vector3, playerPos: Vector3, smokeRadius: number): boolean
    local rayDir = playerPos - guardPos
    local rayLen = rayDir.Magnitude
    if rayLen == 0 then return false end
    local rayUnit = rayDir.Unit

    for _, sPos in ipairs(smokePositions) do
        if (guardPos - sPos).Magnitude <= smokeRadius or (playerPos - sPos).Magnitude <= smokeRadius then
            return true
        end

        local toSmoke = sPos - guardPos
        local projection = toSmoke:Dot(rayUnit)
        if projection > 0 and projection < rayLen then
            local closestPoint = guardPos + rayUnit * projection
            if (sPos - closestPoint).Magnitude <= smokeRadius then
                return true
            end
        end
    end
    return false
end

function LootLogic.CanTaserHit(shooterPos: Vector3, targetPos: Vector3, maxRange: number): boolean
    return (targetPos - shooterPos).Magnitude <= maxRange
end

-- ========================================================
-- 3. ЭКОНОМИКА УБЕЖИЩА И АПГРЕЙДЫ
-- ========================================================

LootLogic.UpgradesConfig = {
    Pockets = {
        Name = "Грузовые ремни",
        BaseCost = 500,
        CostMultiplier = 1.8,
        MaxLevel = 3,
        BonusPerLevel = 5
    },
    SmokeStarter = {
        Name = "Пояс под снаряжение",
        BaseCost = 750,
        CostMultiplier = 2.0,
        MaxLevel = 2,
        BonusPerLevel = 1
    },
    Battery = {
        Name = "LED-аккумулятор",
        BaseCost = 300,
        CostMultiplier = 1.5,
        MaxLevel = 3,
        BonusPerLevel = 15
    }
}

function LootLogic.GetUpgradeCost(upgradeKey: string, currentLevel: number): number?
    local cfg = LootLogic.UpgradesConfig[upgradeKey]
    if not cfg or currentLevel >= cfg.MaxLevel then return nil end
    return math.floor(cfg.BaseCost * (cfg.CostMultiplier ^ currentLevel))
end

function LootLogic.CanPurchaseUpgrade(playerCash: number, upgradeKey: string, currentLevel: number): (boolean, number, number)
    local cost = LootLogic.GetUpgradeCost(upgradeKey, currentLevel)
    if not cost then return false, playerCash, currentLevel end
    if playerCash >= cost then
        return true, playerCash - cost, currentLevel + 1
    end
    return false, playerCash, currentLevel
end

function LootLogic.GetEffectiveMaxWeight(baseMaxWeight: number, pocketsLevel: number): number
    local bonus = (pocketsLevel or 0) * LootLogic.UpgradesConfig.Pockets.BonusPerLevel
    return baseMaxWeight + bonus
end

function LootLogic.GetEffectiveFlashlightRange(baseRange: number, batteryLevel: number): number
    local bonus = (batteryLevel or 0) * LootLogic.UpgradesConfig.Battery.BonusPerLevel
    return baseRange + bonus
end

return LootLogic