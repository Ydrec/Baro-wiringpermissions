if Game.IsSingleplayer then return end

-- local VanillaPermissionsTypes = {
--     "None",
--     "ManageRound",
--     "Kick",
--     "Ban",
--     "Unban",
--     "SelectSub",
--     "SelectMode",
--     "ManageCampaign",
--     "ConsoleCommands",
--     "ServerLog",
--     "ManageSettings",
--     "ManagePermissions",
--     "KarmaImmunity",
--     "ManageMoney",
--     "SellInventoryItems",
--     "SellSubItems",
--     "ManageMap",
--     "ManageHires",
--     "ManageBotTalents",
--     "SpamImmunity",
--     "All"
-- }



local CustomPermission = "ChangeWiring"


--example of how its formatted internally
AccountsWithCustomPermission = {
    --["STEAM_1:1:76708553"] = "Ydrec"
}

--lua for acc, name in pairs(AccountsWithCustomPermission) do print(acc, ' : ', name) end


--All of these lines are for console so no localization for them
local GivePermissionStr = "Granted ChangeWiring permissions to "
--local GivePermissionAllStr = "Granted All permissions to "
local RevokePermissionStr = "Revoked ChangeWiring permissions from "
--local RevokePermissionAllStr = "Revoked All permissions from "
local CantRevokeOwnerStr = "Cannot revoke permissions from the server owner!"
local ChangeWiringPermissionStr = " - " .. CustomPermission

local PermLocStr = TextManager.Get("clientpermission." .. string.lower(CustomPermission))
local PermDescriptionLocStr = TextManager.Get("clientpermission." .. string.lower(CustomPermission) .. ".description")
local NoAccessLocStr = TextManager.Get("clientpermission." .. string.lower(CustomPermission) .. ".noaccessmsg")

local NoAccessMsg = ChatMessage.Create("", NoAccessLocStr.Value, ChatMessageType.Server, nil, nil, nil, Color.Red)
local CantRevokeOwnerMsg = ChatMessage.Create("", CantRevokeOwnerStr, ChatMessageType.Console, nil, nil, nil, Color.Red)
local ChangeWiringPermissionMsg = ChatMessage.Create("", ChangeWiringPermissionStr, ChatMessageType.Console, nil, nil, nil, Color.White)



zapAfflictions = {
    AfflictionPrefab.Prefabs[Identifier("stun")].Instantiate(0.0),
    AfflictionPrefab.Prefabs[Identifier("electricshock")].Instantiate(20),
    AfflictionPrefab.Prefabs[Identifier("burn")].Instantiate(5)
}

local function zap(character)
    local limb = character.AnimController.GetLimb(LimbType.Torso)
    for affliction in zapAfflictions do
        character.CharacterHealth.ApplyAffliction(limb, affliction, true, false, true)
    end
    Networking.CreateEntityEvent(client.Character, CharacterStatusEventData(true))
end



local function deselect(character)
    character.SelectedItem = nil
    --character.UpdateNetInput()
end



local MessageCD = false

local function HasWiringPerms(client)
    if AccountsWithCustomPermission[tostring(client.AccountId)] or client.HasPermission(ClientPermissions.All) then return true end
    --Sent back networking messages may cause false triggering so just wait them out
    --This message with CD should be its own function tbh
    if not MessageCD then
        Game.Server.SendDirectChatMessage(NoAccessMsg, client)
        MessageCD = true
        Timer.Wait(function() 
            MessageCD = false
        end,3000)
    end
    return false
end



--Allow wiring in wrecks and abandoned outposts. Mostly to allow deattaching stuff from walls and to fix beacons.
local function IsItemInFriendlySub(item, character)
    --print(item.Submarine.TeamID)
    character = character or nil
    if character and character.TeamID == item.Submarine.TeamID then
        return true
    elseif item.InPlayerSubmarine then
        return true
    end
    return item.Submarine.TeamID == CharacterTeamType.FriendlyNPC
end


-- local LogMessageType = {
--     Deattach = "",
--     Rewire = "",
--     CircuitBox = "",
--     Property = ""
-- }

-- local LogCD = false

-- local function LogMessage(messageType, client, item, opcode)
--     opcode = opcode or nil
--     if not LogCD then
--         Game.Log(tostring(client.Name) .. LogMessageType[messageType] .. tostring(instance.Item), ServerLogMessageType.Wiring)
--         LogCD = true
--         Timer.Wait(function() 
--             LogCD = false
--         end,1000)
--     end
--     return false
-- end



local CharacterClientTable = {}

local function RebuildCharacterClientTable()
    CharacterClientTable = {}
    for client in Client.ClientList do
        CharacterClientTable[client.Character.ID] = client
    end
end

--clientside doesnt have DebugConsole.FindClient so had to make my own
--identifier can be client.Name Or tostring(client.SessionId) Or tostring(client.AccountId) Or client.character.ID
local function FindClient(identifier, alreadyrebuild)
    local alreadyrebuild = alreadyrebuild or false
    if not identifier then return end
    --print("%%%:", LuaUserData.TypeOf(identifier))
    if LuaUserData.IsTargetType(identifier, "System.String") then
        for client in Client.ClientList do
            if client.SessionOrAccountIdMatches(identifier) or client.Name == identifier then
                return client
            end
        end
    else
        if CharacterClientTable[identifier] or alreadyrebuild then
            return CharacterClientTable[identifier]
        else
            RebuildCharacterClientTable()
            return FindClient(identifier, true)
        end
    end

end



local function TblContainsStr(table, targetstr)
    for str in table do
        if tostring(str) == targetstr then return true end
    end
    return false
end



local function TblContainsValue(table, targetvalue) 
    for value in table do
        if value == targetvalue then return true end
    end
    return false
end 




local function printchildren(GUIComponent, indexstr)
    indexstr = indexstr or ""
    local i = 0
    if indexstr == "3, 0, 4, 1, 1" then return end
    for child in GUIComponent.Children do
        local istr = ""
        if indexstr == "" then
            istr = tostring(i)
        else
            istr = indexstr .. ", " .. tostring(i)
        end
        print(istr, ": ", child)
        if LuaUserData.IsTargetType(child, "Barotrauma.GUITextBlock") then print(child.Text) end
        if child.Children ~= nil then
            --print("\\/\\/\\/")
            printchildren(child, istr)
        end
        i = i + 1
    end
end



if CLIENT then

    LuaUserData.RegisterType("Barotrauma.TabMenu")
    LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.TabMenu'], 'moderatorIcon')

    LuaUserData.RegisterType("System.Collections.Generic.List`1[[Barotrauma.Identifier,BarotraumaCore]]")

    LuaUserData.MakeMethodAccessible(Descriptors['Barotrauma.Networking.GameClient'], 'SetMyPermissions')
    LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.Networking.GameClient'], 'permittedConsoleCommands')
    LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.Networking.GameClient'], 'permissions')



    Hook.Patch("WiringPerms_moderatorstar", 'Barotrauma.TabMenu', 'GetPermissionIcon', function(instance, ptable)
        if ptable["client"] and not ptable["client"].IsOwner and AccountsWithCustomPermission[tostring(ptable["client"].AccountId)] then
            ptable.PreventExecution = true
            return instance.moderatorIcon
        end
    end, Hook.HookMethodType.Before)



    Hook.Patch("WiringPerms_permsannouncement", 'Barotrauma.Networking.GameClient', 'SetMyPermissions', function(instance, ptable)
        if not Game.Client or not Game.Client.MyClient then return end
        if not (Game.Client.MyClient.HasPermission(ClientPermissions.All) or AccountsWithCustomPermission[tostring(Game.Client.MyClient.AccountId)]) then return end
        local GUImsgBox = nil
        for msgBox in GUI.MessageBox.MessageBoxes do
            if tostring(msgBox.UserData) and tostring(msgBox.UserData) == "permissions" then
                GUImsgBox = msgBox
                break
            end
        end
        if not GUImsgBox then return end
        -- printchildren(GUImsgBox)
        -- local GUIpermissionArea = GUImsgBox.GetChild(Int32(0)).GetChild(Int32(0)).GetChild(Int32(1))
        local GUIleftColumn = GUImsgBox.GetChild(Int32(0)).GetChild(Int32(0)).GetChild(Int32(1)).GetChild(Int32(0))
        local GUIpermissionsLabel = GUImsgBox.GetChild(Int32(0)).GetChild(Int32(0)).GetChild(Int32(1)).GetChild(Int32(0)).GetChild(Int32(0))
        local GUIPermsTextBox = GUImsgBox.GetChild(Int32(0)).GetChild(Int32(0)).GetChild(Int32(1)).GetChild(Int32(0)).GetChild(Int32(1))
        if not GUIPermsTextBox then 
            GUIpermissionsLabel.Text = TextManager.Get("CurrentPermissions")
            GUIpermissionsLabel.Font = GUI.Style.SubHeadingFont
            -- GUIpermissionsLabel.Wrap = true
            -- GUIpermissionsLabel.CalculateHeightFromText()
            local permissionList = tostring(LocalizedString.EmptyString)
            -- GUIPermsTextBox = GUI.TextBlock(GUI.RectTransform(Vector2(Int32(1), Int32(0)), GUIleftColumn.RectTransform), permissionList)
            GUIPermsTextBox = GUI.TextBlock(GUIleftColumn.RectTransform, permissionList)
            -- GUIPermsTextBox.RectTransform.RecalculateAnchorPoint()
            -- GUIPermsTextBox.ImmediateFlash(Color.Red)

            -- local permissionAreaHeight = 0
            -- for child in GUIleftColumn.RectTransform.Children do
            --     permissionAreaHeight = permissionAreaHeight + child.Rect.Height
            -- end

            -- local contentHeight = 0
            -- for child in GUImsgBox.Content.RectTransform.Children do
            --     contentHeight = contentHeight + child.Rect.Height
            -- end
            -- contentHeight = (contentHeight + GUImsgBox.Content.AbsoluteSpacing) * 1.05

            -- GUIpermissionArea.RectTransform.IsFixedSize = false
            -- GUIpermissionArea.RectTransform.MinSize = Point(0, Int32(permissionAreaHeight))
            -- GUIpermissionArea.RectTransform.IsFixedSize = true


            -- GUImsgBox.Content.ChildAnchor = GUI.Anchor.TopCenter
            -- GUImsgBox.Content.Stretch = true
            -- GUImsgBox.Content.RectTransform.MinSize = Point(0, Int32(contentHeight))
            -- GUImsgBox.InnerFrame.RectTransform.MinSize = Point(0, Int32(contentHeight / GUIpermissionArea.RectTransform.RelativeSize.Y / GUImsgBox.Content.RectTransform.RelativeSize.Y))
        end

        if string.find(tostring(GUIPermsTextBox.Text), PermLocStr.Value) then return end
        local permissionLines = {}
        local added = false
        for line in string.gmatch(tostring(GUIPermsTextBox.Text), "[^\r\n]+") do
            if string.find(line, tostring(TextManager.Get("clientpermission.all"))) then table.insert(permissionLines, "   - " .. PermLocStr.Value) added = true end
            table.insert(permissionLines, line)
        end
        if not added then table.insert(permissionLines, "   - " .. PermLocStr.Value) end

        GUIPermsTextBox.Text = table.concat(permissionLines, "\n")
        GUImsgBox.RectTransform.RecalculateChildren(true,true)
    end, Hook.HookMethodType.After)
    


    --cl_lua Game.NetLobbyScreen.PlayerFrame.GetChild(Int32(3)).GetChild(Int32(0)).GetChild(Int32(4)).GetChild(Int32(0)).GetChild(Int32(1)).GetChild(Int32(0)).GetChild(Int32(0)).ImmediateFlash(Color.Red)
    --cl_lua print(Game.NetLobbyScreen.PlayerFrame.GetChild(Int32(3)).GetChild(Int32(0)).GetChild(Int32(4)).GetChild(Int32(0)).GetChild(Int32(1)).GetChild(Int32(0)).GetChild(Int32(0)))

    Hook.Patch("WiringPerms_managepermsmenu", 'Barotrauma.NetLobbyScreen', 'SelectPlayer', {"Barotrauma.Networking.Client"}, function(instance, ptable)
        if not instance.PlayerFrame.GetChild(Int32(3)).GetChild(Int32(0)).GetChild(Int32(4)) then return end
        local GUIpermissionsList = instance.PlayerFrame.GetChild(Int32(3)).GetChild(Int32(0)).GetChild(Int32(4)).GetChild(Int32(0)).GetChild(Int32(1))
        local GUIrankDropDown = instance.PlayerFrame.GetChild(Int32(3)).GetChild(Int32(0)).GetChild(Int32(2))

        -- local targetclient = Game.NetLobbyScreen.PlayerFrame.UserData
        local targetclient = ptable["selectedClient"]
        if targetclient == nil then return end
        -- printchildren(Game.NetLobbyScreen.PlayerFrame)
        -- AllTickBox = instance.PlayerFrame.GetChild(Int32(3)).GetChild(Int32(0)).GetChild(Int32(4)).GetChild(Int32(0)).GetChild(Int32(0))
        -- local AllOnSelected = AllTickBox.OnSelected
        -- AllTickBox.OnSelected = function() AllOnSelected.Invoke(AllTickBox) end

        local ChangeWiringTickBox = GUI.TickBox(GUI.RectTransform(Vector2(0.15, 0.15), GUIpermissionsList.Content.RectTransform), PermLocStr, GUI.Style.SmallFont)
        ChangeWiringTickBox.UserData = "ChangeWiring"
        ChangeWiringTickBox.ToolTip = PermDescriptionLocStr
        ChangeWiringTickBox.Selected = AccountsWithCustomPermission[tostring(targetclient.AccountId)] ~= nil
        ChangeWiringTickBox.Selected = ChangeWiringTickBox.Selected or targetclient.HasPermission(ClientPermissions.All)
        --print(targetclient.SessionId, " = ", Game.Client.SessionId)
        ChangeWiringTickBox.Enabled = targetclient.SessionId ~= Game.Client.SessionId --cant change perms for your own client
        ChangeWiringTickBox.OnSelected = function()
            GUIrankDropDown.SelectItem(nil)
            --local targetclient = Game.NetLobbyScreen.PlayerFrame.UserData
            --if not targetclient or not LuaUserData.IsTargetType(targetclient, "Barotrauma.Networking.Client") then return false end

            if ChangeWiringTickBox.Selected then
                AccountsWithCustomPermission[tostring(targetclient.AccountId)] = tostring(targetclient.Name)
            else
                AccountsWithCustomPermission[tostring(targetclient.AccountId)] = nil
            end


            local msg = Networking.Start("WiringPerms_UpdatePermission")
            msg.WriteString(targetclient.AccountId)
            msg.WriteBoolean(AccountsWithCustomPermission[tostring(targetclient.AccountId)] ~= nil)
            Networking.Send(msg)

            if ChangeWiringTickBox.Enabled then
                Game.Client.UpdateClientPermissions(targetclient)
            end
            return true
        end
    end, Hook.HookMethodType.After)



    Networking.Receive("WiringPerms_UpdatePermission", function(msg)
        local accid = msg.ReadString()
        local state = msg.ReadBoolean()
        local changed = state ~= ((AccountsWithCustomPermission[accid] ~= nil) or Game.Client.HasPermission(ClientPermissions.All))
        if state then
            AccountsWithCustomPermission[accid] = FindClient(accid) and FindClient(accid).Name or "?"
        else
            AccountsWithCustomPermission[accid] = nil
        end

        --print(tostring(Game.Client.MyClient.AccountId)," % ", accid)
        --print(Game.Client.MyClient.AccountId)
        if not Game.Client or not Game.Client.MyClient then return end
        if changed and tostring(Game.Client.MyClient.AccountId) == accid then
            --make game show new permissions message by faking a command as permissions themselves are immutable
            local augTable = {}
            for identifier in Game.Client.permittedConsoleCommands do
                table.insert(augTable,identifier)
            end
            table.insert(augTable,Identifier(" "))
            
            Game.Client.SetMyPermissions(Game.Client.permissions, augTable)
            Game.Client.permittedConsoleCommands.Remove(Identifier(" "))
        end
    end)
end



if SERVER then

    LuaUserData.RegisterType("Barotrauma.Items.Components.Holdable+AttachEventData")
    AttachEventData = LuaUserData.CreateStatic('Barotrauma.Items.Components.Holdable+AttachEventData', true)

    LuaUserData.RegisterType('Barotrauma.Character+CharacterStatusEventData') 
    CharacterStatusEventData = LuaUserData.CreateStatic('Barotrauma.Character+CharacterStatusEventData', true)

    CircuitBoxOpcode = LuaUserData.CreateEnumTable("Barotrauma.CircuitBoxOpcode")

    MapEntityCategory = LuaUserData.CreateEnumTable("Barotrauma.MapEntityCategory")

    DebugConsole = LuaUserData.CreateStatic("Barotrauma.DebugConsole")
    LuaUserData.MakeMethodAccessible(Descriptors['Barotrauma.DebugConsole'], 'FindClient')

    --LuaUserData.MakeMethodAccessible(Descriptors['Barotrauma.Networking.GameServer'], 'ClientWriteIngame')
    --LuaUserData.MakeMethodAccessible(Descriptors['Barotrauma.Character'], 'UpdateNetInput')

    LuaUserData.MakeMethodAccessible(Descriptors['Barotrauma.Items.Components.Pickable'], 'StopPicking')
    LuaUserData.MakeMethodAccessible(Descriptors['Barotrauma.Items.Components.Holdable'], 'StopPicking')

    LuaUserData.RegisterType("Barotrauma.ColoredText")
    LuaUserData.RegisterType("System.Collections.Concurrent.ConcurrentQueue`1[[Barotrauma.ColoredText]]")
    LuaUserData.MakeFieldAccessible(Descriptors['Barotrauma.DebugConsole'], 'queuedMessages')
    LuaUserData.MakeMethodAccessible(Descriptors['Barotrauma.DebugConsole'], 'NewMessage', {
        "System.String",
        "Microsoft.Xna.Framework.Color",
        "System.Boolean",
        "System.Boolean"
    })



    local function SendPermissionUpdate(targetclient, reciverclient)
        local msg = Networking.Start("WiringPerms_UpdatePermission")
        msg.WriteString(targetclient.AccountId)
        msg.WriteBoolean(AccountsWithCustomPermission[tostring(targetclient.AccountId)] ~= nil)
        if reciverclient ~= nil then
            Networking.Send(msg, client.Connection)
        else
            Networking.Send(msg)
        end
    end



    --Technically unnecessary but for visual sync network AccountsWithCustomPermission
    Networking.Receive("WiringPerms_UpdatePermission", function(msg, sender)
        if not sender.HasPermission(ClientPermissions.ManagePermissions) then return end
        local targetclient = DebugConsole.FindClient(msg.ReadString())
        if msg.ReadBoolean() then
            AccountsWithCustomPermission[tostring(targetclient.AccountId)] = tostring(targetclient.Name)
        else
            AccountsWithCustomPermission[tostring(targetclient.AccountId)] = nil
        end
        SendPermissionUpdate(targetclient)
    end)



    Hook.Add("client.connected", "WiringPerms_syncnewclient", function(connectedClient)
        for accid, name in pairs(AccountsWithCustomPermission) do
            local msg = Networking.Start("WiringPerms_UpdatePermission")
            msg.WriteString(accid)
            msg.WriteBoolean(AccountsWithCustomPermission[accid] ~= nil)
            Networking.Send(msg, connectedClient.Connection)   
        end
    end)



    Hook.Patch("WiringPerms_serverpermslist", 'Barotrauma.DebugConsole+Command', 'Execute', function(instance, ptable)
        if TblContainsStr(instance.Names, "giveperm")  then
            local queuedMessages = DebugConsole.queuedMessages.ToArray()
            DebugConsole.queuedMessages.Clear()
            for msg in queuedMessages do
                if msg.Text == " - All" then DebugConsole.NewMessage(ChangeWiringPermissionStr, msg.Color, msg.IsCommand, msg.IsError) end
                DebugConsole.NewMessage(msg.Text, msg.Color, msg.IsCommand, msg.IsError)
            end
        end
    end, Hook.HookMethodType.After)

    Hook.Patch("WiringPerms_logpermissionchange", 'Barotrauma.Networking.GameServer', 'Log', function(instance, ptable)
        if ptable["messageType"] ~= ServerLogMessageType.ServerMessage then return end
        local line = ptable["line"]
        --local lineindex = string.find(line, "set the permissions of the client "PlayerB" to ") or string.find(line, "removed all permissions")
        if string.find(line, "set the permissions") then
            local clientToName = string.match(line, "the client \"(.-)[%.-\"]")
            local clientTo = FindClient(string.match(clientToName, "‖.-‖(.-)‖end‖"))
            if clientTo and AccountsWithCustomPermission[tostring(clientTo.AccountId)] then
                ptable["line"] = line .. ", " .. CustomPermission
                --local newlogMsg = "Client \"" .. clientWho .. "\" set the permissions of the client \"" .. clientTo .. "\" to " .. "ALPHA"
                --ptable["line"] = newlogMsg
            end
        elseif string.find(line, "removed all permissions") then
            local clientToName = string.match(line, "the client \"(.-)[%.-\"]")
            local clientWhoName = string.match(line, "Client \"(.-)\"")
            
            --print(clientWhoName, ", ", clientToName)
            local clientTo = FindClient(string.match(clientToName, "‖.-‖(.-)‖end‖"))
            if clientTo and AccountsWithCustomPermission[tostring(clientTo.AccountId)] then
                local newlogMsg = "Client \"" .. clientWhoName .. "\" set the permissions of the client \"" .. clientToName .. "\" to " .. CustomPermission
                ptable["line"] = newlogMsg
            end
        end

    end, Hook.HookMethodType.Before)



    -- wire components break ChangePropertyEventData by having different amount of properties on client/server
    -- dockinghatch has wire component so its guranteed fucked 
    -- update: okay fuck spamming lock events, seems like sending this only to one client would require building custom net msg from zero,yuck
    -- No free DDOS for this Chrismas
    -- function lockitems(index)
    --     eventspercycle = 10
    --     local events = 0
    --     local i = 1
    --     while events < eventspercycle do
    --         local item = Item.ItemList[index+i]
    --         if item == nil then print("finished locking items") return end
    --         local connectionpanel = item.GetComponent(Components.ConnectionPanel)
    --         if connectionpanel and not (tostring(item.Prefab.Identifier) == "dockinghatch") then
    --             connectionpanel.Locked = true
    --             Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(connectionpanel.SerializableProperties[Identifier("Locked")], connectionpanel))
    --             events = events + 1
    --         end
    --         i = i + 1
    --     end
    --     Timer.Wait(function()
    --         lockitems(index+i-1)
    --     end,50)
    -- end


    -- function lockitemsinstant()
    --     for item in Item.ItemList do
    --         local connectionpanel = item.GetComponent(Components.ConnectionPanel)
    --         if connectionpanel and not (tostring(item.Prefab.Identifier) == "dockinghatch") then
    --             connectionpanel.Locked = true
    --             Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(connectionpanel.SerializableProperties[Identifier("Locked")], connectionpanel))
    --         end
    --     end
    --     print("finished instantly locking items")
    -- end

    --lockitemsinstant()
    --lockitems(0)



    Hook.Patch("WiringPerms_connectionpanel", 'Barotrauma.Items.Components.ConnectionPanel', 'ServerEventRead', function(instance, ptable)
        local client = ptable["c"]
        if not IsItemInFriendlySub(instance.Item, client.Character) then return end
        if not HasWiringPerms(client) then
            --zap(ptable["c"].Character)
            deselect(client.Character)
            ptable.PreventExecution = true
            Game.Log(tostring(client.Name) .. " attempted to change wiring in " .. tostring(instance.Item), ServerLogMessageType.Wiring)
        end
        return
    end, Hook.HookMethodType.Before)



    --look but no change
    AllowedOpcodes = {
        CircuitBoxOpcode.Cursor,
        CircuitBoxOpcode.SelectComponents,
        CircuitBoxOpcode.SelectWires,
        CircuitBoxOpcode.UpdateSelection
    }

    OpcodeStrings = {
        [CircuitBoxOpcode.Error] = "Error",
        [CircuitBoxOpcode.Cursor] = "Move cursor",
        [CircuitBoxOpcode.AddComponent] = "Add component",
        [CircuitBoxOpcode.MoveComponent] = "Move component",
        [CircuitBoxOpcode.AddWire] = "Add wire",
        [CircuitBoxOpcode.RemoveWire] = "Remove wire",
        [CircuitBoxOpcode.SelectComponents] = "Select component",
        [CircuitBoxOpcode.SelectWires] = "Select wires",
        [CircuitBoxOpcode.UpdateSelection] = "Update selection",
        [CircuitBoxOpcode.DeleteComponent] = "Delete component",
        [CircuitBoxOpcode.RenameLabel] = "Rename label",
        [CircuitBoxOpcode.AddLabel] = "Add label",
        [CircuitBoxOpcode.RemoveLabel] = "Remove label",
        [CircuitBoxOpcode.ResizeLabel] = "Resize label",
        [CircuitBoxOpcode.RenameConnections] = "Rename connecitons",
        [CircuitBoxOpcode.ServerInitialize] = "Server intitialize"
    }

    local TemporarilyLocked = false
    Hook.Patch("WiringPerms_circuitbox_before", 'Barotrauma.Items.Components.CircuitBox', 'ServerEventRead', function(instance, ptable)
        local client = ptable["c"]
        if not IsItemInFriendlySub(instance.Item, client.Character) then return end
        local msg = ptable["msg"]

        --this seems to sometimes cause horrific crash idk why, sever doesnt even make crashlog and client crashlog is junk
        WiringPerms_Opcode = msg.PeekByte()
        --bitpos = msg.BitPosition
        --Opcode = msg.ReadByte()
        --msg.BitPosition = bitpos

        if not TblContainsValue(AllowedOpcodes, WiringPerms_Opcode) then
            if not HasWiringPerms(client) then
                instance.Item.NonInteractable = true
                TemporarilyLocked = true
                --zap(ptable["c"].Character)
                deselect(client.Character)
                --ptable.PreventExecution = true
                Game.Log(tostring(client.Name) .. " attempted to " .. OpcodeStrings[WiringPerms_Opcode] .. " in " .. tostring(instance.Item), ServerLogMessageType.Wiring)
            end
        end
        return
    end, Hook.HookMethodType.Before)



    Hook.Patch("WiringPerms_circuitbox_after", 'Barotrauma.Items.Components.CircuitBox', 'ServerEventRead', function(instance, ptable)
        if TemporarilyLocked then
            instance.Item.NonInteractable = false
            TemporarilyLocked = false
        end
    end, Hook.HookMethodType.After)



    --returning true to this exits original method early
    Hook.Add("item.readPropertyChange", "WiringPerms_propertychange", function(item, property, parentObject, allowEditing, client)
        --if not attached and not contained in circuitbox skip
        --some items have toggles while holding/wearing
        if  item == nil then return end
        if not IsItemInFriendlySub(item, client.Character) then return end
        if (item.GetComponent(Components.Pickable) and not item.GetComponent(Components.Pickable).IsAttached) and
            (item.Container and not item.Container.GetComponentString("CircuitBox"))
        then return end
        local cBox = (item.Container and item.Container.GetComponentString("CircuitBox")) or nil
        if item.Prefab.Category == MapEntityCategory.Electrical then
            Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(property, parentObject))
            if not HasWiringPerms(client) then
                --zap(client.Character)
                deselect(client.Character)
                if cBox then
                    Game.Log(tostring(client.Name) .. " attempted to change propery " .. tostring(property.Name) .. " of " .. tostring(item) .. " in a " .. tostring(cBox.Item), ServerLogMessageType.Wiring)
                else
                    Game.Log(tostring(client.Name) .. " attempted to change propery " .. tostring(property.Name) .. " of " .. tostring(item), ServerLogMessageType.Wiring)
                end
                return true
            end
        end
        return
    end)

local deattchLogCD = 0
local lastPicker = nil

    Hook.Patch("WiringPerms_deattach", 'Barotrauma.Items.Components.Pickable', 'Pick', function(instance, ptable)
        local picker = ptable["picker"]
        if not picker.IsPlayer then return end
        if not IsItemInFriendlySub(instance.Item, picker) then return end
        if instance.IsAttached and instance.Item.Prefab.Category == MapEntityCategory.Electrical then
            client = FindClient(picker.ID)
            if (not client) or (HasWiringPerms(client)) then return end
            instance.StopPicking(picker)
            Networking.CreateEntityEvent(instance.Item, Item.ComponentStateEventData.__new(instance, AttachEventData.__new(Vector2.Zero,picker)))
            --zap(client.Character)
            deselect(picker)
            ptable.PreventExecution = true

            --This was too spammable
            if Timer.GetTime() > deattchLogCD or picker ~= lastPicker then
                Game.Log(tostring(client.Name) .. " attempted to deattach " .. tostring(instance.Item), ServerLogMessageType.Wiring)
                lastPicker = picker
                deattchLogCD = Timer.GetTime() + 3
            end
        end
        return
    end, Hook.HookMethodType.Before)



    --These hooks should be self sufient and not cause conflicts even if multiple mods reuse this as long as hooks are named differently
    Hook.Patch("WiringPerms_serverexecute", 'Barotrauma.DebugConsole+Command', 'Execute', function(instance, ptable)
        if TblContainsStr(instance.Names, "giveperm") then
            local perm = ptable["args"][2] and string.lower(ptable["args"][2])
            if perm == string.lower(CustomPermission) or perm == string.lower("All") then
                local targetclient = DebugConsole.FindClient(ptable["args"][1])
                if not targetclient then return end

                AccountsWithCustomPermission[tostring(targetclient.AccountId)] = tostring(targetclient.Name)
                
                if perm == string.lower(CustomPermission) then
                    ptable.PreventExecution = true
                    DebugConsole.NewMessage(GivePermissionStr .. targetclient.Name  .. ".", Color.White)
                end
                
                --Doesn't seem like game logs permission changes
                --Game.Log("Gave Wiring permissions to " .. targetclient.Name , ServerLogMessageType.Wiring)
                SendPermissionUpdate(targetclient)
                --Networking.UpdateClientPermissions(targetclient)
            end
        elseif TblContainsStr(instance.Names, "revokeperm") then
            local perm = ptable["args"][2] and string.lower(ptable["args"][2])
            if perm == string.lower(CustomPermission) or perm == string.lower("All") then
                local targetclient = DebugConsole.FindClient(ptable["args"][1])
                if (not targetclient) or targetclient.Connection == Game.Server.OwnerConnection then return end

                AccountsWithCustomPermission[tostring(targetclient.AccountId)] = nil

                if perm == string.lower(CustomPermission) then
                    ptable.PreventExecution = true
                    DebugConsole.NewMessage(RevokePermissionStr .. targetclient.Name  .. ".", Color.White)
                end
                
                SendPermissionUpdate(targetclient)
                --Networking.UpdateClientPermissions(targetclient)
            end
        end
    end, Hook.HookMethodType.Before)



    Hook.Patch("WiringPerms_clientrequestexecute", 'Barotrauma.DebugConsole+Command', 'ServerExecuteOnClientRequest', function(instance, ptable)
        if TblContainsStr(instance.Names, "giveperm") then
            Game.Server.SendDirectChatMessage(ChangeWiringPermissionMsg, ptable["client"])
            local perm = ptable["args"][2] and string.lower(ptable["args"][2])
            if perm == string.lower(CustomPermission) or perm == string.lower("All") then
                local targetclient = DebugConsole.FindClient(ptable["args"][1])
                if not targetclient then return end

                AccountsWithCustomPermission[tostring(targetclient.AccountId)] = tostring(targetclient.Name)

                if perm == string.lower(CustomPermission) then
                    ptable.PreventExecution = true
                    local GivePermissionMsg = ChatMessage.Create("", GivePermissionStr .. tostring(targetclient.Name)  .. ".", ChatMessageType.Console, nil, nil, nil, Color.White)
                    Game.Server.SendDirectChatMessage(GivePermissionMsg, ptable["client"])
                end

                --Doesn't seem like game logs permission changes
                --Game.Log("Gave Wiring permissions to " .. targetclient.Name , ServerLogMessageType.Wiring)
                SendPermissionUpdate(targetclient)
                --Networking.UpdateClientPermissions(targetclient)
            end
        elseif TblContainsStr(instance.Names, "revokeperm") then
            --Game.Server.SendDirectChatMessage(ChangeWiringPermissionMsg, ptable["client"])
            local perm = ptable["args"][2] and string.lower(ptable["args"][2])
            if perm == string.lower(CustomPermission) or perm == string.lower("All") then
                local targetclient = DebugConsole.FindClient(ptable["args"][1])
                if (not targetclient) or targetclient == Game.Server.OwnerConnection then return end

                AccountsWithCustomPermission[tostring(targetclient.AccountId)] = nil
                
                if perm == string.lower(CustomPermission) then
                    ptable.PreventExecution = true
                    local RevokePermissionMsg = ChatMessage.Create("", RevokePermissionStr .. tostring(targetclient.Name)  .. ".", ChatMessageType.Console, nil, nil, nil, Color.White)
                    Game.Server.SendDirectChatMessage(RevokePermissionMsg, ptable["client"])
                end
                
                SendPermissionUpdate(targetclient)
                --Networking.UpdateClientPermissions(targetclient)
                
            end
        end
        return
    end, Hook.HookMethodType.Before)



    Hook.Patch("WiringPerms_saveperms", 'Barotrauma.Networking.ServerSettings', 'SaveClientPermissions', function(instance, ptable)
        if File.Exists(Game.ServerSettings.ClientPermissionsFile) then
            local PermissionsDoc = XDocument.Load(Game.ServerSettings.ClientPermissionsFile)
            
            for accid, name in pairs(AccountsWithCustomPermission) do
                local clientElement = nil
                for element in PermissionsDoc.Root.Elements() do

                    if accid == element.GetAttributeString("accountid") then
                        clientElement = element
                        break
                    end
                end

                if clientElement then
                    local permissions = clientElement.GetAttributeString("permissions")
                    if not string.find(permissions, CustomPermission) then
                        clientElement.SetAttributeValue("permissions", permissions .. ", " .. CustomPermission)
                    end
                else
                    --if client has no other permissions they wouldnt have clientElement so we make one
                    if name ~= nil then
                        clientElement = XElement("Client", XAttribute("name", name))
                        clientElement.Add(XAttribute("accountid", accid))
                        clientElement.Add(XAttribute("permissions", CustomPermission))
                        PermissionsDoc.Root.Add(clientElement)
                    end
                end
            end

            PermissionsDoc.Save(Game.ServerSettings.ClientPermissionsFile)
        end
        return
    end, Hook.HookMethodType.After)



    Hook.Patch("WiringPerms_loadperms", 'Barotrauma.Networking.ServerSettings', 'LoadClientPermissions', function(instance, ptable)
        AccountsWithCustomPermission = {}

        if File.Exists(Game.ServerSettings.ClientPermissionsFile) then
            local PermissionsDoc = XDocument.Load(Game.ServerSettings.ClientPermissionsFile)

            for clientElement in PermissionsDoc.Root.Elements() do
                local permissions = clientElement.GetAttributeString("permissions")
                if string.find(permissions, "All") or string.find(permissions, CustomPermission) then
                    AccountsWithCustomPermission[clientElement.GetAttributeString("accountid")] = clientElement.GetAttributeString("name")

                    -- delete custom permissions from perms config file before game sees it 
                    -- or game gonna throw a fit and delete all permissions
                    local pattern = ""
                    if string.find(permissions, "^" .. CustomPermission) then
                        pattern =   CustomPermission .. ",?%s?"
                    else
                        pattern = ",?%s?" .. CustomPermission
                    end
                    local newpermissionStr = string.gsub(permissions, pattern, "")
                    if newpermissionStr == "" then newpermissionStr = "None" end
                    clientElement.SetAttributeValue("permissions", newpermissionStr)
                end
            end

            PermissionsDoc.Save(Game.ServerSettings.ClientPermissionsFile)
        end
        return
    end, Hook.HookMethodType.Before)



    --Save current permissions in case lua unexpectedly stops aka reloadlua 
    Hook.Add("stop", "WiringPerms_luastop", function ()
        Game.ServerSettings.SaveClientPermissions()
    end)

    --explicit load in case of reloadlua
    Game.ServerSettings.LoadClientPermissions()
end

