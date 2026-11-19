--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

export type Contract = {
    Id: string,
    TitleKey: string,
    Title: string,
    TargetAmount: number,
    RewardCash: number,
}

local ContractService = {}

local DailyPool: { Contract } = {
    {
        Id = "LootValue1500",
        TitleKey = "Contract_LootValue_Title",
        Title = Locale.Get("Contract_LootValue_Title"),
        TargetAmount = 1500,
        RewardCash = 500,
    },
    {
        Id = "UnlockVault",
        TitleKey = "Contract_UnlockVault_Title",
        Title = Locale.Get("Contract_UnlockVault_Title"),
        TargetAmount = 1,
        RewardCash = 400,
    },
    {
        Id = "EscapeStreak2",
        TitleKey = "Contract_EscapeStreak_Title",
        Title = Locale.Get("Contract_EscapeStreak_Title"),
        TargetAmount = 2,
        RewardCash = 600,
    },
    {
        Id = "ExtractFragile",
        TitleKey = "Contract_ExtractFragile_Title",
        Title = Locale.Get("Contract_ExtractFragile_Title"),
        TargetAmount = 1,
        RewardCash = 450,
    },
}

function ContractService.GetDayNumber(): number
    return math.floor(os.time() / 86400)
end

function ContractService.GetDailyContracts(): { Contract }
    local day = ContractService.GetDayNumber()
    local rng = Random.new(day)
    local selected = {}
    local poolCopy = {}

    for _, c in ipairs(DailyPool) do
        table.insert(poolCopy, c)
    end

    for _ = 1, math.min(3, #poolCopy) do
        local idx = rng:NextInteger(1, #poolCopy)
        table.insert(selected, poolCopy[idx])
        table.remove(poolCopy, idx)
    end

    return selected
end

return ContractService
