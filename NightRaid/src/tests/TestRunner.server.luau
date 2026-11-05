local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LootLogic = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LootLogic"))

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
    local noiseNearby = Vector3.new(20, 3, 0) -- Дистанция 20 studs
    AssertTest("Шум в радиусе слышимости (20 <= 40) -> Услышан", LootLogic.IsNoiseAudible(guardPos, noiseNearby, 40), true)

    local noiseFaraway = Vector3.new(50, 3, 0) -- Дистанция 50 studs
    AssertTest("Шум за пределами радиуса (50 > 40) -> Не услышан", LootLogic.IsNoiseAudible(guardPos, noiseFaraway, 40), false)

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

    print("\n--------------------------------------------------------")
    if failCount == 0 then
        print(string.format("РЕЗУЛЬТАТ: ВСЕ ТЕСТЫ УСПЕШНО ПРОЙДЕНЫ! (%d/%d)", passCount, totalCount))
    else
        warn(string.format("РЕЗУЛЬТАТ: ОБНАРУЖЕНЫ ОШИБКИ! Пройдено: %d, Провалено: %d из %d", passCount, failCount, totalCount))
    end
    print("========================================================\n")
end

task.spawn(RunSuite)
