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
Function showPreferencesScreen()
	port = CreateObject("roMessagePort") 

    manifest = ReadAsciiFile("pkg:/manifest")
    lines = manifest.Tokenize(chr(10))
    aa = {}
    for each line in lines
        entry = line.Tokenize("=")
        aa.AddReplace(entry[0],entry[1])
    end for
	
	ls = CreateObject("roListScreen")
	ls.SetMEssagePort(port)
	ls.setTitle("Preferences v."+aa["version"])
	ls.setheader("Set Plex Channel Preferences")
	print "Quality:";currentQualityTitle
	ls.SetContent([{title:"Plex Media Servers"},
		{title:"Quality: "+getCurrentQualityName()},
		{title:"H264 Level: " + getCurrentH264Level()},
		{title:"5.1 Support: " + getCurrentFiveOneSetting()}])
		
	device = CreateObject("roDeviceInfo")
	version = device.GetVersion()
	major = Mid(version, 3, 1)
	minor = Mid(version, 5, 2)
	build = Mid(version, 8, 5)
	print "Device Version:" + major +"." + minor +" build "+build
	buttonCount = 5
	if major.toInt() < 4  and device.hasFeature("1080p_hardware") then
		ls.AddContent({title:"1080p Settings"})
		buttonCount = 6
	end if
	
	ls.AddContent({title:"Close Preferences"})
	
    changes = {}
    serversBefore = {}
    for each server in PlexMediaServers()
        if server.machineID <> invalid then
            serversBefore[server.machineID] = ""
        end if
    next
	
	ls.show()
	
    timeout = 0
    while true 
        msg = wait(timeout, ls.GetMessagePort())         
        if type(msg) = "roListScreenEvent"
			'print "Event: ";type(msg)
            'print msg.GetType(),msg.GetIndex(),msg.GetData()
            if msg.isScreenClosed() then
                ls.close()
                exit while
            else if msg.isListItemSelected() then
                if msg.getIndex() = 0 then
                    m.ShowMediaServersScreen(changes)
                else if msg.getIndex() = 1 then
                    m.ShowQualityScreen(changes)
                    ls.setItem(msg.getIndex(), {title:"Quality: "+ getCurrentQualityName() })
                else if msg.getIndex() = 2 then
                    m.ShowH264Screen(changes)
                    ls.setItem(msg.getIndex(), {title:"H264 Level: " + getCurrentH264Level()})
                else if msg.getIndex() = 3 then
                     m.ShowFivePointOneScreen(changes)
                     ls.setItem(msg.getIndex(), {title:"5.1 Support: " + getCurrentFiveOneSetting()})
                else if msg.getIndex() = 4 then
					if buttonCount = 6 then
						m.Show1080pScreen(changes)
					else 
						ls.close()
					endif
                else if msg.getIndex() = 5 then
                    ls.close()
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

    if NOT changes.DoesExist("servers") then
        changes["servers"] = {}
    end if

    for each machineID in serversAfter
        if NOT serversBefore.Delete(machineID) then
            changes["servers"].AddReplace(machineID, "added")
        end if
    next

    for each machineID in serversBefore
        changes["servers"].AddReplace(machineID, "removed")
    next

    m.Refresh(changes)
End Function

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

Function showFivePointOneScreen(changes)
	port = CreateObject("roMessagePort") 
	ls = CreateObject("roListScreen") 
	ls.SetMessagePort(port)
	ls.SetTitle("5.1 Support") 
	ls.setHeader("5.1 audio is only supported on the Roku 2 (4.x) firmware. "+chr(10)+"This setting will be ignored if that firmware is not detected.")

	
	fiveone = CreateObject("roArray", 6 , true)
	fiveone.Push("Enabled")
	fiveone.Push("Disabled")

	if not(RegExists("fivepointone", "preferences")) then
		RegWrite("fivepointone", "1", "preferences")
	end if
	current = RegRead("fivepointone", "preferences")

	for each value in fiveone
		fiveoneTitle = value
		ls.AddContent({title: fiveoneTitle})
	next
	ls.setFocusedListItem(current.toint() -1)
	ls.Show()
	while true 
		msg = wait(0, ls.GetMessagePort()) 
		if type(msg) = "roListScreenEvent"
			if msg.isScreenClosed() then
				ls.close()
				exit while
			else if msg.isListItemSelected() then
        		fiveone = (msg.getIndex()+1).tostr()
        		print "Set 5.1 support to ";fiveone
        		RegWrite("fivepointone", fiveone, "preferences")
                changes.AddReplace("fiveone", fiveone)
                Capabilities(true)
				ls.close()
			end if 
		end if
	end while
End Function

Function showQualityScreen(changes)
	port = CreateObject("roMessagePort") 
	ls = CreateObject("roListScreen")
	ls.SetMessagePort(port)
	ls.SetTitle("Quality Settings") 
	ls.setHeader("Higher settings produce better video quality but require more" + chr(10) + "network bandwidth.")
	
	qualities = CreateObject("roArray", 6 , true)
	
	qualities.Push("720 kbps, 320p") 'N=1, Q=4
	qualities.Push("1.5 Mbps, 480p") 'N=2, Q=5
	qualities.Push("2.0 Mbps, 720p") 'N=3, Q=6
	qualities.Push("3.0 Mbps, 720p") 'N=4, Q=7
	qualities.Push("4.0 Mbps, 720p") 'N=5, Q=8
	qualities.Push("8.0 Mbps, 1080p") 'N=6, Q=9
	
	if not(RegExists("quality", "preferences")) then
		RegWrite("quality", "7", "preferences")
	end if
	current = RegRead("quality", "preferences")
	
	
	for each quality in qualities
		listTitle = quality		
		ls.AddContent({title: listTitle})
	next
	ls.setFocusedListItem(current.toint()-4)
	ls.Show()
	while true 
		msg = wait(0, ls.GetMessagePort()) 
		if type(msg) = "roListScreenEvent"
			if msg.isScreenClosed() then
				ls.close()
				exit while
			else if msg.isListItemSelected() then
				if msg.getIndex() = 0 then
					quality = "Auto"
				else
        			quality = (4 + msg.getIndex()).tostr()
        		end if
        		print "Set selected quality to ";quality
        		RegWrite("quality", quality, "preferences")
                changes.AddReplace("quality", quality)
				ls.close()
				exit while
			end if 
		end if
	end while
End Function

Function showH264Screen(changes)
	port = CreateObject("roMessagePort") 
	ls = CreateObject("roListScreen") 
	ls.SetMessagePort(port)
	ls.SetTitle("H264 Level") 
	ls.setHeader("Use specific H264 level. Only 4.0 is officially supported.")
	
	
	levels = CreateObject("roArray", 5 , true)
	
	levels.Push("Level 4.0 (Supported)") 'N=1
	levels.Push("Level 4.1") 'N=2
	levels.Push("Level 4.2") 'N=3
	levels.Push("Level 5.0") 'N=4
	levels.Push("Level 5.1") 'N=5
	
	if not(RegExists("level", "preferences")) then
		RegWrite("level", "40", "preferences")
	end if

	current = "Level 4.0 (Default)"
	selected = 0
	if RegRead("level", "preferences") = "40" then
		current = "Level 4.0 (Default)"
		selected = 0
	else if RegRead("level", "preferences") = "41" then
		current = "Level 4.1"
		selected = 1
	else if RegRead("level", "preferences") = "42" then
		current = "Level 4.2"
		selected = 2
	else if RegRead("level", "preferences") = "50" then
		current = "Level 5.0"
		selected = 3
	else if RegRead("level", "preferences") = "51" then
		current = "Level 5.1"
		selected = 4
	end if
	for each level in levels
		levelTitle = level		
		ls.AddContent({title: levelTitle})		
	next
	ls.setFocusedListItem(selected)
	ls.Show()
	while true 
		msg = wait(0, ls.GetMessagePort()) 
		if type(msg) = "roListScreenEvent"
			if msg.isScreenClosed() then
				ls.close()
				exit while
			else if msg.isListItemSelected() then
				if msg.getIndex() = 0 then
					level = "40"
				else if msg.getIndex() = 1 then
					level = "41"
				else if msg.getIndex() = 2 then
					level = "42"
				else if msg.getIndex() = 3 then
					level = "50"
				else if msg.getIndex() = 4 then
					level = "51"
				end if
        		print "Set selected level to ";level
        		RegWrite("level", level, "preferences")
                changes.AddReplace("level", level)
                Capabilities(true)
				ls.close()
			end if
		end if 
	end while
End Function


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



Function getCurrentQualityName()
	qualities = CreateObject("roArray", 6 , true)
	qualities.Push("720 kbps, 320p") 'N=1, Q=4
	qualities.Push("1.5 Mbps, 480p") 'N=2, Q=5
	qualities.Push("2.0 Mbps, 720p") 'N=3, Q=6
	qualities.Push("3.0 Mbps, 720p") 'N=4, Q=7
	qualities.Push("4.0 Mbps, 720p") 'N=5, Q=8
	qualities.Push("8.0 Mbps, 1080p") 'N=6, Q=9
	
	if not(RegExists("quality", "preferences")) then
		RegWrite("quality", "7", "preferences")
	end if
	currentQuality = RegRead("quality", "preferences")
	if currentQuality = "Auto" then
		currentQualityTitle = "Auto"
	else 
		currentQualityIndex = currentQuality.toint() -4
		currentQualityTitle = qualities[currentQualityIndex]
	endif
	return currentQualityTitle
End Function

Function getCurrentH264Level()
	if not(RegExists("level", "preferences")) then
		RegWrite("level", "40", "preferences")
	end if

	currentLevel = "Level 4.0 (Default)"
	if RegRead("level", "preferences") = "40" then
		currentLevel = "Level 4.0 (Default)"
	else if RegRead("level", "preferences") = "41" then
		currentLevel = "Level 4.1"
	else if RegRead("level", "preferences") = "42" then
		currentLevel = "Level 4.2"
	else if RegRead("level", "preferences") = "50" then
		currentLevel = "Level 5.0"
	else if RegRead("level", "preferences") = "51" then
		currentLevel = "Level 5.1"
	end if
	return currentLevel
End Function

Function getCurrentFiveOneSetting()
	fiveone = CreateObject("roArray", 6 , true)
	fiveone.Push("Enabled")
	fiveone.Push("Disabled")
	if not(RegExists("fivepointone", "preferences")) then
		RegWrite("fivepointone", "1", "preferences")
	end if
	current = RegRead("fivepointone", "preferences")
	currentText = fiveone[current.toint()-1]
	if currentText = invalid then
		currentText = ""
	endif
		
	return currentText
End Function

