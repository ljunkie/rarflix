Function createSettingsScreen(item, viewController) As Object
    obj = CreateObject("roAssociativeArray")
    port = CreateObject("roMessagePort")
    screen = CreateObject("roListScreen")

    screen.SetMessagePort(port)
    screen.SetHeader(item.Title)

    ' Standard properties for all our screen types
    obj.Item = item
    obj.Screen = screen
    obj.Port = port
    obj.ViewController = viewController
    obj.MessageHandler = invalid
    obj.MsgTimeout = 0

    obj.Show = showSettingsScreen

    return obj
End Function

Sub showSettingsScreen()
    server = m.Item.server
    container = createPlexContainerForUrl(server, m.Item.sourceUrl, m.Item.key)
    settings = container.GetSettings()

    for each setting in settings
        title = setting.label
        value = setting.GetValueString()
        if value <> "" then
            title = title + ": " + value
        end if

        m.Screen.AddContent({title: title})
    next
    m.Screen.AddContent({title: "Close"})

    m.Screen.Show()

	while true 
        msg = wait(m.MsgTimeout, m.Port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roListScreenEvent" then
            if msg.isScreenClosed() then
                print "Exiting settings screen"
                m.ViewController.PopScreen(m)
                exit while
            else if msg.isListItemSelected() then
                if msg.GetIndex() < settings.Count() then
                    setting = settings[msg.GetIndex()]

                    modified = false

                    if setting.type = "text" then
                        screen = m.ViewController.CreateTextInputScreen("Enter " + setting.label, [], false)
                        screen.Screen.SetText(setting.value)
                        screen.Screen.SetSecureText(setting.hidden OR setting.secure)
                        screen.Show()

                        if screen.Text <> invalid then
                            setting.value = screen.Text
                            modified = true
                        end if
                    else if setting.type = "bool" then
                        screen = m.ViewController.CreateEnumInputScreen(["true", "false"], setting.value, setting.label, [])
                        if screen.SelectedValue <> invalid then
                            setting.value = screen.SelectedValue
                            modified = true
                        end if
                    else if setting.type = "enum" then
                        screen = m.ViewController.CreateEnumInputScreen(setting.values, setting.value.toint(), setting.label, [])
                        if screen.SelectedIndex <> invalid then
                            setting.value = screen.SelectedIndex.tostr()
                            modified = true
                        end if
                    end if

                    if modified then
                        server.SetPref(m.Item.key, setting.id, setting.value)
                        m.Screen.SetItem(msg.GetIndex(), {title: setting.label + ": " + setting.GetValueString()})
                    end if
                else if msg.GetIndex() = settings.Count() then
                    m.Screen.Close()
                end if
            end if
        end if
	end while
End Sub


'#######################################################
'Below are the preference Functions for the Global 
' Roku channel settings
'#######################################################
Function createPreferencesScreen(viewController) As Object
    obj = CreateObject("roAssociativeArray")
    port = CreateObject("roMessagePort")
    screen = CreateObject("roListScreen")

    screen.SetMessagePort(port)

    ' Standard properties for all our Screen types
    obj.Item = invalid
    obj.Screen = screen
    obj.Port = port
    obj.ViewController = viewController
    obj.MessageHandler = invalid
    obj.MsgTimeout = 0

    obj.Show = showPreferencesScreen

    obj.Changes = CreateObject("roAssociativeArray")
    obj.Prefs = CreateObject("roAssociativeArray")

    ' Quality settings
    qualities = [
        { title: "720 kbps, 320p", EnumValue: "Auto" },
        { title: "1.5 Mbps, 480p", EnumValue: "5" },
        { title: "2.0 Mbps, 720p", EnumValue: "6" },
        { title: "3.0 Mbps, 720p", EnumValue: "7" },
        { title: "4.0 Mbps, 720p", EnumValue: "8" },
        { title: "8.0 Mbps, 1080p", EnumValue: "9" }
    ]
    obj.Prefs["quality"] = {
        values: qualities,
        label: "Quality",
        heading: "Higher settings produce better video quality but require more" + Chr(10) + "network bandwidth.",
        default: "7"
    }

    ' H.264 Level
    levels = [
        { title: "Level 4.0 (Supported)", EnumValue: "40" },
        { title: "Level 4.1", EnumValue: "41" },
        { title: "Level 4.2", EnumValue: "42" },
        { title: "Level 5.0", EnumValue: "50" },
        { title: "Level 5.1", EnumValue: "51" }
    ]
    obj.Prefs["level"] = {
        values: levels,
        label: "H.264",
        heading: "Use specific H264 level. Only 4.0 is officially supported.",
        default: "40"
    }

    ' 5.1 Support
    fiveone = [
        { title: "Enabled", EnumValue: "1" },
        { title: "Disabled", EnumValue: "2" }
    ]
    obj.Prefs["fivepointone"] = {
        values: fiveone,
        label: "5.1 Support",
        heading: "5.1 audio support.",
        default: "1"
    }

    ' Direct play options
    directplay = [
        { title: "Automatic (recommended)", EnumValue: "0" },
        { title: "Direct Play", EnumValue: "1" },
        { title: "Direct Play w/ Fallback", EnumValue: "2" },
        { title: "Always Transcode", EnumValue: "3" }
    ]
    obj.Prefs["directplay"] = {
        values: directplay,
        label: "Direct Play",
        heading: "Direct Play preferences",
        default: "0"
    }

    obj.HandleEnumPreference = prefsHandleEnumPreference
    obj.GetEnumLabel = prefsGetEnumLabel

    ' This is a slightly evil amount of reaching inside another object...
    obj.myplex = viewController.Home.myplex

    return obj
End Function

Sub showPreferencesScreen()
    manifest = ReadAsciiFile("pkg:/manifest")
    lines = manifest.Tokenize(chr(10))
    aa = {}
    for each line in lines
        entry = line.Tokenize("=")
        aa.AddReplace(entry[0],entry[1])
    end for

	device = CreateObject("roDeviceInfo")
	version = device.GetVersion()
	major = Mid(version, 3, 1)
	minor = Mid(version, 5, 2)
	build = Mid(version, 8, 5)
	print "Device Version:" + major +"." + minor +" build "+build

    m.Screen.SetTitle("Preferences v" + aa["version"])
    m.Screen.SetHeader("Set Plex Channel Preferences")

    items = []

    m.Screen.AddContent({title: "Plex Media Servers"})
    items.Push("servers")

    m.Screen.AddContent({title: getCurrentMyPlexLabel(m.myplex)})
    items.Push("myplex")

    m.Screen.AddContent({title: m.GetEnumLabel("quality")})
    items.Push("quality")

    m.Screen.AddContent({title: m.GetEnumLabel("level")})
    items.Push("level")

    m.Screen.AddContent({title: m.GetEnumLabel("directplay")})
    items.Push("directplay")

    if major.toInt() >= 4 AND device.hasFeature("5.1_surround_sound") then
        m.Screen.AddContent({title: m.GetEnumLabel("fivepointone")})
        items.Push("fivepointone")
    end if

	if major.toInt() < 4  and device.hasFeature("1080p_hardware") then
        m.Screen.AddContent({title: "1080p Settings"})
        items.Push("1080p")
	end if

    m.Screen.AddContent({title: "Close Preferences"})
    items.Push("close")

    serversBefore = {}
    for each server in PlexMediaServers()
        if server.machineID <> invalid then
            serversBefore[server.machineID] = ""
        end if
    next

    m.Screen.Show()

    while true
        msg = wait(m.MsgTimeout, m.Port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roListScreenEvent" then
            if msg.isScreenClosed() then
                m.ViewController.PopScreen(m)
                exit while
            else if msg.isListItemSelected() then
                command = items[msg.GetIndex()]
                if command = "servers" then
                    screen = createManageServersScreen(m.ViewController)
                    m.ViewController.InitializeOtherScreen(screen, ["Plex Media Servers"])
                    screen.Show()
                    m.Changes.Append(screen.Changes)
                    screen = invalid
                else if command = "myplex" then
                    if m.myplex.IsSignedIn then
                        m.myplex.Disconnect()
                        m.Changes["myplex"] = "disconnected"
                    else
                        m.myplex.ShowPinScreen()
                        if m.myplex.IsSignedIn then
                            m.Changes["myplex"] = "connected"
                        end if
                    end if
                    m.Screen.SetItem(msg.GetIndex(), {title: getCurrentMyPlexLabel(m.myplex)})
                else if command = "quality" OR command = "level" OR command = "fivepointone" OR command = "directplay" then
                    m.HandleEnumPreference(command, msg.GetIndex())
                else if command = "1080p" then
                    screen = create1080PreferencesScreen(m.ViewController)
                    m.ViewController.InitializeOtherScreen(screen, ["1080p Settings"])
                    screen.Show()
                    screen = invalid
                else if command = "close" then
                    m.Screen.Close()
                end if
            end if
        end if
    end while

    serversAfter = {}
    for each server in PlexMediaServers()
        if server.machineID <> invalid then
            serversAfter[server.machineID] = ""
        end if
    next

    if NOT m.Changes.DoesExist("servers") then
        m.Changes["servers"] = {}
    end if

    for each machineID in serversAfter
        if NOT serversBefore.Delete(machineID) then
            m.Changes["servers"].AddReplace(machineID, "added")
        end if
    next

    for each machineID in serversBefore
        m.Changes["servers"].AddReplace(machineID, "removed")
    next

    m.ViewController.Home.Refresh(m.Changes)
End Sub

Function create1080PreferencesScreen(viewController) As Object
    obj = CreateObject("roAssociativeArray")
    port = CreateObject("roMessagePort")
    screen = CreateObject("roListScreen")

    screen.SetMessagePort(port)

    ' Standard properties for all our Screen types
    obj.Item = invalid
    obj.Screen = screen
    obj.Port = port
    obj.ViewController = viewController
    obj.MessageHandler = invalid
    obj.MsgTimeout = 0

    obj.Show = show1080PreferencesScreen

    obj.Changes = CreateObject("roAssociativeArray")
    obj.Prefs = CreateObject("roAssociativeArray")

    ' Legacy 1080p enabled
    options = [
        { title: "Enabled", EnumValue: "enabled" },
        { title: "Disabled", EnumValue: "disabled" }
    ]
    obj.Prefs["legacy1080p"] = {
        values: options,
        label: "1080p Support",
        heading: "1080p support (Roku 1 only)",
        default: "disabled"
    }

    ' Framerate override
    options = [
        { title: "auto", EnumValue: "auto" },
        { title: "24", EnumValue: "24" },
        { title: "30", EnumValue: "30" }
    ]
    obj.Prefs["legacy1080pframerate"] = {
        values: options,
        label: "Frame Rate Override",
        heading: "Select a frame rate to use with 1080p content.",
        default: "auto"
    }

    obj.HandleEnumPreference = prefsHandleEnumPreference
    obj.GetEnumLabel = prefsGetEnumLabel

    return obj
End Function

Sub show1080PreferencesScreen()
    m.Screen.SetHeader("1080p settings (Roku 1 only)")

    items = []

    m.Screen.AddContent({title: m.GetEnumLabel("legacy1080p")})
    items.Push("legacy1080p")

    m.Screen.AddContent({title: m.GetEnumLabel("legacy1080pframerate")})
    items.Push("legacy1080pframerate")

    m.Screen.AddContent({title: "Close"})
    items.Push("close")

    m.Screen.Show()

    while true
        msg = wait(m.MsgTimeout, m.Port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roListScreenEvent" then
            if msg.isScreenClosed() then
                m.ViewController.PopScreen(m)
                exit while
            else if msg.isListItemSelected() then
                command = items[msg.GetIndex()]
                if command = "legacy1080p" OR command = "legacy1080pframerate" then
                    m.HandleEnumPreference(command, msg.GetIndex())
                else if command = "close" then
                    m.Screen.Close()
                end if
            end if
        end if
    end while
End Sub

Sub prefsHandleEnumPreference(regKey, index)
    pref = m.Prefs[regKey]
    screen = m.ViewController.CreateEnumInputScreen(pref.values, RegRead(regKey, "preferences", pref.default), pref.heading, [pref.label])
    if screen.SelectedIndex <> invalid then
        print "Set "; pref.label; " to "; screen.SelectedValue
        RegWrite(regKey, screen.SelectedValue, "preferences")
        m.Changes.AddReplace(regKey, screen.SelectedValue)
        m.Screen.SetItem(index, {title:pref.label + ": " + screen.SelectedLabel})
    end if
End Sub

Function createManageServersScreen(viewController) As Object
    obj = CreateObject("roAssociativeArray")
    port = CreateObject("roMessagePort")
    screen = CreateObject("roListScreen")

    screen.SetMessagePort(port)

    ' Standard properties for all our Screen types
    obj.Item = invalid
    obj.Screen = screen
    obj.Port = port
    obj.ViewController = viewController
    obj.MessageHandler = invalid
    obj.MsgTimeout = 0

    obj.Show = showManageServersScreen

    obj.RefreshServerList = manageRefreshServerList

    obj.Changes = CreateObject("roAssociativeArray")
    obj.Prefs = CreateObject("roAssociativeArray")

    ' Automatic discovery
    options = [
        { title: "Enabled", EnumValue: "1" },
        { title: "Disabled", EnumValue: "0" }
    ]
    obj.Prefs["autodiscover"] = {
        values: options,
        label: "Discover at Startup",
        heading: "Automatically discover Plex Media Servers at startup.",
        default: "1"
    }

    obj.HandleEnumPreference = prefsHandleEnumPreference
    obj.GetEnumLabel = prefsGetEnumLabel

    return obj
End Function

Sub showManageServersScreen()
    m.Screen.SetHeader("Manage Plex Media Servers")

    items = []

    m.Screen.AddContent({title: "Add Server Manually"})
    items.Push("manual")

    m.Screen.AddContent({title: "Discover Servers"})
    items.Push("discover")

    m.Screen.AddContent({title: m.GetEnumLabel("autodiscover")})
    items.Push("autodiscover")

    m.Screen.AddContent({title: "Remove All Servers"})
    items.Push("removeall")

    removeOffset = items.Count()
    m.RefreshServerList(removeOffset, items)

    m.Screen.Show()

    while true
        msg = wait(m.MsgTimeout, m.Port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roListScreenEvent" then
            if msg.isScreenClosed() then
                print "Manage servers closed event"
                m.ViewController.PopScreen(m)
                exit while
            else if msg.isListItemSelected() then
                command = items[msg.GetIndex()]
                if command = "manual" then
                    screen = m.ViewController.CreateTextInputScreen("Enter Host Name or IP without http:// or :32400", ["Add Server Manually"], false)
                    screen.Screen.SetMaxLength(80)
                    screen.ValidateText = AddUnnamedServer
                    screen.Show()

                    if screen.Text <> invalid then
                        m.RefreshServerList(removeOffset, items)
                    end if

                    screen = invalid
                else if command = "discover" then
                    DiscoverPlexMediaServers()
                    m.RefreshServerList(removeOffset, items)
                else if command = "autodiscover" then
                    m.HandleEnumPreference(command, msg.GetIndex())
                else if command = "removeall" then
                    RemoveAllServers()
                    m.RefreshServerList(removeOffset, items)
                else if command = "remove" then
                    RemoveServer(msg.GetIndex() - removeOffset)
                    items.Delete(msg.GetIndex())
                    m.Screen.RemoveContent(msg.GetIndex())
                else if command = "close" then
                    m.Screen.Close()
                end if
            end if
        end if
    end while
End Sub

Sub manageRefreshServerList(removeOffset, items)
    while items.Count() > removeOffset
        items.Pop()
        m.Screen.RemoveContent(removeOffset)
    end while

    servers = RegRead("serverList", "servers")
    if servers <> invalid then
        serverTokens = strTokenize(servers, "{")
        for each token in serverTokens
            serverDetails = strTokenize(token, "\")
            m.Screen.AddContent({title: "Remove " + serverDetails[1] + " (" + serverDetails[0] + ")"})
            items.Push("remove")
        next
    end if

    m.Screen.AddContent({title: "Close"})
    items.Push("close")
End Sub

Function prefsGetEnumLabel(regKey) As String
    pref = m.Prefs[regKey]
    value = RegRead(regKey, "preferences", pref.default)
    for each item in pref.values
        if value = item.EnumValue then
            return pref.label + ": " + item.title
        end if
    next

    return pref.label
End Function

