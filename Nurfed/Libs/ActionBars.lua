------------------------------------------
--  Nurfed Action Bar Library
------------------------------------------

-- Locals
local _G = getfenv(0)
local pairs = pairs
local ipairs = ipairs
local isloaded
local playerClass = select(2, UnitClass("player"))

-- Default Options
NURFED_ACTIONBARS = NURFED_ACTIONBARS or {
  ["Nurfed_Bar1"] = {
    rows = 1,
    cols = 12,
    scale = 1,
    alpha = 1,
    unitshow = false,
    xgap = 2,
    ygap = 2,
    buttons = {},
    statemaps = {},
    visible = "show",
  },
}

----------------------------------------------------------------
-- Button functions
local function updateitem(btn)
  if btn.spell then
    local count = _G[btn:GetName().."Count"]
    local border = _G[btn:GetName().."Border"]

    if btn.type == "spell" then
      local reg = GetSpellCount(btn.spell)
      if reg and reg > 0 then
        count:SetText(reg)
      else
        count:SetText(nil)
      end
      border:Hide()
    elseif btn.type == "item" then
      local num = GetItemCount(btn.spell)
      if num > 1 then
        count:SetText(num)
      else
        count:SetText(nil)
      end
      if IsEquippedItem(btn.spell) then
        border:SetVertexColor(0, 1.0, 0, 0.35)
        border:Show()
      else
        border:Hide()
      end
    elseif btn.type == "macro" then
      local item, link = GetMacroItem(btn.spell)
      local spell, rank = GetMacroSpell(btn.spell)
      if item then
        local num = GetItemCount(item)
        if num > 1 then
          count:SetText(num)
        else
          count:SetText(nil)
        end
        if IsEquippedItem(item) then
          border:SetVertexColor(0, 1.0, 0, 0.35)
          border:Show()
        else
          border:Hide()
        end
      elseif spell then
        local reg = GetSpellCount(spell)
        if reg and reg > 0 then
          count:SetText(reg)
        else
          count:SetText(nil)
        end
        border:Hide()
      else
        border:Hide()
        count:SetText(nil)
      end
    end
  end
end

local function updatecooldown(btn)
  local start, duration, enable = 0, 0, 0
  local cooldown = _G[btn:GetName().."Cooldown"]
  if btn.spell then
    if btn.type == "spell" then
      start, duration, enable = GetSpellCooldown(btn.spell)
    elseif btn.type == "item" then
      start, duration, enable = GetItemCooldown(btn.spell)
    elseif btn.type == "macro" then
      local item, link = GetMacroItem(btn.spell)
      local spell, rank = GetMacroSpell(btn.spell)
      if item then
        start, duration, enable = GetItemCooldown(item)
      elseif spell then
        start, duration, enable = GetSpellCooldown(spell)
      end
    end
  end
  if start and duration then
    CooldownFrame_SetTimer(cooldown, start, duration, enable)
  end
end
-- unlocalize and change the name to an unused global to allow hooking from PT3Bar and AutoBar etc
-- No Reason to use "CooldownCount" etc if this function does everything we want in a nice clean fashion
--local cooldowntext = function(btn)
nrfcooldowntext = function(btn)
  local cd = _G[btn:GetName().."Cooldown"]
  if cd.text and cd.cool then
    local cdscale = cd:GetScale()
    local r, g, b = 1, 0, 0
    local height = floor(20 / cdscale)
    local fheight = select(2, cd.text:GetFont())
    local remain = (cd.start + cd.duration) - GetTime()
    if remain >= 0 then
      remain = math.round(remain)
      if remain >= 3600 then
        remain = math.floor(remain / 3600).."h"
        r, g, b = 0.6, 0.6, 0.6
        height = floor(12 / cdscale)
      elseif remain >= 60 then
        local min = math.floor(remain / 60)
        r, g, b = 1, 1, 0
        height = floor(12 / cdscale)
        if min < 10 then
          local sec = math.floor(math.fmod(remain, 60))
          remain = string.format("%2d:%02s", min, sec)
        else
          remain = min.."m"
        end
      end
      cd.text:SetText(remain)
      cd.text:SetTextColor(r, g, b)
      if height ~= fheight then
        cd.text:SetFont("Fonts\\FRIZQT__.TTF", height, "OUTLINE")
        cd:SetFrameLevel(30)
      end
    else
      cd.text:SetText(nil)
      cd.cool = nil
    end
  end
end

local function convert(btn, value)
  local unit = SecureButton_GetAttribute(btn, "unit")
  if unit and unit ~= "none" and UnitExists(unit) then
    if UnitCanAttack("player", unit) then
      value = SecureButton_GetModifiedAttribute(btn, "harmbutton", value) or value
    elseif UnitCanAssist("player", unit) then
      value = SecureButton_GetModifiedAttribute(btn, "helpbutton", value) or value
    end
  end
  return value
end

local function seticon(btn)
  local value = btn:GetAttribute("state-parent")
  if value then
    value = convert(btn, value)
    local texture, spell
    local text = _G[btn:GetName().."Name"]
    local new = SecureButton_GetModifiedAttribute(btn, "type", value)
    btn.type = new
    btn.attack = nil
    text:SetText(nil)
    if new then
      spell = SecureButton_GetModifiedAttribute(btn, new, value)
      if spell then
        if new == "spell" then
          texture = GetSpellTexture(spell)
          if IsAttackSpell(spell) or IsAutoRepeatSpell(spell) then
            btn.attack = true
          end
        elseif new == "item" then
          local itemid = SecureButton_GetModifiedAttribute(btn, "itemid", value)
          if itemid then
            texture = select(10, GetItemInfo(itemid))
          end
        elseif new == "macro" then
					local id = btn:GetAttribute("*macroID")
					if id then
						texture = GetActionTexture(id)
						spell = GetActionText(id)
					else
						spell, texture = GetMacroInfo(spell)
					end
          if Nurfed:getopt("macrotext") then
            text:SetText(spell)
          end
        end
      end
      btn.spell = spell
    end
    
    local icon = _G[btn:GetName().."Icon"]
    if icon:GetTexture() ~= texture then
      icon:SetTexture(texture)
      if texture then
        btn:SetAlpha(1)
        if Nurfed:getopt("fadein") then
          UIFrameFadeIn(icon, 0.35)
        end
      end
      updateitem(btn)
      updatecooldown(btn)
    end
      
    if not texture and not btn.grid then
      btn:SetAlpha(0)
    end
  end
end

----------------------------------------------------------------
-- Button creation and management
local function btnenter(self)
  local tooltip = Nurfed:getopt("tooltips")
  if tooltip and self.type then
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    if self.type == "spell" then
      local id = Nurfed:getspell(self.spell)
      if id then
        local rank = select(2, GetSpellName(id, BOOKTYPE_SPELL))
        GameTooltip:SetSpell(id, BOOKTYPE_SPELL)
        if rank then
          GameTooltipTextRight1:SetText(rank)
          GameTooltipTextRight1:SetTextColor(0.5, 0.5, 0.5)
          GameTooltipTextRight1:Show()
        end
      end
    elseif self.type == "item" then
      if GetItemInfo(self.spell) then
        GameTooltip:SetHyperlink(select(2, GetItemInfo(self.spell)))
      end
    elseif self.type == "macro" and GetMacroBody(self.spell) then
      local action = SecureCmdOptionParse(GetMacroBody(self.spell))
      if action then
        if GetItemInfo(action) then
          GameTooltip:SetHyperlink(select(2, GetItemInfo(action)))
        else
          local id = Nurfed:getspell(action)
          if id then
            local rank = select(2, GetSpellName(id, BOOKTYPE_SPELL))
            GameTooltip:SetSpell(id, BOOKTYPE_SPELL)
            if rank then
              GameTooltipTextRight1:SetText(rank)
              GameTooltipTextRight1:SetTextColor(0.5, 0.5, 0.5)
              GameTooltipTextRight1:Show()
            end
          end
        end
      end
    end

    GameTooltip:Show()
  end
end

local function btndragstart(self)
  if not NRF_LOCKED and not InCombatLockdown() then
    local state = self:GetAttribute("state-parent")
    if state == "0" then
      state = "LeftButton"
    end
    local value = convert(self, state)
    local new = SecureButton_GetModifiedAttribute(self, "type", value)
    if new then
      spell = SecureButton_GetModifiedAttribute(self, new, value)
      if spell then
        if new == "spell" then
          local id = Nurfed:getspell(spell)
          PickupSpell(id, BOOKTYPE_SPELL)
        elseif new == "item" then
          PickupItem(spell)
        elseif new == "macro" then
          PickupMacro(spell)
        end
        
        if state == "LeftButton" then
          value = "*"
        else
          value = "-"..value
        end
        self:SetAttribute("*type"..value, nil)
        self:SetAttribute("*"..new..value, nil)

        local unit = SecureButton_GetModifiedUnit(self, state)
        local useunit = self:GetParent():GetAttribute("useunit")
        if useunit and unit and unit ~= "none" and UnitExists(unit) then
          if state == "LeftButton" then
            state = "*"
          else
            state = "-"..state
          end
          if UnitCanAttack("player", unit) then
            self:SetAttribute("*harmbutton"..state, nil)
          elseif UnitCanAssist("player", unit) then
            self:SetAttribute("*helpbutton"..state, nil)
          end
        end
      end
    end
  end
end

local function btnreceivedrag(self)
  if GetCursorInfo() and not InCombatLockdown() then
    local oldtype = self.type
    local oldspell = self.spell
    local cursor, arg1, arg2 = GetCursorInfo()
    local value = self:GetAttribute("state-parent")
    if value == "0" then
      value = nil
    end
    local unit = SecureButton_GetModifiedUnit(self, (value or "LeftButton"))
    if value then
      value = "-"..value
    else
      value = "*"
    end
    
    local useunit = self:GetParent():GetAttribute("useunit")
    if useunit and unit and unit ~= "none" and UnitExists(unit) then
      if UnitCanAttack("player", unit) then
        self:SetAttribute("*harmbutton"..value, "nuke"..value)
        value = "-nuke"..value
      elseif UnitCanAssist("player", unit) then
        self:SetAttribute("*helpbutton"..value, "heal"..value)
        value = "-heal"..value
      end
    end
    
    self:SetAttribute("*type"..value, cursor)
    if cursor == "spell" then
      local spell, rank = GetSpellName(arg1, arg2)
      if string.find(rank, RANK) then
        spell = spell.."("..rank..")"
      elseif string.find(spell, "%(") then
        spell = spell.."()"
      end
      self:SetAttribute("*spell"..value, spell)
      self:SetAttribute("*item"..value, nil)
      self:SetAttribute("*itemid"..value, nil)
      self:SetAttribute("*macro"..value, nil)
	  self:SetAttribute("*macroID", nil)
    elseif cursor == "item" then
      local item = GetItemInfo(arg1)
      self:SetAttribute("*spell"..value, nil)
      self:SetAttribute("*item"..value, item)
      self:SetAttribute("*itemid"..value, arg1)
      self:SetAttribute("*macro"..value, nil)
	  self:SetAttribute("*macroID", nil)
    elseif cursor == "macro" then
      self:SetAttribute("*spell"..value, nil)
      self:SetAttribute("*item"..value, nil)
      self:SetAttribute("*itemid"..value, nil)
      self:SetAttribute("*macro"..value, arg1)
		for i=1, 72 do
			if select(2, GetActionInfo(i)) == arg1 then
				self:SetAttribute("*macroID", i)
				break
			end
		end
	end
    ClearCursor()
    
    if oldtype and oldspell then
      if oldtype == "spell" then
        local id = Nurfed:getspell(oldspell)
        if id then
          PickupSpell(id, BOOKTYPE_SPELL)
        end
      elseif oldtype == "item" then
      elseif oldtype == "macro" then
        PickupMacro(oldspell)
      end
    end
  end
end

local function saveattrib(self, name, value)
  if string.find(name, "^%*") or string.find(name, "^shift") or string.find(name, "^ctrl") or string.find(name, "^alt") then
    NURFED_ACTIONBARS[self:GetParent():GetName()].buttons[self:GetID()][name] = value
    name = "state-parent"
  end

  if name == "state-parent" then
    seticon(self)
  end
end

local live, dead = {}, {}

local function getbtn()
  local btn
  if #dead > 0 then
    btn = table.remove(dead)
  else
    local new = #live + 1
    btn = CreateFrame("CheckButton", "Nurfed_Button"..new, UIParent, "SecureActionButtonTemplate, ActionButtonTemplate")
    btn:RegisterForClicks("AnyUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetAttribute("checkselfcast", true)
    btn:SetAttribute("useparent-unit", true)
    btn:SetAttribute("useparent-statebutton", true)
    btn:SetScript("OnEnter", function(self) btnenter(self) end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnDragStart", function(self) btndragstart(self) end)
    btn:SetScript("OnReceiveDrag", function(self) btnreceivedrag(self) end)
    btn:SetScript("PreClick", function(self)
        if GetCursorInfo() and not InCombatLockdown() then
          self:SetScript("OnClick", nil)
          btnreceivedrag(self)
        end
      end)
    btn:SetScript("PostClick", function(self)
        self:SetChecked(nil)
        if not self:GetScript("OnClick") then
          self:GetParent():SetAttribute("addchild", self)
        end
      end)

    local cd = _G[btn:GetName().."Cooldown"]
    cd.text = cd:CreateFontString(nil, "OVERLAY")
    cd.text:SetPoint("CENTER")
    cd.text:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    local flash = _G[btn:GetName().."Flash"]
    flash:ClearAllPoints()
    flash:SetAllPoints(cd)
    btn.flashtime = 0
  end
  table.insert(live, btn)
  btn:SetScript("OnAttributeChanged", saveattrib)
  return btn
end

local function delbtn(btn)
  for k, v in ipairs(live) do
    if v == btn then
      table.remove(live, k)
      table.insert(dead, btn)
      break
    end
  end
  
  btn:SetScript("OnAttributeChanged", nil)
  
  local attribs = NURFED_ACTIONBARS[btn:GetParent():GetName()].buttons[btn:GetID()]
  for k in pairs(attribs) do
    btn:SetAttribute(k, nil)
  end

  btn:SetParent(UIParent)
  btn:Hide()
  btn:SetID(0)
  _G[btn:GetName().."HotKey"]:SetText(nil)
end

----------------------------------------------------------------
-- Button events
local btnevents = {
  ["PLAYER_ENTERING_WORLD"] = function(btn) seticon(btn) end,
  ["PLAYER_TARGET_CHANGED"] = function(btn)
    if SecureButton_GetUnit(btn) == "target" then
      seticon(btn)
    end
  end,
  ["PLAYER_FOCUS_CHANGED"] = function(btn)
    if SecureButton_GetUnit(btn) == "focus" then
      seticon(btn)
    end
  end,
  ["MODIFIER_STATE_CHANGED"] = function(btn) seticon(btn) end,
  ["ACTIONBAR_UPDATE_USABLE"] = function(btn) updatecooldown(btn) end,
  ["UPDATE_INVENTORY_ALERTS"] = function(btn) updatecooldown(btn) end,
  ["ACTIONBAR_UPDATE_COOLDOWN"] = function(btn) updatecooldown(btn) end,
  ["UPDATE_BINDINGS"] = function(btn)
    if isloaded then
      local id = btn:GetID()
      if id > 0 then
        local key = GetBindingKey("CLICK "..btn:GetName()..":LeftButton")
        local parent = btn:GetParent():GetName()
        NURFED_ACTIONBARS[parent].buttons[id].bind = key
        if key then
          key = Nurfed:binding(key)
        end
        if Nurfed:getopt("showbindings") then
			_G[btn:GetName().."HotKey"]:SetText(key)
			_G[btn:GetName().."HotKey"]:Show()
		else-- added clearing of hotkeys for settings so you dont have to reload everytime you change the setting
			_G[btn:GetName().."HotKey"]:SetText(nil)
			_G[btn:GetName().."HotKey"]:Hide()
		end
      end
    end
  end,
  ["UPDATE_MACROS"] = function(btn)
    if btn.type == "macro" then
      seticon(btn)
    end
  end,
  ["BAG_UPDATE"] = function(btn)
    updateitem(btn)
  end,
  ["UNIT_SPELLCAST_SUCCEEDED"] = function(btn)
    if btn.type == "macro" then
      btn.macro = true
    end
  end,
  ["ACTIONBAR_SHOWGRID"] = function(btn)
    btn.grid = true
    btn:SetAlpha(1)
  end,
  ["ACTIONBAR_HIDEGRID"] = function(btn)
    btn.grid = nil
    if not _G[btn:GetName().."Icon"]:GetTexture() then
      btn:SetAlpha(0)
    end
  end,
  ["PLAYER_ENTER_COMBAT"] = function(btn) btn.flash = true end,
  ["START_AUTOREPEAT_SPELL"] = function(btn) btn.flash = true end,
  ["PLAYER_LEAVE_COMBAT"] = function(btn) btn.flash = nil end,
  ["STOP_AUTOREPEAT_SPELL"] = function(btn) btn.flash = nil end,
  ["UNIT_FACTION"] = function(btn, ...)
    if SecureButton_GetUnit(btn) == arg1 then
      seticon(btn)
    end
  end,
}

local function btnevent(event, ...)
  for _, btn in ipairs(live) do
    btnevents[event](btn, ...)
  end
end

for event, func in pairs(btnevents) do
  Nurfed:regevent(event, btnevent)
end

local function btnupdate()
  for _, btn in ipairs(live) do
    local r, g, b = 1, 1, 1
    local unit = SecureButton_GetUnit(btn)
    if btn.type == "spell" then
      if IsCurrentSpell(btn.spell) then
        btn:SetChecked(true)
      else
        btn:SetChecked(nil)
      end
      local usable, nomana = IsUsableSpell(btn.spell)
      if nomana then
        r, g, b = 0.5, 0.5, 1
      elseif not usable then
        r, g, b = 0.4, 0.4, 0.4
      elseif SpellHasRange(btn.spell) and IsSpellInRange(btn.spell, unit) == 0 then
        r, g, b = 1, 0, 0
      end
    elseif btn.type == "item" then
      if not IsUsableItem(btn.spell) then
        r, g, b = 0.4, 0.4, 0.4
      elseif ItemHasRange(btn.spell) and IsItemInRange(btn.spell, unit) == 0 then
        r, g, b = 1, 0, 0
      end
    elseif btn.type == "macro" then
      local item, link = GetMacroItem(btn.spell)
      local spell, rank = GetMacroSpell(btn.spell)
      if item then
        if not IsUsableItem(item) then
          r, g, b = 0.4, 0.4, 0.4
        elseif ItemHasRange(item) and IsItemInRange(item, unit) == 0 then
          r, g, b = 1, 0, 0
        end
      elseif spell then
        local usable, nomana = IsUsableSpell(spell)
        if nomana then
          r, g, b = 0.5, 0.5, 1
        elseif not usable then
          r, g, b = 0.4, 0.4, 0.4
        elseif SpellHasRange(spell) and IsSpellInRange(spell, unit) == 0 then
          r, g, b = 1, 0, 0
        end
      end

      if btn.macro then
        seticon(btn)
        btn.macro = nil
      end
    end
    _G[btn:GetName().."Icon"]:SetVertexColor(r, g, b)
    nrfcooldowntext(btn)
  end
end

Nurfed:schedule(TOOLTIP_UPDATE_TIME, btnupdate, true)

local function btnflash()
  for _, btn in ipairs(live) do
    local flash = _G[btn:GetName().."Flash"]
    if btn.flash and btn.attack then
      if flash:IsVisible() then
        flash:Hide()
      else
        flash:Show()
      end
    else
      flash:Hide()
    end
  end
end

Nurfed:schedule(ATTACK_BUTTON_FLASH_TIME, btnflash, true)

----------------------------------------------------------------
-- Reset stance bar border
hooksecurefunc("UIParent_ManageFramePositions", function()
    if not MainMenuBar:IsShown() then
      for i = 1, 10 do
        local border = _G["ShapeshiftButton"..i.."NormalTexture"]
        border:SetWidth(50)
        border:SetHeight(50)
      end
    end
  end)

----------------------------------------------------------------
-- Add cooldown text
local function updatecooling(this, start, duration, enable)
  if not this:GetName() or not this.text then return end
  if start > 2 and duration > 2 then
    this.cool = true
    this.start = start
    this.duration = duration
  else
    this.cool = nil
    this.text:SetText(nil)
  end
end

if not GetAddOnMetadata("OmniCC", "Version") and not IsAddOnLoaded("CooldownCount") then
  hooksecurefunc("CooldownFrame_SetTimer", updatecooling)
end

----------------------------------------------------------------
-- Action bar management
function Nurfed:updatebar(hdr)
  local state, visible
  local btns, statelist, driver = {}, {}, {}
  for _, child in ipairs({ hdr:GetChildren() }) do
    if string.find(child:GetName(), "^Nurfed_Button") then
      table.insert(btns, child:GetID(), child)
    end
  end

  local vals = NURFED_ACTIONBARS[hdr:GetName()]
  if vals.statemaps then
    for k, v in pairs(vals.statemaps) do
      if string.find(k, "%-") then
        k = string.gsub(k, "%-", ":")
      end

      local add = true
      local list = v..":"..v
      table.insert(driver, "["..k.."] "..v)

      for _, l in ipairs(statelist) do
        if l == list then
          add = nil
          break
        end
      end

      if add then
        table.insert(statelist, v..":"..v)
      end
    end
  end

  driver = table.concat(driver, ";")
  state = SecureCmdOptionParse(driver)
  statelist = table.concat(statelist, ";")

  if #driver == 0 then
    state = "0"
  end

  if not vals.visible or vals.visible =="" then
    vals.visible = "show"
  end

  visible = vals.visible

  if vals.visible ~= "hide" and vals.visible ~= "show" then
    visible = "["..vals.visible.."]".." show; hide"
  end


  RegisterStateDriver(hdr, "state", driver)
  RegisterStateDriver(hdr, "visibility", visible)
  hdr:SetAttribute("statemap-state", "$input")
  hdr:SetAttribute("statebutton", statelist)
  hdr:SetAttribute("state", state)
  hdr:SetWidth(vals.cols * (36 + vals.xgap) - vals.xgap)
  hdr:SetHeight(vals.rows * (36 + vals.ygap) - vals.ygap)
  
  local last, begin
  local count = 1
  for i = 1, vals.rows do
    for j = 1, vals.cols do
      local btn = table.remove(btns, 1) or getbtn()
      btn:SetID(count)
      hdr:SetAttribute("addchild", btn)
      vals.buttons[count] = vals.buttons[count] or {}
      
      for k, v in pairs(vals.buttons[count]) do
        if k == "bind" then
          SetBindingClick(v, btn:GetName(), "LeftButton")
        else
          btn:SetAttribute(k, v)
        end
      end

      btn:ClearAllPoints()
      if j == 1 then
        if begin then
          btn:SetPoint("BOTTOMLEFT", begin, "TOPLEFT", 0, vals.ygap)
        else
          btn:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 0)
        end
        begin = btn
      else
        btn:SetPoint("LEFT", last, "RIGHT", vals.xgap, 0)
      end
      last = btn
      count = count + 1
    end
  end

  for _, v in ipairs(btns) do
    delbtn(v)
  end

  if NRF_LOCKED then
    _G[hdr:GetName().."drag"]:Hide()
  end

  return count
end

function Nurfed:deletebar(frame)
  local hdr = _G[frame]
  UnregisterUnitWatch(hdr)
  hdr:SetAttribute("unit", nil)
  RegisterStateDriver(hdr, "visibility", "hide")
  hdr:Hide()

  local children = { hdr:GetChildren() }
  for _, child in ipairs(children) do
    if string.find(child:GetName(), "^Nurfed_Button") then
      delbtn(child)
    end
  end
  NURFED_ACTIONBARS[frame] = nil
end

function Nurfed:createbar(frame)
  local vals = NURFED_ACTIONBARS[frame]
  local hdr = _G[frame] or Nurfed:create(frame, "actionbar")

  if hdr and type(hdr) == "table" then
    hdr:SetScale(vals.scale)
    hdr:SetAlpha(vals.alpha)
    hdr:SetPoint(unpack(vals.Point or {"CENTER"}))
    hdr:SetAttribute("unit", vals.unit)
    hdr:SetAttribute("useunit", vals.useunit)

    _G[frame.."dragtext"]:SetText(frame)

    local count = Nurfed:updatebar(hdr)

    while vals.buttons[count] do
      vals.buttons[count] = nil
      count = count + 1
    end
  end
end

function Nurfed:updatehks(frame)
  local vals = NURFED_ACTIONBARS[frame]
  local hdr = _G[frame] or Nurfed:create(frame, "actionbar")
  if hdr and type(hdr) == "table" then
    local count = Nurfed:updatebar(hdr)
    while vals.buttons[count] do
      vals.buttons[count] = nil
      count = count + 1
    end
  end
end

Nurfed:createtemp("actionbar", {
    type = "Frame",
    uitemp = "SecureStateHeaderTemplate",
    size = { 36, 36 },
    Movable = true,
    Hide = true,
    ClampedToScreen = true,
    OnLoad = function(self)
      if IsLoggedIn() then
        
      end
    end,
    children = {
      drag = {
        type = "Frame",
        Mouse = true,
        size = { 110, 13 },
        Hide = true,
        Backdrop = {
          bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
          edgeFile = nil,
          tile = true,
          tileSize = 16,
          edgeSize = 16,
          insets = { left = 0, right = 0, top = 0, bottom = 0 }
        },
        BackdropColor = { 0, 0, 0 },
        Point = { "TOPLEFT", "$parent", "BOTTOMLEFT" },
        OnLoad = function(self)
          self:RegisterForDrag("LeftButton")
          if not NRF_LOCKED and IsLoggedIn() then
            self:Show()
          end
        end,
        OnAttributeChanged = function(self)
          if NRF_LOCKED and IsLoggedIn() then
            self:Hide()
          end
        end,
        OnDragStart = function(self) self:GetParent():StartMoving() end,
        OnDragStop = function(self)
          local parent = self:GetParent()
          parent:StopMovingOrSizing()
          if NURFED_ACTIONBARS[parent:GetName()] then
            NURFED_ACTIONBARS[parent:GetName()].Point = { parent:GetPoint() }
          else
            parent:SetUserPlaced(true)
          end

          local top = self:GetTop()
          local screen = GetScreenHeight() / 2
          if top and screen then
            self:ClearAllPoints()
            if top >= screen then
              self:SetPoint("TOPLEFT", parent, "BOTTOMLEFT")
            else  
              self:SetPoint("BOTTOMLEFT", parent, "TOPLEFT")
            end
          end
        end,
        OnShow = function(self)
          local top = self:GetTop()
          local screen = GetScreenHeight() / 2
          if top and screen then
            self:ClearAllPoints()
            if top >= screen then
              self:SetPoint("TOPLEFT", self:GetParent(), "BOTTOMLEFT")
            else  
              self:SetPoint("BOTTOMLEFT", self:GetParent(), "TOPLEFT")
            end
          end
          self:SetScript("OnShow", nil)
        end,
        children = {
          text = {
            type = "FontString",
            Point = "all",
            FontObject = "GameFontNormalSmall",
            JustifyH = "CENTER",
            TextColor = { 1, 1, 1 },
          }
        }
      }
    }
  })
  
local barevents = {
  ["NURFED_LOCK"] = function(bar)
    if NRF_LOCKED then
      _G[bar:GetName().."drag"]:Hide()
    else
      _G[bar:GetName().."drag"]:Show()
    end
  end,
}

local function barevent(event, ...)
  for k in pairs(NURFED_ACTIONBARS) do
    barevents[event](_G[k])
  end
end

for event, func in pairs(barevents) do
  Nurfed:regevent(event, barevent)
end

----------------------------------------------------------------
-- Built in bars
local blizzbars = {
  ["bags"] = 36,
  ["micro"] = 37,
  ["stance"] = 36,
  ["petbar"] = 30,
}

function nrf_updatemainbar(bar)
  local show = Nurfed:getopt(bar.."show")
  local scale = Nurfed:getopt(bar.."scale")
  local vert = Nurfed:getopt(bar.."vert")
  local offset = Nurfed:getopt(bar.."offset")
  bar = _G["Nurfed_"..bar]
  bar:SetScale(scale)

  if bar == Nurfed_petbar then
    if show then
      RegisterUnitWatch(Nurfed_petbar)
    else
      UnregisterUnitWatch(Nurfed_petbar)
    end
    for i = 2, 10 do
      local btn = _G["PetActionButton"..i]
      btn:ClearAllPoints()
      if vert then
        btn:SetPoint("TOP", "PetActionButton"..(i-1), "BOTTOM", 0, offset)
      else
        btn:SetPoint("LEFT", "PetActionButton"..(i-1), "RIGHT", offset, 0)
      end
    end
    
  elseif bar == Nurfed_stance then
    for i = 2, 10 do
      local btn = _G["ShapeshiftButton"..i]
      btn:ClearAllPoints()
      if vert then
        btn:SetPoint("TOP", "ShapeshiftButton"..(i-1), "BOTTOM", 0, -3)
      else
        btn:SetPoint("LEFT", "ShapeshiftButton"..(i-1), "RIGHT", 3, 0)
      end
    end
  elseif bar == Nurfed_bags then
    for i = 0, 3 do
      local bag = _G["CharacterBag"..i.."Slot"]
      bag:ClearAllPoints()
      if vert then
        if i == 0 then
          bag:SetPoint("TOP", "MainMenuBarBackpackButton", "BOTTOM", 0, -3)
        else
          bag:SetPoint("TOP", "CharacterBag"..(i-1).."Slot", "BOTTOM", 0, -3)
        end
      else
        if i == 0 then
          bag:SetPoint("RIGHT", "MainMenuBarBackpackButton", "LEFT", -3, 0)
        else
          bag:SetPoint("RIGHT", "CharacterBag"..(i-1).."Slot", "LEFT", -3, 0)
        end
      end
    end
  end
  if show then
    bar:Show()
  else
    bar:Hide()
  end
end

local function createbars()
  for k in pairs(NURFED_ACTIONBARS) do
    Nurfed:createbar(k)
  end

  local bar, drag
  for k, v in pairs(blizzbars) do
    bar = Nurfed:create("Nurfed_"..k, "actionbar")
    bar:SetHeight(v)
    if not bar:IsUserPlaced() then
      bar:SetPoint("CENTER")
    end
    if k == "petbar" then
      bar:SetAttribute("unit", "pet")
    end
    _G["Nurfed_"..k.."dragtext"]:SetText("Nurfed_"..k)
  end
end

Nurfed:regevent("VARIABLES_LOADED", createbars)
Nurfed:regevent("PLAYER_LOGIN", function()
    for k in pairs(NURFED_ACTIONBARS) do
      Nurfed:updatehks(k)
    end
    isloaded = true
    Nurfed:sendevent("UPDATE_BINDINGS")
    SaveBindings(GetCurrentBindingSet())
  end)

Nurfed:regevent("NURFED_LOCK", function()
    if NRF_LOCKED then
      Nurfed_bagsdrag:Hide()
      Nurfed_microdrag:Hide()
      Nurfed_stancedrag:Hide()
      Nurfed_petbardrag:Hide()
    else
      Nurfed_bagsdrag:Show()
      Nurfed_microdrag:Show()
      Nurfed_stancedrag:Show()
      Nurfed_petbardrag:Show()
    end
  end)

----------------------------------------------------------------
-- Toggle main action bar
local old_ShapeshiftBar_Update = ShapeshiftBar_Update

function nrf_mainmenu()
  if IsAddOnLoaded("Bartender3") or IsAddOnLoaded("Bartender4") or IsAddOnLoaded("TrinityBars") or IsAddOnLoaded("Bongos2_ActionBar") or IsAddOnLoaded("Bongos3_ActionBar") then
    return
  end

  if not Nurfed:getopt("hidemain") then
    if MainMenuBar:IsShown() then return end
    KeyRingButton:SetParent(MainMenuBarArtFrame)
    KeyRingButton:ClearAllPoints()
    KeyRingButton:SetPoint("RIGHT", "CharacterBag3Slot", "LEFT", -5, 0)

    MainMenuBarBackpackButton:SetParent(MainMenuBarArtFrame)
    MainMenuBarBackpackButton:ClearAllPoints()
    MainMenuBarBackpackButton:SetPoint("BOTTOMRIGHT", -6, 2)

    for i = 0, 3 do
      local bag = _G["CharacterBag"..i.."Slot"]
      bag:SetParent(MainMenuBarArtFrame)
      bag:ClearAllPoints()
      if i == 0 then
        bag:SetPoint("RIGHT", "MainMenuBarBackpackButton", "LEFT", -5, 0)
      else
        bag:SetPoint("RIGHT", "CharacterBag"..(i-1).."Slot", "LEFT", -5, 0)
      end
    end

    CharacterMicroButton:SetParent(MainMenuBarArtFrame)
    CharacterMicroButton:ClearAllPoints()
    CharacterMicroButton:SetPoint("BOTTOMLEFT", 552, 2)

    local children = { Nurfed_micro:GetChildren() }
    for _, child in ipairs(children) do
      if not string.find(child:GetName(), "^Nurfed") then
        child:SetParent(MainMenuBarArtFrame)
      end
    end

    for i = 1, 10 do
      local btn = _G["ShapeshiftButton"..i]
      btn:SetParent(ShapeshiftBarFrame)
      btn:ClearAllPoints()
      if i == 1 then
        btn:SetPoint("BOTTOMLEFT", 11, 3)
      else
        btn:SetPoint("LEFT", "ShapeshiftButton"..(i-1), "RIGHT", 7, 0)
      end

      btn = _G["PetActionButton"..i]
      btn:SetParent(PetActionBarFrame)
      btn:ClearAllPoints()
      if i == 1 then
        btn:SetPoint("BOTTOMLEFT", 36, 2)
      else
        btn:SetPoint("LEFT", "PetActionButton"..(i-1), "RIGHT", 8, 0)
      end
    end
    ShapeshiftBar_Update = old_ShapeshiftBar_Update
    MainMenuBar:Show()
  else
    KeyRingButton:SetParent(MainMenuBarBackpackButton)
    KeyRingButton:ClearAllPoints()
    KeyRingButton:SetPoint("LEFT", "MainMenuBarBackpackButton", "RIGHT", 2, 0)

    MainMenuBarBackpackButton:SetParent(Nurfed_bags)
    MainMenuBarBackpackButton:ClearAllPoints()
    MainMenuBarBackpackButton:SetPoint("BOTTOMLEFT")

    for i = 0, 3 do
      local bag = _G["CharacterBag"..i.."Slot"]
      bag:SetParent(Nurfed_bags)
    end


    CharacterMicroButton:SetParent(Nurfed_micro)
    CharacterMicroButton:ClearAllPoints()
    CharacterMicroButton:SetPoint("BOTTOMLEFT")

    local children = { MainMenuBarArtFrame:GetChildren() }
    for _, child in ipairs(children) do
      local name = child:GetName()
      if (string.find(name, "MicroButton", 1, true)) then
        child:SetParent(Nurfed_micro)
      end
    end

    for i = 1, 10 do
      local btn = _G["ShapeshiftButton"..i]
      local cooldown = _G["ShapeshiftButton"..i.."Cooldown"]
      if not cooldown.text then
        cooldown.text = cooldown:CreateFontString(nil, "OVERLAY")
        cooldown.text:SetPoint("CENTER")
        cooldown.text:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
      end
      btn:SetParent(Nurfed_stance)
      btn:SetScript("OnUpdate", nrfcooldowntext)
      if i == 1 then
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMLEFT")
      end

      btn = _G["PetActionButton"..i]
      cooldown = _G["PetActionButton"..i.."Cooldown"]
      if not cooldown.text then
        cooldown.text = cooldown:CreateFontString(nil, "OVERLAY")
        cooldown.text:SetPoint("CENTER")
        cooldown.text:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
      end
      btn:SetParent(Nurfed_petbar)
      btn:SetScript("OnUpdate", nrfcooldowntext)
      if i == 1 then
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMLEFT")
      end
    end
    nrf_updatemainbar("bags")
    nrf_updatemainbar("micro")
    nrf_updatemainbar("stance")
    nrf_updatemainbar("petbar")

    ShapeshiftBar_Update = function() end
    MainMenuBar:Hide()
  end
end
Nurfed:setver("$Date$")
Nurfed:setrev("$Rev$")