local _, VT = ...
local AceGUI = LibStub("AceGUI-3.0")
local conflictFrame
local L = VT.L

-- In DungeonTools case the AddOn has not been updated in over a year and has caused many users to be
-- confused about VT not working. This will prompt users to remove the abandoned AddOn and prevent them
-- from opening up a broken instance.

local candidates = {
  ["DungeonTools"] = {
    name = "Dungeon Tools",
    detected = false,
    onDetect = function()
      SLASH_DUNGEONTOOLS1 = "/vtools"
      SLASH_DUNGEONTOOLS2 = "/vt"
      SLASH_DUNGEONTOOLS3 = "/visiontools"
      function SlashCmdList.DUNGEONTOOLS(cmd, editbox)
        VT:Async(function() VT:ShowInterfaceInternal() end, "showInterface")
      end

      local ldb = LibStub("LibDBIcon-1.0")
      ldb.objects["DungeonTools"]:SetScript("OnClick", function() VT:Async(function() VT:ShowInterfaceInternal() end, "showInterface") end)
    end
  },
  ["VTGuide"] = {
    name = "VTGuide",
    version = 123, --latest version that causes issues
    detected = false,
    onDetect = function()

    end,
    note = L["VTGuideNote"]
  },
  ["MethodDungeonTools"] = {
    name = "MethodDungeonTools",
    detected = false,
    onDetect = function()

    end,
  },
  ["ChatCopyPaste"] = {
    name = "ChatCopyPaste",
    version = 122, --latest version that causes issues
    detected = false,
    onDetect = function()

    end,
  },
}

local conflictCheckFrame = CreateFrame("Frame")
conflictCheckFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
conflictCheckFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_ENTERING_WORLD" then
    -- fire onDetect for all candidates that have been detected
    for _, candidate in pairs(candidates) do
      if candidate.detected then
        candidate.onDetect()
      end
    end
    conflictCheckFrame:UnregisterEvent("ADDON_LOADED")
    conflictCheckFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
  end
end)

function VT:CheckAddonConflicts()
  for i = 1, C_AddOns.GetNumAddOns() do
    local name = C_AddOns.GetAddOnInfo(i)
    local loaded = C_AddOns.IsAddOnLoaded(i)
    local candidate = candidates[name]
    if loaded and candidate then
      if candidate.version then
        ---@diagnostic disable-next-line: redundant-parameter
        local version = C_AddOns.GetAddOnMetadata(i, "Version"):gsub("%.", "")
        local versionNum = tonumber(version)
        candidate.detected = versionNum <= candidate.version
      else
        candidate.detected = true
      end
    end
  end

  for _, candidate in pairs(candidates) do
    if candidate.detected then
      return true
    end
  end
  return false
end

function VT:ShowConflictFrame()
  if not conflictFrame then
    conflictFrame = AceGUI:Create("Frame")
    conflictFrame:EnableResize(false)
    conflictFrame:SetLayout("Flow")
    conflictFrame:SetCallback("OnClose", function(widget) end)
    conflictFrame:SetTitle(L["Addon Conflict"])

    conflictFrame.label = AceGUI:Create("Label")
    conflictFrame.label:SetWidth(550)
    conflictFrame.label:SetFontObject('GameFontNormalLarge')
    local labelText = L["conflictPrompt"]
    -- add all conflicting addons to the text in red color
    for _, candidate in pairs(candidates) do
      if candidate.detected then
        local updateNote = "\n- |cFFFF0000"..candidate.name.."|r"
        if candidate.note then
          updateNote = updateNote.." "..candidate.note
        end
        labelText = labelText..updateNote
      end
    end

    conflictFrame.label:SetText(labelText)
    conflictFrame:AddChild(conflictFrame.label)
  end
  conflictFrame:Show()
end
