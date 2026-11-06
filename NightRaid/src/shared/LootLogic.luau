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

function LootLogic.GetDeathDropItems(items)
    local droppedItems = {}
    for _, item in ipairs(items) do
        table.insert(droppedItems, item)
    end
    return droppedItems
end

function LootLogic.IsNoiseAudible(guardPos: Vector3, noisePos: Vector3, noiseRadius: number): boolean
    return (guardPos - noisePos).Magnitude <= noiseRadius
end

-- Alert mode improves awareness and movement for a short time after a sighting or loud noise.
function LootLogic.GetGuardAwareness(isAlerted: boolean)
    if isAlerted then
        return {
            ViewDistance = 70,
            FovDotThreshold = 0.2,
            PatrolSpeed = 16,
            SearchSpeed = 18,
            InvestigateSpeed = 18
        }
    end

    return {
        ViewDistance = 55,
        FovDotThreshold = 0.35,
        PatrolSpeed = 13.5,
        SearchSpeed = 16,
        InvestigateSpeed = 16
    }
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
        BonusPerLevel = 5,
        Description = "Рюкзак: +%d кг за уровень"
    },
    SmokeStarter = {
        Name = "Пояс под снаряжение",
        BaseCost = 750,
        CostMultiplier = 2.0,
        MaxLevel = 2,
        BonusPerLevel = 2,
        Description = "Дымовая шашка: перезарядка -%d с за уровень"
    },
    Battery = {
        Name = "LED-аккумулятор",
        BaseCost = 300,
        CostMultiplier = 1.5,
        MaxLevel = 3,
        BonusPerLevel = 15,
        Description = "Фонарь: дальность +%d за уровень"
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

-- Базовая перезарядка дыма (сек). Апгрейд SmokeStarter сокращает её на BonusPerLevel за уровень.
LootLogic.SmokeBaseCooldown = 10

function LootLogic.GetSmokeCooldown(starterLevel: number): number
    local cfg = LootLogic.UpgradesConfig.SmokeStarter
    local level = math.clamp(math.floor(starterLevel or 0), 0, cfg.MaxLevel)
    return LootLogic.SmokeBaseCooldown - level * cfg.BonusPerLevel
end

-- ========================================================
-- 4. СЕРИЯ УСПЕШНЫХ РЕЙДОВ
-- ========================================================

-- За каждый подряд успешный рейд выручка растёт на 10%, максимум +50%.
-- Считаем в целых процентах, чтобы не получать ошибки округления дробных чисел.
LootLogic.StreakBonusPercentPerRaid = 10
LootLogic.MaxStreakBonusPercent = 50

function LootLogic.GetStreakBonusPercent(streak: number): number
    local count = math.max(0, math.floor(streak or 0))
    return math.min(count * LootLogic.StreakBonusPercentPerRaid, LootLogic.MaxStreakBonusPercent)
end

function LootLogic.ApplyStreakBonus(baseValue: number, streak: number): number
    local percent = LootLogic.GetStreakBonusPercent(streak)
    return math.floor(baseValue * (100 + percent) / 100)
end


return LootLogic