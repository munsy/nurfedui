------------------------------------------
--  Nurfed General Functions
------------------------------------------

-- Locals
local sellFrame = CreateFrame("Frame")
local invite
local pingflood = {}
local afkstring = Nurfed:formatgs(RAID_MEMBERS_AFK, true)
local ingroup = Nurfed:formatgs(ERR_ALREADY_IN_GROUP_S, true)
local dnsLst = {
	[20558] = true,
	[20559] = true,
	[20560] = true,
	[29024] = true,
	[32823] = true,
}
-- Default Options
NURFED_SAVED = NURFED_SAVED or {}

local wowmenu = {
  { CHARACTER, function() CharacterMicroButton:Click() end },
  { SPELLBOOK, function() SpellbookMicroButton:Click() end },
  { TALENTS, function() TalentMicroButton:Click() end },
  { QUESTLOG_BUTTON, function() QuestLogMicroButton:Click() end },
  { FRIENDS, function() SocialsMicroButton:Click() end },
  { LFG_TITLE, function() LFGMicroButton:Click() end },
  { BINDING_NAME_TOGGLEGAMEMENU, function() MainMenuMicroButton:Click() end },
  { KNOWLEDGE_BASE, function() HelpMicroButton:Click() end },
  { KEYRING, function() KeyRingButton:Click() end },
}

local function onenter()
  GameTooltip:SetOwner(this, "ANCHOR_LEFT")
  GameTooltip:AddLine("Nurfed UI", 0, 0.75, 1)
  if NRF_LOCKED then
    GameTooltip:AddLine("Left Click - |cffff0000Unlock|r UI", 0.75, 0.75, 0.75)
  else
    GameTooltip:AddLine("Left Click - |cff00ff00Lock|r UI", 0.75, 0.75, 0.75)
  end
  GameTooltip:AddLine("Right Click - Nurfed Menu", 0.75, 0.75, 0.75)
  GameTooltip:AddLine("Middle Click - WoW Micro Menu", 0.75, 0.75, 0.75)
  GameTooltip:AddLine("Ctrl + Drag moves your Action Bars.", 0, 1, 0)
  GameTooltip:Show()
end

local function onclick(button)
  if button == "LeftButton" then
    NRF_LOCKED = this:GetChecked()
    local icon = _G[this:GetName().."icon"]
    if NRF_LOCKED then
      icon:SetTexture(NRF_IMG.."locked")
    else
      icon:SetTexture(NRF_IMG.."unlocked")
    end
    PlaySound("igMainMenuOption")
    onenter()
    Nurfed:sendevent("NURFED_LOCK")
  else
    this:SetChecked(NRF_LOCKED)
	if button == "RightButton" then
		Nurfed_ToggleOptions()
	else
		local drop = Nurfed_LockButtondropdown
		local info = {}
		if not drop.initialize then
		  drop.displayMode = "MENU"
		  drop.initialize = function()
			info.text = "WoW Menu"
			info.isTitle = 1
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info)
			info = {}

			for _, v in ipairs(wowmenu) do
			  info.text = v[1]
			  info.func = v[2]
			  info.notCheckable = 1
			  UIDropDownMenu_AddButton(info)
			end
		  end
		end
		ToggleDropDownMenu(1, nil, drop, "cursor")
	  end
	 end
end

local function onupdate(self)
  if self.isMoving then
    local square = Nurfed:getopt("squareminimap")
    local xpos, ypos = GetCursorPosition()
    local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()

    xpos = xmin - xpos/Minimap:GetEffectiveScale() + 70
    ypos = ypos / Minimap:GetEffectiveScale() - ymin - 70
    local angle = math.deg(math.atan2(ypos, xpos))

    if square then
      xpos = 110 * cos(angle)
      ypos = 110 * sin(angle)
      xpos = math.max(-82, math.min(xpos,84))
      ypos = math.max(-86, math.min(ypos,82))
    else
      xpos = 80 * cos(angle)
      ypos = 80 * sin(angle)
    end
    self:SetPoint("TOPLEFT", "Minimap", "TOPLEFT", 52-xpos, ypos-52)
  end
end

local function onevent(self, event, arg1, arg2, arg3, arg4, arg5)
  if event == "CHAT_MSG_WHISPER" then
    local invite = Nurfed:getopt("autoinvite")
    if invite and (IsPartyLeader() or IsRaidLeader() or IsRaidOfficer() or (GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0)) then
      local text = string.lower(arg1)
      local keyword = string.lower(Nurfed:getopt("keyword"))
      if (string.find(text, "^"..keyword)) then
        InviteUnit(arg2)
        lastinvite = GetTime()
      end
    end
  elseif event == "MINIMAP_PING" and Nurfed:getopt("ping") then
	local name = UnitName(arg1)
	if name ~= UnitName("player") and not pingflood[name] then
		Nurfed:print(name.." Ping.", 1, 1, 1, 0)
		pingflood[name] = GetTime()
	end
	
  elseif event == "CHAT_MSG_SYSTEM" then
	if arg1 == READY_CHECK_ALL_READY or string.find(arg1, afkstring) then
      if Nurfed:getopt("readycheck") then
        SendChatMessage(arg1, "RAID")
      end
    else
      local invitetext = Nurfed:getopt("invitetext")
      if invitetext and (IsPartyLeader() or IsRaidLeader() or IsRaidOfficer()) then
        if string.find(arg1, ERR_GROUP_FULL, 1, true) and lastinvite then
          local lastTell = ChatEdit_GetLastTellTarget(DEFAULT_CHAT_FRAME.editBox)
          if lastTell ~= "" then
            SendChatMessage("Party Full", "WHISPER", nil, lastTell)
          end
        else
          local result = { string.find(arg1, ingroup) }
          if (result[1]) then
			SendChatMessage("Drop group and resend '"..Nurfed:getopt("keyword").."'", "WHISPER", nil, result[3])
          end
        end
      end
    end
    
  elseif event == "PARTY_INVITE_REQUEST" and Nurfed:getopt("autojoingroup") then
	local i = 1
	while i do
		local name = GetGuildRosterInfo(i)
		if name == arg1 then
			AcceptGroup()
			StaticPopup_Hide("PARTY_INVITE")
			return
		end
		i = name and i+1 or nil
	end

  elseif event == "MERCHANT_SHOW" then
	local isRepairing, startRepMoney
	if Nurfed:getopt("repair") then
		local limit = tonumber(Nurfed:getopt("repairlimit"))
		local money = tonumber(math.floor(GetMoney() / COPPER_PER_GOLD))
		if money >= limit then
			local repairAllCost, canRepair = GetRepairAllCost()
			if canRepair then
				startRepMoney = GetMoney()
				local gold = math.floor(repairAllCost / (COPPER_PER_SILVER * SILVER_PER_GOLD))
				local silver = math.floor((repairAllCost - (gold * COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER)
				local copper = math.fmod(repairAllCost, COPPER_PER_SILVER)
				if CanGuildBankRepair() and min(GetGuildBankWithdrawMoney(), GetGuildBankMoney()) > repairAllCost then
					RepairAllItems(1)
					Nurfed:print("|cffffffffSpent|r |c00ffff66"..gold.."g|r |c00c0c0c0"..silver.."s|r |c00cc9900"..copper.."c|r |cffffffffOn Repairs (Guild).|r")
				else
					isRepairing = true
					RepairAllItems()
					Nurfed:print("|cffffffffSpent|r |c00ffff66"..gold.."g|r |c00c0c0c0"..silver.."s|r |c00cc9900"..copper.."c|r |cffffffffOn Repairs.|r")
				end
			end
		end
	end
    if Nurfed:getopt("autosell") then
		if isRepairing then
			local timer = 1
			sellFrame:SetScript("OnUpdate", function()
				timer = timer + 1
				if timer >= 45 then
					if GetMoney() == startRepMoney then
						timer = 0
						return
					else
						sellFrame:SetScript("OnUpdate", nil)
						Nurfed_LockButton:GetScript("OnEvent")(Nurfed_LockButton, "MERCHANT_SHOW")
					end
				end
			end)
			return
		end
		
		local soldNum, soldItems, sold, startMoney = 0, "", nil, GetMoney()
		local soldLst = {}
		for bag=0,4,1 do
			for slot=1, GetContainerNumSlots(bag), 1 do
				if GetContainerItemLink(bag, slot) then
					local name, link, rarity = GetItemInfo(GetContainerItemLink(bag, slot))
					if name and not dnsLst[link:find("Hitem:(%d+)")] and rarity == 0 then
						if not soldLst[name] then
							if GetItemCount(link) ~= 1 then
								soldNum = soldNum + GetItemCount(link)
								soldItems = soldItems == "" and link or soldItems..", "..link.."x"..GetItemCount(link)
							else
								soldNum = soldNum + 1
								soldItems = soldItems == "" and link or soldItems..", "..link
							end
							soldLst[name] = true
						else
							soldItems = soldItems:gsub(link, link.."x"..GetItemCount(link))
						end
						UseContainerItem(bag, slot)
						sold = true
					end
				end
			end
		end
		if sold then
			if soldNum == 1 then
				Nurfed:print("|cffffffffSold |r"..soldNum.." |cffffffffItem: |r"..soldItems)
			else
				Nurfed:print("|cffffffffSold |r"..soldNum.." |cffffffffItems: |r"..soldItems)
			end
			local timer = 1
			sellFrame:SetScript("OnUpdate", function()
				timer=timer+1
				if timer >= 45 then
					local money = GetMoney() - startMoney
					if money == 0 then 
						timer = 0
						return
					end

					local gold = math.floor(money / (COPPER_PER_SILVER * SILVER_PER_GOLD))
					local silver = math.floor((money - (gold * COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER)
					local copper = math.fmod(money, COPPER_PER_SILVER)
					Nurfed:print("|cffffffffReceived|r |c00ffff66"..gold.."g|r |c00c0c0c0"..silver.."s|r |c00cc9900"..copper.."c|r |cfffffffffrom selling trash loot.|r")
					sellFrame:SetScript("OnUpdate", nil)
				end
			end)
		end
	end

  elseif event == "TRAINER_SHOW" and Nurfed:getopt("traineravailable") then
	SetTrainerServiceTypeFilter("unavailable", 0)
    
  elseif event == "ADDON_LOADED" and arg1 == "Blizzard_InspectUI" then
	InspectPaperDollFrame:SetScript("OnShow", Nurfed_InspectOnShow)
    
  elseif event == "PLAYER_ENTERING_WORLD" then
    this:UnregisterEvent(event)
    nrf_togglechat()
    nrf_togglcast()
    nrf_mainmenu()
    CombatLogQuickButtonFrame_Custom:UnregisterEvent("PLAYER_ENTERING_WORLD")
	if NURFED_SAVED[MANA] then
		NURFED_SAVED["mana"] = NURFED_SAVED[MANA]
		NURFED_SAVED[MANA] = nil
	end
	if NURFED_SAVED[RAGE_POINTS or RAGE] then
		NURFED_SAVED["rage"] = NURFED_SAVED[RAGE_POINTS or RAGE]
		NURFED_SAVED[RAGE_POINTS or RAGE] = nil
	end
	if NURFED_SAVED[ENERGY_POINTS or ENERGY] then
		NURFED_SAVED["energy"] = NURFED_SAVED[ENERGY_POINTS or ENERGY]
		NURFED_SAVED[ENERGY_POINTS or ENERGY] = nil
	end
	if NURFED_SAVED[FOCUS_POINTS or FOCUS] then
		NURFED_SAVED["focus"] = NURFED_SAVED[FOCUS_POINTS or FOCUS]
		NURFED_SAVED[FOCUS_POINTS or FOCUS] = nil
	end
	if NURFED_SAVED[HAPPINESS_POINTS or HAPPINESS] then
		NURFED_SAVED["happiness"] = NURFED_SAVED[HAPPINESS_POINTS or HAPPINESS]
		NURFED_SAVED[HAPPINESS_POINTS or HAPPINESS] = nil
	end
	
  elseif event == "VARIABLES_LOADED" then
    if this:IsUserPlaced() then
      this:SetUserPlaced(nil)
    end
    this:SetPoint(unpack(Nurfed:getopt("lock")))

    for _, val in pairs(RAID_CLASS_COLORS) do
      val.hex = Nurfed:rgbhex(val.r, val.g, val.b)
    end

    for _, val in ipairs(UnitReactionColor) do
      val.hex = Nurfed:rgbhex(val.r, val.g, val.b)
    end

    for i = 0, 4 do
		local color = Nurfed:getopt(i == 0 and "mana" or i == 1 and "rage" or i == 2 and "focus" or i == 3 and "energy" or i == 4 and "happiness")
		ManaBarColor[i].r = color[1]
		ManaBarColor[i].g = color[2]
		ManaBarColor[i].b = color[3]
    end

    if NURFED_FRAMES.templates then
      for k, v in pairs(NURFED_FRAMES.templates) do
        Nurfed:createtemp(k, v)
      end
    end

    if NURFED_FRAMES.frames then
      for k, v in pairs(NURFED_FRAMES.frames) do
        local f = Nurfed:create(k, v)
        if not v.Point then f:SetPoint("CENTER", UIParent, "CENTER") end
        Nurfed:unitimbue(f)
      end
    end

    CameraPanelOptions.cameraDistanceMaxFactor.maxValue = 4
  end
end

Nurfed:create("Nurfed_LockButton", {
  type = "CheckButton",
  size = { 33, 33 },
  FrameStrata = "LOW",
  Checked = NRF_LOCKED,
  Movable = true,
  events = {
    "ADDON_LOADED",
    "MERCHANT_SHOW",
    "TRAINER_SHOW",
    "MINIMAP_PING",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_SYSTEM",
    "PLAYER_ENTERING_WORLD",
    "VARIABLES_LOADED",
    "PARTY_INVITE_REQUEST",
  },
  children = {
    dropdown = { type = "Frame" },
    Border = {
      type = "Texture",
      size = { 52, 52 },
      layer = "ARTWORK",
      Texture = "Interface\\Minimap\\MiniMap-TrackingBorder",
      Anchor = { "TOPLEFT", "$parent", "TOPLEFT", 0, 0 },
    },
    HighlightTexture = {
      type = "Texture",
      size = { 33, 33 },
      alphaMode = "ADD",
      Texture = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
      Anchor = { "TOPLEFT", "$parent", "TOPLEFT", 0, 0 },
    },
    icon = {
      type = "Texture",
      size = { 23, 23 },
      layer = "BACKGROUND",
      Texture = NRF_IMG.."locked",
      Anchor = { "CENTER", "$parent", "CENTER", -1, 1 },
    },
  },
  OnEvent = onevent,
  OnEnter = onenter,
  OnClick = function() onclick(arg1) end,
  OnLeave = function() GameTooltip:Hide() end,
  OnDragStart = function(self)
    self.isMoving = true
    self:SetScript("OnUpdate", function(self) onupdate(self) end)
  end,
  OnDragStop = function(self)
    self.isMoving = nil
    self:SetScript("OnUpdate", nil)
    NURFED_SAVED["lock"] = { self:GetPoint() }
    NURFED_SAVED["lock"][2] = "Minimap"
  end,
}, Minimap)

Nurfed_LockButton:RegisterForClicks("AnyUp")
Nurfed_LockButton:RegisterForDrag("LeftButton")

-- Modify chat frames
ChatTypeInfo["CHANNEL"].sticky = 1
ChatTypeInfo["OFFICER"].sticky = 1

local function OnMouseWheel()
  if IsShiftKeyDown() then
    if arg1 > 0 then this:PageUp()
    elseif arg1 < 0 then this:PageDown()
    end
  elseif IsControlKeyDown() then
    if arg1 > 0 then this:ScrollToTop()
    elseif arg1 < 0 then this:ScrollToBottom()
    end
  else
    if arg1 > 0 then this:ScrollUp()
    elseif arg1 < 0 then this:ScrollDown()
    end
  end
end

local messageText = {}
local function message(this, msg, r, g, b, id)
  if (msg and type(msg) == "string") then
	messageText[1] = nil; messageText[2] = nil
	
    if Nurfed:getopt("timestamps") then
      table.insert(messageText, date(Nurfed:getopt("timestampsformat")))
    end
    
    if not Nurfed:getopt("chatprefix") then
		local _, _, channel = msg:find("^%[(.-)%]")
		if channel then
			if channel:match("^%d%.%s") then
				if not Nurfed:getopt("numchatprefix") then
					msg = msg:gsub("%.%s%a+%]", "]", 1)
				end
			elseif not msg:match("^%[%d") then
				msg = msg:gsub("%["..channel.."%] ", "", 1)
			end
		end
    end
    table.insert(messageText, msg)
    this:O_AddMessage(table.concat(messageText, " "), r, g, b, id)
  end
end

CastingBarFrame.O_onevent = CastingBarFrame:GetScript("OnEvent")
CastingBarFrame.O_onupdate = CastingBarFrame:GetScript("OnUpdate")

function nrf_togglcast()
  local hide = Nurfed:getopt("hidecasting")
  if hide then
    CastingBarFrame:SetScript("OnEvent", nil)
    CastingBarFrame:SetScript("OnUpdate", nil)
    CastingBarFrame:Hide()
  else
    CastingBarFrame:SetScript("OnEvent", CastingBarFrame.O_onevent)
    CastingBarFrame:SetScript("OnUpdate", CastingBarFrame.O_onupdate)
  end
end

function nrf_togglechat()
  local buttons = Nurfed:getopt("chatbuttons")
  local fade = Nurfed:getopt("chatfade")
  local fadetime = Nurfed:getopt("chatfadetime")
  for i = 1, 7 do
    local chatframe = _G["ChatFrame"..i]
    local up = _G["ChatFrame"..i.."UpButton"]
    local down = _G["ChatFrame"..i.."DownButton"]
    local bottom = _G["ChatFrame"..i.."BottomButton"]
    if buttons then
      up:Hide()
      down:Hide()
      bottom:Hide()
      if i == 1 then ChatFrameMenuButton:Hide() end
      chatframe:SetScript("OnShow", function() SetChatWindowShown(this:GetID(), 1) end)
    else
      up:Show()
      down:Show()
      bottom:Show()
      if i == 1 then ChatFrameMenuButton:Show() end
      chatframe:SetScript("OnShow", chatframe.O_OnShow)
    end
    chatframe:SetFading(fade)
    chatframe:SetTimeVisible(fadetime)
  end
end

for i = 1, 7 do
  local chatframe = _G["ChatFrame"..i]
  local buttons = Nurfed:getopt("chatbuttons")
  chatframe:EnableMouseWheel(true)
  chatframe:SetScript("OnMouseWheel", OnMouseWheel)
  if not chatframe.O_AddMessage then
    chatframe.O_AddMessage = chatframe.AddMessage
    chatframe.AddMessage = message
  end
  if not chatframe.O_OnShow then
    chatframe.O_OnShow = chatframe:GetScript("OnShow")
  end
end

-- Overwrite Blizzard seconds conversion
function SecondsToTimeAbbrev(seconds)
  local time
  if seconds > 86400 then
    time = format(DAY_ONELETTER_ABBR, ceil(seconds / 86400))
  elseif seconds > 3600 then
    time = format(HOUR_ONELETTER_ABBR, ceil(seconds / 3600))
  elseif seconds > 60 then
    local min = floor(seconds / 60)
    local sec = floor(seconds-(min)*60)
    time = format("%02d:%02d", min, sec)
  else
    time = format("00:%02d", seconds)
  end
  return time
end

-- Add guild line to inspect
function Nurfed_InspectOnShow()
  InspectPaperDollFrame_OnShow()
  local guildname, guildtitle = GetGuildInfo("target")
  if guildname and guildtitle then
    InspectTitleText:SetText(format(TEXT(GUILD_TITLE_TEMPLATE), guildtitle, guildname))
    InspectTitleText:Show()
  else
    InspectTitleText:Hide()
  end
end

local function flood()
  local now = GetTime()
  if invite and now - invite > 1 then invite = nil end
  for n, t in pairs(pingflood) do
    if now - t > 1 then pingflood[n] = nil end
  end
end

Nurfed:schedule(0.5, flood, true)

----------------------------------------------------------------
-- Add point gain to team frame
for i = 1, 3 do
  local score = _G["PVPTeam"..i]:CreateFontString("PVPTeam"..i.."points", "ARTWORK")
  score:SetFont(STANDARD_TEXT_FONT, 10)
  score:SetTextColor(0, 1, 0)
  score:SetPoint("LEFT", 15, -4)
end

local function rating()
  local size, rating, score, points
  local buttonIndex = 0
  local ARENA_TEAMS = {};
  ARENA_TEAMS[1] = {size = 2}
  ARENA_TEAMS[2] = {size = 3}
  ARENA_TEAMS[3] = {size = 5}

  for index, value in pairs(ARENA_TEAMS) do
    for i = 1, MAX_ARENA_TEAMS do
      teamName, teamSize = GetArenaTeam(i)
      if value.size == teamSize then
        value.index = i
      end
    end
  end

  for index, value in pairs(ARENA_TEAMS) do
    if value.index then
      _, size, rating = GetArenaTeam(value.index);
      buttonIndex = buttonIndex + 1
      score = _G["PVPTeam"..buttonIndex.."points"]
      if rating <= 1500 then
        points = 0.22 * rating + 14
      else
        points = 1511.26 / (1 + 1639.28 * math.exp(-0.00412 * rating))
      end

      if size == 2 then
        points = points * 0.76
      elseif size == 3 then
        points = points * 0.88
      end

      score:SetText(format("%d", points))
    end
  end
end

PVPFrame:HookScript("OnShow", rating)

-- Reload UI Popup
StaticPopupDialogs["NRF_RELOADUI"] = {
  text = "Reload User Interface?",
  button1 = TEXT(ACCEPT),
  button2 = TEXT(CANCEL),
  OnAccept = ReloadUI,
  timeout = 10,
  whileDead = 1,
  hideOnEscape = 1,
}

Nurfed:createtemp("uipanel", {
    type = "Frame",
    children = {
      Title = {
        type = "FontString",
        Point = {"TOPLEFT", 16, -16},
        FontObject = "GameFontNormalLarge",
        JustifyH = "LEFT",
        JustifyV = "TOP",
      },
      SubText = {
        type = "FontString",	
        Point = {"TOPLEFT", "$parentTitle", "BOTTOMLEFT", 0, -8},
        Point2 = {"RIGHT", -32, 0},
        FontObject = "GameFontHighlightSmall",
        JustifyH = "LEFT",
        JustifyV = "TOP",
        Height = 32,
        NonSpaceWrap = true,
      },
      VerText = {
		type = "FontString",
		Point = { "BOTTOMLEFT", "$parent", "BOTTOMLEFT", 16, 16 },
        FontObject = "GameFontHighlightSmall",
        JustifyH = "LEFT",
        JustifyV = "TOP",
       },
    }
  })

local panel = Nurfed:create("NurfedHeader", "uipanel")
panel:SetScript("OnShow", function(self)
    LoadAddOn("Nurfed_Options")
    NurfedHeaderVerText:SetText("|cffbbccddNurfed Version:|r "..Nurfed:getver().."("..Nurfed:getrev()..")\r|cffaabbccConfig Version:|r "..Nurfed:getver(1).."("..Nurfed:getrev(1)..")\r|cffccddeeArena Version:|r "..Nurfed:getver(2).."("..Nurfed:getrev(2)..")\r|cffddeeffCombatLog Version:|r "..Nurfed:getver(3).."("..Nurfed:getrev(3)..")")
    self:SetScript("OnShow", nil)
end)
panel.name = "Nurfed"
NurfedHeaderTitle:SetText("Nurfed")
NurfedHeaderSubText:SetText("This is the main Nurfed options menu, please select a subcategory to change options.")
InterfaceOptions_AddCategory(panel)

local button = CreateFrame("Button", "NurfedHeaderFrameEditor", panel, "UIPanelButtonTemplate")
button:SetText("Frame Editor")
button:SetWidth(106)
button:SetHeight(24)
button:SetPoint("CENTER", 0, 0)

button = CreateFrame("Button", "NurfedHeaderReloadui", panel, "UIPanelButtonTemplate")
button:SetText("Reload UI")
button:SetWidth(86)
button:SetHeight(24)
button:SetPoint("BOTTOMRIGHT", -5, 5)
button:SetScript("OnClick", function() StaticPopup_Show("NRF_RELOADUI") end)

Nurfed:setver("$Date$")
Nurfed:setrev("$Rev$")

