-- ManaMeter 
-- Written by Sharpedge_Gaming
-- v1.0 - 10.1.7

local addonName, addonTable = ...
local AceAddon = LibStub("AceAddon-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local lowManaAlertPlayed = false

local LDB = LibStub("LibDataBroker-1.1")
local dataBroker = LDB:NewDataObject("ManaMeter", {
    type = "data source",
    text = "ManaMeter",
    icon = "Interface\\Icons\\INV_Potion_137", -- Change to your preferred icon
    OnClick = function(clickedframe, button)
        if button == "LeftButton" then
            -- Toggle the visibility of the mana bar
            if ManaMeterFrame:IsShown() then
                ManaMeterFrame:Hide()
            else
                ManaMeterFrame:Show()
            end
        elseif button == "RightButton" then
            -- Open the addon's settings
            InterfaceOptionsFrame_OpenToCategory("ManaMeter")
            InterfaceOptionsFrame_OpenToCategory("ManaMeter") -- Call twice to ensure the category is selected
        end
    end,
    OnTooltipShow = function(tooltip)
        -- Define what your tooltip will show when moused over.
        tooltip:AddLine("ManaMeter")
        tooltip:AddLine("Left-click to toggle the mana bar.")
        tooltip:AddLine("Right-click to open settings.")
    end,
})

BACKDROP_DIALOG_EDGE_32  = {
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tileEdge = true,
	edgeSize = 32,
}

local function UsesMana()
    local _, classFileName = UnitClass("player")
    local specID = GetSpecialization() and GetSpecializationInfo(GetSpecialization()) or nil

    -- Specs that use Mana
    local manaSpecs = {
        -- Druid
        [105] = true, -- Restoration
        -- Monk
        [270] = true, -- Mistweaver
        -- Paladin
        [65] = true,  -- Holy
        -- Priest
        [257] = true, -- Holy
        [256] = true, -- Discipline
		[258] = true, -- Shadow
        -- Shaman
        [264] = true, -- Restoration
        -- Mage
        [62] = true,  -- Arcane
        [63] = true,  -- Fire
        [64] = true,  -- Frost
        -- Evokers
        [1468] = true  -- Preservation
    }

    return manaSpecs[specID] or false
end


-- Create the main frame
local ManaMeterFrame = CreateFrame("Frame", "ManaMeterFrame", UIParent, "BackdropTemplate")
ManaMeterFrame:SetSize(200, 30)
ManaMeterFrame:SetPoint("CENTER", UIParent, "CENTER")
Mixin(ManaMeterFrame, BackdropTemplateMixin)
ManaMeterFrame:SetBackdrop(BACKDROP_DIALOG_EDGE_32)
ManaMeterFrame:SetMovable(true)
ManaMeterFrame:EnableMouse(true)
ManaMeterFrame:RegisterForDrag("LeftButton")
ManaMeterFrame:SetScript("OnDragStart", ManaMeterFrame.StartMoving)
ManaMeterFrame:SetScript("OnDragStop", ManaMeterFrame.StopMovingOrSizing)
ManaMeterFrame:Hide()  -- Hide the frame by default

-- Create the mana bar
local ManaBar = CreateFrame("StatusBar", nil, ManaMeterFrame)
ManaBar:SetSize(176, 6)
ManaBar:SetPoint("CENTER", ManaMeterFrame, "CENTER")
ManaBar:SetStatusBarTexture("Interface\\BUTTONS\\WHITE8X8")
ManaBar:SetStatusBarColor(0, 1, 0, 0.5)  -- R, G, B, Alpha (0.5 makes it semi-transparent)

ManaBar:GetStatusBarTexture():SetHorizTile(false)
ManaBar:GetStatusBarTexture():SetVertTile(false)
ManaBar:SetMinMaxValues(0, 100)
ManaBar:SetFrameLevel(ManaMeterFrame:GetFrameLevel() + 1)

-- Create a new frame for the percentage text
local ManaPercentageFrame = CreateFrame("Frame", nil, ManaMeterFrame)
ManaPercentageFrame:SetAllPoints(ManaBar)
ManaPercentageFrame:SetFrameLevel(ManaBar:GetFrameLevel() + 1)

-- Create the font string on the new frame
local ManaPercentage = ManaPercentageFrame:CreateFontString(nil, "OVERLAY")
ManaPercentage:SetPoint("CENTER", ManaPercentageFrame, "CENTER")
ManaPercentage:SetFont("Fonts\\FRIZQT__.TTF", 12)
ManaPercentage:Hide()  -- Hide by default, will be shown based on user settings

-- Update the mana bar color and value
local function UpdateManaBar()
    local currentMana = UnitPower("player", Enum.PowerType.Mana) or 0
    local maxMana = UnitPowerMax("player", Enum.PowerType.Mana) or 1 -- Ensure it's not zero to avoid division by zero
    local percentageMana = 0

    if maxMana > 0 then
        percentageMana = (currentMana / maxMana) * 100
    end

    if percentageMana >= 0 and percentageMana <= 100 then
        ManaBar:SetValue(percentageMana)
    else
        ManaBar:SetValue(0) -- Default to 0 if the percentage is out of bounds
    end

    -- Calculate the color based on the percentage
    local red = 1
    local green = 1

    if percentageMana > 50 then
        red = (100 - percentageMana) * 2 / 100
    else
        green = percentageMana * 2 / 100
    end

    ManaBar:SetStatusBarColor(red, green, 0, 0.5)  -- Adjusted color based on percentage

    -- Update the percentage display
    if ManaMeterDB.profile.showPercentage then
        ManaPercentage:SetText(string.format("%.1f%%", percentageMana))
    else
        ManaPercentage:SetText("") -- Clear the text if the option is disabled
    end
end

local soundPaths = {
    Sound1 = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\Sheldon.mp3",
    Sound2 = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\Target Acquired.mp3",
    Sound3 = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\ReadyCheck.mp3",
    Sound4 = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\Buzzer.mp3",
    Sound5 = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\Arrow Swoosh.mp3"
}

local function CheckManaLevelAndPlaySound()
    -- Check if the player uses Mana
    if not UsesMana() then
        return
    end

    local currentMana = UnitPower("player", Enum.PowerType.Mana) or 0
    local maxMana = UnitPowerMax("player", Enum.PowerType.Mana) or 1
    local percentageMana = (currentMana / maxMana) * 100

    if percentageMana <= ManaMeterDB.profile.lowManaAlert.threshold and not lowManaAlertPlayed then
        local soundKey = ManaMeterDB.profile.lowManaAlert.sound
        local soundPath = soundPaths[soundKey]
        if soundPath then
            PlaySoundFile(soundPath)
            lowManaAlertPlayed = true
        end

        if ManaMeterDB.profile.lowManaAlert.sendMessage then
            local selectedMessage = ManaMeterDB.profile.lowManaAlert.message or "Message1"
            
            local messageTemplates = {
                ["Message1"] = "My mana is running low!",
                ["Message2"] = "I'm almost out of mana!",
                ["Message3"] = "Mana is getting critical!",
                ["Message4"] = "Need mana soon!",
                ["Message5"] = "Mana is depleting!"
            }

            local messageToSend = messageTemplates[selectedMessage]

            -- Send a message to the Instance chat
            SendChatMessage(messageToSend, "INSTANCE_CHAT")
        end

    elseif percentageMana > ManaMeterDB.profile.lowManaAlert.threshold then
        lowManaAlertPlayed = false
    end
end



local function OnAddonLoaded(self, event, addon)
    if event == "ADDON_LOADED" and addon == "ManaMeter" then
        if not ManaMeterDB then
            ManaMeterDB = {}
        end
        if not ManaMeterDB.profile then
            ManaMeterDB.profile = {
                barWidth = 200,      -- default width
                barThickness = 30,  -- default thickness
                orientation = "HORIZONTAL"  -- default orientation
            }
        end
		
        -- Initialize the showPercentage value if it doesn't exist
        if not ManaMeterDB.profile.showPercentage then
            ManaMeterDB.profile.showPercentage = true
        end

        -- Initialize the lowManaAlert values if they don't exist
        if not ManaMeterDB.profile.lowManaAlert then
            ManaMeterDB.profile.lowManaAlert = {
                enabled = true,
                threshold = 25,  -- Default to 25%
                sound = "LowManaAlert"  -- Default sound
            }
        end

        -- Initialize the mana bar with saved settings
        ManaMeterFrame:SetWidth(ManaMeterDB.profile.barWidth)
        ManaBar:SetWidth(ManaMeterDB.profile.barWidth - 24)
        ManaMeterFrame:SetHeight(ManaMeterDB.profile.barThickness + 24)
        ManaBar:SetHeight(ManaMeterDB.profile.barThickness)
        UpdateManaBar()

        -- Set the orientation based on the saved profile
        local orientation = ManaMeterDB.profile.orientation or "HORIZONTAL"
        ManaBar:SetOrientation(orientation)
        if orientation == "VERTICAL" then
            ManaMeterFrame:SetSize(ManaMeterDB.profile.barThickness + 24, ManaMeterDB.profile.barWidth)
            ManaBar:SetSize(ManaMeterDB.profile.barThickness, ManaMeterDB.profile.barWidth - 24)
        else
            ManaMeterFrame:SetSize(ManaMeterDB.profile.barWidth, ManaMeterDB.profile.barThickness + 24)
            ManaBar:SetSize(ManaMeterDB.profile.barWidth - 24, ManaMeterDB.profile.barThickness)
        end

        -- Handle the percentage display based on the saved profile
        if ManaMeterDB.profile.showPercentage then
            ManaPercentage:Show()
        else
            ManaPercentage:Hide()
        end

        ManaPercentage:SetFont(ManaPercentage:GetFont(), ManaMeterDB.profile.percentageSize or 12)

        -- Set the frame's locked state based on the saved profile
        if ManaMeterDB.profile.locked then
            ManaMeterFrame:EnableMouse(false)
        else
            ManaMeterFrame:EnableMouse(true)
        end

        -- Set the script to update the mana bar and play the alert sound if enabled
        ManaMeterFrame:SetScript("OnEvent", function(self, event, ...)
            if event == "UNIT_POWER_UPDATE" then
                UpdateManaBar()
                if ManaMeterDB.profile.lowManaAlert.enabled then
                    CheckManaLevelAndPlaySound()
                end
            elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
                if UsesMana() then
                    ManaMeterFrame:Show()
                else
                    ManaMeterFrame:Hide()
                end
            end
        end)

    elseif event == "PLAYER_LOGIN" then
        -- Check if the player uses Mana
        if UsesMana() then
            -- Delay showing and updating the mana bar by 2 seconds
            C_Timer.After(2, function()
                ManaMeterFrame:Show()  -- Show the frame if the player uses Mana
                UpdateManaBar()        -- Update the mana bar after the delay
            end)
        else
            ManaMeterFrame:Hide()  -- Hide the frame if the player doesn't use Mana
        end
    end
end

-- Register the event handlers
ManaMeterFrame:RegisterEvent("ADDON_LOADED")
ManaMeterFrame:RegisterEvent("PLAYER_LOGIN")
ManaMeterFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

-- Create an event frame to listen for the ADDON_LOADED and PLAYER_LOGIN events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", OnAddonLoaded)

-- Register an event to update the mana bar when mana changes
ManaMeterFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
ManaMeterFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_POWER_UPDATE" then
        UpdateManaBar()
    end
end)

-- Configuration table
local options = {
    name = "ManaMeter",
    type = "group",
    args = {
        generalHeader = {
            type = "header",
            name = "General",
            order = 0
        },
        lockToggle = {
            type = "toggle",
            name = "Lock Bar",
            desc = "Lock or unlock the mana bar for movement.",
            set = function(info, val)
                if val then
                    ManaMeterFrame:EnableMouse(false)
                else
                    ManaMeterFrame:EnableMouse(true)
                end
                ManaMeterDB.profile.locked = val
            end,
            get = function(info)
                return ManaMeterDB.profile.locked
            end,
            order = 1
        },
        orientationHeader = {
            type = "header",
            name = "Orientation",
            order = 2
        },
        orientation = {
            type = "select",
            name = "Orientation",
            desc = "Set the orientation of the mana bar.",
            values = {
                ["HORIZONTAL"] = "Horizontal",
                ["VERTICAL"] = "Vertical"
            },
            set = function(info, val)
                ManaBar:SetOrientation(val)
                ManaMeterDB.profile.orientation = val

                if val == "VERTICAL" then
                    ManaMeterFrame:SetSize(ManaMeterDB.profile.barThickness + 24, ManaMeterDB.profile.barWidth)
                    ManaBar:SetSize(ManaMeterDB.profile.barThickness, ManaMeterDB.profile.barWidth - 24)
                else
                    ManaMeterFrame:SetSize(ManaMeterDB.profile.barWidth, ManaMeterDB.profile.barThickness + 24)
                    ManaBar:SetSize(ManaMeterDB.profile.barWidth - 24, ManaMeterDB.profile.barThickness)
                end
            end,
            get = function(info)
                return ManaMeterDB.profile.orientation
            end,
            order = 3
        },
        appearanceHeader = {
            type = "header",
            name = "Appearance",
            order = 4
        },
        barSize = {
            type = "range",
            name = "Bar Length",
            desc = "Adjust the width of the mana bar.",
            min = 10,
            max = 400,
            step = 1,
            set = function(info, val)
                ManaMeterFrame:SetWidth(val)
                ManaBar:SetWidth(val - 24) -- Adjusting for the border size
                ManaMeterDB.profile.barWidth = val
            end,
            get = function(info)
                return ManaMeterDB.profile.barWidth
            end,
            order = 5
        },
        barThickness = {
            type = "range",
            name = "Bar Thickness",
            desc = "Adjust the thickness (height) of the mana bar.",
            min = 5,
            max = 100,
            step = 1,
            set = function(info, val)
                ManaMeterFrame:SetHeight(val + 24) -- Adjusting for the border size
                ManaBar:SetHeight(val)
                ManaMeterDB.profile.barThickness = val
            end,
            get = function(info)
                return ManaMeterDB.profile.barThickness
            end,
            order = 6
        },
        displayOptionsHeader = {
            type = "header",
            name = "Display Options",
            order = 7
        },
        showPercentage = {
            type = "toggle",
            name = "Show Percentage",
            desc = "Toggle the display of the mana percentage on the bar.",
            set = function(info, val)
                ManaMeterDB.profile.showPercentage = val
                if val then
                    ManaPercentage:Show()
                else
                    ManaPercentage:Hide()
                end
            end,
            get = function(info)
                return ManaMeterDB.profile.showPercentage
            end,
            order = 8
        },
        percentageSize = {
            type = "range",
            name = "Percentage Font Size",
            desc = "Adjust the font size of the percentage display.",
            min = 8,
            max = 32,
            step = 1,
            set = function(info, val)
                ManaPercentage:SetFont(ManaPercentage:GetFont(), val)
                ManaMeterDB.profile.percentageSize = val
            end,
            get = function(info)
                return ManaMeterDB.profile.percentageSize or 12 -- Default to 12 if not set
            end,
            order = 9
        },
        lowManaAlertHeader = {
            type = "header",
            name = "Low Mana Alert",
            order = 10
        },
        lowManaAlertToggle = {
            type = "toggle",
            name = "Enable Low Mana Alert",
            desc = "Toggle the low mana alert sound.",
            set = function(info, val)
                ManaMeterDB.profile.lowManaAlert.enabled = val
            end,
            get = function(info)
                return ManaMeterDB.profile.lowManaAlert.enabled
            end,
            order = 11
        },
        lowManaAlertThreshold = {
            type = "range",
            name = "Alert Threshold",
            desc = "Set the mana percentage at which the alert sound should play.",
            min = 5,
            max = 50,
            step = 1,
            set = function(info, val)
                ManaMeterDB.profile.lowManaAlert.threshold = val
            end,
            get = function(info)
                return ManaMeterDB.profile.lowManaAlert.threshold
            end,
            order = 12
        },
        soundSelection = {
            type = "select",
            name = "Alert Sound",
            desc = "Choose the sound to play when the mana threshold is reached.",
            values = {
                ["Sound1"] = "Sheldon",
                ["Sound2"] = "Target Acquired",
                ["Sound3"] = "ReadyCheck",
                ["Sound4"] = "Buzzer",
                ["Sound5"] = "Arrow Swoosh"
            },
            set = function(info, val)
                ManaMeterDB.profile.lowManaAlert.sound = val
                local soundPath = soundPaths[val]
                if soundPath then
                    PlaySoundFile(soundPath)
                end
            end,
            get = function(info)
                return ManaMeterDB.profile.lowManaAlert.sound
            end,
            order = 13
        },
        lowManaMessageSelection = {
            type = "select",
            name = "Low Mana Message",
            desc = "Choose the message to send when mana is low.",
            values = {
                ["Message1"] = "My mana is running low!",
                ["Message2"] = "I'm almost out of mana!",
                ["Message3"] = "Mana is getting critical!",
                ["Message4"] = "Need mana soon!",
                ["Message5"] = "Mana is depleting!"
            },
            set = function(info, val)
                ManaMeterDB.profile.lowManaAlert.message = val
            end,
            get = function(info)
                return ManaMeterDB.profile.lowManaAlert.message
            end,
            order = 14
        },
        sendMessageToggle = {
            type = "toggle",
            name = "Send Low Mana Message",
            desc = "Toggle sending a message in instance chat when mana is low.",
            set = function(info, val)
                ManaMeterDB.profile.lowManaAlert.sendMessage = val
            end,
            get = function(info)
                return ManaMeterDB.profile.lowManaAlert.sendMessage
            end,
            order = 15
        }
    }
}

-- Register the options table
AceConfig:RegisterOptionsTable("ManaMeter", options)

-- Add to the Interface Options
AceConfigDialog:AddToBlizOptions("ManaMeter", "ManaMeter")


















