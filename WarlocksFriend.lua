local ADDON_NAME = ... or "WarlocksFriend"

local WF = CreateFrame("Frame", "WarlocksFriendEventFrame")
WarlocksFriend = WF

local UPDATE_INTERVAL = 0.20
local SOUND_COOLDOWN = 1.00
local EXPIRE_SOUND_COOLDOWN = 1.00
local FLASH_DURATION = 0.35
local MAX_THRESHOLD = 10
local ELVUI_MOVER_NAME = "WarlocksFriendAlertMover"

local ALERT_SOUND = "Sound\\Interface\\RaidWarning.wav"
local EXPIRE_SOUND = "Sound\\Interface\\AlarmClockWarning3.wav"

local DEFAULTS = {
	locked = true,
	activeMode = "target_boss",
	position = {
		point = "CENTER",
		relativePoint = "CENTER",
		x = 0,
		y = 130,
	},
	thresholds = {
		lifeTap = 2,
		corruption = 2,
		immolate = 2,
		incinerate = 2,
	},
	style = {
		showBackground = true,
		showBorder = true,
		centerText = false,
		useElvUIStyle = false,
		useElvUIMover = false,
	},
}

local ACTIVE_MODES = {
	{ key = "never", label = "Never" },
	{ key = "target_any", label = "When targeting any hostile mob" },
	{ key = "target_boss", label = "Only when targeting a boss" },
	{ key = "focus_boss", label = "Only when a boss is on focus" },
}

local ACTIVE_MODE_LABELS = {}
for _, mode in ipairs(ACTIVE_MODES) do
	ACTIVE_MODE_LABELS[mode.key] = mode.label
end

local THRESHOLD_OPTIONS = {
	{ key = "lifeTap", command = "lifetap", label = "Life Tap buff" },
	{ key = "corruption", command = "corruption", label = "Corruption debuff" },
	{ key = "immolate", command = "immolate", label = "Immolate debuff" },
	{ key = "incinerate", command = "incinerate", label = "Incinerate debuff" },
}

local THRESHOLD_LABELS = {}
for _, option in ipairs(THRESHOLD_OPTIONS) do
	THRESHOLD_LABELS[option.key] = option.label
end

local THRESHOLD_ALIASES = {
	life = "lifeTap",
	tap = "lifeTap",
	lifetap = "lifeTap",
	life_tap = "lifeTap",
	corr = "corruption",
	corruption = "corruption",
	immo = "immolate",
	immolate = "immolate",
	incin = "incinerate",
	incinerate = "incinerate",
}

local ACTIVE_MODE_ALIASES = {
	never = "never",
	off = "never",
	disabled = "never",
	any = "target_any",
	all = "target_any",
	mob = "target_any",
	mobs = "target_any",
	simple = "target_any",
	targetany = "target_any",
	target_any = "target_any",
	targetmob = "target_any",
	target_mob = "target_any",
	target = "target_boss",
	targetboss = "target_boss",
	target_boss = "target_boss",
	boss = "target_boss",
	focus = "focus_boss",
	focusboss = "focus_boss",
	focus_boss = "focus_boss",
}

local BOOLEAN_ALIASES = {
	["1"] = true,
	["0"] = false,
	on = true,
	off = false,
	["true"] = true,
	["false"] = false,
	yes = true,
	no = false,
	show = true,
	hide = false,
	enable = true,
	disable = false,
	enabled = true,
	disabled = false,
}

local WARNING_COLORS = {
	missing = { 1.00, 0.28, 0.18 },
	expiring = { 1.00, 0.82, 0.18 },
	preview = { 0.75, 0.75, 0.75 },
}

local function Spell(id, fallbackName, fallbackIcon, color)
	local name, _, icon = GetSpellInfo(id)
	return {
		id = id,
		name = name or fallbackName,
		fallbackName = fallbackName,
		icon = icon or fallbackIcon,
		color = color or { 1, 1, 1 },
	}
end

local SPELLS = {
	shadowBolt = Spell(686, "Shadow Bolt", "Interface\\Icons\\Spell_Shadow_ShadowBolt", { 0.72, 0.45, 1.00 }),
	incinerate = Spell(29722, "Incinerate", "Interface\\Icons\\Spell_Fire_Burnout", { 1.00, 0.42, 0.12 }),
	soulFire = Spell(6353, "Soul Fire", "Interface\\Icons\\Spell_Fire_Fireball02", { 1.00, 0.82, 0.24 }),

	immolate = Spell(348, "Immolate", "Interface\\Icons\\Spell_Fire_Immolation", { 1.00, 0.36, 0.16 }),
	corruption = Spell(172, "Corruption", "Interface\\Icons\\Spell_Shadow_AbominationExplosion", { 0.74, 0.42, 1.00 }),

	metamorphosis = Spell(47241, "Metamorphosis", "Interface\\Icons\\Spell_Shadow_DemonForm"),
	decimation = Spell(63167, "Decimation", "Interface\\Icons\\Spell_Fire_Fireball02"),
	moltenCore = Spell(71165, "Molten Core", "Interface\\Icons\\Ability_Warlock_MoltenCore"),
	lifeTap = Spell(63321, "Life Tap", "Interface\\Icons\\Spell_Shadow_BurningSpirit", { 0.42, 0.86, 1.00 }),
}

local function CopyDefaults(source, target)
	for key, value in pairs(source) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			CopyDefaults(value, target[key])
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

local function Clamp(value, minValue, maxValue)
	if value < minValue then
		return minValue
	end
	if value > maxValue then
		return maxValue
	end
	return value
end

local function RoundThreshold(value)
	value = tonumber(value) or 0
	return Clamp(math.floor((value * 2) + 0.5) / 2, 0, MAX_THRESHOLD)
end

local function ParseBoolean(value)
	if not value then
		return nil
	end

	return BOOLEAN_ALIASES[string.lower(value)]
end

local function AuraMatches(name, spellId, spell)
	return (spellId and spell.id and spellId == spell.id)
		or name == spell.name
		or name == spell.fallbackName
end

function WF:Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff9482c9WarlocksFriend|r: " .. message)
end

function WF:InitializeDB()
	WarlocksFriendDB = WarlocksFriendDB or {}
	CopyDefaults(DEFAULTS, WarlocksFriendDB)
	self.db = WarlocksFriendDB

	if type(self.db.locked) ~= "boolean" then
		self.db.locked = DEFAULTS.locked
	end

	if not ACTIVE_MODE_LABELS[self.db.activeMode] then
		self.db.activeMode = DEFAULTS.activeMode
	end

	for _, option in ipairs(THRESHOLD_OPTIONS) do
		self.db.thresholds[option.key] = RoundThreshold(self.db.thresholds[option.key])
	end

	if type(self.db.style.showBackground) ~= "boolean" then
		self.db.style.showBackground = DEFAULTS.style.showBackground
	end
	if type(self.db.style.showBorder) ~= "boolean" then
		self.db.style.showBorder = DEFAULTS.style.showBorder
	end
	if type(self.db.style.centerText) ~= "boolean" then
		self.db.style.centerText = DEFAULTS.style.centerText
	end
	if type(self.db.style.useElvUIStyle) ~= "boolean" then
		self.db.style.useElvUIStyle = DEFAULTS.style.useElvUIStyle
	end
	if type(self.db.style.useElvUIMover) ~= "boolean" then
		self.db.style.useElvUIMover = DEFAULTS.style.useElvUIMover
	end
end

function WF:GetElvUI()
	if type(ElvUI) == "table" then
		return ElvUI[1]
	end

	return nil
end

function WF:IsElvUIAvailable()
	return self:GetElvUI() ~= nil
end

function WF:SetElvUIBorderVisibility(visible)
	local frame = self.alertFrame
	if not frame then
		return
	end

	if frame.iborder then
		if visible then
			frame.iborder:Show()
		else
			frame.iborder:Hide()
		end
	end

	if frame.oborder then
		if visible then
			frame.oborder:Show()
		else
			frame.oborder:Hide()
		end
	end
end

function WF:ApplyFrameStyle()
	if not self.alertFrame or not self.db then
		return
	end

	local frame = self.alertFrame
	local style = self.db.style
	local useElvUIStyle = style.useElvUIStyle and self:IsElvUIAvailable() and frame.SetTemplate

	if useElvUIStyle then
		if style.showBackground or style.showBorder then
			frame:SetTemplate("Transparent")
		else
			frame:SetTemplate("NoBackdrop")
		end

		if not style.showBackground then
			frame:SetBackdropColor(0, 0, 0, 0)
		end
		self:SetElvUIBorderVisibility(style.showBorder)
		if not style.showBorder then
			frame:SetBackdropBorderColor(0, 0, 0, 0)
		end

		return
	end

	self:SetElvUIBorderVisibility(false)

	local backdrop = {}
	if style.showBackground then
		backdrop.bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"
		backdrop.tile = true
		backdrop.tileSize = 16
	end
	if style.showBorder then
		backdrop.edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border"
		backdrop.edgeSize = 12
		backdrop.insets = { left = 3, right = 3, top = 3, bottom = 3 }
	end

	if style.showBackground or style.showBorder then
		frame:SetBackdrop(backdrop)
		frame:SetBackdropColor(0, 0, 0, style.showBackground and 0.78 or 0)
		frame:SetBackdropBorderColor(0.35, 0.35, 0.35, style.showBorder and 1 or 0)
	else
		frame:SetBackdrop(nil)
	end
end

function WF:ApplyTextStyle()
	if not self.alertFrame or not self.db then
		return
	end

	local justify = self.db.style.centerText and "CENTER" or "LEFT"
	self.alertFrame.mainText:SetJustifyH(justify)

	if self.alertFrame.warningList and self.alertFrame.warningList.warnings then
		for _, warning in ipairs(self.alertFrame.warningList.warnings) do
			warning.text:SetJustifyH(justify)
		end
	end
end

function WF:SetShowBackground(showBackground)
	self:InitializeDB()
	self.db.style.showBackground = showBackground and true or false
	self:ApplyFrameStyle()
	self:RefreshOptions()
	self:RefreshElvUIOptions()
	self:UpdateAlerts()
end

function WF:SetShowBorder(showBorder)
	self:InitializeDB()
	self.db.style.showBorder = showBorder and true or false
	self:ApplyFrameStyle()
	self:RefreshOptions()
	self:RefreshElvUIOptions()
	self:UpdateAlerts()
end

function WF:SetCenterText(centerText)
	self:InitializeDB()
	self.db.style.centerText = centerText and true or false
	self:ApplyTextStyle()
	self:RefreshOptions()
	self:RefreshElvUIOptions()
	self:UpdateAlerts()
end

function WF:SetUseElvUIStyle(useElvUIStyle)
	self:InitializeDB()
	if useElvUIStyle and not self:IsElvUIAvailable() then
		return false
	end

	self.db.style.useElvUIStyle = useElvUIStyle and true or false
	self:ApplyFrameStyle()
	self:RefreshOptions()
	self:RefreshElvUIOptions()
	self:UpdateAlerts()
	return true
end

function WF:GetDragFrame()
	if self.db
		and self.db.style.useElvUIMover
		and self.alertFrame
		and self.alertFrame.mover then
		return self.alertFrame.mover
	end

	return self.alertFrame
end

function WF:SaveElvUIMoverPosition()
	local E = self:GetElvUI()
	if E and E.SaveMoverPosition and _G[ELVUI_MOVER_NAME] then
		E:SaveMoverPosition(ELVUI_MOVER_NAME)
	end
end

function WF:RegisterElvUIMover()
	local E = self:GetElvUI()
	if not E or not E.CreateMover or not self.alertFrame then
		return false
	end

	if not self.elvUIMoverRegistered then
		E:CreateMover(self.alertFrame, ELVUI_MOVER_NAME, "WarlocksFriend Alerts", nil, nil, function()
			WF:SavePosition()
		end, "ALL,GENERAL", nil, "plugins,warlocksfriend")
		self.elvUIMoverRegistered = true
	elseif E.EnableMover and E.DisabledMovers and E.DisabledMovers[ELVUI_MOVER_NAME] then
		E:EnableMover(ELVUI_MOVER_NAME)
	end

	if _G[ELVUI_MOVER_NAME] then
		self:ApplyPosition()
	end

	return true
end

function WF:ApplyElvUIMover()
	if not self.alertFrame or not self.db then
		return
	end

	local E = self:GetElvUI()
	if self.db.style.useElvUIMover then
		if self:RegisterElvUIMover() then
			return
		end

		self.db.style.useElvUIMover = false
	end

	if E and E.DisableMover and E.CreatedMovers and E.CreatedMovers[ELVUI_MOVER_NAME] then
		E:DisableMover(ELVUI_MOVER_NAME)
	end

	self:ApplyPosition()
end

function WF:SetUseElvUIMover(useElvUIMover)
	self:InitializeDB()
	if useElvUIMover and not self:IsElvUIAvailable() then
		return false
	end

	self.db.style.useElvUIMover = useElvUIMover and true or false
	self:ApplyElvUIMover()
	self:ApplyLockState()
	self:RefreshOptions()
	self:RefreshElvUIOptions()
	self:UpdateAlerts()
	return true
end

function WF:RegisterElvUIOptions()
	local E = self:GetElvUI()
	if not E or not E.Options or not E.Options.args or not E.Options.args.plugins then
		return
	end

	E.Options.args.plugins.args.warlocksfriend = {
		order = 100,
		type = "group",
		name = "WarlocksFriend",
		args = {
			header = {
				order = 1,
				type = "header",
				name = "WarlocksFriend",
			},
			useElvUIStyle = {
				order = 2,
				type = "toggle",
				name = "Use ElvUI style",
				get = function()
					return WF.db and WF.db.style.useElvUIStyle
				end,
				set = function(_, value)
					WF:SetUseElvUIStyle(value)
				end,
			},
			useElvUIMover = {
				order = 3,
				type = "toggle",
				name = "Use ElvUI mover",
				get = function()
					return WF.db and WF.db.style.useElvUIMover
				end,
				set = function(_, value)
					WF:SetUseElvUIMover(value)
				end,
			},
			centerText = {
				order = 4,
				type = "toggle",
				name = "Center text",
				get = function()
					return WF.db and WF.db.style.centerText
				end,
				set = function(_, value)
					WF:SetCenterText(value)
				end,
			},
			showBackground = {
				order = 5,
				type = "toggle",
				name = "Show background",
				get = function()
					return WF.db and WF.db.style.showBackground
				end,
				set = function(_, value)
					WF:SetShowBackground(value)
				end,
			},
			showBorder = {
				order = 6,
				type = "toggle",
				name = "Show border",
				get = function()
					return WF.db and WF.db.style.showBorder
				end,
				set = function(_, value)
					WF:SetShowBorder(value)
				end,
			},
			openMovers = {
				order = 7,
				type = "execute",
				name = "Open ElvUI movers",
				func = function()
					local E = WF:GetElvUI()
					if E and E.ToggleMovers and WF:SetUseElvUIMover(true) then
						E:ToggleMovers(true, "ALL")
					end
				end,
			},
		},
	}
end

function WF:RegisterElvUIIntegration()
	if not self:IsElvUIAvailable() then
		return
	end

	local E = self:GetElvUI()
	if E and E.Libs and E.Libs.EP and E.Libs.EP.RegisterPlugin and not self.elvUIPluginRegistered then
		E.Libs.EP:RegisterPlugin(ADDON_NAME, function()
			WF:RegisterElvUIOptions()
		end)
		self.elvUIPluginRegistered = true
	else
		self:RegisterElvUIOptions()
	end

	self:ApplyElvUIMover()
end

function WF:RefreshElvUIOptions()
	if not self:IsElvUIAvailable() then
		return
	end

	local registry = LibStub and LibStub("AceConfigRegistry-3.0", true)
	if registry and registry.NotifyChange then
		registry:NotifyChange("ElvUI")
	end
end

function WF:FindAura(unit, spell, filter, requirePlayerCaster)
	for i = 1, 40 do
		local name, _, icon, count, _, duration, expirationTime, unitCaster, _, _, spellId = UnitAura(unit, i, filter)
		if not name then
			return nil
		end

		if AuraMatches(name, spellId, spell) and (not requirePlayerCaster or unitCaster == "player") then
			return true, icon, count, duration, expirationTime
		end
	end

	return nil
end

function WF:GetAuraRemaining(unit, spell, filter, requirePlayerCaster)
	local found, _, _, duration, expirationTime = self:FindAura(unit, spell, filter, requirePlayerCaster)
	if not found or not expirationTime or expirationTime <= 0 then
		return nil
	end

	local remaining = expirationTime - GetTime()
	if remaining <= 0 then
		return 0
	end

	return remaining, duration
end

function WF:HasMetamorphosis()
	local wanted = SPELLS.metamorphosis.name or SPELLS.metamorphosis.fallbackName
	local numTabs = GetNumTalentTabs and GetNumTalentTabs() or 3

	for tab = 1, numTabs do
		local numTalents = GetNumTalents and GetNumTalents(tab) or 0
		for talentIndex = 1, numTalents do
			local name, _, _, _, currentRank = GetTalentInfo(tab, talentIndex)
			if (name == wanted or name == SPELLS.metamorphosis.fallbackName) and currentRank and currentRank > 0 then
				return true
			end
		end
	end

	return false
end

function WF:RefreshEligibility()
	local _, class = UnitClass("player")
	self.isEligible = class == "WARLOCK" and self:HasMetamorphosis()

	if not self.isEligible then
		self:HideAlerts()
	end
end

function WF:IsBossUnit(unit)
	if not UnitExists(unit) or not UnitCanAttack("player", unit) or UnitIsDead(unit) then
		return false
	end

	return UnitClassification(unit) == "worldboss" or UnitLevel(unit) == -1
end

function WF:IsActivationAllowed()
	if not self.db then
		return false
	end

	if self.db.activeMode == "never" then
		return false
	end

	if self.db.activeMode == "target_any" then
		return self:HasHostileTarget()
	end

	if self.db.activeMode == "target_boss" then
		return self:IsBossUnit("target")
	end

	if self.db.activeMode == "focus_boss" then
		return self:IsBossUnit("focus")
	end

	return false
end

function WF:HasHostileTarget()
	return UnitExists("target")
		and UnitCanAttack("player", "target")
		and not UnitIsDead("target")
end

function WF:GetFillerRecommendation()
	if self:FindAura("player", SPELLS.decimation, "HELPFUL") then
		return "soulFire", SPELLS.soulFire
	end

	if self:FindAura("player", SPELLS.moltenCore, "HELPFUL") then
		return "incinerate", SPELLS.incinerate
	end

	return "shadowBolt", SPELLS.shadowBolt
end

function WF:CreateWarning(parent, index)
	local warning = CreateFrame("Frame", nil, parent)
	warning:SetWidth(310)
	warning:SetHeight(22)

	warning.icon = warning:CreateTexture(nil, "ARTWORK")
	warning.icon:SetWidth(18)
	warning.icon:SetHeight(18)
	warning.icon:SetPoint("LEFT", warning, "LEFT", 0, 0)

	warning.text = warning:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	warning.text:SetPoint("LEFT", warning.icon, "RIGHT", 6, 0)
	warning.text:SetPoint("RIGHT", warning, "RIGHT", 0, 0)
	warning.text:SetJustifyH("LEFT")

	parent.warnings[index] = warning
	return warning
end

function WF:SavePosition()
	if not self.alertFrame or not self.db then
		return
	end

	local frame = self:GetDragFrame()
	if not frame then
		return
	end

	local point, _, relativePoint, x, y = frame:GetPoint(1)
	self.db.position.point = point or DEFAULTS.position.point
	self.db.position.relativePoint = relativePoint or DEFAULTS.position.relativePoint
	self.db.position.x = x or DEFAULTS.position.x
	self.db.position.y = y or DEFAULTS.position.y
end

function WF:ApplyPosition()
	if not self.alertFrame or not self.db then
		return
	end

	local frame = self:GetDragFrame()
	if not frame then
		return
	end

	local position = self.db.position
	frame:ClearAllPoints()
	frame:SetPoint(
		position.point or DEFAULTS.position.point,
		UIParent,
		position.relativePoint or DEFAULTS.position.relativePoint,
		position.x or DEFAULTS.position.x,
		position.y or DEFAULTS.position.y
	)

	if frame ~= self.alertFrame then
		self.alertFrame:ClearAllPoints()
		self.alertFrame:SetPoint("CENTER", frame, "CENTER", 0, 0)
	end
end

function WF:ApplyLockState()
	if not self.alertFrame or not self.db then
		return
	end

	local unlocked = not self.db.locked
	self.alertFrame:EnableMouse(unlocked)
	self.alertFrame:SetMovable(unlocked)
end

function WF:SetLocked(locked)
	self:InitializeDB()
	self.db.locked = locked and true or false
	self:ApplyLockState()
	self:RefreshOptions()

	if self.db.locked then
		self:HideAlerts()
	else
		self:ShowMoverPreview()
	end
end

function WF:SetActiveMode(mode)
	self:InitializeDB()
	if not ACTIVE_MODE_LABELS[mode] then
		return false
	end

	self.db.activeMode = mode
	self:RefreshOptions()
	self:UpdateAlerts()
	return true
end

function WF:SetThreshold(key, value)
	self:InitializeDB()
	if self.db.thresholds[key] == nil then
		return false
	end

	self.db.thresholds[key] = RoundThreshold(value)
	self:RefreshOptions()
	self:UpdateAlerts()
	return true
end

function WF:ResetPosition()
	self:InitializeDB()
	self.db.position.point = DEFAULTS.position.point
	self.db.position.relativePoint = DEFAULTS.position.relativePoint
	self.db.position.x = DEFAULTS.position.x
	self.db.position.y = DEFAULTS.position.y
	self:ApplyPosition()
	self:SaveElvUIMoverPosition()
	self:ShowMoverPreview()
end

function WF:CreateUI()
	if self.alertFrame then
		return
	end

	local frame = CreateFrame("Frame", "WarlocksFriendAlertFrame", UIParent)
	frame:SetWidth(340)
	frame:SetHeight(94)
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:Hide()

	frame:SetScript("OnDragStart", function(self)
		if WF.db and not WF.db.locked then
			local dragFrame = WF:GetDragFrame()
			if dragFrame then
				dragFrame:StartMoving()
			end
		end
	end)
	frame:SetScript("OnDragStop", function(self)
		local dragFrame = WF:GetDragFrame()
		if dragFrame then
			dragFrame:StopMovingOrSizing()
		end
		WF:SavePosition()
		WF:SaveElvUIMoverPosition()
	end)

	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	frame:SetBackdropColor(0, 0, 0, 0.78)
	frame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

	frame.flash = frame:CreateTexture(nil, "OVERLAY")
	frame.flash:SetTexture("Interface\\Buttons\\WHITE8X8")
	frame.flash:SetVertexColor(1, 0.86, 0.25, 0.45)
	frame.flash:SetAllPoints(frame)
	frame.flash:Hide()

	frame.mainIcon = frame:CreateTexture(nil, "ARTWORK")
	frame.mainIcon:SetWidth(42)
	frame.mainIcon:SetHeight(42)
	frame.mainIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)

	frame.mainText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	frame.mainText:SetPoint("LEFT", frame.mainIcon, "RIGHT", 10, 0)
	frame.mainText:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
	frame.mainText:SetJustifyH("LEFT")

	frame.warningList = CreateFrame("Frame", nil, frame)
	frame.warningList:SetWidth(310)
	frame.warningList:SetPoint("LEFT", frame, "LEFT", 16, 0)
	frame.warningList.warnings = {}

	self.alertFrame = frame
	self:ApplyPosition()
	self:ApplyLockState()
	self:ApplyFrameStyle()
	self:ApplyTextStyle()
	self:RegisterElvUIIntegration()
end

function WF:ShouldShowPreview()
	return self.db and not self.db.locked and not UnitAffectingCombat("player")
end

function WF:ShowMoverPreview()
	if not self:ShouldShowPreview() then
		return
	end

	if not self.alertFrame then
		self:CreateUI()
	end

	self.isPreviewing = true
	self:Render(SPELLS.shadowBolt, {
		{ spell = SPELLS.lifeTap, text = "No " .. SPELLS.lifeTap.name, state = "preview" },
	})
end

function WF:HideAlerts()
	self.currentFiller = nil
	self.lastTargetGuid = nil
	self.warningState = {}
	self.expiringState = {}

	if self.alertFrame then
		self.alertFrame.flash:Hide()
		if self:ShouldShowPreview() then
			self:ShowMoverPreview()
		else
			self.isPreviewing = false
			self.alertFrame:Hide()
		end
	end
end

function WF:ResetTargetWarnings(targetGuid)
	if self.lastTargetGuid ~= targetGuid then
		self.lastTargetGuid = targetGuid
		self.warningState.missing_immolate = nil
		self.warningState.missing_corruption = nil
		self.expiringState.immolate = nil
		self.expiringState.corruption = nil
		self.expiringState.incinerate = nil
	end
end

function WF:PlayAlert()
	local now = GetTime()
	if self.lastSoundAt and now - self.lastSoundAt < SOUND_COOLDOWN then
		return
	end

	self.lastSoundAt = now
	PlaySoundFile(ALERT_SOUND)
end

function WF:PlayExpireAlert()
	local now = GetTime()
	if self.lastExpireSoundAt and now - self.lastExpireSoundAt < EXPIRE_SOUND_COOLDOWN then
		return
	end

	self.lastExpireSoundAt = now
	PlaySoundFile(EXPIRE_SOUND)
end

function WF:Flash()
	if not self.alertFrame then
		return
	end

	self.flashRemaining = FLASH_DURATION
	self.alertFrame.flash:SetAlpha(1)
	self.alertFrame.flash:Show()
end

function WF:Render(recommendation, warnings)
	local frame = self.alertFrame
	local warningCount = #warnings
	local hasRecommendation = recommendation ~= nil
	local baseHeight = hasRecommendation and 76 or 24
	local height = baseHeight + (warningCount * 22)
	local centerText = self.db and self.db.style.centerText

	if not hasRecommendation and warningCount == 0 then
		frame:Hide()
		return
	end

	frame:SetHeight(height)

	if hasRecommendation then
		local color = recommendation.color
		frame.mainIcon:SetTexture(recommendation.icon)
		frame.mainIcon:ClearAllPoints()
		frame.mainIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
		frame.mainIcon:Show()
		frame.mainText:ClearAllPoints()
		if centerText then
			frame.mainText:SetPoint("TOPLEFT", frame, "TOPLEFT", 58, -22)
			frame.mainText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -58, -22)
		else
			frame.mainText:SetPoint("LEFT", frame.mainIcon, "RIGHT", 10, 0)
			frame.mainText:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
		end
		frame.mainText:SetText(recommendation.name)
		frame.mainText:SetTextColor(color[1], color[2], color[3])
		frame.mainText:SetJustifyH(centerText and "CENTER" or "LEFT")
		frame.mainText:Show()
		frame.warningList:ClearAllPoints()
		frame.warningList:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -62)
	else
		frame.mainIcon:Hide()
		frame.mainText:Hide()
		frame.warningList:ClearAllPoints()
		frame.warningList:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -13)
	end

	frame.warningList:SetHeight(math.max(1, warningCount * 22))

	for i = 1, #frame.warningList.warnings do
		frame.warningList.warnings[i]:Hide()
	end

	for i = 1, warningCount do
		local warning = frame.warningList.warnings[i]
		local item = warnings[i]
		local color = WARNING_COLORS[item.state or "missing"] or WARNING_COLORS.missing

		if not warning then
			warning = self:CreateWarning(frame.warningList, i)
		end

		warning:ClearAllPoints()
		warning:SetPoint("TOPLEFT", frame.warningList, "TOPLEFT", 0, -((i - 1) * 22))
		warning.icon:SetTexture(item.spell.icon)
		warning.text:SetText(item.text)
		warning.text:SetTextColor(color[1], color[2], color[3])
		warning.text:SetJustifyH(centerText and "CENTER" or "LEFT")
		warning:Show()
	end

	frame:Show()
end

function WF:AddMissingWarning(warnings, key, spell, isMissing)
	local stateKey = "missing_" .. key
	if isMissing and not self.warningState[stateKey] then
		self.shouldPlayAlert = true
	end

	self.warningState[stateKey] = isMissing

	if isMissing then
		table.insert(warnings, {
			spell = spell,
			text = "No " .. spell.name,
			state = "missing",
		})
	end
end

function WF:AddExpiringWarning(warnings, key, spell, remaining)
	local threshold = self.db.thresholds[key] or 0
	local isExpiring = threshold > 0 and remaining ~= nil and remaining > 0 and remaining <= threshold

	if isExpiring and not self.expiringState[key] then
		self.shouldPlayExpireAlert = true
	end

	self.expiringState[key] = isExpiring

	if isExpiring then
		table.insert(warnings, {
			spell = spell,
			text = spell.name .. " " .. string.format("%.1f", remaining) .. "s",
			state = "expiring",
		})
	end
end

function WF:UpdateAlerts()
	if not self.db then
		return
	end

	if not self.isEligible or not UnitAffectingCombat("player") or not self:IsActivationAllowed() then
		self:HideAlerts()
		return
	end

	if not self.alertFrame then
		self:CreateUI()
	end

	self.isPreviewing = false
	self.shouldPlayAlert = false
	self.shouldPlayExpireAlert = false

	local hasTarget = self:HasHostileTarget()
	local targetGuid = hasTarget and UnitGUID("target") or nil
	self:ResetTargetWarnings(targetGuid)

	local fillerKey, fillerSpell
	if hasTarget then
		fillerKey, fillerSpell = self:GetFillerRecommendation()
	end

	if fillerKey and self.currentFiller and fillerKey ~= self.currentFiller then
		self.shouldPlayAlert = true
	elseif fillerKey and not self.currentFiller and fillerKey ~= "shadowBolt" then
		self.shouldPlayAlert = true
	end
	self.currentFiller = fillerKey

	local warnings = {}
	local foundLifeTap = self:FindAura("player", SPELLS.lifeTap, "HELPFUL")
	local lifeTapRemaining = self:GetAuraRemaining("player", SPELLS.lifeTap, "HELPFUL")

	if hasTarget then
		local foundImmolate = self:FindAura("target", SPELLS.immolate, "HARMFUL", true)
		local foundCorruption = self:FindAura("target", SPELLS.corruption, "HARMFUL", true)
		local immolateRemaining = self:GetAuraRemaining("target", SPELLS.immolate, "HARMFUL", true)
		local corruptionRemaining = self:GetAuraRemaining("target", SPELLS.corruption, "HARMFUL", true)
		local incinerateRemaining = self:GetAuraRemaining("target", SPELLS.incinerate, "HARMFUL", true)

		self:AddMissingWarning(warnings, "immolate", SPELLS.immolate, not foundImmolate)
		self:AddMissingWarning(warnings, "corruption", SPELLS.corruption, not foundCorruption)

		if foundImmolate then
			self:AddExpiringWarning(warnings, "immolate", SPELLS.immolate, immolateRemaining)
		else
			self.expiringState.immolate = nil
		end

		if foundCorruption then
			self:AddExpiringWarning(warnings, "corruption", SPELLS.corruption, corruptionRemaining)
		else
			self.expiringState.corruption = nil
		end

		self:AddExpiringWarning(warnings, "incinerate", SPELLS.incinerate, incinerateRemaining)
	else
		self:ResetTargetWarnings(nil)
	end

	self:AddMissingWarning(warnings, "lifeTap", SPELLS.lifeTap, not foundLifeTap)
	if foundLifeTap then
		self:AddExpiringWarning(warnings, "lifeTap", SPELLS.lifeTap, lifeTapRemaining)
	else
		self.expiringState.lifeTap = nil
	end

	self:Render(fillerSpell, warnings)

	if self.shouldPlayAlert then
		self:PlayAlert()
		self:Flash()
	end

	if self.shouldPlayExpireAlert then
		self:PlayExpireAlert()
		self:Flash()
	end
end

function WF:OnUpdate(elapsed)
	if self.flashRemaining and self.flashRemaining > 0 and self.alertFrame then
		self.flashRemaining = self.flashRemaining - elapsed
		if self.flashRemaining <= 0 then
			self.alertFrame.flash:Hide()
		else
			self.alertFrame.flash:SetAlpha(self.flashRemaining / FLASH_DURATION)
		end
	end

	if not self.isEligible or not UnitAffectingCombat("player") then
		return
	end

	self.updateElapsed = (self.updateElapsed or 0) + elapsed
	if self.updateElapsed >= UPDATE_INTERVAL then
		self.updateElapsed = 0
		self:UpdateAlerts()
	end
end

function WF:CreateLabel(parent, text, x, y, template)
	local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	label:SetText(text)
	return label
end

function WF:CreateThresholdSlider(parent, option, y)
	local name = "WarlocksFriend" .. option.key .. "ThresholdSlider"
	local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 28, y)
	slider:SetMinMaxValues(0, MAX_THRESHOLD)
	slider:SetValueStep(0.5)
	slider:SetWidth(260)

	if _G[name .. "Low"] then
		_G[name .. "Low"]:SetText("0")
	end
	if _G[name .. "High"] then
		_G[name .. "High"]:SetText(tostring(MAX_THRESHOLD))
	end

	slider.option = option
	slider:SetScript("OnValueChanged", function(self, value)
		if WF.refreshingOptions then
			return
		end

		WF.db.thresholds[self.option.key] = RoundThreshold(value)
		WF:RefreshOptions()
		WF:UpdateAlerts()
	end)

	return slider
end

function WF:CreateOptionCheck(parent, name, text, x, y, setter, tooltip)
	local check = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
	check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	if _G[name .. "Text"] then
		_G[name .. "Text"]:SetText(text)
	end
	check.tooltipText = tooltip
	check:SetScript("OnClick", function(self)
		setter(self:GetChecked())
	end)
	return check
end

function WF:InitializeModeDropDown()
	for _, mode in ipairs(ACTIVE_MODES) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = mode.label
		info.value = mode.key
		info.checked = self.db.activeMode == mode.key
		info.func = function(button)
			WF:SetActiveMode(button.value)
		end
		UIDropDownMenu_AddButton(info)
	end
end

function WF:CreateOptionsPanel()
	if self.optionsPanel then
		return
	end

	self:InitializeDB()

	local panel = CreateFrame("Frame", "WarlocksFriendOptionsPanel", UIParent)
	panel.name = "WarlocksFriend"

	self:CreateLabel(panel, "WarlocksFriend", 16, -16, "GameFontNormalLarge")
	self:CreateLabel(panel, "Combat alerts for Demonology Warlocks.", 16, -42, "GameFontHighlightSmall")

	local lock = CreateFrame("CheckButton", "WarlocksFriendLockedCheckButton", panel, "InterfaceOptionsCheckButtonTemplate")
	lock:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -74)
	if _G[lock:GetName() .. "Text"] then
		_G[lock:GetName() .. "Text"]:SetText("Lock alert frame")
	end
	lock.tooltipText = "Unlock to drag the alert frame. Lock it when the position feels right."
	lock:SetScript("OnClick", function(self)
		WF:SetLocked(self:GetChecked())
	end)
	panel.lock = lock

	self:CreateLabel(panel, "Frame appearance", 330, -74)
	panel.styleChecks = {}
	panel.styleChecks.showBackground = self:CreateOptionCheck(
		panel,
		"WarlocksFriendShowBackgroundCheckButton",
		"Show background",
		330,
		-100,
		function(value)
			WF:SetShowBackground(value)
		end,
		"Show or hide the alert frame background."
	)
	panel.styleChecks.showBorder = self:CreateOptionCheck(
		panel,
		"WarlocksFriendShowBorderCheckButton",
		"Show border",
		330,
		-124,
		function(value)
			WF:SetShowBorder(value)
		end,
		"Show or hide the alert frame border."
	)
	panel.styleChecks.centerText = self:CreateOptionCheck(
		panel,
		"WarlocksFriendCenterTextCheckButton",
		"Center text",
		330,
		-148,
		function(value)
			WF:SetCenterText(value)
		end,
		"Center the main alert and warning text."
	)

	self:CreateLabel(panel, "ElvUI integration", 330, -188)
	panel.elvUIStatus = self:CreateLabel(panel, "", 330, -210, "GameFontHighlightSmall")
	panel.styleChecks.useElvUIStyle = self:CreateOptionCheck(
		panel,
		"WarlocksFriendUseElvUIStyleCheckButton",
		"Use ElvUI style",
		330,
		-236,
		function(value)
			if not WF:SetUseElvUIStyle(value) then
				WF:Print("ElvUI is not available.")
				WF:RefreshOptions()
			end
		end,
		"Use ElvUI backdrop styling for the alert frame."
	)
	panel.styleChecks.useElvUIMover = self:CreateOptionCheck(
		panel,
		"WarlocksFriendUseElvUIMoverCheckButton",
		"Use ElvUI mover",
		330,
		-260,
		function(value)
			if not WF:SetUseElvUIMover(value) then
				WF:Print("ElvUI is not available.")
				WF:RefreshOptions()
			end
		end,
		"Expose the alert frame in ElvUI mover mode."
	)

	local elvUIAnchors = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	elvUIAnchors:SetWidth(130)
	elvUIAnchors:SetHeight(22)
	elvUIAnchors:SetPoint("TOPLEFT", panel, "TOPLEFT", 332, -292)
	elvUIAnchors:SetText("ElvUI Anchors")
	elvUIAnchors:SetScript("OnClick", function()
		local E = WF:GetElvUI()
		if E and E.ToggleMovers and WF:SetUseElvUIMover(true) then
			E:ToggleMovers(true, "ALL")
		end
	end)
	panel.elvUIAnchors = elvUIAnchors

	self:CreateLabel(panel, "Active mode", 16, -116)
	local modeDropDown = CreateFrame("Frame", "WarlocksFriendActiveModeDropDown", panel, "UIDropDownMenuTemplate")
	modeDropDown:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -136)
	UIDropDownMenu_SetWidth(modeDropDown, 220)
	UIDropDownMenu_Initialize(modeDropDown, function()
		WF:InitializeModeDropDown()
	end)
	panel.modeDropDown = modeDropDown

	self:CreateLabel(panel, "About-to-expire warning lead time", 16, -184)
	panel.thresholdSliders = {}
	local y = -218
	for _, option in ipairs(THRESHOLD_OPTIONS) do
		panel.thresholdSliders[option.key] = self:CreateThresholdSlider(panel, option, y)
		y = y - 54
	end

	local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	reset:SetWidth(110)
	reset:SetHeight(22)
	reset:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, y - 4)
	reset:SetText("Reset Position")
	reset:SetScript("OnClick", function()
		WF:ResetPosition()
	end)

	panel:SetScript("OnShow", function()
		WF:RefreshOptions()
		WF:ShowMoverPreview()
	end)

	InterfaceOptions_AddCategory(panel)
	self.optionsPanel = panel
	self:RefreshOptions()
end

function WF:RefreshOptions()
	if not self.optionsPanel or not self.db then
		return
	end

	self.refreshingOptions = true
	self.optionsPanel.lock:SetChecked(self.db.locked)
	self.optionsPanel.styleChecks.showBackground:SetChecked(self.db.style.showBackground)
	self.optionsPanel.styleChecks.showBorder:SetChecked(self.db.style.showBorder)
	self.optionsPanel.styleChecks.centerText:SetChecked(self.db.style.centerText)
	self.optionsPanel.styleChecks.useElvUIStyle:SetChecked(self.db.style.useElvUIStyle)
	self.optionsPanel.styleChecks.useElvUIMover:SetChecked(self.db.style.useElvUIMover)

	if self:IsElvUIAvailable() then
		self.optionsPanel.elvUIStatus:SetText("|cff00ff00ElvUI detected.|r")
		self.optionsPanel.styleChecks.useElvUIStyle:Enable()
		self.optionsPanel.styleChecks.useElvUIMover:Enable()
		self.optionsPanel.elvUIAnchors:Enable()
	else
		self.optionsPanel.elvUIStatus:SetText("|cff999999ElvUI not loaded.|r")
		self.optionsPanel.styleChecks.useElvUIStyle:Disable()
		self.optionsPanel.styleChecks.useElvUIMover:Disable()
		self.optionsPanel.elvUIAnchors:Disable()
	end

	UIDropDownMenu_SetSelectedValue(self.optionsPanel.modeDropDown, self.db.activeMode)
	UIDropDownMenu_SetText(self.optionsPanel.modeDropDown, ACTIVE_MODE_LABELS[self.db.activeMode])

	for _, option in ipairs(THRESHOLD_OPTIONS) do
		local slider = self.optionsPanel.thresholdSliders[option.key]
		local value = self.db.thresholds[option.key] or DEFAULTS.thresholds[option.key]
		if _G[slider:GetName() .. "Text"] then
			_G[slider:GetName() .. "Text"]:SetText(option.label .. ": " .. string.format("%.1f", value) .. "s")
		end
		slider:SetValue(value)
	end

	self.refreshingOptions = false
end

function WF:OpenOptions()
	if not self.optionsPanel then
		self:CreateOptionsPanel()
	end

	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
	end
end

function WF:PrintHelp()
	self:Print("/wf options")
	self:Print("/wf lock | unlock")
	self:Print("/wf mode never | mob | target | focus")
	self:Print("/wf threshold lifetap|corruption|immolate|incinerate <seconds>")
	self:Print("/wf background on|off")
	self:Print("/wf border on|off")
	self:Print("/wf center on|off")
	self:Print("/wf elvui style on|off")
	self:Print("/wf elvui mover on|off")
	self:Print("/wf resetpos")
	self:Print("/wf status")
end

function WF:PrintStatus()
	self:InitializeDB()
	self:Print("Frame: " .. (self.db.locked and "locked" or "unlocked"))
	self:Print("Active mode: " .. ACTIVE_MODE_LABELS[self.db.activeMode])
	self:Print("Background: " .. (self.db.style.showBackground and "shown" or "hidden"))
	self:Print("Border: " .. (self.db.style.showBorder and "shown" or "hidden"))
	self:Print("Text alignment: " .. (self.db.style.centerText and "centered" or "left"))
	self:Print("ElvUI style: " .. (self.db.style.useElvUIStyle and "enabled" or "disabled"))
	self:Print("ElvUI mover: " .. (self.db.style.useElvUIMover and "enabled" or "disabled"))
	for _, option in ipairs(THRESHOLD_OPTIONS) do
		self:Print(option.label .. ": " .. string.format("%.1f", self.db.thresholds[option.key]) .. "s")
	end
end

function WF:HandleSlash(input)
	self:InitializeDB()

	local command, rest = string.match(input or "", "^%s*(%S*)%s*(.-)%s*$")
	command = string.lower(command or "")
	rest = rest or ""

	if command == "" or command == "help" then
		self:PrintHelp()
	elseif command == "options" or command == "config" then
		self:OpenOptions()
	elseif command == "lock" then
		self:SetLocked(true)
		self:Print("Alert frame locked.")
	elseif command == "unlock" or command == "move" then
		self:SetLocked(false)
		self:Print("Alert frame unlocked.")
	elseif command == "mode" or command == "active" then
		local mode = ACTIVE_MODE_ALIASES[string.lower(rest)]
		if mode and self:SetActiveMode(mode) then
			self:Print("Active mode set to " .. ACTIVE_MODE_LABELS[mode] .. ".")
		else
			self:Print("Usage: /wf mode never | mob | target | focus")
		end
	elseif command == "threshold" or command == "lead" then
		local aura, seconds = string.match(rest, "^(%S+)%s+(%S+)$")
		local key = aura and THRESHOLD_ALIASES[string.lower(aura)]
		if key and seconds and self:SetThreshold(key, seconds) then
			self:Print(THRESHOLD_LABELS[key] .. " warning set to " .. string.format("%.1f", self.db.thresholds[key]) .. "s.")
		else
			self:Print("Usage: /wf threshold lifetap|corruption|immolate|incinerate <seconds>")
		end
	elseif command == "background" or command == "bg" then
		local value = ParseBoolean(rest)
		if value == nil then
			self:Print("Usage: /wf background on|off")
		else
			self:SetShowBackground(value)
			self:Print("Background " .. (value and "shown." or "hidden."))
		end
	elseif command == "border" then
		local value = ParseBoolean(rest)
		if value == nil then
			self:Print("Usage: /wf border on|off")
		else
			self:SetShowBorder(value)
			self:Print("Border " .. (value and "shown." or "hidden."))
		end
	elseif command == "center" or command == "centertext" or command == "align" then
		local value = ParseBoolean(rest)
		if value == nil then
			self:Print("Usage: /wf center on|off")
		else
			self:SetCenterText(value)
			self:Print("Text alignment set to " .. (value and "center." or "left."))
		end
	elseif command == "style" then
		local styleCommand, styleValue = string.match(rest, "^(%S+)%s+(%S+)$")
		styleCommand = styleCommand and string.lower(styleCommand)
		local value = ParseBoolean(styleValue)
		if not styleCommand or value == nil then
			self:Print("Usage: /wf style background|border|center <on|off>")
		elseif styleCommand == "background" or styleCommand == "bg" then
			self:SetShowBackground(value)
			self:Print("Background " .. (value and "shown." or "hidden."))
		elseif styleCommand == "border" then
			self:SetShowBorder(value)
			self:Print("Border " .. (value and "shown." or "hidden."))
		elseif styleCommand == "center" or styleCommand == "centertext" or styleCommand == "align" then
			self:SetCenterText(value)
			self:Print("Text alignment set to " .. (value and "center." or "left."))
		else
			self:Print("Usage: /wf style background|border|center <on|off>")
		end
	elseif command == "elvui" then
		local elvuiCommand, elvuiValue = string.match(rest, "^(%S+)%s*(%S*)$")
		elvuiCommand = elvuiCommand and string.lower(elvuiCommand)
		local value = ParseBoolean(elvuiValue)

		if elvuiCommand == "style" and value ~= nil then
			if self:SetUseElvUIStyle(value) then
				self:Print("ElvUI style " .. (value and "enabled." or "disabled."))
			else
				self:Print("ElvUI is not available.")
			end
		elseif elvuiCommand == "mover" and value ~= nil then
			if self:SetUseElvUIMover(value) then
				self:Print("ElvUI mover " .. (value and "enabled." or "disabled."))
			else
				self:Print("ElvUI is not available.")
			end
		elseif elvuiCommand == "anchors" or elvuiCommand == "movers" then
			local E = self:GetElvUI()
			if E and E.ToggleMovers and self:SetUseElvUIMover(true) then
				E:ToggleMovers(true, "ALL")
			else
				self:Print("ElvUI is not available.")
			end
		else
			self:Print("Usage: /wf elvui style|mover <on|off> or /wf elvui anchors")
		end
	elseif command == "resetpos" or command == "resetposition" then
		self:ResetPosition()
		self:Print("Alert frame position reset.")
	elseif command == "status" then
		self:PrintStatus()
	else
		self:PrintHelp()
	end
end

function WF:OnEvent(event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			self:InitializeDB()
			self:CreateUI()
			self:CreateOptionsPanel()
			self:RegisterElvUIIntegration()
			return
		end

		if arg1 == "ElvUI" or arg1 == "ElvUI_OptionsUI" then
			self:RegisterElvUIIntegration()
			self:RegisterElvUIOptions()
			self:RefreshOptions()
			self:ApplyFrameStyle()
			return
		end

		return
	end

	if event == "PLAYER_LOGIN" then
		self:InitializeDB()
		self:CreateUI()
		self:CreateOptionsPanel()
		self:RegisterElvUIIntegration()
		self:RefreshEligibility()
		self:UpdateAlerts()
		return
	end

	if event == "PLAYER_REGEN_DISABLED" then
		self:RefreshEligibility()
		self:UpdateAlerts()
		return
	end

	if event == "PLAYER_REGEN_ENABLED" then
		self:HideAlerts()
		return
	end

	if event == "UNIT_AURA" and arg1 ~= "player" and arg1 ~= "target" then
		return
	end

	if event == "UNIT_HEALTH" and arg1 ~= "target" then
		return
	end

	if event == "PLAYER_TARGET_CHANGED" then
		self:ResetTargetWarnings(nil)
	end

	if event == "CHARACTER_POINTS_CHANGED"
		or event == "ACTIVE_TALENT_GROUP_CHANGED"
		or event == "PLAYER_TALENT_UPDATE" then
		self:RefreshEligibility()
	end

	self:UpdateAlerts()
end

WF.warningState = {}
WF.expiringState = {}

SLASH_WARLOCKSFRIEND1 = "/wf"
SLASH_WARLOCKSFRIEND2 = "/warlocksfriend"
SlashCmdList.WARLOCKSFRIEND = function(input)
	WF:HandleSlash(input)
end

WF:RegisterEvent("ADDON_LOADED")
WF:RegisterEvent("PLAYER_LOGIN")
WF:RegisterEvent("PLAYER_REGEN_DISABLED")
WF:RegisterEvent("PLAYER_REGEN_ENABLED")
WF:RegisterEvent("PLAYER_TARGET_CHANGED")
WF:RegisterEvent("PLAYER_FOCUS_CHANGED")
WF:RegisterEvent("UNIT_AURA")
WF:RegisterEvent("UNIT_HEALTH")
WF:RegisterEvent("CHARACTER_POINTS_CHANGED")
WF:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
WF:RegisterEvent("PLAYER_TALENT_UPDATE")
WF:SetScript("OnEvent", function(self, event, ...)
	self:OnEvent(event, ...)
end)
WF:SetScript("OnUpdate", function(self, elapsed)
	self:OnUpdate(elapsed)
end)
