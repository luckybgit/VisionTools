local AddonName, VT = ...
local L = VT.L
local Compresser = LibStub:GetLibrary("LibCompress")
local Encoder = Compresser:GetAddonEncodeTable()
local Serializer = LibStub:GetLibrary("AceSerializer-3.0")
local LibDeflate = LibStub:GetLibrary("LibDeflate")
local configForDeflate = {
  [1] = { level = 1 },
  [2] = { level = 2 },
  [3] = { level = 3 },
  [4] = { level = 4 },
  [5] = { level = 5 },
  [6] = { level = 6 },
  [7] = { level = 7 },
  [8] = { level = 8 },
  [9] = { level = 9 },
}
VTcommsObject = LibStub("AceAddon-3.0"):NewAddon("VTCommsObject", "AceComm-3.0", "AceSerializer-3.0")
local numActiveTransmissions = 0

-- Lua APIs
local string_char, tremove, tinsert = string.char, table.remove, table.insert
local pairs, type, unpack = pairs, type, unpack
local bit_band, bit_lshift, bit_rshift = bit.band, bit.lshift, bit.rshift

--Based on code from WeakAuras2, all credit goes to the authors
local bytetoB64 = {
  [0] = "a",
  "b",
  "c",
  "d",
  "e",
  "f",
  "g",
  "h",
  "i",
  "j",
  "k",
  "l",
  "m",
  "n",
  "o",
  "p",
  "q",
  "r",
  "s",
  "t",
  "u",
  "v",
  "w",
  "x",
  "y",
  "z",
  "A",
  "B",
  "C",
  "D",
  "E",
  "F",
  "G",
  "H",
  "I",
  "J",
  "K",
  "L",
  "M",
  "N",
  "O",
  "P",
  "Q",
  "R",
  "S",
  "T",
  "U",
  "V",
  "W",
  "X",
  "Y",
  "Z",
  "0",
  "1",
  "2",
  "3",
  "4",
  "5",
  "6",
  "7",
  "8",
  "9",
  "(",
  ")"
}

local B64tobyte = {
  a = 0,
  b = 1,
  c = 2,
  d = 3,
  e = 4,
  f = 5,
  g = 6,
  h = 7,
  i = 8,
  j = 9,
  k = 10,
  l = 11,
  m = 12,
  n = 13,
  o = 14,
  p = 15,
  q = 16,
  r = 17,
  s = 18,
  t = 19,
  u = 20,
  v = 21,
  w = 22,
  x = 23,
  y = 24,
  z = 25,
  A = 26,
  B = 27,
  C = 28,
  D = 29,
  E = 30,
  F = 31,
  G = 32,
  H = 33,
  I = 34,
  J = 35,
  K = 36,
  L = 37,
  M = 38,
  N = 39,
  O = 40,
  P = 41,
  Q = 42,
  R = 43,
  S = 44,
  T = 45,
  U = 46,
  V = 47,
  W = 48,
  X = 49,
  Y = 50,
  Z = 51,
  ["0"] = 52,
  ["1"] = 53,
  ["2"] = 54,
  ["3"] = 55,
  ["4"] = 56,
  ["5"] = 57,
  ["6"] = 58,
  ["7"] = 59,
  ["8"] = 60,
  ["9"] = 61,
  ["("] = 62,
  [")"] = 63
}

-- This code is based on the Encode7Bit algorithm from LibCompress
-- Credit goes to Galmok (galmok@gmail.com)
local decodeB64Table = {}

local function decodeB64(str)
  local bit8 = decodeB64Table
  local decoded_size = 0
  local ch
  local i = 1
  local bitfield_len = 0
  local bitfield = 0
  local l = #str
  while true do
    if bitfield_len >= 8 then
      decoded_size = decoded_size + 1
      bit8[decoded_size] = string_char(bit_band(bitfield, 255))
      bitfield = bit_rshift(bitfield, 8)
      bitfield_len = bitfield_len - 8
    end
    ch = B64tobyte[str:sub(i, i)]
    bitfield = bitfield + bit_lshift(ch or 0, bitfield_len)
    bitfield_len = bitfield_len + 6
    if i > l then
      break
    end
    i = i + 1
  end
  return table.concat(bit8, "", 1, decoded_size)
end

function VT:TableToString(inTable, forChat, level)
  local serialized = Serializer:Serialize(inTable)
  local compressed = LibDeflate:CompressDeflate(serialized, configForDeflate[level])
  -- prepend with "!" so that we know that it is not a legacy compression
  -- also this way, old versions will error out due to the "bad" encoding
  local encoded = "!"
  if (forChat) then
    encoded = encoded..LibDeflate:EncodeForPrint(compressed)
  else
    encoded = encoded..LibDeflate:EncodeForWoWAddonChannel(compressed)
  end
  return encoded
end

function VT:StringToTable(inString, fromChat)
  -- if gsub strips off a ! at the beginning then we know that this is not a legacy encoding
  local encoded, usesDeflate = inString:gsub("^%!", "")
  local decoded
  if (fromChat) then
    if usesDeflate == 1 then
      decoded = LibDeflate:DecodeForPrint(encoded)
    else
      decoded = decodeB64(encoded)
    end
  else
    decoded = LibDeflate:DecodeForWoWAddonChannel(encoded)
  end

  if not decoded then
    return "Error decoding."
  end

  local decompressed, errorMsg = nil, "unknown compression method"
  if usesDeflate == 1 then
    decompressed = LibDeflate:DecompressDeflate(decoded)
  else
    decompressed, errorMsg = Compresser:Decompress(decoded)
  end
  if not (decompressed) then
    return "Error decompressing: "..errorMsg
  end

  local success, deserialized = Serializer:Deserialize(decompressed)
  if not (success) then
    return "Error deserializing "..deserialized
  end
  return deserialized
end

local checkChatframeInteractive
do
  local lastPrintTime = 0
  checkChatframeInteractive = function(chatFrame)
    if chatFrame and chatFrame.isUninteractable then
      local currentTime = GetTime()
      if currentTime - lastPrintTime >= 5 * 60 then
        C_Timer.After(0.2, function()
          print("VT: |cFFFF0000Warning!|r "..L["chatNoninteractiveWarning"])
        end)
        lastPrintTime = currentTime
      end
    end
  end
end

local function filterFunc(chatFrame, event, msg, player, l, cs, t, flag, channelId, ...)
  if flag == "GM" or flag == "DEV" or (event == "CHAT_MSG_CHANNEL" and type(channelId) == "number" and channelId > 0) then
    return
  end
  local newMsg = ""
  local remaining = msg
  local done
  repeat
    local start, finish, characterName, displayName = remaining:find("%[VT_v2: ([^%s]+) %- ([^%]]+)%]")
    local startLive, finishLive, characterNameLive, displayNameLive = remaining:find("%[VTLive: ([^%s]+) %- ([^%]]+)%]")
    if (characterName and displayName) then
      characterName = characterName:gsub("|c[Ff][Ff]......", ""):gsub("|r", "")
      displayName = displayName:gsub("|c[Ff][Ff]......", ""):gsub("|r", "")
      newMsg = newMsg..remaining:sub(1, start - 1)
      local texture = "|TInterface\\AddOns\\"..AddonName.."\\Textures\\NnoggieMinimap:12|t"
      newMsg = "|cffe6cc80|Hgarrmission:VT-"..characterName.."|h["..displayName.."]|h|r"
      remaining = remaining:sub(finish + 1)
      checkChatframeInteractive(chatFrame)
    elseif (characterNameLive and displayNameLive) then
      characterNameLive = characterNameLive:gsub("|c[Ff][Ff]......", ""):gsub("|r", "")
      displayNameLive = displayNameLive:gsub("|c[Ff][Ff]......", ""):gsub("|r", "")
      newMsg = newMsg..remaining:sub(1, startLive - 1)
      newMsg = newMsg..
          "|Hgarrmission:VTlive-"..
          characterNameLive.."|h[".."|cFF00FF00Live Session: |cffe6cc80"..""..displayNameLive.."]|h|r"
      remaining = remaining:sub(finishLive + 1)
      checkChatframeInteractive(chatFrame)
    else
      done = true
    end
  until (done)
  if newMsg ~= "" then
    return false, newMsg, player, l, cs, t, flag, channelId, ...
  end
end

local presetCommPrefix = "VTPreset"

VT.liveSessionPrefixes = {
  ["enabled"] = "VTLiveEnabled",
  ["request"] = "VTLiveReq",
  ["ping"] = "VTLivePing",
  ["obj"] = "VTLiveObj",
  ["objOff"] = "VTLiveObjOff",
  ["objChg"] = "VTLiveObjChg",
  ["cmd"] = "VTLiveCmd",
  ["note"] = "VTLiveNote",
  ["preset"] = "VTLivePreset",
  ["pull"] = "VTLivePull",
  ["week"] = "VTLiveWeek",
  ["free"] = "VTLiveFree",
  ["bora"] = "VTLiveBora",
  ["reqPre"] = "VTLiveReqPre",
  ["corrupted"] = "VTLiveCor",
  ["difficulty"] = "VTLiveLvl",
  ["poiAssignment"] = "VTPOIAssignment",
}

VT.dataCollectionPrefixes = {
  ["request"] = "VTDataReq",
  ["distribute"] = "VTDataDist",
}

---@diagnostic disable-next-line: duplicate-set-field
function VTcommsObject:OnEnable()
  self:RegisterComm(presetCommPrefix)
  for _, prefix in pairs(VT.liveSessionPrefixes) do
    self:RegisterComm(prefix)
  end
  for _, prefix in pairs(VT.dataCollectionPrefixes) do
    self:RegisterComm(prefix)
  end
  VT.transmissionCache = {}
  ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", filterFunc)
  ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", filterFunc)
  ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", filterFunc)
  ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", filterFunc)
end

--handle preset chat link clicks
hooksecurefunc("SetItemRef", function(link, text)
  if (link and link:sub(0, 19) == "garrmission:VTlive") then
    local sender = link:sub(21, string.len(link))
    local name, realm = string.match(sender, "(.*)+(.*)")
    sender = name.."-"..realm
    --ignore importing the live preset when sender is player, open VT only
    local playerName, playerRealm = UnitFullName("player")
    playerName = playerName.."-"..playerRealm
    if sender == playerName then
      VT:Async(function() VT:ShowInterfaceInternal(true) end, "showInterface")
    else
      VT:Async(function()
        VT:ShowInterfaceInternal(true)
        VT:LiveSession_Enable()
      end, "showInterfaceLive")
    end
    return
  elseif (link and link:sub(0, 15) == "garrmission:VT") then
    local sender = link:sub(17, string.len(link))
    local name, realm = string.match(sender, "(.*)+(.*)")
    if (not name) or (not realm) then
      local msg = "\nsender: "..sender
      local escapedText = text:gsub("|", "||")
      msg = msg.."\nfull text: "..escapedText
      local cache = VT.U.TableToString(VT.transmissionCache)
      VT:OnError(msg, cache, "VT failed to import preset from chat link")
      return
    end
    -- to get the displayName (name of the preset) we need to get everything between the starting and closing brackets
    local displayName = text:match("%[(.-)%]")
    sender = name.."-"..realm
    local preset = VT.transmissionCache[sender][displayName]
    if preset and type(preset) == "table" then
      VT:Async(function()
        VT:ShowInterfaceInternal(true)
        VT:ImportPreset(CopyTable(preset))
      end, "showInterfaceChatImport")
    else
      local msg = "\nparsed displayName: "..displayName
      msg = msg.."\nsender: "..sender
      local escapedText = text:gsub("|", "||")
      msg = msg.."\nfull text: "..escapedText
      local cache = VT.U.TableToString(VT.transmissionCache)
      VT:OnError(msg, cache, "VT failed to import preset from chat link")
    end
    return
  end
end)

function VTcommsObject:OnCommReceived(prefix, message, distribution, sender)
  --[[
        Sender has no realm name attached when sender is from the same realm as the player
        UnitFullName("Nnoggie") returns no realm while UnitFullName("player") does
        UnitFullName("Nnoggie-TarrenMill") returns realm even if you are not on the same realm as Nnoggie
        We append our realm if there is no realm
    ]]
  local name, realm = UnitFullName(sender)
  if not name then return end
  if not realm or string.len(realm) < 3 then
    local _, r = UnitFullName("player")
    realm = r
  end
  local fullName = name.."-"..realm

  --standard preset transmission
  --we cache the preset here already
  --the user still decides if he wants to click the chat link and add the preset to his db
  if prefix == presetCommPrefix then
    local preset = VT:StringToTable(message, false)
    local dungeon = VT:GetDungeonName(preset.value.currentDungeonIdx, true)
    local presetName = preset.text
    local displayName = dungeon..": "..presetName
    VT.transmissionCache[fullName] = VT.transmissionCache[fullName] or {}
    VT.transmissionCache[fullName][displayName] = preset
    --live session preset
    if VT.liveSessionActive and VT.liveSessionAcceptingPreset and preset.uid == VT.livePresetUID then
      if VT:ValidateImportPreset(preset) then
        VT:ImportPreset(preset, true)
        VT.liveSessionAcceptingPreset = false
        VT.main_frame.SendingStatusBar:Hide()
        if VT.main_frame.LoadingSpinner then
          VT.main_frame.LoadingSpinner:Hide()
          VT.main_frame.LoadingSpinner.Anim:Stop()
        end
        VT.liveSessionRequested = false
      end
    end
  end

  if prefix == VT.dataCollectionPrefixes.request then
    VT.DataCollection:DistributeData()
  end

  if prefix == VT.dataCollectionPrefixes.distribute then
    if sender == UnitFullName("player") then return end
    local package = VT:StringToTable(message, false)
    print("Received data package from "..fullName)
    VT.DataCollection:MergeReceiveData(package)
  end

  if prefix == VT.liveSessionPrefixes.enabled then
    if VT.liveSessionRequested == true then
      VT:LiveSession_SessionFound(fullName, message)
    end
  end

  --pulls
  if prefix == VT.liveSessionPrefixes.pull then
    if VT.liveSessionActive then
      local preset = VT:GetCurrentLivePreset()
      local pulls = VT:StringToTable(message, false)
      preset.value.pulls = pulls
      if not preset.value.pulls[preset.value.currentPull] then
        preset.value.currentPull = #preset.value.pulls
        preset.value.selection = { #preset.value.pulls }
      end
      if preset == VT:GetCurrentPreset() then
        VT:ReloadPullButtons()
        VT:SetSelectionToPull(VT:GetCurrentPull())
        VT:POI_UpdateAll() --for corrupted spires
        VT:UpdateProgressbar()
      end
    end
  end

  --corrupted
  if prefix == VT.liveSessionPrefixes.corrupted then
    if VT.liveSessionActive then
      local preset = VT:GetCurrentLivePreset()
      local offsets = VT:StringToTable(message, false)
      --only reposition if no blip is currently moving
      if not VT.draggedBlip then
        preset.value.riftOffsets = offsets
        VT:UpdateMap()
      end
    end
  end

  --difficulty
  if prefix == VT.liveSessionPrefixes.difficulty then
    if VT.liveSessionActive then
      local db = VT:GetDB()
      local difficulty = tonumber(message)
      if difficulty and difficulty ~= db.currentDifficulty then
        local updateSeasonal
        if ((difficulty >= 10 and db.currentDifficulty < 10) or (difficulty < 10 and db.currentDifficulty >= 10)) then
          updateSeasonal = true
        end
        db.currentDifficulty = difficulty
        VT.main_frame.sidePanel.DifficultySlider:SetValue(difficulty)
        VT:UpdateProgressbar()
        if VT.EnemyInfoFrame and VT.EnemyInfoFrame.frame:IsShown() then VT:UpdateEnemyInfoData() end
        VT:ReloadPullButtons()
        if updateSeasonal then
          VT:POI_UpdateAll()
          VT:KillAllAnimatedLines()
          VT:DrawAllAnimatedLines()
        end
      end
    end
  end

  --week
  if prefix == VT.liveSessionPrefixes.week then
    if VT.liveSessionActive then
      local preset = VT:GetCurrentLivePreset()
      local week = tonumber(message)
      if preset.week ~= week then
        preset.week = week
        local teeming = VT:IsPresetTeeming(preset)
        preset.value.teeming = teeming
        if preset == VT:GetCurrentPreset() then
          local affixDropdown = VT.main_frame.sidePanel.affixDropdown
          affixDropdown:SetValue(week)
          if not VT:GetCurrentAffixWeek() then
            VT.main_frame.sidePanel.affixWeekWarning.image:Hide()
            VT.main_frame.sidePanel.affixWeekWarning:SetDisabled(true)
          elseif VT:GetCurrentAffixWeek() == week then
            VT.main_frame.sidePanel.affixWeekWarning.image:Hide()
            VT.main_frame.sidePanel.affixWeekWarning:SetDisabled(true)
          else
            VT.main_frame.sidePanel.affixWeekWarning.image:Show()
            VT.main_frame.sidePanel.affixWeekWarning:SetDisabled(false)
          end
          VT:POI_UpdateAll()
          VT:UpdateProgressbar()
          VT:ReloadPullButtons()
          VT:KillAllAnimatedLines()
          VT:DrawAllAnimatedLines()
        end
      end
    end
  end

  if prefix == VT.liveSessionPrefixes.poiAssignment then
    if VT.liveSessionActive then
      local preset = VT:GetCurrentLivePreset()
      local deserialized = VT:StringToTable(message, false)
      if deserialized and type(deserialized) == "table" then
        local sublevel, poiIdx, value = unpack(deserialized)
        preset.value.poiAssignments = preset.value.poiAssignments or {}
        preset.value.poiAssignments[sublevel] = preset.value.poiAssignments[sublevel] or {}
        preset.value.poiAssignments[sublevel][poiIdx] = value
        VT:UpdateMap()
        if sender ~= UnitFullName("player") and VT:GetCurrentSubLevel() == sublevel then
          local poiFrame = VT:POI_GetFrameForPOI(poiIdx)
          if poiFrame then UIFrameFlash(poiFrame, 0.5, 1, 1, true, 1, 0); end
        end
      end
    end
  end

  --live session messages that ignore concurrency from here on, we ignore our own messages
  if sender == UnitFullName("player") then return end


  if prefix == VT.liveSessionPrefixes.request then
    if VT.liveSessionActive then
      VT:LiveSession_NotifyEnabled()
    end
  end

  --request preset
  if prefix == VT.liveSessionPrefixes.reqPre then
    local playerName, playerRealm = UnitFullName("player")
    playerName = playerName.."-"..playerRealm
    if playerName == message then
      VT:SendToGroup(VT:IsPlayerInGroup(), true, VT:GetCurrentLivePreset())
    end
  end


  --ping
  if prefix == VT.liveSessionPrefixes.ping then
    local currentUID = VT:GetCurrentPreset().uid
    if VT.liveSessionActive and (currentUID and currentUID == VT.livePresetUID) then
      local x, y, sublevel = string.match(message, "(.*):(.*):(.*)")
      x = tonumber(x)
      y = tonumber(y)
      sublevel = tonumber(sublevel)
      local scale = VT:GetScale()
      if sublevel == VT:GetCurrentSubLevel() then
        VT:PingMap(x * scale, y * scale)
      end
    end
  end

  --preset objects
  if prefix == VT.liveSessionPrefixes.obj then
    if VT.liveSessionActive then
      local preset = VT:GetCurrentLivePreset()
      local obj = VT:StringToTable(message, false)
      VT:StorePresetObject(obj, true, preset)
      if preset == VT:GetCurrentPreset() then
        local scale = VT:GetScale()
        local currentPreset = VT:GetCurrentPreset()
        local currentSublevel = VT:GetCurrentSubLevel()
        VT:DrawPresetObject(obj, nil, scale, currentPreset, currentSublevel)
      end
    end
  end

  --preset object offsets
  if prefix == VT.liveSessionPrefixes.objOff then
    if VT.liveSessionActive then
      local preset = VT:GetCurrentLivePreset()
      local objIdx, x, y = string.match(message, "(.*):(.*):(.*)")
      objIdx = tonumber(objIdx)
      x = tonumber(x)
      y = tonumber(y)
      VT:UpdatePresetObjectOffsets(objIdx, x, y, preset, true)
      if preset == VT:GetCurrentPreset() then VT:DrawAllPresetObjects() end
    end
  end

  --preset object changed (deletions, partial deletions)
  if prefix == VT.liveSessionPrefixes.objChg then
    if VT.liveSessionActive then
      local preset = VT:GetCurrentLivePreset()
      local changedObjects = VT:StringToTable(message, false)
      if changedObjects and type(changedObjects) == "table" then
        for objIdx, obj in pairs(changedObjects) do
          preset.objects[objIdx] = obj
        end
        if preset == VT:GetCurrentPreset() then VT:DrawAllPresetObjects() end
      end
    end
  end

  --various commands
  if prefix == VT.liveSessionPrefixes.cmd then
    if VT.liveSessionActive then
      local preset = VT:GetCurrentLivePreset()
      if message == "deletePresetObjects" then VT:DeletePresetObjects(preset, true) end
      if message == "undo" then VT:PresetObjectStepBack(preset, true, true) end
      if message == "redo" then VT:PresetObjectStepForward(preset, true, true) end
      if message == "clear" then VT:ClearPreset(preset, true) end
    end
  end

  --note text update, delete, move
  if prefix == VT.liveSessionPrefixes.note then
    if VT.liveSessionActive then
      local preset = VT:GetCurrentLivePreset()
      local action, noteIdx, text, y = string.match(message, "(.*):(.*):(.*):(.*)")
      noteIdx = tonumber(noteIdx)
      if action == "text" then
        preset.objects[noteIdx].d[5] = text
      elseif action == "delete" then
        tremove(preset.objects, noteIdx)
      elseif action == "move" then
        local x = tonumber(text)
        y = tonumber(y)
        preset.objects[noteIdx].d[1] = x
        preset.objects[noteIdx].d[2] = y
      end
      if preset == VT:GetCurrentPreset() then VT:DrawAllPresetObjects() end
    end
  end

  --preset
  if prefix == VT.liveSessionPrefixes.preset then
    if VT.liveSessionActive then
      local preset = VT:StringToTable(message, false)
      local dungeon = VT:GetDungeonName(preset.value.currentDungeonIdx, true)
      local displayName = dungeon..": "..preset.text
      VT.transmissionCache[fullName] = VT.transmissionCache[fullName] or {}
      VT.transmissionCache[fullName][displayName] = preset
      if VT:ValidateImportPreset(preset) then
        VT.livePresetUID = preset.uid
        VT:ImportPreset(preset, true)
      end
    end
  end
end

---MakeSendingStatusBar
---Creates a bar that indicates sending progress when sharing presets with your group
---Called once from initFrames()
function VT:MakeSendingStatusBar(f)
  f.SendingStatusBar = CreateFrame("StatusBar", nil, f)
  local statusbar = f.SendingStatusBar
  statusbar:SetMinMaxValues(0, 1)
  statusbar:SetPoint("CENTER", VT.main_frame.bottomPanel, "CENTER", 0, 0)
  statusbar:SetWidth(200)
  statusbar:SetHeight(20)
  statusbar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
  statusbar:GetStatusBarTexture():SetHorizTile(false)
  statusbar:GetStatusBarTexture():SetVertTile(false)
  statusbar:SetStatusBarColor(0.26, 0.42, 1)

  statusbar.bg = statusbar:CreateTexture(nil, "BACKGROUND", nil, 0)
  statusbar.bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
  statusbar.bg:SetAllPoints()
  statusbar.bg:SetVertexColor(0.26, 0.42, 1)

  statusbar.value = statusbar:CreateFontString(nil, "OVERLAY")
  statusbar.value:SetPoint("CENTER", statusbar, "CENTER", 0, 0)
  statusbar.value:SetFontObject(GameFontNormalSmall)
  statusbar.value:SetJustifyH("CENTER")
  statusbar.value:SetJustifyV("MIDDLE")
  statusbar.value:SetShadowOffset(1, -1)
  statusbar.value:SetTextColor(1, 1, 1)
  statusbar:Hide()

  --hooks to show/hide the bottom text
  statusbar:HookScript("OnShow", function(self)
    VT.main_frame.bottomPanelString:Hide()
  end)
  statusbar:HookScript("OnHide", function(self)
    VT.main_frame.bottomPanelString:Show()
  end)
end

--callback for SendCommMessage
local function displaySendingProgress(userArgs, bytesSent, bytesToSend)
  VT.main_frame.SendingStatusBar:Show()
  VT.main_frame.SendingStatusBar:SetValue(bytesSent / bytesToSend)
  VT.main_frame.SendingStatusBar.value:SetText(string.format(L["Sending: %.1f"], bytesSent / bytesToSend * 100).."%")
  --done sending
  if bytesSent == bytesToSend then
    local distribution = userArgs[1]
    local preset = userArgs[2]
    local silent = userArgs[3]
    local fromLiveSession = userArgs[4]
    --restore "Send" and "Live" button
    if VT.liveSessionActive then
      VT.main_frame.LiveSessionButton:SetText(L["*Live*"])
    else
      VT.main_frame.LiveSessionButton:SetText(L["Live"])
      VT.main_frame.LiveSessionButton.text:SetTextColor(1, 0.8196, 0)
      VT.main_frame.LinkToChatButton:SetDisabled(false)
      VT.main_frame.LinkToChatButton.text:SetTextColor(1, 0.8196, 0)
    end
    VT.main_frame.LinkToChatButton:SetText(L["Share"])
    VT.main_frame.LiveSessionButton:SetDisabled(false)
    VT.main_frame.SendingStatusBar:Hide()
    --output chat link
    if not silent and preset then
      local prefix = "[VT_v2: "
      local dungeon = VT:GetDungeonName(preset.value.currentDungeonIdx, true)
      local presetName = preset.text
      local name, realm = UnitFullName("player")

      --UnitFullName("player") will always return a players name with a capitalised first letter, regardless of whether
      --or not that is actually the case, while UnitFullName("Nnoggie") will return the player name with case respected.
      --This causes a subtle bug for (the few) players who's name does not begin with a capital, where chat links do not
      --work, because line 243 in OnCommReceived respects the case of the name, but here in the sending code we do not.
      --As a result, the entry in VT.transmissionCache is indexed with case respected, but read on line 225 of this file
      --without respect for case (due to us sending it here, without respect for case). The fix is to subsequently call
      --GetUnitName(name) on the name, in order to get the correct case.

      ---@diagnostic disable-next-line: param-type-mismatch
      name = UnitFullName(name)

      local fullName = name.."+"..realm
      SendChatMessage(prefix..fullName.." - "..dungeon..": "..presetName.."]", distribution)
    end
    numActiveTransmissions = numActiveTransmissions - 1
  end
end

VT.displaySendingProgress = displaySendingProgress

function VT:GetPresetByUid(presetUid)
  local db = VT:GetDB()
  for _, dungeon in pairs(db.presets) do
    for _, preset in pairs(dungeon) do
      if preset.uid == presetUid then
        return preset
      end
    end
  end
end

---generates a unique random 11 digit number in base64
function VT:GenerateUniqueID(length)
  local s = {}
  for i = 1, length do
    tinsert(s, bytetoB64[math.random(0, 63)])
  end
  return table.concat(s)
end

function VT:SetUniqueID(preset)
  if not preset.uid then
    local newUid = VT:GenerateUniqueID(11)
    -- collision check
    local inUse = false
    local presets = VT:GetDB().presets
    for _, dungeon in pairs(presets) do
      for _, pres in pairs(dungeon) do
        if pres.uid and pres.uid == newUid then
          inUse = true
          break
        end
      end
    end
    if not inUse then
      preset.uid = newUid
    else
      VT:SetUniqueID(preset)
    end
  end
end

---SendToGroup
---Send current preset to group/raid
function VT:SendToGroup(distribution, silent, preset)
  preset = preset or VT:GetCurrentPreset()
  --set unique id
  VT:SetUniqueID(preset)
  --gotta encode difficulty into preset
  local db = VT:GetDB()
  preset.difficulty = db.currentDifficulty
  local export = VT:TableToString(preset, false, 5)
  numActiveTransmissions = numActiveTransmissions + 1
  VTcommsObject:SendCommMessage("VTPreset", export, distribution, nil, "BULK", displaySendingProgress,
    { distribution, preset, silent })
end

---GetPresetSize
---Returns the number of characters the string version of the preset contains
function VT:GetPresetSize(forChat, level)
  local preset = VT:GetCurrentPreset()
  local export = VT:TableToString(preset, forChat, level)
  return string.len(export)
end
