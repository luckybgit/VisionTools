local VT = VT
local AceGUI = LibStub("AceGUI-3.0")
local db
local L = VT.L

-- The idea here is to redo the dungeon select dropdown to be more user friendly.
-- This was necesarry as the old implementation did not allow for a dungeon to be part of multiple dungeon sets.
-- Additional dungeon lists just need to be added to seasonList and dungeonSelectionToIndex.

-- How to find the dungeon map files:
-- Add launch option "-console" to wow
-- Unsync your Config.wtf from wow servers: SET synchronizeConfig "0"
-- Add the following to the Config.wtf: SET ConsoleKey "F10" (or whatever key you want)
-- Go to character selection screen and press your console key
-- Run ExportInterfaceFiles art
-- Open the folder BlizzardInterfaceArt in VSCode and search for the dungeon name
-- To get names of dungeons: https://wow.tools/maps/ (search for dungeon name and then check the url)

VT.seasonList = {}
VT.dungeonSelectionToIndex = {}

do
  tinsert(VT.seasonList, L["The War Within Season 1"])
  tinsert(VT.seasonList, L["The War Within Season 2"])
  tinsert(VT.dungeonSelectionToIndex, { 31, 35, 19, 110, 111, 112, 113, 114 })
  tinsert(VT.dungeonSelectionToIndex, { 115, 116, 117, 118, 119, 120, 121, 122 })
end

local seasonList = VT.seasonList
local dungeonSelectionToIndex = VT.dungeonSelectionToIndex

function VT:GetSeasonList()
  return seasonList
end

local dungeonButtons = {}
local BUTTON_SIZE = 40

function VT:UpdateDungeonSelectHighlight()
  for _, button in ipairs(dungeonButtons) do
    if button.dungeonIdx == db.currentDungeonIdx then
      button.selectedTexture:Show()
    else
      button.selectedTexture:Hide()
    end
  end
end

local formatTime = function(time)
  if time then
    local timeMin = math.floor(time / 60)
    local timeSec = math.floor(time - (timeMin * 60))
    if timeMin < 10 then
      ---@diagnostic disable-next-line: cast-local-type
      timeMin = ("0%d"):format(timeMin)
    end
    if timeSec < 10 then
      ---@diagnostic disable-next-line: cast-local-type
      timeSec = ("0%d"):format(timeSec)
    end
    return ("%s:%s"):format(timeMin, timeSec)
  end
end

function VT:UpdateDungeonDropDown()
  local currentList = dungeonSelectionToIndex[db.selectedDungeonList]
  for idx, dungeonIdx in ipairs(currentList) do
    local button = dungeonButtons[idx]
    if not button then
      dungeonButtons[idx] = CreateFrame("Button", "VTDungeonButton"..idx, VT.main_frame)
      button = dungeonButtons[idx]
      button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
      button:ClearAllPoints()
      button:SetPoint("TOPLEFT", VT.main_frame, "TOPLEFT", (idx - 1) * (BUTTON_SIZE - 1), 0)
      button.texture = button:CreateTexture()
      button.texture:SetAllPoints(button)
      button.texture:Show()
      button.highlightTexture = button:CreateTexture()
      button:SetHighlightTexture(button.highlightTexture)
      button.highlightTexture:SetAtlas("bags-innerglow")
      button.selectedTexture = button:CreateTexture()
      button.selectedTexture:SetAllPoints(button)
      button.selectedTexture:SetAtlas("bags-glow-artifact")
      button.selectedTexture:SetDrawLayer("OVERLAY")
      button.shortText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      button.shortText:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
      button.shortText:SetFont(button.shortText:GetFont(), 11, "OUTLINE")
      button.shortText:SetTextColor(1, 1, 1)
      button:SetScript("OnLeave", function()
        GameTooltip:Hide()
      end)
    end
    local mapInfo = VT.mapInfo[dungeonIdx]
    button.dungeonIdx = dungeonIdx
    button.texture:SetTexture(mapInfo.iconId or C_Spell.GetSpellTexture(mapInfo.teleportId) or 134400)
    button.shortText:SetText(mapInfo.shortName)
    button:SetScript("OnClick", function(self, button)
      VT:UpdateToDungeon(dungeonIdx)
      VT:UpdateDungeonSelectHighlight()
    end)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:Show()
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(50)
    button:SetScript("OnEnter", function()
      local timer
      if mapInfo.mapID then
        timer = select(3, C_ChallengeMode.GetMapUIInfo(mapInfo.mapID))
        -- TODO: this is completely gone in S2
        -- we want to always show the correct timer including the Challenger's Peril affix
        -- add 90s if we are not currently in a key
        -- local activeKeystoneLevel = select(1, C_ChallengeMode.GetActiveKeystoneInfo())
        -- if timer and (not activeKeystoneLevel or activeKeystoneLevel < 7) then
        --   timer = timer + 90
        -- end
      end
      GameTooltip:SetOwner(dungeonButtons[idx], "ANCHOR_BOTTOMRIGHT", -dungeonButtons[idx]:GetWidth(), 0)
      GameTooltip:AddLine(VT.dungeonList[dungeonIdx], 1, 1, 1)
      if timer then
        GameTooltip:AddLine(L["Timer"]..": "..formatTime(timer), 1, 1, 1)
      end
      GameTooltip:Show()
    end)
  end
  VT:UpdateDungeonSelectHighlight()
  for idx = #currentList + 1, #dungeonButtons do
    dungeonButtons[idx]:Hide()
  end

  local currentDungeonIdx = db.currentDungeonIdx
  local sublevels = VT.dungeonSubLevels[currentDungeonIdx]
  local sublevelDropdown = VT.main_frame.sublevelSelectionGroup.sublevelDropdown
  sublevelDropdown:SetList(sublevels)
  sublevelDropdown:SetValue(db.presets[currentDungeonIdx][db.currentPreset[currentDungeonIdx]].value.currentSublevel)
  sublevelDropdown:ClearFocus()
  if #sublevels == 1 then
    sublevelDropdown.frame:Hide()
  else
    sublevelDropdown.frame:Show()
  end
end

--for old maps that need it
function VT:CreateSublevelDropdown(frame)
  db = VT:GetDB()
  frame.sublevelSelectionGroup = AceGUI:Create("SimpleGroup")
  frame.sublevelSelectionGroup.frame:SetParent(frame)
  local group = frame.sublevelSelectionGroup
  group.frame:Hide()
  if not group.frame.SetBackdrop then
    Mixin(group.frame, BackdropTemplateMixin)
  end
  group.frame:SetBackdropColor(unpack(VT.BackdropColor))
  group.frame:SetFrameStrata("HIGH")
  group.frame:SetFrameLevel(50)
  group:SetWidth(204) --idk ace added weird margin on left
  group:SetHeight(50)
  group:SetPoint("TOPLEFT", frame.topPanel, "TOPLEFT", 0, -68)
  group:SetLayout("List")
  VT:FixAceGUIShowHide(group)

  group.sublevelDropdown = AceGUI:Create("Dropdown")
  group.sublevelDropdown.pullout.frame:SetParent(group.sublevelDropdown.frame)
  group.sublevelDropdown.text:SetJustifyH("LEFT")
  group.sublevelDropdown:SetCallback("OnValueChanged", function(widget, callbackName, key)
    db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel = key
    VT:UpdateMap()
  end)
  group:AddChild(group.sublevelDropdown)
end

function VT:SetDungeonList(key, dungeonIdx)
  db = VT:GetDB()
  if dungeonIdx then
    -- find an index, first one should be the correct one
    for listIdx, list in ipairs(VT.dungeonSelectionToIndex) do
      for _, dIdx in ipairs(list) do
        if dungeonIdx == dIdx and key == nil then
          key = listIdx
          break
        end
      end
    end
  end
  if not key then return end
  -- make sure we don't go out of bounds
  -- this probably happens if dropdown is being spammed (?)
  local index = math.min(#dungeonSelectionToIndex, key)
  db.selectedDungeonList = index
  local dropdown = VT.main_frame.seasonSelectionGroup.seasonDropdown
  dropdown:SetValue(index)
end

function VT:CreateSeasonDropdown(frame)
  if #seasonList == 1 then
    -- no dropdown needed
    return
  end
  db = VT:GetDB()
  frame.seasonSelectionGroup = AceGUI:Create("SimpleGroup")
  frame.seasonSelectionGroup.frame:SetParent(frame)
  local group = frame.seasonSelectionGroup
  group.frame:Hide()
  if not group.frame.SetBackdrop then
    Mixin(group.frame, BackdropTemplateMixin)
  end
  group.frame:SetBackdropColor(unpack(VT.BackdropColor))
  group.frame:SetFrameStrata("HIGH")
  group.frame:SetFrameLevel(50)
  group:SetWidth(204) --idk ace added weird margin on left
  group:SetHeight(50)
  group:SetPoint("TOPLEFT", frame.topPanel, "TOPLEFT", 0, 0)
  group:SetLayout("List")
  VT:FixAceGUIShowHide(group)

  group.seasonDropdown = AceGUI:Create("Dropdown")
  group.seasonDropdown.pullout.frame:SetParent(group.seasonDropdown.frame)
  group.seasonDropdown.text:SetJustifyH("LEFT")
  group.seasonDropdown:SetCallback("OnValueChanged", function(widget, callbackName, key)
    VT:SetDungeonList(key)
    VT:UpdateDungeonDropDown()
    local currentList = dungeonSelectionToIndex[db.selectedDungeonList]
    VT:UpdateToDungeon(currentList[1])
  end)
  group:AddChild(group.seasonDropdown)

  group.seasonDropdown:SetList(seasonList)
  group.seasonDropdown:SetValue(db.selectedDungeonList)
end

function VT:CheckSeenDungeonLists()
  db = VT:GetDB()
  local defaultSavedVars = VT:GetDefaultSavedVariables().global
  local latestDungeon = defaultSavedVars.currentDungeonIdx
  local latestSeen = db.latestDungeonSeen
  if latestSeen ~= latestDungeon then
    -- find list
    for listIndex, list in pairs(VT.dungeonSelectionToIndex) do
      for _, dngIdx in pairs(list) do
        if dngIdx == latestDungeon then
          db.latestDungeonSeen = latestDungeon
          db.currentDungeonIdx = latestDungeon
          db.selectedDungeonList = listIndex
          return
        end
      end
    end
  end
end
