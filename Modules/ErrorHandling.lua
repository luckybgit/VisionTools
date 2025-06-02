local AddonName, VT = ...
local AceGUI = LibStub("AceGUI-3.0")
local L = VT.L
local tinsert, slen = table.insert, string.len

-- handle most VT errors internally and provide an easy way for users to report these errors

local caughtErrors = {}

local function getDiagnostics()
  local presetExport = VT:TableToString(VT:GetCurrentPreset(), true, 5)
  ---@diagnostic disable-next-line: redundant-parameter
  local addonVersion = C_AddOns.GetAddOnMetadata(AddonName, "Version")
  local locale = GetLocale()
  local dateString = date("%d/%m/%y %H:%M:%S")
  local gameVersion = select(4, GetBuildInfo())
  local name, realm = UnitFullName("player")
  local regionId = GetCurrentRegion()
  local regions = {
    [1] = "US",
    [2] = "Korea",
    [3] = "Europe",
    [4] = "Taiwan",
    [5] = "China",
    [72] = "PTR"
  }
  local region = regions[regionId]
  local combatState = InCombatLockdown() and "In combat" or "Out of combat"
  local mapID = C_Map.GetBestMapForUnit("player");
  local zoneInfo = format("Zone: %s (%d)", C_Map.GetMapInfo(C_Map.GetMapInfo(mapID or 0).parentMapID).name, mapID)
  return {
    presetExport = presetExport,
    addonVersion = addonVersion,
    locale = locale,
    dateString = dateString,
    gameVersion = gameVersion,
    name = name,
    realm = realm,
    region = region,
    combatState = combatState,
    zoneInfo = zoneInfo
  }
end

local hasShown = false

function VT:DisplayErrors(force)
  if not force and hasShown then return end
  hasShown = true
  if #caughtErrors == 0 then return end
  if VT.initSpinner then
    VT.initSpinner:Hide()
    VT.initSpinner.Anim:Stop()
  end

  local function startCopyAction(editBox, copyButton, text)
    editBox:HighlightText(0, slen(text))
    editBox:SetFocus()
    copyButton:SetDisabled(true)
    VT.copyHelper:SmartShow(VT.errorFrame.frame, 0, 0)
  end

  local function stopCopyAction(copyButton)
    copyButton:SetDisabled(false)
    VT.copyHelper:SmartHide()
  end

  local errorBoxText = ""

  if not VT.errorFrame then
    VT.errorFrame = AceGUI:Create("Frame")
    _G["VTErrorFrame"] = VT.errorFrame.frame
    tinsert(UISpecialFrames, "VTErrorFrame")
    local errorFrame = VT.errorFrame
    errorFrame:EnableResize(false)
    errorFrame:SetWidth(800)
    errorFrame:SetHeight(600)
    errorFrame:EnableResize(false)
    errorFrame:SetLayout("Flow")
    errorFrame:SetCallback("OnClose", function(widget) end)
    errorFrame:SetTitle(L["VT Error"])
    errorFrame.label = AceGUI:Create("Label")
    errorFrame.label:SetWidth(800)
    errorFrame.label:SetFontObject("GameFontNormalLarge")
    errorFrame.label.label:SetTextColor(1, 0, 0)
    errorFrame.label:SetText(L["errorLabel1"].."\n"..L["errorLabel2"])
    errorFrame:AddChild(errorFrame.label)

    for _, dest in ipairs(VT.externalLinks) do
      errorFrame[dest.name.."EditBox"] = AceGUI:Create("EditBox")
      local editBox = errorFrame[dest.name.."EditBox"]
      local copyButton
      editBox:SetLabel(dest.name..":")
      editBox:DisableButton(true)
      editBox:SetText(dest.url)
      editBox:SetCallback("OnTextChanged", function()
        editBox:SetText(dest.url)
      end)

      editBox:SetWidth(400)
      editBox.editbox:HookScript('OnEditFocusLost', function()
        stopCopyAction(copyButton)
      end);
      editBox.editbox:SetScript('OnKeyUp', function(_, key)
        if (VT.copyHelper:WasControlKeyDown() and key == 'C') then
          VT.copyHelper:SmartFadeOut()
          editBox:ClearFocus();
        else
          VT.copyHelper:SmartHide()
        end
      end);
      errorFrame[dest.name.."CopyButton"] = AceGUI:Create("Button")
      copyButton = errorFrame[dest.name.."CopyButton"]
      copyButton:SetText(L["Copy"])
      copyButton:SetWidth(100)
      copyButton:SetCallback("OnClick", function(widget, callbackName, value)
        startCopyAction(editBox, copyButton, dest.url)
      end)
      errorFrame:AddChild(editBox)
      errorFrame:AddChild(copyButton)
    end

    local errorBox, errorBoxCopyButton
    errorFrame.errorBox = AceGUI:Create("MultiLineEditBox")
    errorBox = errorFrame.errorBox
    errorBox:SetWidth(800)
    errorBox:SetLabel(L["Error Message:"])
    errorBox:DisableButton(true)
    errorBox:SetNumLines(20)
    errorBox:SetCallback("OnTextChanged", function()
      errorBox:SetText(errorBoxText)
    end)
    errorBox.editBox:HookScript('OnEditFocusLost', function()
      stopCopyAction(errorBoxCopyButton)
    end);
    errorBox.editBox:SetScript('OnKeyUp', function(_, key)
      if (VT.copyHelper:WasControlKeyDown() and key == 'C') then
        VT.copyHelper:SmartFadeOut()
        errorBox:ClearFocus();
      else
        VT.copyHelper:SmartHide()
      end
    end);

    errorFrame.errorBoxCopyButton = AceGUI:Create("Button")
    errorBoxCopyButton = errorFrame.errorBoxCopyButton
    errorBoxCopyButton:SetText(L["Copy error"])
    errorBoxCopyButton:SetHeight(40)
    errorBoxCopyButton:SetCallback("OnClick", function(widget, callbackName, value)
      startCopyAction(errorFrame.errorBox, errorBoxCopyButton, errorBoxText)
    end)

    errorFrame.hardResetButton = AceGUI:Create("Button")
    local hardResetButton = errorFrame.hardResetButton
    hardResetButton:SetText(L["hardResetButton"])
    hardResetButton:SetHeight(40)
    hardResetButton:SetCallback("OnClick", function(widget, callbackName, value)
      VT:Async(function()
        VT:OpenConfirmationFrame(450, 150, L["hardResetPromptTitle"], L["Delete"], L["hardResetPrompt"], VT.HardReset)
      end, "hardReset")
    end)

    errorFrame:AddChild(errorFrame.errorBox)
    errorFrame:AddChild(errorFrame.errorBoxCopyButton)
    errorFrame:AddChild(errorFrame.hardResetButton)
    if VT.main_frame then
      --error button
      local errorButton = AceGUI:Create("Icon")
      errorButton:SetImage("Interface\\AddOns\\VisionTools\\Textures\\icons", 0.76, 1, 0.25, 0.5)
      errorButton:SetCallback("OnClick", function(widget, callbackName)
        VT:DisplayErrors("true")
      end)
      errorButton.tooltipText = L["encounteredErrors"]
      errorButton:SetWidth(24)
      errorButton:SetImageSize(20, 20)
      errorButton:SetCallback("OnEnter", function(widget, callbackName)
        VT:ToggleToolbarTooltip(true, widget, "ANCHOR_TOPLEFT")
      end)
      errorButton:SetCallback("OnLeave", function()
        VT:ToggleToolbarTooltip(false)
      end)

      local externalButtonGroup = VT.main_frame.externalButtonGroup
      externalButtonGroup:AddChild(errorButton)
      VT:FixAceGUIShowHide(externalButtonGroup, VT.main_frame)
    end
  end

  for _, error in ipairs(caughtErrors) do
    errorBoxText = errorBoxText..error.count.."x: "..error.message.."\n"
  end
  --add diagnostics
  local diagnostics = getDiagnostics()
  errorBoxText = errorBoxText.."\n"..diagnostics.dateString.."\nVT: "..diagnostics.addonVersion.."\nClient: "..diagnostics.gameVersion.." "..diagnostics.locale.."\nCharacter: "..diagnostics.name.."-"..diagnostics.realm.." ("..diagnostics.region..")"
  errorBoxText = errorBoxText.."\n"..diagnostics.combatState.."\n"..diagnostics.zoneInfo.."\n"
  errorBoxText = errorBoxText.."\nRoute:\n"..diagnostics.presetExport
  errorBoxText = errorBoxText.."\nStacktraces\n\n"
  for _, error in ipairs(caughtErrors) do
    errorBoxText = errorBoxText..error.stackTrace.."\n"
  end

  VT.errorFrame.errorBox:SetText(errorBoxText)
  VT.errorFrame:Show()
end

local numError = 0
local currentFunc = ""
local addTrace = false
local function onError(msg, stackTrace, name)
  numError = numError + 1
  local funcName = name or currentFunc
  local e = funcName..": "..msg
  -- return early on duplicate errors
  for _, error in pairs(caughtErrors) do
    if error.message == e then
      error.count = error.count + 1
      addTrace = false
      return false
    end
  end
  local stackTraceValue = stackTrace and name..":\n"..stackTrace
  tinsert(caughtErrors, { message = e, stackTrace = stackTraceValue, count = 1 })
  addTrace = true
  local diagnostics = getDiagnostics()
  local diagnosticString = diagnostics.dateString.."\nVT: "..diagnostics.addonVersion.."\nClient: "..diagnostics.gameVersion.." "..diagnostics.locale.."\n"..diagnostics.region
  -- VT.WagoAnalytics:Error(e..diagnosticString)
  if VT.errorTimer then VT.errorTimer:Cancel() end
  VT.errorTimer = C_Timer.NewTimer(0.5, function()
    VT:DisplayErrors(true)
  end)
  --if spam erroring then show errors early otherwise risk error display never showing
  if numError > 100 then
    VT:DisplayErrors(true)
  end
  return false
end

--accessible function for errors in coroutines
function VT:OnError(msg, stackTrace, name)
  onError(msg, stackTrace, name)
end

function VT:GetErrors()
  return caughtErrors
end

function VT:RegisterErrorHandledFunctions()
  --register all functions except the ones that have to run as coroutines
  local blacklisted = {
    ["DungeonEnemies_UpdateSelected"] = true,
    ["DungeonEnemies_UpdateEnemiesAsync"] = true,
    ["ReloadPullButtons"] = true,
    ["DrawAllPresetObjects"] = true,
    ["AddPull"] = true,
    ["ClearPull"] = true,
    ["ShowInterfaceInternal"] = true,
    ["UpdateToDungeon"] = true,
    ["UpdateMap"] = true,
    ["MovePullUp"] = true,
    ["ShowInterface"] = true,
    ["DeletePull"] = true,
    ["ExportDungeonDataIncrementally"] = true,
    ["DrawAllHulls"] = true,
    ["ExportString"] = true,
    ["Async"] = true,
    ["RegisterErrorHandledFunctions"] = true,
    ["OnError"] = true,
    ["DeepCopy"] = true,
  }
  local tablesToAdd = {
    VT, VTDungeonEnemyMixin
  }
  for k, table in pairs(tablesToAdd) do
    for funcName, func in pairs(table) do
      if type(func) == "function" and not blacklisted[funcName] then
        table[funcName] = function(...)
          currentFunc = funcName
          local results = { xpcall(func, onError, ...) }
          local ok = select(1, unpack(results))
          if not ok then
            if addTrace then
              --add stackTrace to the latest error
              caughtErrors[#caughtErrors].stackTrace = currentFunc..":\n"..debugstack()
            end
            return
          end
          return select(2, unpack(results))
        end
      end
    end
  end
end
