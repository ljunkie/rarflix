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

    obj.HandleEnumPreference = prefsHandleEnumPreference
    obj.GetEnumLabel = prefsGetEnumLabel

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

    m.Screen.AddContent({title: m.GetEnumLabel("quality")})
    items.Push("quality")

    m.Screen.AddContent({title: m.GetEnumLabel("level")})
    items.Push("level")

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
                    m.ViewController.Home.ShowMediaServersScreen(m.Changes)
                else if command = "quality" OR command = "level" OR command = "fivepointone" then
                    m.HandleEnumPreference(command, msg.GetIndex())
                else if command = "1080p" then
                    m.ViewController.Home.Show1080pScreen(m.Changes)
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


Function showMediaServersScreen(changes)
	port = CreateObject("roMessagePort") 
	ls = CreateObject("roListScreen")
	ls.SetMessagePort(port)
	ls.SetTitle("Plex Media Servers") 
	ls.setHeader("Manage Plex Media Servers")
	ls.SetContent([{title:"Close Manage Servers"},
		{title: getCurrentMyPlexLabel(m.myplex)},
		{title: "Add Server Manually"},
		{title: "Discover Servers"},
		{title: "Remove All Servers"}])

	fixedSections = 4
	buttonCount = fixedSections + 1
    servers = RegRead("serverList", "servers")
    if servers <> invalid
        serverTokens = strTokenize(servers, "{")
        counter = 0
        for each token in serverTokens
            print "Server token:";token
            serverDetails = strTokenize(token, "\")

		    itemTitle = "Remove "+serverDetails[1] + " ("+serverDetails[0]+")"
		    ls.AddContent({title: itemTitle})
		    buttonCount = buttonCount + 1
        end for
    end if

	ls.Show()

	while true 
        msg = wait(0, ls.GetMessagePort()) 
        if type(msg) = "roListScreenEvent"
            if msg.isScreenClosed() then
                print "Manage servers closed event"
                exit while
             else if msg.isListItemSelected() then
                if msg.getIndex() = 0 then
                    print "Closing Manage Servers"
                    ls.close()
                else if msg.getIndex() = 1 then
                    if m.myplex.IsSignedIn then
                        m.myplex.Disconnect()
                        changes["myplex"] = "disconnected"
                    else
                        m.myplex.ShowPinScreen()
                        if m.myplex.IsSignedIn then
                            changes["myplex"] = "connected"
                        end if
                    end if
                    ls.SetItem(msg.getIndex(), {title: getCurrentMyPlexLabel(m.myplex)})
                else if msg.getIndex() = 2 then
                    m.ShowManualServerScreen()

                    ' UPDATE: I'm not seeing this problem, but I'm loathe to remove such a specific workaround...
                    ' Not sure why this is needed here. It appears that exiting the keyboard
                    ' dialog removes all dialogs then locks up screen. Redrawing the home screen
                    ' works around it.
                    'screen=preShowHomeScreen("", "")
                    'showHomeScreen(screen, PlexMediaServers())
                else if msg.getIndex() = 3 then
                    DiscoverPlexMediaServers()
                    m.showMediaServersScreen(changes)
                    ls.setFocusedListItem(0)
                    ls.close()
                else if msg.getIndex() = 4 then
                    RemoveAllServers()
                    m.showMediaServersScreen(changes)
                    ls.setFocusedListItem(0)
                    ls.close()
                                        
                else
                    RemoveServer(msg.getIndex()-(fixedSections+1))
                    ls.removeContent(msg.getIndex())
                    ls.setFocusedListItem(msg.getIndex() -1)
                end if
            end if 
        end if
	end while
End Function

Sub showManualServerScreen()
    port = CreateObject("roMessagePort") 
    keyb = CreateObject("roKeyboardScreen")    
    keyb.SetMessagePort(port)
    keyb.SetDisplayText("Enter Host Name or IP without http:// or :32400")
    keyb.SetMaxLength(80)
    keyb.AddButton(1, "Done") 
    keyb.AddButton(2, "Close")
    keyb.setText("")
    keyb.Show()
    while true 
        msg = wait(0, keyb.GetMessagePort()) 
        if type(msg) = "roKeyboardScreenEvent" then
            if msg.isScreenClosed() then
                print "Exiting keyboard dialog screen"
                return
            else if msg.isButtonPressed() then
                if msg.getIndex() = 1 then
                    if (AddUnnamedServer(keyb.GetText())) then
                        return
                    end if
                else if msg.getIndex() = 2 then
                    print "Exiting keyboard dialog screen"
                    return
                end if
            end if 
        end if
    end while
End Sub

Function show1080pScreen(changes)
	port = CreateObject("roMessagePort") 
	ls = CreateObject("roListScreen") 
	ls.SetMessagePort(port)
	ls.SetTitle("1080p Roku 1 Support") 
	ls.setHeader("This screen allows you to configure 1080p support for Roku 1 devices.")
	if not(RegExists("legacy1080p", "preferences")) then
		RegWrite("legacy1080p", "disabled", "preferences")
	end if
	if not(RegExists("legacy1080pframerate", "preferences")) then
		RegWrite("legacy1080pframerate", "auto", "preferences")
	end if
	
	ls.setContent([{title: "1080p: "+ RegRead("legacy1080p","preferences") },
		{title: "Framerate Override: "+ RegRead("legacy1080pframerate","preferences")},
		{title: "Close 1080p Menu"}])
	ls.Show()
	
	while true 
		msg = wait(0, ls.GetMessagePort()) 
		if type(msg) = "roListScreenEvent"
			if msg.isScreenClosed() then
				ls.close()
				exit while
			else if msg.isListItemSelected() then
				if msg.getIndex() = 0 then
					show1080pSettingScreen()
					ls.setItem(msg.getIndex(), {title:"1080p: " + RegRead("legacy1080p","preferences")})
				else if msg.getIndex() = 1 then
					show1080pframerateScreen()
					ls.setItem(msg.getIndex(), {title:"Framerate Override: " + RegRead("legacy1080pframerate","preferences")})
				else if msg.getIndex() = 2 then
					ls.close()
				end if
			end if
		end if 
	end while
End Function

Function show1080pSettingScreen()
	port = CreateObject("roMessagePort") 
	ls = CreateObject("roListScreen") 
	ls.SetMessagePort(port)
	ls.SetTitle("1080p Roku 1 setting") 
	ls.setHeader("Enable 1080p Support for Roku 1 devices")
	
	
	ls.setContent([{title: "enable"},
		{title: "disable"}])
	
	if RegRead("legacy1080p","preferences") = "enabled" then
		ls.setFocusedListItem(0)
	else
		ls.setFocusedListItem(1)
	end if
	ls.Show()
	while true 
		msg = wait(0, ls.GetMessagePort()) 
		if type(msg) = "roListScreenEvent"
			if msg.isScreenClosed() then
				ls.close()
				exit while
			else if msg.isListItemSelected() then
				if msg.getIndex() = 0 then
					RegWrite("legacy1080p","enabled","preferences")
				else if msg.getIndex() = 1 then
					RegWrite("legacy1080p","disabled","preferences")
				end if
				ls.close()
			end if
		end if 
	end while
End Function

Function show1080pFramerateScreen()
	port = CreateObject("roMessagePort") 
	ls = CreateObject("roListScreen") 
	ls.SetMessagePort(port)
	ls.SetTitle("1080p Roku 1 Framerate") 
	ls.setHeader("Select [auto] if your device supports both 1080p24 and 1080p30.")
	
	
	ls.setContent([{title: "auto"},
		{title: "24"},
		{title: "30"}])
	
	if RegRead("legacy1080pframerate","preferences") = "24" then
		ls.setFocusedListItem(1)
	else if RegRead("legacy1080pframerate","preferences") = "30"
		ls.setFocusedListItem(2)
	else 
		ls.setFocusedListItem(0)
	end if
	
	ls.Show()
	while true 
		msg = wait(0, ls.GetMessagePort()) 
		if type(msg) = "roListScreenEvent"
			if msg.isScreenClosed() then
				ls.close()
				exit while
			else if msg.isListItemSelected() then
				if msg.getIndex() = 0 then
					RegWrite("legacy1080pframerate","auto","preferences")
				else if msg.getIndex() = 1 then
					RegWrite("legacy1080pframerate","24","preferences")
				else if msg.getIndex() = 2 then
					RegWrite("legacy1080pframerate","30","preferences")
				end if
				ls.close()
			end if
		end if 
	end while
End Function

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

