local Type, Version = "VTNewPullButton", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
local L = VT.L
local width, height = 248, 32

--Methods
local methods = {
  ["OnAcquire"] = function(self)
    self:SetWidth(width);
    self:SetHeight(height);
  end,
  ["Initialize"] = function(self)
    self.callbacks = {};

    function self.callbacks.OnClickNormal(_, mouseButton)
      if not MouseIsOver(VT.main_frame.sidePanel.pullButtonsScrollFrame.frame) then return end
      if (IsControlKeyDown()) then

      elseif (IsShiftKeyDown()) then

      else
        if (mouseButton == "RightButton") then

        else
          --normal click?
          VT:AddPull()
          if VT.liveSessionActive and VT:GetCurrentPreset().uid == VT.livePresetUID then
            VT:LiveSession_SendPulls(VT:GetPulls())
          end
        end
      end
    end

    function self.callbacks.OnDragStart()
      --
    end

    function self.callbacks.OnDragStop()
      --
    end

    function self.callbacks.OnKeyDown(self, key)
      if (key == "ESCAPE") then
        --
      end
    end

    --Set pullNumber
    self.pullNumber:SetText(L["+ Add pull"])
    self.pullNumber:Show()
    self.frame:SetScript("OnClick", self.callbacks.OnClickNormal);
    self.frame:SetScript("OnKeyDown", self.callbacks.OnKeyDown);
    self.frame:EnableKeyboard(false);
    -- self.frame:SetMovable(true);
    -- self.frame:RegisterForDrag("LeftButton");
    -- self.frame:SetScript("OnDragStart", self.callbacks.OnDragStart);
    -- self.frame:SetScript("OnDragStop", self.callbacks.OnDragStop);

    self:Enable();
  end,
  ["SetTitle"] = function(self, title)
    self.titletext = title;
    self.title:SetText(title);
  end,
  ["Disable"] = function(self)
    self.background:Hide();
    self.frame:Disable();
  end,
  ["Enable"] = function(self)
    self.background:Show();
    self.frame:Enable();
  end,
  ["Pick"] = function(self)
    self.frame:LockHighlight();
  end,
  ["ClearPick"] = function(self)
    self.frame:UnlockHighlight();
  end,
  ["SetIndex"] = function(self, index)
    self.index = index
  end,
  ["GetIndex"] = function(self)
    return self.index;
  end,
}

--Constructor
local function Constructor()
  local name = "VTNewPullButton"..AceGUI:GetNextWidgetNum(Type);
  local button = CreateFrame("BUTTON", name, UIParent, "OptionsListButtonTemplate");
  button:SetHeight(height);
  button:SetWidth(width);
  button.dgroup = nil;
  button.data = {};

  local background = button:CreateTexture(nil, "BACKGROUND", nil, 0);
  button.background = background;
  background:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight2.blp");
  background:SetBlendMode("ADD");
  background:SetVertexColor(0.5, 0.5, 0.5, 0.25);
  background:SetPoint("TOP", button, "TOP");
  background:SetPoint("BOTTOM", button, "BOTTOM");
  background:SetPoint("LEFT", button, "LEFT");
  background:SetPoint("RIGHT", button, "RIGHT");

  button.description = {};

  button:SetScript("OnEnter", function()

  end);
  button:SetScript("OnLeave", function()

  end);

  local pullNumber = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  pullNumber:SetHeight(18)
  pullNumber:SetJustifyH("CENTER");
  pullNumber:SetPoint("LEFT", button, "LEFT", 5, 0);

  local widget = {
    frame = button,
    pullNumber = pullNumber,
    background = background,
    type = Type
  }
  for method, func in pairs(methods) do
    ---@diagnostic disable-next-line: assign-type-mismatch
    widget[method] = func
  end

  return AceGUI:RegisterAsWidget(widget);
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
