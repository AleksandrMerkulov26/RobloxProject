--!strict
local LocalizationService = game:GetService("LocalizationService")

local Locale = {}

export type Language = "en" | "ru"

local currentLanguage: Language = "en"

-- Automatically detect language on client or fallback to English
pcall(function()
    local localeId = LocalizationService.RobloxLocaleId:lower()
    if localeId:sub(1, 2) == "ru" then
        currentLanguage = "ru"
    else
        currentLanguage = "en"
    end
end)

function Locale.SetLanguage(lang: Language)
    if lang == "ru" or lang == "en" then
        currentLanguage = lang
    end
end

function Locale.GetLanguage(): Language
    return currentLanguage
end

local Translations: { [string]: { en: string, ru: string } } = {
    -- General / HUD
    ["LootLabel"] = { en = "Loot: $%d", ru = "Добыча: $%d" },
    ["BalanceLabel"] = { en = "Balance: $%d", ru = "Баланс: $%d" },
    ["WeightLabel"] = { en = "Weight: %.1f / %.1f kg [B]", ru = "Вес: %.1f / %.1f кг [B]" },
    ["ExtractionInactive"] = { en = "Extraction: inactive", ru = "Эвакуация: не активна" },
    ["ExtractionSuccess"] = { en = "Extraction: success!", ru = "Эвакуация: успешно!" },
    ["ExtractionAborted"] = { en = "Extraction: aborted", ru = "Эвакуация: прервана" },
    ["ExtractionProgress"] = { en = "Extraction: %.1f s", ru = "Эвакуация: %.1f сек" },
    ["ControlsHint"] = { en = "[E] Interact | [Q] Grapple | [F] Light | [G] Smoke", ru = "[E] Взять | [Q] Крюк | [F] Свет | [G] Дым" },

    -- Backpack modal
    ["BackpackTitle"] = { en = "RAIDER BACKPACK [B to close]", ru = "РЮКЗАК НАЛЁТЧИКА [B чтобы закрыть]" },
    ["DropButton"] = { en = "Drop", ru = "Сбросить" },
    ["FragileTag"] = { en = "[FRAGILE]", ru = "[ХРУПКОЕ]" },

    -- Loadouts modal
    ["LoadoutsTitle"] = { en = "LOADOUTS", ru = "КОМПЛЕКТЫ" },
    ["LoadoutsButton"] = { en = "Loadouts [L]", ru = "Комплекты [L]" },
    ["Equipped"] = { en = "EQUIPPED", ru = "ЭКИПИРОВАН" },
    ["Select"] = { en = "SELECT", ru = "ВЫБРАТЬ" },
    ["BuyCost"] = { en = "BUY $%d", ru = "КУПИТЬ $%d" },
    ["GetFree"] = { en = "GET FREE", ru = "ПОЛУЧИТЬ БЕСПЛАТНО" },

    -- Black Market modal
    ["MarketTitle"] = { en = "BLACK MARKET: UPGRADES", ru = "ЧЁРНЫЙ РЫНОК: АПГРЕЙДЫ" },
    ["UpgradeLevelInfo"] = { en = "%s (Lvl %d/%d)\nBonus: +%d per lvl", ru = "%s (Ур. %d/%d)\nБонус: +%d за уровень" },
    ["BuyUpgradeCost"] = { en = "Buy ($%d)", ru = "Купить ($%d)" },
    ["MaxLevel"] = { en = "MAX LEVEL", ru = "МАКС. УРОВЕНЬ" },

    -- Command Room modal
    ["CommandTitle"] = { en = "RAID COMMAND CENTER", ru = "ЦЕНТР УПРАВЛЕНИЯ РЕЙДОМ" },
    ["CommandStatusDefault"] = { en = "Player Status", ru = "Состояние игроков" },
    ["CommandRefresh"] = { en = "Refresh", ru = "Обновить" },
    ["CommandSpectate"] = { en = "SPECTATE", ru = "НАБЛЮДАТЬ" },
    ["SpectatingTarget"] = { en = "Spectating: %s", ru = "Наблюдение: %s" },
    ["SpectateUnavailable"] = { en = "Player is no longer available to spectate", ru = "Игрок больше недоступен для наблюдения" },
    ["CommandFailed"] = { en = "Failed to fetch raid status", ru = "Не удалось получить состояние рейда" },
    ["CommandActiveCount"] = { en = "Raiders active: %d · Refresh manually", ru = "Игроков в рейде: %d · Обновляй список вручную" },
    ["StatusWaiting"] = { en = "Waiting for raid start", ru = "Ожидает начала рейда" },
    ["StatusInRaid"] = { en = "In Raid", ru = "В рейде" },
    ["StatusEscaped"] = { en = "Extracted", ru = "Эвакуировался" },
    ["StatusEliminated"] = { en = "Eliminated", ru = "Выбыл" },

    -- Timer & Phase
    ["StartRaidButton"] = { en = "START RAID", ru = "НАЧАТЬ РЕЙД" },
    ["StartRaidRequest"] = { en = "REQUESTING...", ru = "ЗАПРОС..." },
    ["LobbyPhaseWaiting"] = { en = "Hideout — waiting for start", ru = "Убежище — ожидание запуска" },
    ["LobbyPhaseTimer"] = { en = "Hideout: %d s", ru = "Убежище: %d сек" },
    ["LootPhaseTimer"] = { en = "Loot Phase: %d s", ru = "Сбор лута: %d сек" },
    ["ExtractionPhaseTimer"] = { en = "EXTRACTION: %d s!", ru = "ЭВАКУАЦИЯ: %d сек!" },

    -- Raid Summary modal
    ["SummarySuccessTitle"] = { en = "EXTRACTION SUCCESSFUL", ru = "ЭВАКУАЦИЯ УСПЕШНА" },
    ["SummaryFailedTitle"] = { en = "RAID FAILED", ru = "РЕЙД НЕ ЗАВЕРШЁН" },
    ["SummarySuccessDetails"] = {
        en = "Items Extracted: %d\nLoot Value: $%d\nPermanent Balance: $%d",
        ru = "Вынесено предметов: %d\nСтоимость добычи: $%d\nПостоянный баланс: $%d"
    },
    ["SummaryFailedDetails"] = {
        en = "Extraction failed.\nLoot lost.\nPermanent Balance: $%d",
        ru = "Эвакуация не состоялась.\nДобыча потеряна.\nПостоянный баланс: $%d"
    },
    ["SummaryContinue"] = { en = "Continue", ru = "Продолжить" },
    ["ViewReplayButton"] = { en = "[▶] View Raid Replay", ru = "[▶] Посмотреть повтор" },
    ["ReplayTitle"] = { en = "TACTICAL RAID REPLAY", ru = "ТАКТИЧЕСКИЙ ПОВТОР РЕЙДА" },
    ["ReplayLegend"] = { en = "Green: You | Red: Guard", ru = "Зеленый: Вы | Красный: Охрана" },

    -- Daily Contracts
    ["Contract_LootValue_Title"] = { en = "Extract with $1,500+ in loot", ru = "Эвакуируйтесь с добычей на сумму $1,500+" },
    ["Contract_UnlockVault_Title"] = { en = "Crack or unlock 1 vault door", ru = "Вскройте или отоприте 1 хранилище" },
    ["Contract_EscapeStreak_Title"] = { en = "Achieve a 2-raid escape streak", ru = "Достигните серии из 2 успешных рейдов" },
    ["Contract_ExtractFragile_Title"] = { en = "Extract with a fragile item intact", ru = "Вынесите хрупкий предмет целым" },
    ["ContractsModalTitle"] = { en = "DAILY UNDERGROUND CONTRACTS", ru = "ЕЖЕДНЕВНЫЕ КОНТРАКТЫ НАЛЁТЧИКА" },
    ["ContractsButton"] = { en = "Contracts [C]", ru = "Контракты [C]" },
    ["ContractReward"] = { en = "Reward: +$%d", ru = "Награда: +$%d" },
    ["ContractCompleted"] = { en = "COMPLETED", ru = "ВЫПОЛНЕНО" },
    ["ContractCompletedNotice"] = { en = "Contract Complete: %s! +$%d cash", ru = "Контракт выполнен: %s! +$%d на баланс" },
    ["ContractProgress"] = { en = "Progress: %d / %d", ru = "Прогресс: %d / %d" },
    ["TabContracts"] = { en = "CONTRACTS", ru = "КОНТРАКТЫ" },
    ["TabLeaderboard"] = { en = "LEADERBOARD", ru = "РЕЙТИНГ" },
    ["TabSpectate"] = { en = "SQUAD RADAR", ru = "ОТРЯД" },
    ["LeaderboardTitle"] = { en = "WEEKLY TOP RAIDERS (CASH)", ru = "ТОП НАЛЁТЧИКОВ НЕДЕЛИ (БАЛАНС)" },
    ["LeaderboardEmpty"] = { en = "No records yet. Be the first!", ru = "Пока нет записей. Станьте первым!" },

    -- Loadouts data
    ["Loadout_Default_Name"] = { en = "Rookie", ru = "Новобранец" },
    ["Loadout_Default_Desc"] = { en = "Balanced standard raider kit.", ru = "Базовый сбалансированный комплект налётчика." },
    ["Loadout_Scout_Name"] = { en = "Scout", ru = "Разведчик" },
    ["Loadout_Scout_Desc"] = { en = "High mobility & long-range grapple, but smaller backpack.", ru = "Высокая скорость и дальнобойная кошка, но малый рюкзак." },
    ["Loadout_Mule_Name"] = { en = "Heavy Mule", ru = "Тяжеловес" },
    ["Loadout_Mule_Desc"] = { en = "Huge backpack for heavy valuables and platinum bars.", ru = "Огромный рюкзак под ценности и драгоценные слитки." },
    ["Loadout_Support_Name"] = { en = "Support Specialist", ru = "Специалист поддержки" },
    ["Loadout_Support_Desc"] = { en = "High-grade tactical smoke, faster revives and squad aid.", ru = "Улучшенный дым, быстрый подъем напарников и помощь отряду." },

    -- Co-op & Revive
    ["RevivePrompt"] = { en = "Revive Teammate", ru = "Помочь напарнику" },
    ["RevivedNotice"] = { en = "Teammate revived you!", ru = "Напарник поднял вас на ноги!" },
    ["RevivedTeammateNotice"] = { en = "You revived %s!", ru = "Вы помогли подняться: %s!" },
    ["DownedNotice"] = { en = "DOWNED! Awaiting teammate assistance...", ru = "НОКАУТ! Ожидайте помощи от напарников..." },
    ["AlertLevelText"] = { en = "FACILITY ALERT: %d%%", ru = "ТРЕВОГА ОБЪЕКТА: %d%%" },
    ["TeamBonusNotice"] = { en = "Co-op bonus: +%d%% payout for surviving squad!", ru = "Командный бонус: +%d%% к выручке за выживший отряд!" },

    -- Upgrades data
    ["Upgrade_Pockets_Name"] = { en = "Cargo Straps", ru = "Грузовые ремни" },
    ["Upgrade_SmokeStarter_Name"] = { en = "Tactical Belt", ru = "Пояс под снаряжение" },
    ["Upgrade_Battery_Name"] = { en = "LED Battery Cell", ru = "LED-аккумулятор" },

    -- Loot Items data
    ["Loot_Watch"] = { en = "Gold Watch", ru = "Золотые часы" },
    ["Loot_Chip"] = { en = "Elite Microchip", ru = "Элитная микросхема" },
    ["Loot_Vase"] = { en = "Fragile Antique Vase", ru = "Хрупкая античная ваза" },
    ["Loot_Platinum"] = { en = "Platinum Ingot", ru = "Слиток платины" },
    ["Loot_Safe"] = { en = "Bond Mini-Safe", ru = "Мини-сейф с облигациями" },
    ["Loot_Crown"] = { en = "Golden Crown", ru = "Золотая корона" },
    ["Loot_DiamondNecklace"] = { en = "Diamond Necklace", ru = "Бриллиантовое ожерелье" },
    ["Loot_EncryptedDrive"] = { en = "Encrypted Drive", ru = "Зашифрованный накопитель" },
    ["Loot_GoldBar"] = { en = "Heavy Gold Bar", ru = "Тяжелый слиток золота" },
    ["Loot_PrototypeLaser"] = { en = "Prototype Laser Unit", ru = "Прототип лазера" },
    ["Loot_RolexCase"] = { en = "Luxury Watch Case", ru = "Кейс элитных часов" },

    -- Night Events data
    ["Event_Blackout_Name"] = { en = "BLACKOUT", ru = "ЧЁРНАЯ НОЧЬ" },
    ["Event_Blackout_Desc"] = { en = "Power grid down. Guard has impaired vision. Loot value +25%.", ru = "Свет отключён. Охранник видит хуже, но и вам сложнее ориентироваться. Добыча дороже на 25%." },
    ["Event_RedAlert_Name"] = { en = "RED ALERT", ru = "КРАСНАЯ ТРЕВОГА" },
    ["Event_RedAlert_Desc"] = { en = "Guards are faster and more alert. Loot value +50%.", ru = "Охрана быстрее и зорче. Зато вся добыча стоит на 50% больше." },
    ["Event_Jackpot_Name"] = { en = "JACKPOT", ru = "ДЖЕКПОТ" },
    ["Event_Jackpot_Desc"] = { en = "Golden Crown hidden inside the locked vault. Crack it open and escape!", ru = "В запертом хранилище спрятана Золотая корона. Вскройте дверь и успейте её вынести!" },
    ["Event_Calm_Name"] = { en = "QUIET NIGHT", ru = "ТИХАЯ НОЧЬ" },
    ["Event_Calm_Desc"] = { en = "Standard conditions. Ideal for a stealthy run.", ru = "Всё спокойно. Обычный рейд — идеальная возможность освоиться." },
    ["Event_PowerSurge_Name"] = { en = "POWER SURGE", ru = "СКАЧОК НАПРЯЖЕНИЯ" },
    ["Event_PowerSurge_Desc"] = { en = "Grid overload. Lasers disabled, but guards move 30% faster! Loot +30%.", ru = "Сбои в сети. Лазеры обесточены, но охрана на 30% быстрее! Лут +30%." },
    ["Event_ThickFog_Name"] = { en = "DENSE FOG", ru = "ГУСТОЙ ТУМАН" },
    ["Event_ThickFog_Desc"] = { en = "Heavy fog blinds guards (-50% view distance), but noise travels farther.", ru = "Плотный туман ослепляет охрану (-50% обзора), но шум слышен дальше." },

    -- Maps
    ["Map_Warehouse_Name"] = { en = "Industrial Warehouse", ru = "Промышленный склад" },
    ["Map_Archive_Name"] = { en = "Bank Archive", ru = "Банковский архив" },
    ["Map_Docks_Name"] = { en = "Cargo Docks", ru = "Грузовой терминал" },
    ["MapAnnounce"] = { en = "RAID LOCATION: %s", ru = "ЛОКАЦИЯ РЕЙДА: %s" },

    -- Keycard Objective
    ["KeycardPrompt"] = { en = "Pick up Keycard", ru = "Взять ключ-карту" },
    ["KeycardItemName"] = { en = "Security Keycard", ru = "Ключ-карта охраны" },
    ["KeycardRequiredNotice"] = { en = "Access Denied: Security Keycard required!", ru = "Доступ запрещен: требуется ключ-карта охраны!" },
    ["VaultUnlockedWithKeycard"] = { en = "Vault unlocked with Keycard!", ru = "Хранилище отперто ключ-картой!" },
    ["KeycardPickedUpNotice"] = { en = "Keycard picked up! Unlock the vault.", ru = "Подобрана ключ-карта! Откройте хранилище." },

    -- Notifications
    ["AlarmLaser"] = { en = "ALARM: Laser crossed!", ru = "ТРЕВОГА: Пересечен лазер!" },
    ["AlarmSafe"] = { en = "Safe alarm triggered!", ru = "Сработала сирена сейфа!" },
    ["TaserPickedUp"] = { en = "Taser picked up [LMB to shoot]", ru = "Подобран шокер [ЛКМ чтобы выстрелить]" },
    ["TaserStunSuccess"] = { en = "Guard stunned with taser for 5s!", ru = "Охранник оглушен электрошоком на 5 секунд!" },
    ["BackpackFull"] = { en = "Backpack full!", ru = "Рюкзак переполнен!" },
    ["ItemDropped"] = { en = "Dropped: %s", ru = "Выброшено: %s" },
    ["ItemBrokenFall"] = { en = "ITEM BROKE FROM FALL: %s!", ru = "ВАШ ПРЕДМЕТ РАЗБИЛСЯ: %s!" },
    ["RaidEliminatedLootLost"] = { en = "Eliminated from raid! Lost loot worth $%d.", ru = "Вы выбыли из рейда! Потеряна добыча на сумму $%d." },
    ["RaidEliminated"] = { en = "You were eliminated from the raid.", ru = "Вы выбыли из рейда." },
    ["StreakBonusNotification"] = { en = "Raid streak: %d. +%d%% payout bonus!", ru = "Серия рейдов: %d. Бонус +%d%% к выручке!" },
    ["RoundResetNotice"] = { en = "New raid! Visit the Dealer in your hideout.", ru = "Новый рейд! Загляните к Скупщику в убежище." },
    ["EquippedLoadoutNotice"] = { en = "Equipped loadout: %s!", ru = "Экипирован комплект: %s!" },
    ["PurchasedUpgradeNotice"] = { en = "Purchased: %s (Lvl %d)!", ru = "Куплено: %s (Ур. %d)!" },

    -- Hideout Station Signs
    ["StationArmory"] = { en = "ARMORY", ru = "АРСЕНАЛ" },
    ["StationWorkshop"] = { en = "WORKSHOP", ru = "МАСТЕРСКАЯ" },
    ["StationCommand"] = { en = "COMMAND", ru = "УПРАВЛЕНИЕ" },
    ["StationLiving"] = { en = "LIVING QUARTERS", ru = "ЖИЛОЙ СЕКТОР" },
    ["StationDealer"] = { en = "Dealer", ru = "Скупщик" },
    ["OpenMarketPrompt"] = { en = "Open Market", ru = "Открыть рынок" },
    ["TakePrompt"] = { en = "Take", ru = "Взять" },
    ["TaserPickupName"] = { en = "Security Taser", ru = "Тайзер охраны" },
    ["HackVaultPrompt"] = { en = "Crack Vault", ru = "Взломать" },
    ["VaultDoorName"] = { en = "Safe Door", ru = "Сейфовая дверь" },
}

function Locale.Get(key: string, lang: Language?): string
    local activeLang = lang or currentLanguage
    local entry = Translations[key]
    if not entry then
        return key
    end
    return entry[activeLang] or entry["en"] or key
end

function Locale.Format(key: string, ...): string
    local template = Locale.Get(key)
    local args = { ... }
    local success, result = pcall(function()
        return string.format(template, table.unpack(args))
    end)
    return success and result or template
end

return Locale
