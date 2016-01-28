-----------------------------------------------------------------------------------------------
-- Client Lua Script for WildStarLogger
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Apollo"
require "Window"
require "Unit"
require "Spell"
require "GameLib"
require "ChatSystemLib"
require "ChatChannelLib"
require "CombatFloater"
require "GroupLib"
require "Time"

-----------------------------------------------------------------------------------------------
-- WildStarLogger Module Definition
-----------------------------------------------------------------------------------------------
local WildStarLogger = {}

local kAPIVersion = Apollo.GetAPIVersion()
local kSavedVersion = 5
if kAPIVersion >= 11 then
	kSavedVersion = 6
end
local kMaxChunkSize = 50000

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function WildStarLogger:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	self.debug = false
	self.on = false
	self.logRaids = false
	self.logDungeons = false
	self.windowShowing = false
	self.inCombat = false
	self.fights = 0
	self.fightIndex = 0
	self.continent = 0
	self.forceSaveDisable = false
	self.eventTable = {}
	self.eventTable[#self.eventTable + 1] = "--- WildStar Logs Data ---"
    return o
end

function WildStarLogger:Init()
    Apollo.RegisterAddon(self, false)
end

function WildStarLogger:ClearTable()
	local newTable = {}
	if self.fightIndex > 0 then
		newTable[#newTable + 1] = "--- WildStar Logs Data ---"
		for i = self.fightIndex + 1, #self.eventTable, 1 do
			newTable[#newTable + 1] = self.eventTable[i]
		end
		self.eventTable = newTable
	else
		self.eventTable = {}
		self.eventTable[#self.eventTable + 1] = "--- WildStar Logs Data ---"
	end
	self.fights = 0
	self.fightIndex = 0
end

function WildStarLogger:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLoc
	
	local tSave = 
	{
		nSavedVersion = kSavedVersion,
		tLocWindow = locWindowLocation and locWindowLocation:ToTable() or nil,
		bLogRaids = self.logRaids,
		bLogDungeons = self.logDungeons,
		bWindowShowing = self.windowShowing,
		nFights = self.fights,
		tEvents = self.eventTable
	}
	
	return tSave
end

function WildStarLogger:OnRestore(eType, tSavedData)
	if tSavedData.nSavedVersion ~= kSavedVersion then
		return
	end
	
	if tSavedData.tLocWindow then
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tLocWindow)
	end
	
	if tSavedData.bLogRaids then
		self.logRaids = tSavedData.bLogRaids
	end
	
	if tSavedData.bLogDungeons then
		self.logDungeons = tSavedData.bLogDungeons
	end

	if tSavedData.bWindowShowing then
		self.windowShowing = true
	end
	
	if tSavedData.nFights then
		self.fights = tSavedData.nFights
	end
	
	if tSavedData.tEvents then
		self.eventTable = tSavedData.tEvents
	end
end

-----------------------------------------------------------------------------------------------
-- WildStarLogger OnLoad 
-----------------------------------------------------------------------------------------------
function WildStarLogger:OnLoad()
    -- load our form file
	self.wndMain = Apollo.LoadForm("WildStarLogger.xml", "LoggerWindow", nil, self)
	if self.wndMain == nil then
		Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
		return Apollo.AddonLoadStatus.LoadingError
	end
	
	self.wndMain:Show(false)
	self.startButton = self.wndMain:FindChild("StartButton")
	self.stopButton = self.wndMain:FindChild("StopButton")
	self.loggingStateLabel = self.wndMain:FindChild("LoggingStateLabel")
	self.fightsCountLabel = self.wndMain:FindChild("FightsCountLabel")
	self.eventsCountLabel = self.wndMain:FindChild("EventsCountLabel")
	self.logRaidsButton = self.wndMain:FindChild("LogRaidsButton")
	self.logDungeonsButton = self.wndMain:FindChild("LogDungeonsButton")
	self.uploadFightsButton = self.wndMain:FindChild("UploadFightsButton")

   	-- if the xmlDoc is no longer needed, you should set it to nil
	-- self.xmlDoc = nil
		
	-- Register handlers for events, slash commands and timer, etc.
	-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
	Apollo.RegisterSlashCommand("wsl", "OnSlashCommand", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat", "OnEnteredCombat", self)
	Apollo.RegisterEventHandler("CombatLogDamage","OnCombatLogDamage", self)
	Apollo.RegisterEventHandler("CombatLogFallingDamage","OnCombatLogFallingDamage", self)
	Apollo.RegisterEventHandler("CombatLogDeflect","OnCombatLogDeflect", self)
	Apollo.RegisterEventHandler("CombatLogImmune","OnCombatLogImmunity", self)
	
	-- New handlers as of v11
	if kAPIVersion >= 11 then
		Apollo.RegisterEventHandler("CombatLogDamageShields", 			"OnCombatLogDamage", self)
		Apollo.RegisterEventHandler("CombatLogReflect", 				"OnCombatLogDamage", self)
		Apollo.RegisterEventHandler("CombatLogMultiHit", 				"OnCombatLogMultiHit", self)
		Apollo.RegisterEventHandler("CombatLogMultiHitShields", 		"OnCombatLogMultiHit", self)
		Apollo.RegisterEventHandler("CombatLogMultiHeal", 				"OnCombatLogMultiHeal", self)
	end
	-- end
	
	Apollo.RegisterEventHandler("CombatLogHeal","OnCombatLogHeal", self)
	Apollo.RegisterEventHandler("CombatLogTransference","OnCombatLogTransference", self)
	Apollo.RegisterEventHandler("CombatLogAbsorption", "OnCombatLogAbsorption", self)
	Apollo.RegisterEventHandler("CombatLogCCState", "OnCombatLogCCState", self)
	Apollo.RegisterEventHandler("CombatLogInterrupted", "OnCombatLogInterrupted", self)
	Apollo.RegisterEventHandler("CombatLogDispel", "OnCombatLogDispel", self)
	Apollo.RegisterEventHandler("CombatLogVitalModifier", "OnCombatLogVitalModifier", self)
	
	--Apollo.RegisterEventHandler("BuffAdded", "OnBuffAdded", self)
	--Apollo.RegisterEventHandler("BuffRemoved", "OnBuffRemoved", self)
	--Apollo.RegisterEventHandler("BuffUpdated", "OnBuffUpdated", self)

	Apollo.RegisterEventHandler("CombatLogVitalModifier", "OnCombatLogVitalModifier", self)
	
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
    Apollo.RegisterEventHandler("ToggleLoggerWindow", "OnToggleLoggerWindow", self)

	Apollo.RegisterEventHandler("SubZoneChanged", "OnZoneChanging", self)

	-- Do additional Addon initialization here
	Apollo.SetConsoleVariable("cmbtlog.disableOtherPlayers", false)
	
	Apollo.RegisterTimerHandler("WildStarLogger_SaveDisabled", "OnSaveDisabledTimer", self)
end


function WildStarLogger:IsRaidContinent(nContinentId)
	return nContinentId == 52 or nContinentId == 67
end

function WildStarLogger:IsDungeonContinent(nContinentId)
	return nContinentId == 27 or nContinentId == 28 or nContinentId == 25 or nContinentId == 16 or nContinentId == 17 or nContinentId == 23
		or nContinentId == 15 or nContinentId == 13 or nContinentId == 14 or nContinentId == 48
end

function WildStarLogger:OnZoneChanging()
	local zoneMap = GameLib.GetCurrentZoneMap()
	if zoneMap and zoneMap.continentId and zoneMap.continentId ~= self.continent then
		local wasInRaid = self:IsRaidContinent(self.continent)
		local wasInDungeon = self:IsDungeonContinent(self.continent)
		
		self.continent = zoneMap.continentId

		local isInRaid = self:IsRaidContinent(self.continent)
		local isInDungeon = self:IsDungeonContinent(self.continent)
		
		if (self.logRaids and wasInRaid ~= isInRaid) or (self.logDungeons and wasInDungeon ~= isInDungeon) then
			self.on = (self.logRaids and isInRaid) or (self.logDungeons and isInDungeon)
			self:UpdateUIState()				
		end
	end
end

function WildStarLogger:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "WildStarLogger", {"ToggleLoggerWindow", "", ""})
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end
	self:OnZoneChanging()
	self:UpdateUIState()
	self.logRaidsButton:SetCheck(self.logRaids)
	self.logDungeonsButton:SetCheck(self.logDungeons)
	self.wndMain:Show(self.windowShowing)
	
end

function WildStarLogger:OnEnteredCombat(unit, bInCombat)
	if not self.on then
		return
	end

	if unit:GetId() == GameLib.GetPlayerUnit():GetId() then
		self.inCombat = bInCombat
		if not bInCombat then
			self.fights = self.fights + 1
			self:UpdateInterfaceMenuAlerts()
		end
		self:UpdateUIState()
	end
end

function WildStarLogger:OnDependencyError(strDep, strError)
	Print("WildStarLogger couldn't load " .. strDep .. ". Fatal error: " .. strError)
	return false
end

function WildStarLogger:UpdateInterfaceMenuAlerts()
	Event_FireGenericEvent("InterfaceMenuList_AlertAddOn", "WildStarLogger", {self.fights > 0, nil, self.fights})
end

function WildStarLogger:OnToggleLoggerWindow()
	if not self.wndMain:IsShown() and self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end
	if self.wndMain:IsShown() then
		self.locSavedWindowLoc = WindowLocation.new(self.wndMain:GetLocation():ToTable())
	end
	self.wndMain:Show(not self.wndMain:IsShown())
	self.windowShowing = self.wndMain:IsShown()
	self:UpdateUIState()
end

function WildStarLogger:AttachEventsToFightsButton()
	if #self.eventTable == 1 then
		return
	end
	
	if #self.eventTable <= kMaxChunkSize + 1 then
		self.eventTable[#self.eventTable + 1] = "" -- Trickery to make sure a \n gets put after the last line without duplicating the string.
		local eventStr = table.concat(self.eventTable, "\n")
		self.uploadFightsButton:SetActionData(GameLib.CodeEnumConfirmButtonType.CopyToClipboard, eventStr)
		table.remove(self.eventTable)
		self.fightIndex = #self.eventTable
	else
		local oldEntry = self.eventTable[kMaxChunkSize + 2]
		self.eventTable[kMaxChunkSize + 2] = ""
		local eventStr = table.concat(self.eventTable, "\n", 1, kMaxChunkSize + 2)
		self.uploadFightsButton:SetActionData(GameLib.CodeEnumConfirmButtonType.CopyToClipboard, eventStr)
		self.eventTable[kMaxChunkSize + 2] = oldEntry
		self.fightIndex = kMaxChunkSize + 1
	end
end

function WildStarLogger:AddEvent(lineStr)
	self.eventTable[#self.eventTable + 1] = lineStr
	self.eventsCountLabel:SetText(#self.eventTable - 1)
	self.uploadFightsButton:Enable(#self.eventTable > 1)
end

-----------------------------------------------------------------------------------------------
-- WildStarLogger Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/wsl"
function WildStarLogger:OnSlashCommand(cmd, args)
	if (args == "debug") then
		self.debug = not self.debug
		if (self.debug) then
			self:PostOnChannel("WildStar Logger debugging mode enabled.")
		else
			self:PostOnChannel("WildStar Logger debugging mode disabled.")
		end
		return
	end
	
	self:OnToggleLoggerWindow()
end

function WildStarLogger:PostOnChannel(strResult)
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, strResult, "")
end


-----------------------------------------------------------------------------------------------
-- Needs Beneficial vs Not Beneficial
-----------------------------------------------------------------------------------------------

function WildStarLogger:HandleDamage(tEventArgs, eventType, bWorkAroundTransferenceBug)
	if not tEventArgs.unitTarget then 
		if eventType == "falling" then
			tEventArgs.unitTarget = GameLib.GetPlayerUnit()
		else
			return
		end
	end
	
	local line = {}
	
	self:TimestampActorsAndAbility(line, tEventArgs, eventType, false)
	
	-- Now the ability school (e.g., Tech, Magic, Physical).
	if kAPIVersion >= 11 then
		line[#line + 1] = tEventArgs.eDamageType and tEventArgs.eDamageType - 1 or 1 -- The school changed in v11 from being 0,1,2 to 1,2,3 so subtract to keep the same.
	else
		line[#line + 1] = tEventArgs.eDamageType
	end

	-- Next is the type of damage (regular, periodic, distance-dependent or distributed). We'll
	-- use the numbers 0-3 to represent these.
	local attackType = 0
	if tEventArgs.bPeriodic then
		attackType = 1
	elseif tEventArgs.eEffectType == Spell.CodeEnumSpellEffectType.DistanceDependentDamage then
		attackType = 2
	elseif tEventArgs.eEffectType == Spell.CodeEnumSpellEffectType.DistributedDamage then
		attackType = 3
	end
	line[#line + 1] = attackType

	line[#line + 1] = tEventArgs.nDamageAmount
	line[#line + 1] = tEventArgs.nShield
	line[#line + 1] = tEventArgs.nAbsorption
	line[#line + 1] = tEventArgs.nOverkill

	-- Crit and vulnerability can be combined as bits.
	local bitField = 0
	if tEventArgs.bTargetVulnerable then
		bitField = 1
	end

	if tEventArgs.eCombatResult == GameLib.CodeEnumCombatResult.Critical then
		bitField = bitField + 2
	end
	
	line[#line + 1] = bitField
	
	if tEventArgs.bMultiHit then
		line[#line + 1] = "1"
	else
		line[#line + 1] = "0"
	end

	if tEventArgs.nGlanceAmount and tEventArgs.nGlanceAmount > 0 then
		line[#line + 1] = tEventArgs.nGlanceAmount
	end
	
	local lineStr =  table.concat(line, ",")
	self:AddEvent(lineStr)
	
	if self.debug then
		self:PostOnChannel(lineStr)
	end
	
	if tEventArgs.bTargetKilled or (bWorkAroundTransferenceBug and tEventArgs.nOverkill > 0) then
		self:HandleDeath(tEventArgs)
	end
end
 
function WildStarLogger:HandleDeath(tEventArgs)
	local line = {}
	self:TimestampActorsAndAbility(line, tEventArgs, "death", false)
	
	local lineStr =  table.concat(line, ",")
	self:AddEvent(lineStr)
	if self.debug then
		self:PostOnChannel(lineStr)
	end
end

function WildStarLogger:OnCombatLogDamage(tEventArgs)
    if (not self.on) then return end
	return self:HandleDamage(tEventArgs, "damage", false)
end

function WildStarLogger:OnCombatLogMultiHit(tEventArgs)
    if (not self.on) then return end
	tEventArgs.bMultiHit = true
	tEventArgs.nOverkill = 0
	return self:HandleDamage(tEventArgs, "damage", false)
end

function WildStarLogger:OnCombatLogFallingDamage(tEventArgs)
    if (not self.on) then return end
	return self:HandleDamage(tEventArgs, "falling", false)
end

function WildStarLogger:OnCombatLogDeflect(tEventArgs)
    if (not self.on) then return end
	return self:HandleDamage(tEventArgs, "deflect", false)
end

function WildStarLogger:OnCombatLogImmunity(tEventArgs)
    if (not self.on) then return end
	return self:HandleDamage(tEventArgs, "immune", false)
end

function WildStarLogger:OnCombatLogHeal(tEventArgs)
    if (not self.on) then return end
	self:HandleHealEvent(tEventArgs, nil)
end

function WildStarLogger:OnCombatLogMultiHeal(tEventArgs)
    if (not self.on) then return end
	tEventArgs.bMultiHit = true
	self:HandleHealEvent(tEventArgs, nil)
end

function WildStarLogger:HandleHealEvent(tEventArgs, tHealData)
	if not tEventArgs.unitTarget then return end
	
	local line = {}
	self:TimestampActorsAndAbility(line, tEventArgs, "heal", tHealData ~= nil)

	if tHealData == nil then
		tHealData = tEventArgs
	end

	local healAmount = 0
	local shieldAmount = 0
	if tEventArgs.eEffectType == Spell.CodeEnumSpellEffectType.HealShields then
		line[#line + 1] = "1"
	else
		line[#line + 1] = "0"
	end
	
	local healType = 0
	if tEventArgs.bPeriodic then
		healType = 1
	end
	line[#line + 1] = healType

	line[#line + 1] = tHealData.nHealAmount
	line[#line + 1] = tHealData.nOverheal
	
	local critField = 0
	if tHealData.eCombatResult == GameLib.CodeEnumCombatResult.Critical then
		critField = 2
	end
	line[#line + 1] = critField
	
	if tEventArgs.bMultiHit then
		line[#line + 1] = "1"
	end

	local lineStr =  table.concat(line, ",")
	self:AddEvent(lineStr)
	if self.debug then
		self:PostOnChannel(lineStr)
	end
end

function WildStarLogger:OnCombatLogTransference(tEventArgs)
	if not self.on then return end
	
	-- HandleDamage does exactly what we need so just pass along the tEventArgs
	self:HandleDamage(tEventArgs, "damage", true)
	
	for _, tHeal in ipairs(tEventArgs.tHealData) do
		self:HandleHealEvent(tEventArgs, tHeal)
	end
end

function WildStarLogger:OnCombatLogAbsorption(tEventArgs)
	if not self.on then return end
	
	local line = {}
	self:TimestampActorsAndAbility(line, tEventArgs, "absorb", false)
	
	line[#line + 1] = tEventArgs.nAmount
	
	local critField = 0
	if tEventArgs.eCombatResult == GameLib.CodeEnumCombatResult.Critical then
		critField = 2
	end
	line[#line + 1] = critField
	
	local lineStr =  table.concat(line, ",")
	self:AddEvent(lineStr)
	if self.debug then
		self:PostOnChannel(lineStr)
	end
end

function WildStarLogger:OnCombatLogInterrupted(tEventArgs)
	if not self.on then return end
	
	if not tEventArgs or not tEventArgs.unitCaster or tEventArgs.unitCaster == tEventArgs.unitTarget then
		return
	end
	
	local line = {}
	self:TimestampActorsAndAbility(line, tEventArgs, "interrupt", false)
	
	-- Ability Name + ID
	if not tEventArgs.splCallingSpell then
		line[#line + 1] = "nil,0"
	else
		local spellName = self:GetActorOrAbilityName(tEventArgs.splCallingSpell)
		if not spellName then
			line[#line + 1] = "nil"
		else
			line[#line + 1] = "\""..spellName.."\""
		end
		line[#line + 1] = tEventArgs.splCallingSpell:GetId() or 0
	end
	
	local lineStr =  table.concat(line, ",")
	self:AddEvent(lineStr)
	if self.debug then
		self:PostOnChannel(lineStr)
	end
end

function WildStarLogger:OnCombatLogDispel(tEventArgs)
	if not self.on then return end
	
	local line = {}
	self:TimestampActorsAndAbility(line, tEventArgs, "dispel", false)
	
	-- Ability Name + ID
	if not tEventArgs.splRemovedSpell then
		line[#line + 1] = "nil,0"
	else
		local spellName = self:GetActorOrAbilityName(tEventArgs.splRemovedSpell)
		if not spellName then
			line[#line + 1] = "nil"
		else
			line[#line + 1] = "\""..spellName.."\""
		end
		line[#line + 1] = tEventArgs.splRemovedSpell:GetId() or 0
	end

	-- The number of instances dispelled
	line[#line + 1] = tEventArgs.nInstancesRemoved

	local lineStr =  table.concat(line, ",")
	self:AddEvent(lineStr)
	if self.debug then
		self:PostOnChannel(lineStr)
	end
end

function WildStarLogger:OnCombatLogCCState(tEventArgs)
	if not self.on then return end
	
	local line = {}
	local eventType = "applycc"
	if tEventArgs.bRemoved then
		eventType = "removecc"
	end

	self:TimestampActorsAndAbility(line, tEventArgs, eventType, false)

	line[#line + 1] = "\"" .. tEventArgs.strState .. "\""
	
	if not tEventArgs.bRemoved then
		if tEventArgs.eResult == CombatFloater.CodeEnumCCStateApplyRulesResult.Stacking_DoesNotStack then
			line[#line + 1] = 1
		elseif tEventArgs.eResult == CombatFloater.CodeEnumCCStateApplyRulesResult.Target_Immune then
			line[#line + 1] = 2
		else
			line[#line + 1] = 0
		end
		line[#line + 1] = tEventArgs.nInterruptArmorHit
	end

	local lineStr =  table.concat(line, ",")
	self:AddEvent(lineStr)
	if self.debug then
		self:PostOnChannel(lineStr)
	end
end

function WildStarLogger:OnCombatLogVitalModifier(tEventArgs)
    if (not self.on) then return end

	-- Should I honor this?
	if not tEventArgs.bShowCombatLog then
		return
	end

	local line = {}
	self:TimestampActorsAndAbility(line, tEventArgs, "gain", false)
	
	line[#line + 1] = tEventArgs.eVitalType or 0
	line[#line + 1] = tEventArgs.nAmount or 0

	
	local lineStr =  table.concat(line, ",")
	self:AddEvent(lineStr)
	if self.debug then
		self:PostOnChannel(lineStr)
	end
end

function WildStarLogger:OnBuffAdded(unit, tBuff)
	if (not self.on or unit == nil) then return end
	local tEventArgs = { unitTarget = unit, splCallingSpell = tBuff.splEffect }
	local name = "applybuff"
	if (not tBuff.splEffect:IsBeneficial()) then
		name = "applydebuff"
	end
	
	local line = {}
	self:TimestampActorsAndAbility(line, tEventArgs, name, false)
	
	local lineStr =  table.concat(line, ",")
	self:AddEvent(lineStr)
	if self.debug then
		self:PostOnChannel(lineStr)
	end
end

function WildStarLogger:OnBuffRemoved(unit, tBuff)
    if (not self.on or unit == nil) then return end
	local tEventArgs = { unitTarget = unit, splCallingSpell = tBuff.splEffect }
	local name = "removebuff"
	if (not tBuff.splEffect:IsBeneficial()) then
		name = "removedebuff"
	end
	
	local line = {}
	self:TimestampActorsAndAbility(line, tEventArgs, name, false)
	
	local lineStr =  table.concat(line, ",")
	self:AddEvent(lineStr)
	if self.debug then
		self:PostOnChannel(lineStr)
	end
end

function WildStarLogger:OnBuffUpdated(unit, tBuff)
    if (not self.on or unit == nil) then return end
	local tEventArgs = { unitTarget = unit, splCallingSpell = tBuff.splEffect }
	local name = "updatebuff"
	if (not tBuff.splEffect:IsBeneficial()) then
		name = "updatedebuff"
	end
	
	local line = {}
	self:TimestampActorsAndAbility(line, tEventArgs, name, false)
	line[#line + 1] = tBuff.nCount or 0
	
	local lineStr =  table.concat(line, ",")
	
	self:AddEvent(lineStr)
	if self.debug then
		self:PostOnChannel(lineStr)
	end
end

function WildStarLogger:TimestampActorsAndAbility(line, tEventArgs, nType, forceSelf)
	-- Begin with the timestamp
    local timeOfEvent = GameLib.GetGameTime()
	
	line[#line + 1] = os.time()
	line[#line + 1] = timeOfEvent
	
	line[#line + 1] = nType -- Type of event such as damage/heal

	local unitSource = tEventArgs.unitCaster
	local unitSourceOwner = tEventArgs.unitCasterOwner
	if (nType == "damage" and unitSource == tEventArgs.unitTarget) or nType == "death" then
		-- Environmental damage or death
		unitSource = nil
		unitSourceOwner = nil
	end
	
	-- Next we add in the source of the damage.
	self:GetActorInfo(line, unitSource, unitSourceOwner)
		
	if forceSelf then
		self:GetActorInfo(line, unitSource, unitSourceOwner)
	else
		-- Next is the target of the damage event.
		self:GetActorInfo(line, tEventArgs.unitTarget, tEventArgs.unitTargetOwner)
	end

	if nType == "death" then
		return
	end
	
	-- Ability Name + ID
	local spell = tEventArgs.splCallingSpell
	if nType == "interrupt" then
		spell = tEventArgs.splInterruptingSpell
	end
	if not spell then
		line[#line + 1] = "nil,0"
	else
		local spellName = self:GetActorOrAbilityName(spell)
		if not spellName then
			line[#line + 1] = "nil"
		else
			line[#line + 1] = "\""..spellName.."\""
		end
		line[#line + 1] = spell:GetId() or 0
	end

	return line
end

function WildStarLogger:GetActorInfo(line, unit, owner)
	if not unit then
		line[#line + 1] = "nil,0,0,0,0,0/0,0,0,0/0,0/0,0/0,0/0,0/0/0,0,0,nil,0"
		return
	end
	
	local actorName = self:GetActorOrAbilityName(unit)
	if not actorName then
		line[#line + 1] = "nil"
	else
		line[#line + 1] = "\""..actorName.."\""
	end
	
	local classID = unit:GetClassId()
	line[#line + 1] = classID
	line[#line + 1] = unit:GetId()
	line[#line + 1] = unit:GetDispositionTo(GameLib.GetPlayerUnit())
	line[#line + 1] = (unit:GetTargetMarker() or 0)
	line[#line + 1] = math.floor(unit:GetHealth() or 0).."/"..math.floor(unit:GetMaxHealth() or 0)
	line[#line + 1] = math.floor(unit:GetAssaultPower() or 0)
	line[#line + 1] = math.floor(unit:GetSupportPower() or 0)
	line[#line + 1] = math.floor(unit:GetShieldCapacity() or 0).."/"..math.floor(unit:GetShieldCapacityMax() or 0)
	line[#line + 1] = math.floor(unit:GetAbsorptionValue() or 0).."/"..math.floor(unit:GetAbsorptionMax() or 0)
	if kAPIVersion >= 11 then -- They fixed the inaccurate naming for focus.
		line[#line + 1] = math.floor(unit:GetFocus() or 0).."/"..math.floor(unit:GetMaxFocus() or 0)
	else
		line[#line + 1] = math.floor(unit:GetMana() or 0).."/"..math.floor(unit:GetMaxMana() or 0)
	end
	line[#line + 1] = math.floor(unit:GetInterruptArmorValue() or 0).."/"..math.floor(unit:GetInterruptArmorMax() or 0)

	-- Class-specific resource. Omit for NPCs. Spellslinger's Spell Power is on 4 rather than 1. Stalker's Suit Power is on 3.
	local resourceToFetch = 1
	if classID == 7 then
		resourceToFetch = 4
	elseif classID == 5 then
		resourceToFetch = 3
	end
	
	if classID <= 7 then
		line[#line + 1] = math.floor(unit:GetResource(resourceToFetch) or 0).."/"..math.floor(unit:GetMaxResource(resourceToFetch) or 0)
	else
		line[#line + 1] = "0/0"
	end

	local position = unit:GetPosition()
	if not position then
		line[#line + 1] = "0,0"
	else 	
		line[#line + 1] = math.floor((position.x or 0) * 100)
		line[#line + 1] = math.floor((position.z or 0) * 100) -- FIXME: This is obviously wrong, but for now just go with it til they fix.
	end

	-- Pet ownership
	if not owner then
		line[#line + 1] = "nil,0"
		return result
	end

	local ownerName = self:GetActorOrAbilityName(owner)
	if not ownerName then
		line[#line + 1] = "nil"
	else
		line[#line + 1] = "\""..ownerName.."\""
	end

	line[#line + 1] = owner:GetId()
end

function WildStarLogger:GetActorOrAbilityName(nArg)
	if nArg and nArg:GetName() then
		return nArg:GetName()
	end
	return nil
end

-----------------------------------------------------------------------------------------------
-- WildStarLoggerForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function WildStarLogger:OnOK()
	self:OnToggleLoggerWindow()
end

-- when the Cancel button is clicked
function WildStarLogger:OnCancel()
	self:OnToggleLoggerWindow()
end

function WildStarLogger:UpdateUIState()
	if not self.windowShowing then return end
	if self.on then
		self.startButton:Show(false)
		self.stopButton:Show(true)
		self.loggingStateLabel:SetText("On")
	else
		self.startButton:Show(true)
		self.stopButton:Show(false)
		self.loggingStateLabel:SetText("Off")
	end
	self.logRaidsButton:SetCheck(self.logRaids)
	self.logDungeonsButton:SetCheck(self.logDungeons)
	self.fightsCountLabel:SetText(self.fights)
	self.eventsCountLabel:SetText(#self.eventTable - 1)
	self.uploadFightsButton:Enable(#self.eventTable > 1 and not self.forceSaveDisable)
end

---------------------------------------------------------------------------------------------------
-- LoggerWindow Functions
---------------------------------------------------------------------------------------------------

function WildStarLogger:OnStartLoggingPressed(wndHandler, wndControl, eMouseButton)
	self.on = true
	self:UpdateUIState()
end

function WildStarLogger:OnStopLoggingPressed(wndHandler, wndControl, eMouseButton)
	self.on = false
	if self.inCombat then
		self.inCombat = false
		self.fights = self.fights + 1
		self:UpdateInterfaceMenuAlerts()
		self:AttachEventsToFightsButton()
	end
	self:UpdateUIState()
end

function WildStarLogger:OnToggleAlwaysLogRaids(wndHandler, wndControl, eMouseButton)
	self.logRaids = self.logRaidsButton:IsChecked()
end

function WildStarLogger:OnToggleAlwaysLogDungeons(wndHandler, wndControl, eMouseButton)
	self.logDungeons = self.logDungeonsButton:IsChecked()
end

function WildStarLogger:OnSaveDisabledTimer()
	Apollo.StopTimer("WildStarLogger_SaveDisabled")
	self.forceSaveDisable = false
	self:UpdateUIState()
	self:AttachEventsToFightsButton()
end

function WildStarLogger:OnStringCopiedToClipboard(wndHandler, wndControl)
	if not self.AllowCopy then return end
	self.AllowCopy = false
	self.forceSaveDisable = false
	self:ClearTable()
	self:UpdateUIState()
	self:UpdateInterfaceMenuAlerts()
	self:UpdateUIState()
	self:AttachEventsToFightsButton()
	self.wndMain:FindChild("PreSave"):Show(true, true)


end

function WildStarLogger:OnBeforeUploadFights(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
	--self:AttachEventsToFightsButton()
end

function WildStarLogger:OnPreSave( wndHandler, wndControl, eMouseButton )
	self:AttachEventsToFightsButton()
	self.AllowCopy = true
	self.wndMain:FindChild("PreSave"):Show(false, true)
end

-----------------------------------------------------------------------------------------------
-- WildStarLogger Instance
-----------------------------------------------------------------------------------------------
local WildStarLoggerInst = WildStarLogger:new()
WildStarLoggerInst:Init()
