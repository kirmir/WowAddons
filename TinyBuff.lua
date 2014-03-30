TinyBuff_Config = TinyBuff_Config or { PlayerBuffsCount = 10, TargetBuffsCount = 12, TargetDebuffsCount = 12, PlayerBuffs = {}, TargetBuffs = {}, TargetDebuffs = {} }
local ICON_SIZE = 30

local Addon = CreateFrame("Frame")
local PlayerGuid
local PlayerBuffs = {}
local TargetBuffs = {}
local TargetDebuffs = {}

local function Find(array, filterFunc)
	for _, v in pairs(array) do
  		if filterFunc(v) then
  			return v
  		end
	end
end

local function Contains(array, value)
	return Find(array, function(x) return x == value end)
end

local function FindByParams(array, spell, guid)
	return Find(array, function(x)
		return x.Spell == spell and x.Guid == guid
	end)
end

local function NewIcon(point, size)
	local icon = CreateFrame("Frame")
	icon:Hide()

	icon:SetSize(size, size)
	icon:SetPoint(unpack(point))
	
	-- icon.Overlay = icon:CreateTexture("Overlay", "BACKGROUND")
	-- icon.Overlay:SetTexture(0, 0, 0)
	-- icon.Overlay:SetPoint("TOPLEFT", -1, 1)
	-- icon.Overlay:SetPoint("BOTTOMRIGHT", 1, -1)
	-- icon.Overlay:SetAlpha(1)

	icon.Image = icon:CreateTexture("Image", "OVERLAY")
	icon.Image:SetAllPoints()
	icon.Image:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon.Image:SetAlpha(0.7)

	icon.Cooldown = CreateFrame("Cooldown", "Cooldown", icon, "CooldownFrameTemplate")
	icon.Cooldown:SetAllPoints(icon.Image)
	icon.Cooldown:SetReverse()

	function icon:Enable(spell, guid, icon, duration, expiration)
		self.Image:SetTexture(icon)
		self.Spell = spell
		self.Guid = guid
		
		if duration then
			self.Expiration = expiration
			self.Cooldown:Show()
			CooldownFrame_SetTimer(self.Cooldown, expiration - duration, duration, 1)
		else
			self.Cooldown:Hide()
		end

		self:SetScript("OnUpdate", function(self)
				if self.Expiration and GetTime() > self.Expiration then
					self:Disable()
				end
			end)

		self:Show()
	end

	function icon:Disable()
		self.Spell = nil
		self.Guid = nil
		self.Expiration = nil
		self:SetScript("OnUpdate", nil)
		self:Hide()
	end

	return icon
end

local function CreateIcons()
	if #TinyBuff_Config.PlayerBuffs > 0 then
		for i = 1, TinyBuff_Config.PlayerBuffsCount do
			local x = -9 - ((i - 1) % 2) * (ICON_SIZE + 4)
			local y = math.floor((i - 1) / 2) * (ICON_SIZE + 4)
			PlayerBuffs[i] = NewIcon({ "BOTTOMRIGHT", "PlayerFrame", "TOPRIGHT", x, y }, ICON_SIZE)
		end
	end
	if #TinyBuff_Config.TargetDebuffs > 0 then
		for i = 1, TinyBuff_Config.TargetDebuffsCount do
			local x = ((i % 2 == 1) and 1 or -1) * (17 - math.ceil((math.floor((i - 1) % 6) + 1) / 2) * (ICON_SIZE + 4))
			local y = -202 + math.floor((i - 1) / 6) * (ICON_SIZE + 4)
			TargetDebuffs[i] = NewIcon({ "CENTER", "UIParent", "CENTER", x, y }, ICON_SIZE)
		end
	end
end

local function GetUnitType(guid)
	if guid == UnitGUID("target") then
		return "target"
	end
	if guid == UnitGUID("focus") then
		return "focus"
	end
end

local function ShowSpell(event, spell, guid, icons, config, auraFunc)
	if not Contains(config, spell) then
		return
	end
	print(spell.." | "..event.." | "..(unit and unit or "nil").." | "..guid)
	if string.match(event, "REMOVED$") then
		local icon = FindByParams(icons, spell, guid)
		if icon then
			icon:Disable()
		end
	else
		local unit = GetUnitType(guid)
		if unit then
			local icon = FindByParams(icons, spell, guid) or FindByParams(icons, nil, nil)
			local _, _, img, _, _, duration, expiration = auraFunc(unit, spell)
			icon:Enable(spell, guid, img, duration, expiration)
		end
	end
end

local function Reset(icons)
	for _, v in pairs(icons) do
	  	v:Disable()
	end
end

local function OnEvent(self, event, addon, combatEvent, _, _, _, _, _, destGuid, _, destFlags, _, _, spell, _, spellType)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		if not string.find(combatEvent, "AURA") then
			return
		end
		
		if destGuid == PlayerGuid and spellType == "BUFF" then
			ShowSpell(combatEvent, spell, destGuid, PlayerBuffs, TinyBuff_Config.PlayerBuffs, UnitBuff)
		elseif bit.band(destFlags, 0x60) ~= 0 then
			if spellType == "BUFF" then
				--
			else
				ShowSpell(combatEvent, spell, destGuid, TargetDebuffs, TinyBuff_Config.TargetDebuffs, UnitDebuff)
			end
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		
	elseif event == "PLAYER_DEAD" then
		Reset(PlayerBuffs)
	elseif event == "PLAYER_ENTERING_WORLD" then
		Reset(PlayerBuffs)
		Reset(TargetBuffs)
		Reset(TargetDebuffs)
	else
		PlayerGuid = UnitGUID("player")
		if PlayerGuid then
			Addon:UnregisterEvent("ADDON_LOADED")
		end
		CreateIcons()
	end
end

Addon:SetScript("OnEvent", OnEvent)
Addon:RegisterEvent("ADDON_LOADED")
Addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
Addon:RegisterEvent("PLAYER_DEAD")
Addon:RegisterEvent("PLAYER_TARGET_CHANGED")
Addon:RegisterEvent("PLAYER_ENTERING_WORLD")