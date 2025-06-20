local VT = VT
local db
local tonumber, tinsert, pairs, ipairs, tostring, twipe, max, tremove, DrawLine = tonumber, table.insert, pairs, ipairs,
    tostring, table.wipe, math.max, table.remove, DrawLine
local L = VT.L
local blips = {}
local preset
local selectedGreen = { 34 / 255, 139 / 255, 34 / 255, 0.7 }
local patrolColor = { 0, 0.5, 1, 0.8 }
local corruptedColor = { 1, 0, 1, 0.8 }

function VT:GetDungeonEnemyBlips()
  return blips
end

--From http://wow.gamepedia.com/UI_coordinates
function VT:DoFramesOverlap(frameA, frameB, offset)
  if not frameA or not frameB then return end
  offset = offset or 0
  --frameA = frameA.texture_Background
  --frameB = frameB.texture_Background

  local sA, sB = frameA:GetEffectiveScale(), frameB:GetEffectiveScale();
  if not sA or not sB then return end

  local frameALeft = frameA:GetLeft() - offset
  local frameARight = frameA:GetRight() + offset
  local frameABottom = frameA:GetBottom() - offset
  local frameATop = frameA:GetTop() + offset

  local frameBLeft = frameB:GetLeft()
  local frameBRight = frameB:GetRight()
  local frameBBottom = frameB:GetBottom()
  local frameBTop = frameB:GetTop()

  if not frameALeft or not frameARight or not frameABottom or not frameATop then return end
  if not frameBLeft or not frameBRight or not frameBBottom or not frameBTop then return end

  return ((frameALeft * sA) < (frameBRight * sB))
      and ((frameBLeft * sB) < (frameARight * sA))
      and ((frameABottom * sA) < (frameBTop * sB))
      and ((frameBBottom * sB) < (frameATop * sA));
end

VTDungeonEnemyMixin = {};

local defaultSizes = {
  ["texture_Background"] = 20,
  ["texture_Portrait"] = 15,
  ["texture_MouseHighlight"] = 20,
  ["texture_SelectedHighlight"] = 20,
  ["texture_Reaping"] = 8,
  ["texture_Dragon"] = 26,
  ["texture_Indicator"] = 20,
  ["texture_PullIndicator"] = 23,
  ["texture_DragDown"] = 8,
  ["texture_DragLeft"] = 8,
  ["texture_DragRight"] = 8,
  ["texture_DragUp"] = 8,
  ["shrouded_Indicator"] = 20,
  ["texture_OverlayIcon"] = 12,
}

function VTDungeonEnemyMixin:updateSizes(scale)
  for tex, size in pairs(defaultSizes) do
    self[tex]:SetSize(size * self.normalScale * scale, size * self.normalScale * scale)
  end
end

function VT:DisplayBlipModifierLabels(modifier)
  for _, blip in pairs(blips) do
    blip.textLocked = true
    local text = (modifier == "alt" and blip.clone.g and "G"..blip.clone.g) or (modifier == "ctrl" and blip.data.count) or ""
    blip.fontstring_Text1:SetText(text)
    blip.fontstring_Text1:Show()
  end
end

function VT:HideAllBlipLabels()
  for _, blip in pairs(blips) do
    if not blip.textLocked then return end
    blip.fontstring_Text1:Hide()
    blip.textLocked = nil
  end
end

function VT:SetUpModifiers(frame)
  if VT:GetDB().devMode then return end
  local ONUPDATE_INTERVAL = 0.1
  local timeSinceLastUpdate = 0
  frame:SetScript("OnUpdate", function(self, elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    if timeSinceLastUpdate >= ONUPDATE_INTERVAL then
      timeSinceLastUpdate = 0
      local modifier = (IsAltKeyDown() and "alt") or (IsControlKeyDown() and "ctrl")
      local overVT = MouseIsOver(frame) or MouseIsOver(frame.sidePanel) or MouseIsOver(frame.topPanel) or MouseIsOver(frame.bottomPanel)
      if modifier and overVT then
        VT:DisplayBlipModifierLabels(modifier)
        local statusText = (modifier == "alt" and L["altKeyDownStatusText"]) or (modifier == "ctrl" and L["ctrlKeyDownStatusText"])
        VT.main_frame.statusString:SetText(statusText)
        VT.main_frame.statusString:Show()
      else
        VT:HideAllBlipLabels()
        VT.main_frame.statusString:Hide()
      end
    end
  end)
end

function VTDungeonEnemyMixin:OnEnter()
  self:updateSizes(1.2)
  self:SetFrameLevel(self:GetFrameLevel() + 5)
  self:DisplayPatrol(true)
  VT:DisplayBlipTooltip(self, true)
  if self.data.corrupted then
    --self.texture_DragDown:Show()
    --self.texture_DragLeft:Show()
    --self.texture_DragRight:Show()
    --self.texture_DragUp:Show()
    if not self.selected then
      local active = VT.GetFramePool("VignettePinTemplate").active
      for _, poiFrame in pairs(active) do
        if poiFrame.spireIndex and poiFrame.npcId == self.data.id then
          poiFrame.HighlightTexture:Show()
          self.spireFrame = poiFrame
          self.animatedLine = VT:ShowAnimatedLine(VT.main_frame.mapPanelFrame, self.spireFrame, self, nil, nil, nil,
            nil, nil, self.selected, self.animatedLine)
          self.spireFrame.animatedLine = self.animatedLine
          break
        end
      end
      local connectedDoor = VT:FindConnectedDoor(self.data.id)
      if connectedDoor then
        self.animatedLine = VT:ShowAnimatedLine(VT.main_frame.mapPanelFrame, connectedDoor, self, nil, nil, nil, nil,
          nil, self.selected, self.animatedLine)
      end
    end
  end
  if not db.devMode then
    if self.textLocked then return end
    self.fontstring_Text1:SetText(VT:IsCurrentPresetTeeming() and self.data.teemingCount or self.data.count)
    self.fontstring_Text1:Show()
    if self.clone.g then
      for _, blip in pairs(blips) do
        if blip.clone.g == self.clone.g then
          blip.fontstring_Text1:SetText(VT:IsCurrentPresetTeeming() and blip.data.teemingCount or blip.data.count)
          blip.fontstring_Text1:Show()
        end
      end
    end
  end
end

function VTDungeonEnemyMixin:OnLeave()
  self:updateSizes(1)
  self:SetFrameLevel(self:GetFrameLevel() - 5)
  if db.devMode then
    if not self.devSelected then self:DisplayPatrol(false) end
  else
    self:DisplayPatrol(false)
  end
  VT:DisplayBlipTooltip(self, false)
  if self.data.corrupted then
    self.texture_DragDown:Hide()
    self.texture_DragLeft:Hide()
    self.texture_DragRight:Hide()
    self.texture_DragUp:Hide()
    local active = VT.GetFramePool("VignettePinTemplate").active
    for _, poiFrame in pairs(active) do
      if poiFrame.spireIndex and poiFrame.npcId == self.data.id then
        poiFrame.HighlightTexture:Hide()
        break
      end
    end
    if not self.selected then
      VT:HideAnimatedLine(self.animatedLine)
    end
  end
  if not db.devMode then
    if self.textLocked then return end
    self.fontstring_Text1:Hide()
    if not self.clone.g then return end
    for _, blip in pairs(blips) do
      if blip.clone.g == self.clone.g then
        blip.fontstring_Text1:Hide()
      end
    end
  end
end

local function setUpMouseHandlers(self)
  self:SetScript("OnMouseDown", function(self, button)

  end)
  local tempPulls
  local targetPull
  self:SetScript("OnDragStart", function()
    local x, y, scale
    preset = VT:GetCurrentPreset()
    tempPulls = VT:DeepCopy(preset.value.pulls)
    targetPull = nil
    local _, _, _, blipX, blipY = self:GetPoint()
    self:SetScript("OnUpdate", function()
      local nx, ny = VT:GetCursorPosition()
      if x ~= nx or y ~= ny then
        x, y = nx, ny
        --find closest pull and measure distance
        local pullIdx, centerX, centerY = VT:FindClosestPull(x, y)
        if not centerX then return end
        local distBlip = (centerX - blipX) ^ 2 + (centerY - blipY) ^ 2
        local distCursor = (centerX - x) ^ 2 + (centerY - y) ^ 2
        local isClose = distCursor < 1 / 3 * distBlip or distBlip < 150
        if not isClose then
          targetPull = nil
          VT:DungeonEnemies_AddOrRemoveBlipToCurrentPull(self, false, IsControlKeyDown(), tempPulls, nil, true)
          VT:DungeonEnemies_UpdateSelected(VT:GetCurrentPull(), tempPulls)
        elseif pullIdx ~= targetPull then
          targetPull = pullIdx
          VT:DungeonEnemies_AddOrRemoveBlipToCurrentPull(self, true, IsControlKeyDown(), tempPulls, pullIdx, true)
          VT:DungeonEnemies_UpdateSelected(VT:GetCurrentPull(), tempPulls)
        end
      end
    end)
  end)
  self:SetScript("OnDragStop", function()
    self:SetScript("OnUpdate", nil)
    preset.value.pulls = tempPulls
    VT:DungeonEnemies_UpdateSelected(VT:GetCurrentPull(), tempPulls)
    VT:SetSelectionToPull(targetPull)
    VT:ReloadPullButtons()
    VT:UpdateProgressbar()
    if VT.liveSessionActive and VT:GetCurrentPreset().uid == VT.livePresetUID then
      VT:LiveSession_SendPulls(VT:GetPulls())
    end
  end)
end

local function setUpMouseHandlersAwakened(self, clone, scale, riftOffsets)
  local xOffset, yOffset
  local oldX, oldY
  self:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
      riftOffsets = VT:GetRiftOffsets()
      local x, y = VT:GetCursorPosition()
      local scale = VT:GetScale()
      x = x * (1 / scale)
      y = y * (1 / scale)
      oldX = riftOffsets and riftOffsets[self.data.id] and riftOffsets[self.data.id].x or clone.x
      oldY = riftOffsets and riftOffsets[self.data.id] and riftOffsets[self.data.id].y or clone.y
      xOffset = x - oldX
      yOffset = y - oldY
    end
  end)
  self:SetScript("OnDragStart", function()
    self:StartMoving()
    VT.draggedBlip = self
    local activeDoors = VT.GetFramePool("MapLinkPinTemplate").active
    riftOffsets = VT:GetRiftOffsets()
    self:SetScript("OnUpdate", function()
      for _, poiFrame in pairs(activeDoors) do
        if VT:DoFramesOverlap(self, poiFrame, -10) then
          poiFrame.HighlightTexture:Show()
        else
          poiFrame.HighlightTexture:Hide()
        end
      end
      --reposition animated line
      local x, y = VT:GetCursorPosition()
      local scale = VT:GetScale()
      x = x * (1 / scale)
      y = y * (1 / scale)
      x = x - xOffset
      y = y - yOffset
      if x ~= self.adjustedX or y ~= self.adjustedY then
        local sizex, sizey = VT:GetDefaultMapPanelSize()
        x = x <= 0 and 0 or x >= sizex and sizex or x
        y = y >= 0 and 0 or y <= (-1) * sizey and (-1) * sizey or y
        self.adjustedX = x
        self.adjustedY = y
        local connectedDoor = VT:FindConnectedDoor(self.data.id)
        self.animatedLine = VT:ShowAnimatedLine(VT.main_frame.mapPanelFrame, connectedDoor or self.spireFrame, self,
          nil, nil, nil, nil, nil, self.selected, self.animatedLine)
        riftOffsets[self.data.id] = riftOffsets[self.data.id] or {}
        riftOffsets[self.data.id].x = x
        riftOffsets[self.data.id].y = y
        self:ClearAllPoints()
        self:SetPoint("CENTER", VT.main_frame.mapPanelTile1, "TOPLEFT", x * scale, y * scale)
      end
    end)
  end)
  self:SetScript("OnDragStop", function()
    VT.draggedBlip = nil
    riftOffsets = VT:GetRiftOffsets()
    self:StopMovingOrSizing()
    self:SetScript("OnUpdate", nil)
    self:ClearAllPoints()
    self:SetPoint("CENTER", VT.main_frame.mapPanelTile1, "TOPLEFT", self.adjustedX * scale, self.adjustedY * scale)
    --dragged ontop of door
    --find doors,check overlap,break,swap sublevel,change poi sublevel
    local active = VT.GetFramePool("MapLinkPinTemplate").active
    for _, poiFrame in pairs(active) do
      if VT:DoFramesOverlap(self, poiFrame, -10) then
        riftOffsets[self.data.id].sublevel = poiFrame.target
        riftOffsets[self.data.id].homeSublevel = self.clone.sublevel or 1
        riftOffsets[self.data.id].connections = riftOffsets[self.data.id].connections or {}
        local c = riftOffsets[self.data.id].connections
        local shouldAdd = true
        for idx, value in ipairs(c) do
          if value.source == poiFrame.poi.target then
            tremove(c, idx)
            shouldAdd = false
            break
          end
        end
        if shouldAdd then
          tinsert(c,
            {
              connectionIndex = poiFrame.poi.connectionIndex,
              source = VT:GetCurrentSubLevel() + 0,
              target = poiFrame.poi.target
            })
        end
        if riftOffsets[self.data.id].sublevel == (self.clone.sublevel or 1) then
          riftOffsets[self.data.id].sublevel = nil
          riftOffsets[self.data.id].homeSublevel = nil
        end
        --zoom out
        --move frame
        poiFrame:Click()
        break
      end
    end
    if VT.liveSessionActive and VT:GetCurrentPreset().uid == VT.livePresetUID then
      VT:LiveSession_SendCorruptedPositions(preset.value.riftOffsets)
    end
  end)
end

local iconColors = {
  { 1,   .92, 0,    1 },
  { .98, .57, 0,    1 },
  { .83, .22, .9,   1 },
  { .04, .95, 0,    1 },
  { .7,  .82, .875, 1 },
  { 0,   .71, 1,    1 },
  { 1,   .24, .168, 1 },
  { .98, .98, .98,  1 },
}

local createEnemyContextMenu = function(frame)
  VT:GetCurrentPreset().value.enemyAssignments = VT:GetCurrentPreset().value.enemyAssignments or {}
  local assignments = VT:GetCurrentPreset().value.enemyAssignments
  MenuUtil.CreateContextMenu(VT.main_frame, function(ownerRegion, rootDescription)
    rootDescription:CreateTitle(L[frame.data.name])

    local function IsSelected(data)
      local assignment = assignments[data.enemyIdx] and assignments[data.enemyIdx][data.cloneIdx]
      return assignment and assignment == data.index or false
    end
    local function SetSelected(data)
      assignments[data.enemyIdx] = assignments[data.enemyIdx] or {}
      assignments[data.enemyIdx][data.cloneIdx] = data.index ~= 0 and data.index or nil
      frame:SetUp(frame.data, frame.clone)
      if not db.hasSeenAssignmentWarning then
        VT:OpenConfirmationFrame(450, 150, L["Warning"], L["Okay"], L["assignmentWarning"])
        db.hasSeenAssignmentWarning = true
      end
    end
    local submenu = rootDescription:CreateButton(L["Set Target Marker"], function() end);
    for i = 1, 8 do
      local iconPath = ICON_LIST[i].."16:16:|t"
      local color = CreateColor(unpack(iconColors[i]))
      local iconName = WrapTextInColor(_G["RAID_TARGET_"..i], color)
      submenu:CreateRadio(iconPath.." "..iconName, IsSelected, SetSelected, { enemyIdx = frame.enemyIdx, cloneIdx = frame.cloneIdx, index = i })
    end
    submenu:CreateRadio(L["None"], IsSelected, SetSelected, { enemyIdx = frame.enemyIdx, cloneIdx = frame.cloneIdx, index = 0 })
    submenu:CreateButton(L["Clear all Markers"], function()
      twipe(assignments)
      VT:Async(function()
        VT:DungeonEnemies_UpdateEnemiesAsync()
      end, "ClearAllMarkers")
    end)
    rootDescription:CreateButton(L["Open Enemy Info"], function()
      VT:ShowEnemyInfoFrame(frame)
    end)
  end)
end

function VTDungeonEnemyMixin:OnClick(button, down)
  --always deselect toolbar tool
  VT:UpdateSelectedToolbarTool()
  if button == "LeftButton" then
    if IsShiftKeyDown() and not self.selected then
      local newPullIdx = VT:GetCurrentPull() + 1
      VT:PresetsAddPull(newPullIdx)
      VT:GetCurrentPreset().value.selection = { newPullIdx }
      VT:SetSelectionToPull(newPullIdx)
    end
    VT:DungeonEnemies_AddOrRemoveBlipToCurrentPull(self, not self.selected, IsControlKeyDown())
    VT:DungeonEnemies_UpdateSelected(VT:GetCurrentPull())
    VT:UpdateProgressbar()
    VT:ReloadPullButtons()
    if VT.liveSessionActive and VT:GetCurrentPreset().uid == VT.livePresetUID then
      VT:LiveSession_SendPulls(VT:GetPulls())
    end
    if self.data.corrupted then
      local connectedFrame
      local active = VT.GetFramePool("VignettePinTemplate").active
      for _, poiFrame in pairs(active) do
        if poiFrame.spireIndex and poiFrame.npcId and poiFrame.npcId == self.data.id then
          if self.selected then
            poiFrame.Texture:SetAtlas("poi-rift1")
            poiFrame.Texture:SetSize(17 * poiFrame.poiScale, 17 * poiFrame.poiScale)
            poiFrame.HighlightTexture:SetAtlas("poi-rift1")
            poiFrame.HighlightTexture:SetSize(17 * poiFrame.poiScale, 17 * poiFrame.poiScale)
            poiFrame.isSpire = false
            poiFrame.ShowAnim:Play()
            poiFrame.textString:Show()
          else
            poiFrame.Texture:SetSize(16 * poiFrame.poiScale, 22 * poiFrame.poiScale)
            poiFrame.Texture:SetAtlas("poi-nzothpylon")
            poiFrame.HighlightTexture:SetSize(16, 22 * poiFrame.poiScale, 22, 22 * poiFrame.poiScale)
            poiFrame.HighlightTexture:SetAtlas("poi-nzothpylon")
            poiFrame.isSpire = true
            poiFrame.ShowAnim:Play()
            poiFrame.textString:Hide()
          end
          connectedFrame = poiFrame
          break
        end
      end
      local connectedDoor = VT:FindConnectedDoor(self.data.id)
      connectedFrame = connectedDoor or connectedFrame
      self.animatedLine = VT:ShowAnimatedLine(VT.main_frame.mapPanelFrame, connectedFrame, self, nil, nil, nil, nil,
        nil, self.selected, self.animatedLine)
      connectedFrame.animatedLine = self.animatedLine
      if VT.liveSessionActive and VT:GetCurrentPreset().uid == VT.livePresetUID then
        VT:LiveSession_SendCorruptedPositions(preset.value.riftOffsets)
      end
    end
  elseif button == "RightButton" then
    if db.devMode then
      if IsAltKeyDown() then
        VT.dungeonEnemies[db.currentDungeonIdx][self.enemyIdx].clones[self.cloneIdx] = nil
        self:Hide()
      else
        self.devSelected = (not self.devSelected) or nil
        self:DisplayPatrol(self.devSelected)
        for blipIdx, blip in pairs(blips) do
          if blip ~= self then
            blip.devSelected = nil
          end
          if blip.devSelected then
            blip.texture_Portrait:SetVertexColor(1, 0, 0, 1)
          else
            blip.texture_Portrait:SetVertexColor(1, 1, 1, 1)
          end
        end
      end
      VT:UpdateMap()
    else
      createEnemyContextMenu(self)
    end
  end
end

local patrolPoints = {}
local patrolLines = {}

function VT:GetPatrolBlips()
  return patrolPoints
end

function VTDungeonEnemyMixin:DisplayPatrol(shown)
  local scale = VT:GetScale()

  --Hide all points/line
  for _, point in pairs(patrolPoints) do point:Hide() end
  for _, line in pairs(patrolLines) do line:Hide() end
  if not shown then return end

  if self.clone.patrol then
    local firstWaypointBlip
    local oldWaypointBlip
    for patrolIdx, waypoint in ipairs(self.clone.patrol) do
      patrolPoints[patrolIdx] = patrolPoints[patrolIdx] or
          VT.main_frame.mapPanelFrame:CreateTexture("VTDungeonPatrolPoint"..patrolIdx, "BACKGROUND", nil, 0)


      patrolPoints[patrolIdx]:SetDrawLayer("OVERLAY", 2)
      patrolPoints[patrolIdx]:SetTexture("Interface\\Worldmap\\X_Mark_64Grey")
      patrolPoints[patrolIdx]:SetSize(4 * scale, 4 * scale)
      patrolPoints[patrolIdx]:SetVertexColor(0, 0.2, 0.5, 0.6)
      patrolPoints[patrolIdx]:ClearAllPoints()
      patrolPoints[patrolIdx]:SetPoint("CENTER", VT.main_frame.mapPanelTile1, "TOPLEFT", waypoint.x * scale,
        waypoint.y * scale)
      patrolPoints[patrolIdx].x = waypoint.x
      patrolPoints[patrolIdx].y = waypoint.y
      patrolPoints[patrolIdx]:Show()

      patrolLines[patrolIdx] = patrolLines[patrolIdx] or
          VT.main_frame.mapPanelFrame:CreateTexture("VTDungeonPatrolLine"..patrolIdx, "BACKGROUND", nil, 0)
      patrolLines[patrolIdx]:SetDrawLayer("OVERLAY", 1)
      patrolLines[patrolIdx]:SetTexture("Interface\\AddOns\\VisionTools\\Textures\\Square_White")
      patrolLines[patrolIdx]:SetVertexColor(0, 0.2, 0.5, 0.6)
      patrolLines[patrolIdx]:Show()

      --connect 2 waypoints
      if oldWaypointBlip then
        local _, _, _, startX, startY = patrolPoints[patrolIdx]:GetPoint()
        local _, _, _, endX, endY = oldWaypointBlip:GetPoint()
        DrawLine(patrolLines[patrolIdx], VT.main_frame.mapPanelTile1, startX, startY, endX, endY, 1 * scale, 1,
          "TOPLEFT")
        patrolLines[patrolIdx]:Show()
      else
        firstWaypointBlip = patrolPoints[patrolIdx]
      end
      oldWaypointBlip = patrolPoints[patrolIdx]
    end
    --connect last 2 waypoints
    if firstWaypointBlip and oldWaypointBlip then
      local _, _, _, startX, startY = firstWaypointBlip:GetPoint()
      local _, _, _, endX, endY = oldWaypointBlip:GetPoint()
      DrawLine(patrolLines[1], VT.main_frame.mapPanelTile1, startX, startY, endX, endY, 1 * scale, 1, "TOPLEFT")
      patrolLines[1]:Show()
    end
  else
    --find patrol leader if no patrol
    for _, blip in pairs(blips) do
      if blip:IsShown() and blip.clone.g and self.clone.g then
        if blip.clone.g == self.clone.g and blip.clone.patrol then
          blip:DisplayPatrol(shown)
        end
      end
    end
  end
end

local encryptedIds = { [185685] = true, [185683] = true, [185680] = true }

local ranOnce
function VT:DisplayBlipTooltip(blip, shown)
  if not ranOnce then
    VT.tooltip:ClearAllPoints()
    VT.tooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT")
    VT.tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT")
    VT.tooltip:Show()
    VT.tooltip:Hide()
    ranOnce = true
  end

  local tooltip = VT.tooltip
  local data = blip.data
  if shown then
    --- for some creatures (e.g. encrypted relics) it shows no model; prefer displayId then
    if data.badCreatureModel then
      tooltip.Model:SetDisplayInfo(data.displayId)
    else
      tooltip.Model:SetCreature(data.id)
    end
    if data.modelPosition then
      tooltip.Model:SetPosition(unpack(data.modelPosition))
    else
      tooltip.Model:SetPosition(0, 0, 0)
    end
    tooltip.String:Show()
    tooltip:Show()
  else
    tooltip.String:Hide()
    tooltip:Hide()
    return
  end

  local boss = blip.data.isBoss or false
  local health = VT:CalculateEnemyHealth(boss, data.health, db.currentDifficulty, data.ignoreFortified)
  local group = blip.clone.g and " "..string.format(L["(G %d)"], blip.clone.g) or ""
  --local upstairs = blip.clone.upstairs and CreateTextureMarkup("Interface\\MINIMAP\\MiniMap-PositionArrows", 16, 32, 16, 16, 0, 1, 0, 0.5,0,-50) or ""
  --[[
        function CreateAtlasMarkup(atlasName, height, width, offsetX, offsetY) return ("|A:%s:%d:%d:%d:%d|a"):format( atlasName , height or 0 , width or 0 , offsetX or 0 , offsetY or 0 );end
    ]]
  local occurence = (blip.data.isBoss and "") or blip.cloneIdx

  --remove tormented clones ids
  if blip.data.powers then occurence = "" end

  --remove encrypted clones ids
  if encryptedIds[blip.data.id] then occurence = "" end
  if not L[data.name] then print("VT: Could not find localization for "..data.name) end
  local text = L[data.name]..
      " "..
      occurence..
      group..
      "\n"..
      string.format(L["Level %d %s"], data.level, L[data.creatureType]).." "..data.id..
      "\n"..string.format(L["%s HP"], VT:FormatEnemyHealth(health)).."\n"

  local count = VT:IsCurrentPresetTeeming() and data.teemingCount or data.count
  text = text..L["Forces"]..": "..VT:FormatEnemyForces(count)
  text = text.."\n"..L["Efficiency Score"]..": "..VT:GetEfficiencyScoreString(count, data.health)
  local reapingText
  if reapingText then text = text.."\n"..reapingText end
  text = text.."\n\n["..L["Right click for more info"].."]"
  tooltip.String:SetText(text)

  -- if this mob grants a bonus buff, show it in the tooltip ad-hoc
  if blip.data.bonusSpell then
    local name, _, icon = C_Spell.GetSpellInfo(blip.data.bonusSpell)
    local bonusDesc = C_Spell.GetSpellDescription(blip.data.bonusSpell)
    local bonusIcon = tooltip.bonusIcon or tooltip:CreateTexture(nil, "OVERLAY", nil, 0);
    bonusIcon:SetWidth(54);
    bonusIcon:SetHeight(54);
    bonusIcon:SetTexture(icon)
    bonusIcon:SetPoint("TOPLEFT", tooltip.Model, "BOTTOMLEFT", 8, -8);
    tooltip.bonusIcon = bonusIcon

    local bonusString = tooltip.bonusString or tooltip:CreateFontString("VTToolTipString")
    bonusString:SetFontObject("GameFontNormalSmall")
    bonusString:SetFont(tooltip.String:GetFont(), 10, "")
    bonusString:SetTextColor(1, 1, 1, 1)
    bonusString:SetJustifyH("LEFT")
    bonusString:SetWidth(tooltip:GetWidth())
    bonusString:SetHeight(60)
    bonusString:SetWidth(200)
    bonusString:SetText(bonusDesc and bonusDesc or name)
    bonusString:SetPoint("TOPLEFT", tooltip.bonusIcon, "TOPRIGHT", 8, 3)
    tooltip.bonusString = bonusString

    tooltip.bonusString:Show()
    tooltip.bonusIcon:Show()
    tooltip.mySizes = { x = 290, y = 180 }
  elseif tooltip.bonusIcon then
    tooltip.bonusIcon:Hide()
    tooltip.bonusString:Hide()
    tooltip.mySizes = { x = 290, y = 120 }
  end

  tooltip:ClearAllPoints()
  if db.tooltipInCorner then
    tooltip:SetPoint("BOTTOMRIGHT", VT.main_frame, "BOTTOMRIGHT", 0, 0)
    tooltip:SetPoint("TOPLEFT", VT.main_frame, "BOTTOMRIGHT", -tooltip.mySizes.x, tooltip.mySizes.y)
  else
    --check for bottom clipping
    tooltip:ClearAllPoints()
    tooltip:SetPoint("TOPLEFT", blip, "BOTTOMRIGHT", 30, 0)
    tooltip:SetPoint("BOTTOMRIGHT", blip, "BOTTOMRIGHT", 30 + tooltip.mySizes.x, -tooltip.mySizes.y)
    local bottomOffset = 0
    local rightOffset = 0
    local tooltipBottom = tooltip:GetBottom()
    local mainFrameBottom = VT.main_frame:GetBottom()
    if tooltipBottom < mainFrameBottom then
      bottomOffset = tooltip.mySizes.y
    end
    --right side clipping
    local tooltipRight = tooltip:GetRight()
    local mainFrameRight = VT.main_frame:GetRight()
    if tooltipRight > mainFrameRight then
      rightOffset = -(tooltip.mySizes.x + 60)
    end

    tooltip:SetPoint("TOPLEFT", blip, "BOTTOMRIGHT", 30 + rightOffset, bottomOffset)
    tooltip:SetPoint("BOTTOMRIGHT", blip, "BOTTOMRIGHT", 30 + tooltip.mySizes.x + rightOffset,
      -tooltip.mySizes.y + bottomOffset)
  end
end

function VT:GetEfficiencyScoreString(count, health)
  local totalCount = VT.dungeonTotalCount[db.currentDungeonIdx].normal
  local score = 2.5 * (count / totalCount) * 13000 / (health / 1000000)
  local formattedScore = VT:Round(score, 1)
  local value = score / 10
  --https://stackoverflow.com/a/7947812/17380548
  local colorHex = VT:RGBToHex(math.max(0, math.min(1, 2 * (1 - value))), math.min(1, 2 * value), 0)
  return ("|cFF%s%s|r"):format(colorHex, formattedScore)
end

function VT:GetCurrentDevmodeBlip()
  for blipIdx, blip in pairs(blips) do
    if blip.devSelected then
      return blip
    end
  end
end

--make blip movable in devMode and store new position
local function blipDevModeSetup(blip)
  blip:SetMovable(true)
  blip:RegisterForDrag("LeftButton")

  local groupColors = {
    [1] = { 1, 0, 0, 1 },
    [2] = { 0, 1, 0, 1 },
    [3] = { 0, 0, 1, 1 },
    [4] = { 1, 0, 1, 1 },
    [5] = { 0, 1, 1, 1 },
  }
  local function updateBlipText()
    if db.devModeBlipTextHidden then
      blip.fontstring_Text1:SetText("")
      return
    end
    blip.fontstring_Text1:Show()
    blip.fontstring_Text1:SetText((blip.clone.g or "").."  "..
      WrapTextInColorCode((blip.clone.scale or ""), "ffffffff"))
    if blip.clone.g then blip.fontstring_Text1:SetTextColor(unpack(groupColors[blip.clone.g % 5 + 1])) end
  end
  blip.UpdateBlipText = updateBlipText

  local xOffset, yOffset
  blip:SetScript("OnMouseDown", function()
    local x, y = VT:GetCursorPosition()
    local scale = VT:GetScale()
    x = x * (1 / scale)
    y = y * (1 / scale)
    local nx = VT.dungeonEnemies[db.currentDungeonIdx][blip.enemyIdx].clones[blip.cloneIdx].x
    local ny = VT.dungeonEnemies[db.currentDungeonIdx][blip.enemyIdx].clones[blip.cloneIdx].y
    xOffset = x - nx
    yOffset = y - ny
  end)
  local moveGroup
  blip:SetScript("OnDragStart", function()
    if not db.devModeBlipsMovable then return end
    if IsShiftKeyDown() then
      moveGroup = true
    end
    blip:StartMoving()
  end)
  blip:SetScript("OnDragStop", function()
    if not db.devModeBlipsMovable then return end
    if IsShiftKeyDown() then
      moveGroup = true
    end
    local x, y = VT:GetCursorPosition()
    local scale = VT:GetScale()
    x = x * (1 / scale)
    y = y * (1 / scale)
    x = x - xOffset
    y = y - yOffset
    local deltaX = x - VT.dungeonEnemies[db.currentDungeonIdx][blip.enemyIdx].clones[blip.cloneIdx].x
    local deltaY = y - VT.dungeonEnemies[db.currentDungeonIdx][blip.enemyIdx].clones[blip.cloneIdx].y
    if moveGroup then
      for enemyIdx, data in pairs(VT.dungeonEnemies[db.currentDungeonIdx]) do
        for cloneIdx, clone in pairs(data.clones) do
          if clone.g == blip.clone.g then
            clone.x = clone.x + deltaX
            clone.y = clone.y + deltaY
            --move blip
            local cloneBlip = VT:GetBlip(enemyIdx, cloneIdx)
            if cloneBlip then
              cloneBlip:ClearAllPoints()
              cloneBlip:SetPoint("CENTER", VT.main_frame.mapPanelTile1, "TOPLEFT", clone.x * scale, clone.y * scale)
            end
          end
        end
      end
    end
    blip:StopMovingOrSizing()
    blip:ClearAllPoints()
    blip:SetPoint("CENTER", VT.main_frame.mapPanelTile1, "TOPLEFT", x * scale, y * scale)
    VT.dungeonEnemies[db.currentDungeonIdx][blip.enemyIdx].clones[blip.cloneIdx].x = x
    VT.dungeonEnemies[db.currentDungeonIdx][blip.enemyIdx].clones[blip.cloneIdx].y = y
    moveGroup = nil
  end)
  blip:SetScript("OnMouseWheel", function(self, delta)
    if not db.devModeBlipsScrollable then return end
    -- alt scroll to scale blip and connected blips
    if IsAltKeyDown() then
      if IsShiftKeyDown() then
        -- scale whole sublevel
        for _, data in pairs(VT.dungeonEnemies[db.currentDungeonIdx]) do
          for _, clone in pairs(data.clones) do
            if clone.sublevel == VT:GetCurrentSubLevel() then
              clone.scale = (clone.scale or 1) + delta * 0.1
            end
          end
        end
      elseif IsControlKeyDown() then
        -- only scale this specific blip
        local clone = VT.dungeonEnemies[db.currentDungeonIdx][self.enemyIdx].clones[self.cloneIdx]
        clone.scale = (clone.scale or 1) + delta * 0.1
      else
        -- only scale this blip and it's connected blips
        if blip.clone.g then
          for _, data in pairs(VT.dungeonEnemies[db.currentDungeonIdx]) do
            for _, clone in pairs(data.clones) do
              if clone.g == blip.clone.g then
                clone.scale = (clone.scale or 1) + delta * 0.1
              end
            end
          end
        else
          blip.clone.scale = (blip.clone.scale or 1) + delta * 0.1
        end
      end
      VT:UpdateMap()
    else
      if not blip.clone.g then
        local maxGroup = 0
        for _, data in pairs(VT.dungeonEnemies[db.currentDungeonIdx]) do
          for _, clone in pairs(data.clones) do
            maxGroup = (clone.g and (clone.g > maxGroup)) and clone.g or maxGroup
          end
        end
        if IsControlKeyDown() then
          maxGroup = maxGroup + 1
        end
        blip.clone.g = maxGroup
      else
        local blipGroup = blip.clone.g
        if IsShiftKeyDown() then
          --change group of all connected blips
          for enemyIdx, data in pairs(VT.dungeonEnemies[db.currentDungeonIdx]) do
            for cloneIdx, clone in pairs(data.clones) do
              if clone.g == blipGroup then
                clone.g = blipGroup + delta
                local cloneBlip = VT:GetBlip(enemyIdx, cloneIdx)
                cloneBlip.UpdateBlipText()
              end
            end
          end
        else
          blip.clone.g = blip.clone.g + delta
          updateBlipText()
        end
      end
    end
  end)
  updateBlipText()
end

local emissaryIds = { [155432] = true, [155433] = true, [155434] = true }
local tormentedIds = { [179891] = true, [179892] = true, [179890] = true, [179446] = true }

function VTDungeonEnemyMixin:SetUp(data, clone)
  local scale = VT:GetScale()
  self:ClearAllPoints()
  self:SetPoint("CENTER", VT.main_frame.mapPanelTile1, "TOPLEFT", clone.x * scale, clone.y * scale)
  local cloneScale = clone.scale or 1
  self.normalScale = cloneScale * data.scale * (data.isBoss and 1.7 or 1) *
      (VT.scaleMultiplier[db.currentDungeonIdx] or 1) * scale
  self.normalScale = self.normalScale * 0.6
  self:SetSize(self.normalScale * 13, self.normalScale * 13)
  self:updateSizes(1)
  self.texture_Portrait:SetDesaturated(false)
  local raise = 4
  if not data.corrupted then
    for k, v in pairs(blips) do
      --only check neighboring blips - saves performance on big maps
      if ((clone.x - v.clone.x) ^ 2 + (clone.y - v.clone.y) ^ 2 < 81) and VT:DoFramesOverlap(self, v, 5) then
        raise = max(raise
        , v:GetFrameLevel() + 1)
      end
    end
  end
  self:SetFrameLevel(raise)
  self.fontstring_Text1:SetFontObject("GameFontNormal")
  local textScale = math.max(0.2, self.normalScale * 10)
  self.fontstring_Text1:SetFont(self.fontstring_Text1:GetFont(), textScale, "OUTLINE", "")
  self.fontstring_Text1:SetText((clone.isBoss and data.count == 0 and "") or data.count)
  self.texture_MouseHighlight:SetAlpha(0.4)
  if data.isBoss then self.texture_Dragon:Show() else self.texture_Dragon:Hide() end
  self.texture_Background:SetVertexColor(1, 1, 1, 1)
  if clone.patrol then self.texture_Background:SetVertexColor(unpack(patrolColor)) end
  self.data = data
  self.clone = clone
  self:Show()
  self:SetScript("OnUpdate", nil)
  self:SetMovable(false)
  --awakened/corrupted adjustments: movable and color and stored position
  if data.corrupted then
    self:SetFrameLevel(15)
    self.texture_Background:SetVertexColor(unpack(corruptedColor))
    self.texture_DragLeft:SetRotation(-1.5708)
    self.texture_DragRight:SetRotation(1.5708)
    self.texture_DragUp:SetRotation(3.14159)
    local riftOffsets = VT:GetRiftOffsets()
    self.adjustedX = riftOffsets and riftOffsets[self.data.id] and riftOffsets[self.data.id].x or clone.x
    self.adjustedY = riftOffsets and riftOffsets[self.data.id] and riftOffsets[self.data.id].y or clone.y
    self:ClearAllPoints()
    self:SetPoint("CENTER", VT.main_frame.mapPanelTile1, "TOPLEFT", self.adjustedX * scale, self.adjustedY * scale)
    self:SetMovable(true)
    self.animatedLine = nil
    setUpMouseHandlersAwakened(self, clone, scale, riftOffsets)
    self:Hide()
  else
    setUpMouseHandlers(self)
  end
  --tormented visual
  if data.powers then
    local tormentedColor = { 0.7, 0, 1, 1 }
    self.texture_Background:SetVertexColor(unpack(tormentedColor))
  end
  if emissaryIds[self.data.id] then self:Hide() end --hide beguiling emissaries by default
  tinsert(blips, self)
  if db.enemyStyle == 2 then
    self.texture_Portrait:SetTexture("Interface\\Worldmap\\WorldMapPartyIcon")
  else
    if data.iconTexture then
      SetPortraitToTexture(self.texture_Portrait, data.iconTexture);
    else
      SetPortraitTextureFromCreatureDisplayID(self.texture_Portrait, data.displayId or 39490)
    end
  end
  self.texture_Indicator:Hide()
  self.shrouded_Indicator:Hide()
  local assignments = VT:GetCurrentPreset().value.enemyAssignments
  local assignment = assignments and assignments[self.enemyIdx] and assignments[self.enemyIdx][self.cloneIdx]
  if assignment then
    self.texture_OverlayIcon:Show()
    if assignment >= 1 and assignment <= 8 then
      self.texture_OverlayIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..assignment)
    else
      --TODO: other pre set icons, sheep, sap etc they will have specific indexes
    end
  else
    self.texture_OverlayIcon:Hide()
  end
  if db.devMode then blipDevModeSetup(self) end
end

---DungeonEnemies_IsAnyBlipMoving
function VT:DungeonEnemies_IsAnyBlipMoving()
  local isAnyMoving
  for blipIdx, blip in pairs(blips) do
    if blip:IsDragging() then
      isAnyMoving = true
      break
    end
  end
  return isAnyMoving
end

---DungeonEnemies_HideAllBlips
---Used to hide blips during scaling changes to the map
function VT:DungeonEnemies_HideAllBlips()
  VT.dungeonEnemies_framePool:ReleaseAll()
end

function VT:DungeonEnemies_UpdateEnemiesAsync()
  VT.dungeonEnemies_framePool:ReleaseAll()
  coroutine.yield()
  twipe(blips)
  if not db then db = VT:GetDB() end
  local enemies = VT.dungeonEnemies[db.currentDungeonIdx]
  if not enemies then return end
  preset = VT:GetCurrentPreset()

  local riftOffsets = VT:GetRiftOffsets()
  local currentSublevel = VT:GetCurrentSubLevel()

  for enemyIdx, data in pairs(enemies) do
    for cloneIdx, clone in pairs(data["clones"]) do
      --check sublevel
      if clone.sublevel == currentSublevel or (not clone.sublevel) then
        --skip rifts that were dragged to another sublevel
        if not (data.corrupted and riftOffsets and riftOffsets[data.id] and riftOffsets[data.id].sublevel) then
          local blip = VT.dungeonEnemies_framePool:Acquire()
          blip.enemyIdx = enemyIdx
          blip.cloneIdx = cloneIdx
          blip:SetUp(data, clone)
          coroutine.yield()
        end
      end
    end
  end
  --add blips that were dragged to a different sublevel
  if riftOffsets then
    for npcId, offsetData in pairs(riftOffsets) do
      if offsetData and offsetData.sublevel and offsetData.homeSublevel and offsetData.sublevel == currentSublevel then
        for enemyIdx, data in pairs(enemies) do
          if data.id == npcId then
            for cloneIdx, clone in pairs(data["clones"]) do
              local blip = VT.dungeonEnemies_framePool:Acquire("VTDungeonEnemyTemplate")
              blip:SetUp(data, clone)
              blip.enemyIdx = enemyIdx
              blip.cloneIdx = cloneIdx
              coroutine.yield()
            end
          end
        end
      end
    end
  end
end

function VT:DungeonEnemies_CreateFramePools()
  db = self:GetDB()
  VT.dungeonEnemies_framePool = VT.CreateFramePool("Button", VT.main_frame.mapPanelFrame, "VTDungeonEnemyTemplate")
end

function VT:FindPullOfBlip(blip)
  local preset = VT:GetCurrentPreset()
  local pulls = preset.value.pulls or {}

  for pullIdx, pull in ipairs(pulls) do
    if pull[blip.enemyIdx] then
      for storageIdx, cloneIdx in ipairs(pull[blip.enemyIdx]) do
        if cloneIdx == blip.cloneIdx then
          return pullIdx
        end
      end
    end
  end
end

function VT:GetBlip(enemyIdx, cloneIdx)
  for blipIdx, blip in pairs(blips) do
    if blip.enemyIdx == enemyIdx and blip.cloneIdx == cloneIdx then
      return blip
    end
  end
end

local function isCloneConstrained(clone)
  if not clone.constrained then return false end
  local amount = 0
  local data = VT.dungeonEnemies[db.currentDungeonIdx]
  for enemyIdx, enemy in pairs(data) do
    for cloneIdx, c in pairs(enemy.clones) do
      if c.constrained and c.constrained.index == clone.constrained.index and VT:IsCloneInPulls(enemyIdx, cloneIdx) then
        amount = amount + 1
      end
    end
  end
  if amount >= clone.constrained.amount then
    print(L["VT: Cannot add enemy - you are trying to add too many enemies of the same kind"])
    return true
  end
  return false
end

---DungeonEnemies_AddOrRemoveBlipToCurrentPull
---Adds or removes an enemy clone and all it's linked npcs to the currently selected pull
function VT:DungeonEnemies_AddOrRemoveBlipToCurrentPull(blip, add, ignoreGrouped, pulls, pull, ignoreUpdates)
  local preset = self:GetCurrentPreset()
  local enemyIdx = blip.enemyIdx
  local cloneIdx = blip.cloneIdx
  pull = pull or preset.value.currentPull
  pulls = pulls or preset.value.pulls or {}
  pulls[pull] = pulls[pull] or {}
  pulls[pull][enemyIdx] = pulls[pull][enemyIdx] or {}
  --remove clone from all other pulls first
  for pullIdx, p in pairs(pulls) do
    if pullIdx ~= pull and p[enemyIdx] then
      for k, v in pairs(p[enemyIdx]) do
        if v == cloneIdx then
          tremove(pulls[pullIdx][enemyIdx], k)
        end
      end
    end
    -- if not ignoreUpdates then self:UpdatePullButtonNPCData(pullIdx) end
  end
  if add then
    if isCloneConstrained(blip.clone) then return end
    if blip then blip.selected = true end
    local found = false
    for _, v in pairs(pulls[pull][enemyIdx]) do
      if v == cloneIdx then found = true end
    end
    if found == false and blip:IsEnabled() then
      tinsert(pulls[pull][enemyIdx], cloneIdx)
    end
  else
    blip.selected = false
    for k, v in pairs(pulls[pull][enemyIdx]) do
      if v == cloneIdx then
        tremove(pulls[pull][enemyIdx], k)
      end
    end
  end
  --linked npcs
  if not ignoreGrouped then
    for idx, otherBlip in pairs(blips) do
      if blip.clone.g and otherBlip.clone.g == blip.clone.g and blip ~= otherBlip then
        self:DungeonEnemies_AddOrRemoveBlipToCurrentPull(otherBlip, add, true, pulls, pull, ignoreUpdates)
      end
    end
  end
  -- if not ignoreUpdates then self:UpdatePullButtonNPCData(pull) end
end

---DungeonEnemies_UpdateBlipColors
---Updates the colors of all selected blips of the specified pull
function VT:DungeonEnemies_UpdateBlipColors(pull, r, g, b, pulls)
  local week = preset.week
  local isInspiring = VT:IsWeekInspiring(week)
  pulls = pulls or preset.value.pulls
  local p = pulls[pull]
  if not p then return end
  for enemyIdx, clones in pairs(p) do
    if tonumber(enemyIdx) then
      for _, cloneIdx in pairs(clones) do
        for _, blip in pairs(blips) do
          if (blip.enemyIdx == enemyIdx) and (blip.cloneIdx == cloneIdx) then
            if not db.devMode then
              if db.enemyStyle == 2 then
                blip.texture_Portrait:SetVertexColor(r, g, b, 1)
              elseif (not blip.data.corrupted) then
                blip.texture_Portrait:SetVertexColor(r, g, b, 1)
                blip.texture_SelectedHighlight:SetVertexColor(r, g, b, 0.7)
              end
            end
            break
          end
        end
      end
    end
  end
end

---Updates the selected Enemies on the map and marks them according to their pull color
function VT:DungeonEnemies_UpdateSelected(pull, pulls, ignoreHulls)
  preset = VT:GetCurrentPreset()
  pulls = pulls or preset.value.pulls
  local week = preset.week
  local isInspiring = VT:IsWeekInspiring(week)
  --deselect all
  for _, blip in pairs(blips) do
    blip.texture_SelectedHighlight:Hide()
    blip.selected = false
    blip.texture_PullIndicator:Hide()
    if not db.devMode then
      if db.enemyStyle == 2 then
        blip.texture_Portrait:SetVertexColor(1, 1, 1, 1)
      else
        if blip.data.corrupted then
          blip.texture_Background:SetVertexColor(unpack(corruptedColor))
          blip.texture_Portrait:SetVertexColor(1, 1, 1, 1)
          SetPortraitTextureFromCreatureDisplayID(blip.texture_Portrait, blip.data.displayId or 39490)
        else
          blip.texture_Portrait:SetVertexColor(1, 1, 1, 1)
        end
      end
    end
  end
  --highlight all pull enemies
  for pullIdx, p in pairs(pulls) do
    local r, g, b = VT:DungeonEnemies_GetPullColor(pullIdx)
    for enemyIdx, clones in pairs(p) do
      if tonumber(enemyIdx) then
        for _, cloneIdx in pairs(clones) do
          for _, blip in pairs(blips) do
            if (blip.enemyIdx == enemyIdx) and (blip.cloneIdx == cloneIdx) then
              blip.texture_SelectedHighlight:Show()
              blip.selected = true
              if not db.devMode then
                if db.enemyStyle == 2 then
                  blip.texture_Portrait:SetVertexColor(0, 1, 0, 1)
                else
                  if blip.data.corrupted then
                    blip.texture_Portrait:SetAtlas("poi-rift1")
                    blip.texture_Background:SetVertexColor(0.5, 1, 0.1, 1)
                    blip.texture_SelectedHighlight:Hide()
                  else
                    if blip.clone.inspiring and isInspiring then
                      ---@diagnostic disable-next-line: param-type-mismatch
                      SetPortraitToTexture(blip.texture_Portrait, 135946);
                    end
                    blip.texture_Portrait:SetVertexColor(r, g, b, 1)
                    blip.texture_SelectedHighlight:SetVertexColor(r, g, b, 0.7)
                  end
                end
              end
              if pullIdx == pull then
                blip.texture_PullIndicator:Show()
              end
              break
            end
          end
        end
      end
    end
  end
  -- if not ignoreHulls then VT:DrawAllHulls(pulls) end
end

---DungeonEnemies_SetPullColor
---Sets a custom color for a pull
function VT:DungeonEnemies_SetPullColor(pull, r, g, b)
  preset = VT:GetCurrentPreset()
  if not preset.value.pulls[pull] then return end
  preset.value.pulls[pull]["color"] = VT:RGBToHex(r, g, b)
end

---DungeonEnemies_GetPullColor
---Returns the custom color for a pull
function VT:DungeonEnemies_GetPullColor(pull, pulls)
  pulls = pulls or preset.value.pulls
  local r, g, b = VT:HexToRGB(pulls[pull]["color"])
  if not r then
    r, g, b = VT:HexToRGB(db.defaultColor)
    VT:DungeonEnemies_SetPullColor(pull, r, g, b)
  end
  return r, g, b
end

function VT:IsNPCInPulls(poi)
  local week = self:GetEffectivePresetWeek()
  local data = self.dungeonEnemies[db.currentDungeonIdx]
  for enemyIdx, enemy in pairs(data) do
    if enemy.id == poi.npcId then
      local included = false
      for cloneIdx, clone in pairs(enemy.clones) do
        if clone.week[week] then
          return VT:IsCloneInPulls(enemyIdx, cloneIdx)
        end
      end
    end
  end
end

function VT:IsCloneInPulls(enemyIdx, cloneIdx)
  local pulls = VT:GetCurrentPreset().value.pulls
  local numClones = 0
  for _, pull in pairs(pulls) do
    if pull[enemyIdx] then
      if cloneIdx then
        for _, pullCloneIndex in pairs(pull[enemyIdx]) do
          if pullCloneIndex == cloneIdx then return true end
        end
      else
        for _, pullCloneIndex in pairs(pull[enemyIdx]) do
          numClones = numClones + 1
        end
      end
    end
  end
  return numClones > 0
end

---tries to retrieve npc name by npcId
---only looks for npcs in the current dungeon
function VT:GetNPCNameById(npcId)
  local data = VT.dungeonEnemies[db.currentDungeonIdx]
  if data then
    for _, enemy in pairs(data) do
      if enemy.id == npcId then
        return enemy.name
      end
    end
  end
end

---updates the enemy tables with new count and teemingCount or displayId values
---data is retrieved with the the get_count.py or get_displayids python script
---data needs to afterwards be exported manually for every dungeon
function VT:UpdateDungeonData(dungeonData)
  local function printDungeonName(shouldPrint, dungeonIdx)
    if shouldPrint then
      print("-----", VT:GetDungeonName(dungeonIdx))
    end
    return false
  end

  for dungeonIdx, newData in pairs(dungeonData) do
    --dungeon total count changes
    local totalCount = VT.dungeonTotalCount[dungeonIdx]
    if newData[0] and (newData[0].count ~= totalCount.normal or newData[0].teeming_count ~= totalCount.teeming) then
      print("TOTAL ", totalCount.normal, totalCount.teeming, ">>>", newData[0].count, newData[0].teeming_count)
      totalCount.normal = newData[0].count
      totalCount.teeming = newData[0].teeming_count
    end

    --enemy changes
    local shouldPrintDungeonName = true
    local enemyData = VT.dungeonEnemies[dungeonIdx]
    if enemyData then
      for _, enemy in pairs(enemyData) do
        --ignore enchanted emissary (gives count but can almost never pull it off, keep 0 to keep it simple)
        --ignore spark channeler, always gives 11 count but data says 6
        if newData[enemy.id] and (enemy.id ~= 155432 and enemy.id ~= 139110) then
          if newData[enemy.id].count then
            --normal count changes
            if newData[enemy.id].count ~= enemy.count then
              shouldPrintDungeonName = printDungeonName(shouldPrintDungeonName, dungeonIdx)
              print(enemy.name, enemy.id, enemy.count, ">>>", newData[enemy.id].count)
              enemy.count = newData[enemy.id].count
            end

            --teeming count changes
            if newData[enemy.id].count ~= newData[enemy.id].teeming_count
                and (newData[enemy.id].count ~= enemy.count or newData[enemy.id].teeming_count ~= enemy.teemingCount)
            then
              shouldPrintDungeonName = printDungeonName(shouldPrintDungeonName, dungeonIdx)
              print("TEEMING ", enemy.name, enemy.id, newData[enemy.id].count, "||", newData[enemy.id].teeming_count)
              enemy.count = newData[enemy.id].count
              enemy.teemingCount = newData[enemy.id].teeming_count
            end
          end

          --displayId changes
          if newData[enemy.id].displayId and newData[enemy.id].displayId ~= enemy.displayId then
            shouldPrintDungeonName = printDungeonName(shouldPrintDungeonName, dungeonIdx)
            print("DISPLAYID ", enemy.name, enemy.id, enemy.displayId, ">>>", newData[enemy.id].displayId)
            enemy.displayId = newData[enemy.id].displayId
          end
        end
      end
    end
  end
end

---exports all ids of npcs that do not have a displayId associated to them
--dungeons = [
--Dungeon(name='AtalDazar', idx=15, npcIds=[134739, 161241, 136347]),
--    Dungeon(name='RandomDungeon', idx=14, npcIds=[161241, 134739, 136347]),
--]
function VT:ExportNPCIdsWithoutDisplayIds()
  local output = "dungeons = [\n"
  for idx = 15, VT:GetNumDungeons() do
    local shouldAddDungeonText = true
    local enemyData = VT.dungeonEnemies[idx]
    if enemyData then
      for _, enemy in pairs(enemyData) do
        if not enemy.displayId then
          if shouldAddDungeonText then
            output = output.."Dungeon(name='"..VT:GetDungeonName(idx).."', idx="..idx..", npcIds=["
            shouldAddDungeonText = false
          end
          output = output..enemy.id..", "
        end
      end
      if not shouldAddDungeonText then output = output.."]),\n" end
    end
  end
  output = output.."]"
  VT:HideAllDialogs()
  VT.main_frame.ExportFrame:Show()
  VT.main_frame.ExportFrame:ClearAllPoints()
  VT.main_frame.ExportFrame:SetPoint("CENTER", VT.main_frame, "CENTER", 0, 50)
  VT.main_frame.ExportFrameEditbox:SetText(output)
  VT.main_frame.ExportFrameEditbox:HighlightText(0, string.len(output))
  VT.main_frame.ExportFrameEditbox:SetFocus()
  VT.main_frame.ExportFrameEditbox:SetLabel("NPC ids without displayId")
end

local function ArrayRemove(t, fnKeep)
  local j, n = 1, #t;

  for i = 1, n do
    if (fnKeep(t, i, j)) then
      -- Move i's kept value to j's position, if it's not already there.
      if (i ~= j) then
        t[j] = t[i];
        t[i] = nil;
      end
      j = j + 1; -- Increment position of where we'll place the next kept value.
    else
      t[i] = nil;
    end
  end

  return t;
end

---removes enemies of the current dungeon without any clones
function VT:CleanEnemyData(dungeonIdx)
  local enemies = VT.dungeonEnemies[dungeonIdx]
  ArrayRemove(enemies, function(t, i, j)
    local countClones = 0
    for _, _ in pairs(t[i].clones) do
      countClones = countClones + 1
    end
    return countClones > 0
  end)
end
