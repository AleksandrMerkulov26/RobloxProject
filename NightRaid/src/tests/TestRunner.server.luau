local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LootLogic = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LootLogic"))
local NightEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NightEvents"))

local totalCount = 0
local passCount = 0
local failCount = 0

local function AssertTest(testName: string, actual: any, expected: any)
    totalCount += 1
    if actual == expected then
        passCount += 1
        print(string.format("  [PASS] %s", testName))
    else
        failCount += 1
        warn(string.format("  [FAIL] %s | Ожидалось: %s, Получено: %s", testName, tostring(expected), tostring(actual)))
    end
end

local function RunSuite()
    task.wait(0.1) -- Даем консоли инициализироваться

    print("\n========================================================")
    print("           ПОЛНЫЙ ПРОГОН АВТОТЕСТОВ СИСТЕМЫ             ")
    print("========================================================")

    -- ----------------------------------------------------
    -- БЛОК 1: ИНВЕНТАРЬ И ВЕС
    -- ----------------------------------------------------
    print("\n-- [1. Инвентарь, Вес и Лимиты] --")
    AssertTest("Предмет влезает (18 + 5 <= 25 кг)", LootLogic.CanAddItem(18, 5, 25), true)
    AssertTest("Граничный случай: точное заполнение (20 + 5 == 25)", LootLogic.CanAddItem(20, 5, 25), true)
    AssertTest("Блокировка перегруза (24 + 1.5 > 25)", LootLogic.CanAddItem(24, 1.5, 25), false)

    -- ----------------------------------------------------
    -- БЛОК 2: СКОРОСТЬ ПЕРЕДВИЖЕНИЯ
    -- ----------------------------------------------------
    print("\n-- [2. Кривая скорости ходьбы] --")
    -- Базовая: 16, Мин: 8, Макс вес: 20
    AssertTest("Пустой рюкзак (0 кг) -> скорость 16 studs/s", LootLogic.CalculateWalkSpeed(0, 20, 16, 8), 16)
    AssertTest("Половина веса (10 кг) -> скорость 12 studs/s", LootLogic.CalculateWalkSpeed(10, 20, 16, 8), 12)
    AssertTest("Полный вес (20 кг) -> минимальная скорость 8 studs/s", LootLogic.CalculateWalkSpeed(20, 20, 16, 8), 8)
    AssertTest("Сверхлимит (30 кг при максе 20) -> не падает ниже 8", LootLogic.CalculateWalkSpeed(30, 20, 16, 8), 8)

    -- ----------------------------------------------------
    -- БЛОК 3: БАЛАНС И ПОКУПКА ЭКИПИРОВКИ
    -- ----------------------------------------------------
    print("\n-- [3. Автосеты и Баланс Cash] --")
    local canBuy1, remCash1 = LootLogic.CanAffordLoadout(1000, 350)
    AssertTest("Покупка сета за $350 при балансе $1000 разрешена", canBuy1, true)
    AssertTest("Корректный остаток ($1000 - $350 = $650)", remCash1, 650)

    local canBuy2, remCash2 = LootLogic.CanAffordLoadout(300, 600)
    AssertTest("Отказ в покупке при балансе $300 и цене $600", canBuy2, false)
    AssertTest("Баланс игрока остался нетронутым ($300)", remCash2, 300)

    -- ----------------------------------------------------
    -- БЛОК 4: ХРУПКИЙ ЛУТ И ПАДЕНИЯ
    -- ----------------------------------------------------
    print("\n-- [4. Физика хрупкого лута] --")
    local testPack = {
        { Name = "Золотые часы", Weight = 1.5, Value = 150, Fragile = false },
        { Name = "Античная ваза", Weight = 4.0, Value = 550, Fragile = true },
        { Name = "Слиток", Weight = 8.0, Value = 450, Fragile = false }
    }

    -- Прыжок с безопасной высоты 10 studs (порог 14)
    local safeRem, safeBroken = LootLogic.ProcessFallDamage(testPack, 10, 14)
    AssertTest("Падение с высоты 10 studs: разбито 0 предметов", #safeBroken, 0)
    AssertTest("Падение с высоты 10 studs: сохранено 3 предмета", #safeRem, 3)

    -- Жесткое падение с высоты 18 studs
    local hardRem, hardBroken, newW, newV = LootLogic.ProcessFallDamage(testPack, 18, 14)
    AssertTest("Падение с высоты 18 studs: разбита ваза (1 предмет)", #hardBroken, 1)
    AssertTest("В рюкзаке осталось 2 предмета", #hardRem, 2)
    AssertTest("Вес пересчитан без вазы (1.5 + 8.0 = 9.5 кг)", newW, 9.5)
    AssertTest("Стоимость пересчитана без вазы (150 + 450 = 600)", newV, 600)

    -- ----------------------------------------------------
    -- БЛОК 5: ЗРЕНИЕ ИИ ОХРАННИКА
    -- ----------------------------------------------------
    print("\n-- [5. Зрение и Обнаружение Охранника] --")
    local guardPos = Vector3.new(0, 3, 0)
    local guardForward = Vector3.new(0, 0, -1) -- Смотрит строго на Север (-Z)

    -- Игрок прямо перед глазами на дистанции 25 studs (в пределах 55)
    local playerInFront = Vector3.new(0, 3, -25)
    AssertTest("Игрок прямо в луче света -> Обнаружен", LootLogic.IsPlayerDetected(guardPos, guardForward, playerInFront, 55, 0.35, 12), true)

    -- Игрок сбоку под углом 90 градусов
    local playerSide = Vector3.new(25, 3, 0)
    AssertTest("Игрок сбоку вне конуса обзора -> Не обнаружен", LootLogic.IsPlayerDetected(guardPos, guardForward, playerSide, 55, 0.35, 12), false)

    -- Игрок слишком далеко (70 studs при максимуме 55)
    local playerFar = Vector3.new(0, 3, -70)
    AssertTest("Игрок в конусе, но дальше дальности зрения -> Не обнаружен", LootLogic.IsPlayerDetected(guardPos, guardForward, playerFar, 55, 0.35, 12), false)

    -- Игрок подошел вплотную со спины (дистанция 8 studs при чутье 12)
    local playerBackClose = Vector3.new(0, 3, 8)
    AssertTest("Игрок подошел со спины вплотную (8 studs) -> Сработало чутье", LootLogic.IsPlayerDetected(guardPos, guardForward, playerBackClose, 55, 0.35, 12), true)

    -- Игрок со спины вдалеке (дистанция 20 studs)
    local playerBackFar = Vector3.new(0, 3, 20)
    AssertTest("Игрок со спины на дистанции 20 studs -> Не обнаружен", LootLogic.IsPlayerDetected(guardPos, guardForward, playerBackFar, 55, 0.35, 12), false)

    -- ----------------------------------------------------
    -- БЛОК 6: РЕАКЦИЯ НА ШУМ
    -- ----------------------------------------------------
    print("\n-- [6. Слух и Детекция шума] --")
    local deathDropSource = {
        { Name = "Золотые часы", Weight = 1.5, Value = 150 },
        { Name = "Слиток", Weight = 8.0, Value = 450 }
    }
    local deathDropItems = LootLogic.GetDeathDropItems(deathDropSource)
    AssertTest("При смерти копируются все предметы инвентаря", #deathDropItems, 2)
    AssertTest("Порядок предметов при выбросе сохраняется", deathDropItems[1].Name, "Золотые часы")
    AssertTest("Подготовка выброса не очищает исходный инвентарь", #deathDropSource, 2)

    local noiseNearby = Vector3.new(20, 3, 0) -- Дистанция 20 studs
    AssertTest("Шум в радиусе слышимости (20 <= 40) -> Услышан", LootLogic.IsNoiseAudible(guardPos, noiseNearby, 40), true)

    local noiseFaraway = Vector3.new(50, 3, 0) -- Дистанция 50 studs
    AssertTest("Шум за пределами радиуса (50 > 40) -> Не услышан", LootLogic.IsNoiseAudible(guardPos, noiseFaraway, 40), false)

    -- Повышенная готовность временно усиливает зрение и скорость охранника.
    local normalAwareness = LootLogic.GetGuardAwareness(false)
    AssertTest("Обычная дальность зрения охранника", normalAwareness.ViewDistance, 55)
    AssertTest("Обычная скорость патруля", normalAwareness.PatrolSpeed, 13.5)

    local alertedAwareness = LootLogic.GetGuardAwareness(true)
    AssertTest("Дальность зрения при тревоге", alertedAwareness.ViewDistance, 70)
    AssertTest("Более широкий обзор при тревоге", alertedAwareness.FovDotThreshold, 0.2)
    AssertTest("Увеличенная скорость патруля при тревоге", alertedAwareness.PatrolSpeed, 16)
    AssertTest("Увеличенная скорость поиска при тревоге", alertedAwareness.SearchSpeed, 18)

    -- ----------------------------------------------------
    -- БЛОК 7: ДЫМОВАЯ ЗАВЕСА И ТАЙЗЕР
    -- ----------------------------------------------------
    print("\n-- [7. Гаджеты: Дым и Шокер] --")
-- Дым брошен на дистанции 20 studs в направлении Севера (Z = -20)
    local smokeBetween = { Vector3.new(0, 3, -20) }

    -- 1. Игрок стоит внутри дыма на Z = -22 (дистанция до дыма 2 studs <= 10)
    AssertTest("Игрок внутри дымового облака -> Зрение заблокировано", 
        LootLogic.IsVisionBlockedBySmoke(smokeBetween, guardPos, Vector3.new(0, 3, -22), 10), true)

    -- 2. Игрок стоит далеко сбоку (50, 3, 50), дым на (0, 3, -20) не задевает охранника и линию взгляда
    AssertTest("Игрок на позиции (50, 3, 50) вне дыма -> Зрение не заблокировано", 
        LootLogic.IsVisionBlockedBySmoke(smokeBetween, guardPos, Vector3.new(50, 3, 50), 10), false)

    -- Дым между охранником и игроком также должен блокировать обзор.
    local smokeAcrossSightline = { Vector3.new(0, 3, -12) }
    AssertTest("Дым между охранником и игроком -> Зрение заблокировано",
        LootLogic.IsVisionBlockedBySmoke(smokeAcrossSightline, guardPos, Vector3.new(0, 3, -25), 10), true)

    AssertTest("Выстрел тайзера с 25 studs (макс 45) -> Попадание", LootLogic.CanTaserHit(Vector3.zero, Vector3.new(0, 0, 25), 45), true)
    AssertTest("Выстрел тайзера с 60 studs (макс 45) -> Промах по дальности", LootLogic.CanTaserHit(Vector3.zero, Vector3.new(0, 0, 60), 45), false)

-- ----------------------------------------------------
    -- БЛОК 8: ЭКОНОМИКА УБЕЖИЩА И АПГРЕЙДЫ
    -- ----------------------------------------------------
    print("\n-- [8. Прогресс убежища и апгрейды] --")
    local costLvl0 = LootLogic.GetUpgradeCost("Pockets", 0)
    AssertTest("Стоимость 1 уровня карманов равна базе (500)", costLvl0, 500)

    local costLvlMax = LootLogic.GetUpgradeCost("Pockets", 3)
    AssertTest("Попытка купить апгрейд выше MaxLevel возвращает nil", costLvlMax, nil)

    local canUp, leftCash, newLvl = LootLogic.CanPurchaseUpgrade(1000, "Pockets", 0)
    AssertTest("Успешная покупка 1 уровня ремней при $1000", canUp, true)
    AssertTest("Списание денег за апгрейд ($1000 - $500 = $500)", leftCash, 500)
    AssertTest("Уровень повышен до 1", newLvl, 1)

    local failUp, unchCash = LootLogic.CanPurchaseUpgrade(200, "Pockets", 0)
    AssertTest("Отказ в покупке ремней при недостатке денег ($200 < $500)", failUp, false)
    AssertTest("Деньги не списались при отказе", unchCash, 200)

    local effWeight = LootLogic.GetEffectiveMaxWeight(25, 2)
    AssertTest("Финальный вес сета 25 кг с ремнями 2 ур (+10 кг) = 35 кг", effWeight, 35)

    local effLight = LootLogic.GetEffectiveFlashlightRange(75, 1)
    AssertTest("Дальность фонаря 75 + акб 1 ур (+15 studs) = 90 studs", effLight, 90)

    -- ----------------------------------------------------
    -- БЛОК 10: СЕРИЯ УСПЕШНЫХ РЕЙДОВ
    -- ----------------------------------------------------
    print("\n-- [10. Серия рейдов и бонус к выручке] --")
    AssertTest("Серия 0 -> бонус 0%", LootLogic.GetStreakBonusPercent(0), 0)
    AssertTest("Серия 1 -> бонус 10%", LootLogic.GetStreakBonusPercent(1), 10)
    AssertTest("Серия 3 -> бонус 30%", LootLogic.GetStreakBonusPercent(3), 30)
    AssertTest("Серия 5 -> бонус 50% (максимум)", LootLogic.GetStreakBonusPercent(5), 50)
    AssertTest("Серия выше лимита не увеличивает бонус", LootLogic.GetStreakBonusPercent(9), 50)
    AssertTest("Отрицательная серия даёт нулевой бонус", LootLogic.GetStreakBonusPercent(-2), 0)
    AssertTest("Без серии выплата не меняется", LootLogic.ApplyStreakBonus(1000, 0), 1000)
    AssertTest("Серия 3: выплата 1000 -> 1300", LootLogic.ApplyStreakBonus(1000, 3), 1300)
    AssertTest("Дробная часть выплаты округляется вниз", LootLogic.ApplyStreakBonus(155, 1), 170)

    -- ----------------------------------------------------
    -- БЛОК 11: НОЧНЫЕ СОБЫТИЯ
    -- ----------------------------------------------------
    print("\n-- [11. Ночные события] --")
    AssertTest("roll 0.15 выбирает Чёрную ночь", NightEvents.Pick(0.15).Id, "Blackout")
    AssertTest("roll 0.4 выбирает Красную тревогу", NightEvents.Pick(0.4).Id, "RedAlert")
    AssertTest("roll 0.6 выбирает Джекпот", NightEvents.Pick(0.6).Id, "Jackpot")
    AssertTest("roll 0.9 выбирает Тихую ночь", NightEvents.Pick(0.9).Id, "Calm")
    AssertTest("У всех событий положительный вес", (function()
        for _, event in ipairs(NightEvents.Events) do
            if event.Weight <= 0 then return false end
        end
        return true
    end)(), true)
    local baseLoot = { Name = "Тест", Value = 100, Weight = 2, Color = Color3.new(1, 1, 1), Fragile = true }
    local scaledLoot = NightEvents.ScaleLootValue(baseLoot, 1.5)
    AssertTest("Множитель 1.5 повышает стоимость 100 до 150", scaledLoot.Value, 150)
    AssertTest("Масштабирование не меняет вес предмета", scaledLoot.Weight, 2)
    AssertTest("Исходный предмет остаётся неизменным", baseLoot.Value, 100)
    local awareness = LootLogic.GetGuardAwareness(false)
    local blackoutAwareness = NightEvents.ApplyToAwareness(awareness, NightEvents.Pick(0.15))
    AssertTest("Чёрная ночь уменьшает обзор охранника", blackoutAwareness.ViewDistance, 38.5)
    local alertAwareness = NightEvents.ApplyToAwareness(awareness, NightEvents.Pick(0.4))
    AssertTest("Красная тревога увеличивает обзор охранника", alertAwareness.ViewDistance, 66)
    AssertTest("Джекпот содержит корону", NightEvents.Pick(0.6).JackpotLoot.Name, "Золотая корона")

    print("\n--------------------------------------------------------")
    if failCount == 0 then
        print(string.format("РЕЗУЛЬТАТ: ВСЕ ТЕСТЫ УСПЕШНО ПРОЙДЕНЫ! (%d/%d)", passCount, totalCount))
    else
        warn(string.format("РЕЗУЛЬТАТ: ОБНАРУЖЕНЫ ОШИБКИ! Пройдено: %d, Провалено: %d из %d", passCount, failCount, totalCount))
    end
    print("========================================================\n")
end

task.spawn(RunSuite)
