local VT = VT
local L = VT.L
local VTcommsObject = VTcommsObject
local twipe, tinsert = table.wipe, table.insert

local timer
local requestTimer
---LiveSession_Enable
function VT:LiveSession_Enable()
  if self.liveSessionActive then return end
  self.main_frame.LiveSessionButton:SetText(L["*Live*"])
  self.main_frame.LiveSessionButton.text:SetTextColor(0, 1, 0)
  self.main_frame.LinkToChatButton:SetDisabled(true)
  self.main_frame.LinkToChatButton.text:SetTextColor(0.5, 0.5, 0.5)
  self.main_frame.sidePanelDeleteButton:SetDisabled(true)
  self.main_frame.sidePanelDeleteButton.text:SetTextColor(0.5, 0.5, 0.5)
  self.liveSessionActive = true
  --check if there is other clients having live mode active
  self:LiveSession_RequestSession()
  --set id here incase there is no other sessions
  self:SetUniqueID(self:GetCurrentPreset())
  self.livePresetUID = self:GetCurrentPreset().uid
  self:UpdatePresetDropdownTextColor()
  timer = C_Timer.NewTimer(2, function()
    local callback = function()
      self.liveSessionRequested = false
      local distribution = self:IsPlayerInGroup()
      local preset = self:GetCurrentPreset()
      local prefix = "[VTLive: "
      local dungeon = self:GetDungeonName(preset.value.currentDungeonIdx)
      local presetName = preset.text
      local name, realm = UnitFullName("player")
      local fullName = name.."+"..realm
      SendChatMessage(prefix..fullName.." - "..dungeon..": "..presetName.."]", distribution)
    end
    local cancelCallback = function()
      VT:LiveSession_Disable()
    end
    local fireCancelOnClose = true
    VT:CheckPresetSize(callback, cancelCallback, fireCancelOnClose)
  end)
end

---LiveSession_Disable
function VT:LiveSession_Disable()
  local widget = VT.main_frame.LiveSessionButton
  widget.text:SetTextColor(widget.normalTextColor.r, widget.normalTextColor.g, widget.normalTextColor.b)
  widget.text:SetText(L["Live"])
  VT.main_frame.LinkToChatButton:SetDisabled(false)
  self.main_frame.LinkToChatButton.text:SetTextColor(1, 0.8196, 0)
  local db = VT:GetDB()
  if db.presets[db.currentDungeonIdx][1] == VT:GetCurrentPreset() then
    VT.main_frame.sidePanelDeleteButton:SetDisabled(true)
    VT.main_frame.sidePanelDeleteButton.text:SetTextColor(0.5, 0.5, 0.5)
  else
    self.main_frame.sidePanelDeleteButton:SetDisabled(false)
    self.main_frame.sidePanelDeleteButton.text:SetTextColor(1, 0.8196, 0)
  end
  self.liveSessionActive = false
  self.liveSessionAcceptingPreset = false
  self:UpdatePresetDropdownTextColor()
  self.main_frame.liveReturnButton:Hide()
  self.main_frame.setLivePresetButton:Hide()
  if timer then timer:Cancel() end
  self.liveSessionRequested = false
  self.main_frame.SendingStatusBar:Hide()
  if self.main_frame.LoadingSpinner then
    self.main_frame.LoadingSpinner:Hide()
    self.main_frame.LoadingSpinner.Anim:Stop()
  end
end

---Notify specific group member that my live session is active
local lastNotify
function VT:LiveSession_NotifyEnabled()
  local now = GetTime()
  if not lastNotify or lastNotify < now - 0.2 then
    lastNotify = now
    local distribution = self:IsPlayerInGroup()
    if (not distribution) or (not self.liveSessionActive) then return end
    local uid = self.livePresetUID
    VTcommsObject:SendCommMessage(self.liveSessionPrefixes.enabled, uid, distribution, nil, "ALERT")
  end
  --self:SendToGroup(self:IsPlayerInGroup(),true,self:GetCurrentLivePreset())
end

---Send a request to the group to send notify messages for active sessions
function VT:LiveSession_RequestSession()
  local distribution = self:IsPlayerInGroup()
  if (not distribution) or (not self.liveSessionActive) then return end
  self.liveSessionRequested = true
  self.liveSessionActiveSessions = self.liveSessionActiveSessions or {}
  twipe(self.liveSessionActiveSessions)
  VTcommsObject:SendCommMessage(self.liveSessionPrefixes.request, "0", distribution, nil, "ALERT")
end

function VT:LiveSession_SessionFound(fullName, uid)
  local fullNamePlayer, realm = UnitFullName("player")
  fullNamePlayer = fullNamePlayer.."-"..realm

  if (not self.liveSessionAcceptingPreset) and fullNamePlayer ~= fullName then
    if timer then timer:Cancel() end
    self.liveSessionAcceptingPreset = true
    --request the preset from one client only after a short delay
    --we have to delay a bit to catch all active clients
    requestTimer = C_Timer.NewTimer(0.5, function()
      if self.liveSessionActiveSessions[1][1] ~= fullNamePlayer then
        self.main_frame.SendingStatusBar:Show()
        self.main_frame.SendingStatusBar:SetValue(0 / 1)
        self.main_frame.SendingStatusBar.value:SetText(L["Receiving: ..."])
        if not self.main_frame.LoadingSpinner then
          self.main_frame.LoadingSpinner = CreateFrame("Button", "VTLoadingSpinner", self.main_frame,
            "LoadingSpinnerTemplate")
          self.main_frame.LoadingSpinner:SetPoint("CENTER", self.main_frame, "CENTER")
          self.main_frame.LoadingSpinner:SetSize(60, 60)
        end
        self.main_frame.LoadingSpinner:Show()
        self.main_frame.LoadingSpinner.Anim:Play()
        self:UpdatePresetDropdownTextColor(true)

        self.liveSessionRequested = false
        self:LiveSession_RequestPreset(self.liveSessionActiveSessions[1][1])
        self.livePresetUID = self.liveSessionActiveSessions[1][2]
      else
        self.liveSessionAcceptingPreset = false
        self.liveSessionRequested = false
      end
    end)
  end
  --catch clients
  tinsert(self.liveSessionActiveSessions, { fullName, uid })
end

function VT:LiveSession_RequestPreset(fullName)
  local distribution = self:IsPlayerInGroup()
  if (not distribution) or (not self.liveSessionActive) then return end
  VTcommsObject:SendCommMessage(self.liveSessionPrefixes.reqPre, fullName, distribution, nil, "ALERT")
end

---Sends a map ping
function VT:LiveSession_SendPing(x, y, sublevel)
  --only send ping if we are in the livesession preset
  if self:GetCurrentPreset().uid == self.livePresetUID then
    local distribution = self:IsPlayerInGroup()
    if distribution then
      local scale = self:GetScale()
      VTcommsObject:SendCommMessage(self.liveSessionPrefixes.ping, x * (1 / scale)..":"..y * (1 / scale)..
        ":"..sublevel, distribution, nil, "ALERT")
    end
  end
end

---Sends a preset object
function VT:LiveSession_SendObject(obj)
  if self:GetCurrentPreset().uid == self.livePresetUID then
    local distribution = self:IsPlayerInGroup()
    if distribution then
      local export = VT:TableToString(obj, false, 5)
      local silent, fromLiveSession = true, true
      VTcommsObject:SendCommMessage(self.liveSessionPrefixes.obj, export, distribution, nil, "BULK", VT.displaySendingProgress,
        { distribution, nil, silent, fromLiveSession })
    end
  end
end

---Sends updated object offsets (move object)
function VT:LiveSession_SendObjectOffsets(objIdx, x, y)
  if self:GetCurrentPreset().uid == self.livePresetUID then
    local distribution = self:IsPlayerInGroup()
    if distribution then
      VTcommsObject:SendCommMessage(self.liveSessionPrefixes.objOff, objIdx..":"..x..":"..y, distribution, nil,
        "ALERT")
    end
  end
end

---Sends updated objects - instead of sending an update every time we erase a part of an object we send one message after mouse up
function VT:LiveSession_SendUpdatedObjects(changedObjects)
  if self:GetCurrentPreset().uid == self.livePresetUID then
    local distribution = self:IsPlayerInGroup()
    if distribution then
      local export = VT:TableToString(changedObjects, false, 5)
      VTcommsObject:SendCommMessage(self.liveSessionPrefixes.objChg, export, distribution, nil, "ALERT")
    end
  end
end

---Sends various commands: delete all drawings, clear preset, undo, redo
function VT:LiveSession_SendCommand(cmd)
  if self:GetCurrentPreset().uid == self.livePresetUID then
    local distribution = self:IsPlayerInGroup()
    if distribution then
      VTcommsObject:SendCommMessage(self.liveSessionPrefixes.cmd, cmd, distribution, nil, "ALERT")
    end
  end
end

---Sends a note text update
function VT:LiveSession_SendNoteCommand(cmd, noteIdx, text, y)
  if self:GetCurrentPreset().uid == self.livePresetUID then
    local distribution = self:IsPlayerInGroup()
    if distribution then
      text = text..":"..(y or "0")
      VTcommsObject:SendCommMessage(self.liveSessionPrefixes.note, cmd..":"..noteIdx..":"..text, distribution,
        nil, "ALERT")
    end
  end
end

---Sends a new preset to be used as the new live session preset
function VT:LiveSession_SendPreset(preset)
  local distribution = self:IsPlayerInGroup()
  if distribution then
    local db = self:GetDB()
    preset.difficulty = db.currentDifficulty
    local export = VT:TableToString(preset, false, 5)
    local silent, fromLiveSession = true, true
    VTcommsObject:SendCommMessage(self.liveSessionPrefixes.preset, export, distribution, nil, "BULK", VT.displaySendingProgress,
      { distribution, preset, silent, fromLiveSession })
  end
end

---Sends all pulls
function VT:LiveSession_SendPulls(pulls)
  local distribution = self:IsPlayerInGroup()
  if distribution then
    local msg = VT:TableToString(pulls, false, 5)
    VTcommsObject:SendCommMessage(self.liveSessionPrefixes.pull, msg, distribution, nil, "ALERT")
  end
end

---Sends Affix Week Change
function VT:LiveSession_SendAffixWeek(week)
  local distribution = self:IsPlayerInGroup()
  if distribution then
    VTcommsObject:SendCommMessage(self.liveSessionPrefixes.week, week.."", distribution, nil, "ALERT")
  end
end

do
  local colorTimer
  ---LiveSession_QueueColorUpdate
  ---Disgusting workaround for shitty colorpicker
  ---Only send an update once a color of a pull has not changed for 0.2 seconds
  function VT:LiveSession_QueueColorUpdate()
    if colorTimer then colorTimer:Cancel() end
    colorTimer = C_Timer.NewTimer(0.2, function()
      self:LiveSession_SendPulls(self:GetPulls())
    end)
  end
end

---Sends Corrupted NPC Offset Positions
function VT:LiveSession_SendCorruptedPositions(offsets)
  local distribution = self:IsPlayerInGroup()
  if distribution then
    local export = VT:TableToString(offsets, false, 5)
    VTcommsObject:SendCommMessage(self.liveSessionPrefixes.corrupted, export, distribution, nil, "ALERT")
  end
end

---Sends current difficulty
function VT:LiveSession_SendDifficulty()
  local distribution = self:IsPlayerInGroup()
  if distribution then
    local export = self:GetDB().currentDifficulty
    VTcommsObject:SendCommMessage(self.liveSessionPrefixes.difficulty, export.."", distribution, nil, "ALERT")
  end
end

function VT:LiveSession_SendPOIAssignment(sublevel, poiIdx, value)
  local distribution = self:IsPlayerInGroup()
  if distribution then
    local export = VT:TableToString({ sublevel, poiIdx, value }, false, 5)
    VTcommsObject:SendCommMessage(self.liveSessionPrefixes.poiAssignment, export, distribution, nil, "ALERT")
  end
end
