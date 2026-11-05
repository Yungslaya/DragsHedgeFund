local _, GG = ...

-- Costs from Wowhead (Forever), 2026-11-05:
-- Apprentice Riding 100g (level 40), Journeyman Riding 1,000g (level 60).
-- Faction mounts: about 100g at 40, 1,000g epic at 60.
GG.PRESETS = {
    { key = "l40", name = "Level 40 mount", gold = 200, note = "Riding 100g + mount 100g" },
    { key = "l60", name = "Level 60 epic mount", gold = 2000, note = "Riding 1,000g + mount 1,000g" },
}
-- Paladins and Warlocks get their mount from a class quest: riding only.
GG.CLASS_MOUNT = { PALADIN = true, WARLOCK = true }
GG.CLASS_PRESET_GOLD = { l40 = 100, l60 = 1000 }

GG.TIPS = {
    "Sell gray items to a vendor.",
    "Loot every mob.",
    "Sell cloth on the AH.",
    "Repair only when gear is yellow.",
    "Quests pay gold. Do them all.",
    "Don't buy food. Loot it.",
}

-- Tips for professions you HAVE. Keyed by skill line, name as backup.
GG.PROF_TIPS = {
    [186] = { "Mining", "Sell ore and bars on the AH.", "Sell extra stone." },
    [182] = { "Herbalism", "Sell herbs on the AH." },
    [393] = { "Skinning", "Sell leather on the AH." },
    [197] = { "Tailoring", "Make bags. They sell well." },
    [165] = { "Leatherworking", "Sell armor kits." },
    [164] = { "Blacksmithing", "Sell sharpening stones." },
    [171] = { "Alchemy", "Sell healing potions." },
    [333] = { "Enchanting", "Break greens. Sell the dust." },
    [202] = { "Engineering", "Sell extra ore and stone." },
    [185] = { "Cooking", "Cook your own food." },
    [356] = { "Fishing", "Sell extra fish on the AH." },
    [129] = { "First Aid", "Make your own bandages." },
}
GG.PROF_BY_NAME = {}
for line, t in pairs(GG.PROF_TIPS) do GG.PROF_BY_NAME[t[1]] = line end
