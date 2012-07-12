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

    lsInitBaseListScreen(obj)

    return obj
End Function

Sub showSettingsScreen()
    server = m.Item.server
    container = createPlexContainerForUrl(server, m.Item.sourceUrl, m.Item.key)
    settings = container.GetSettings()

    for each setting in settings
        setting.title = setting.label
        m.AddItem(setting, "setting", setting.GetValueString())
    next
    m.AddItem({title: "Close"}, "close")

    m.Screen.Show()

	while true 
        msg = wait(m.MsgTimeout, m.Port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roListScreenEvent" then
            if msg.isScreenClosed() then
                Debug("Exiting settings screen")
                m.ViewController.PopScreen(m)
                exit while
            else if msg.isListItemSelected() then
                command = m.GetSelectedCommand(msg.GetIndex())
                if command = "setting" then
                    setting = m.contentArray[msg.GetIndex()]

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
                        m.AppendValue(msg.GetIndex(), setting.GetValueString())
                    end if
                else if command = "close" then
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
Function createBasePrefsScreen(viewController) As Object
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

    obj.Changes = CreateObject("roAssociativeArray")
    obj.Prefs = CreateObject("roAssociativeArray")

    lsInitBaseListScreen(obj)

    obj.HandleEnumPreference = prefsHandleEnumPreference
    obj.GetEnumValue = prefsGetEnumValue

    return obj
End Function

Function createPreferencesScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.Show = showPreferencesScreen

    ' Quality settings
    qualities = [
        { title: "720 kbps, 320p", EnumValue: "4" },
        { title: "1.5 Mbps, 480p", EnumValue: "5" },
        { title: "2.0 Mbps, 720p", EnumValue: "6" },
        { title: "3.0 Mbps, 720p", EnumValue: "7", ShortDescriptionLine2: "Default" },
        { title: "4.0 Mbps, 720p", EnumValue: "8" },
        { title: "8.0 Mbps, 1080p", EnumValue: "9", ShortDescriptionLine2: "Pushing the limits, requires fast connection." }
        { title: "10.0 Mbps, 1080p", EnumValue: "10", ShortDescriptionLine2: "May be unstable, not recommended." }
        { title: "12.0 Mbps, 1080p", EnumValue: "11", ShortDescriptionLine2: "May be unstable, not recommended." }
        { title: "20.0 Mbps, 1080p", EnumValue: "12", ShortDescriptionLine2: "May be unstable, not recommended." }
    ]
    obj.Prefs["quality"] = {
        values: qualities,
        heading: "Higher settings produce better video quality but require more" + Chr(10) + "network bandwidth.",
        default: "7"
    }

    ' Direct play options
    directplay = [
        { title: "Automatic (recommended)", EnumValue: "0" },
        { title: "Direct Play", EnumValue: "1", ShortDescriptionLine2: "Always Direct Play, no matter what." },
        { title: "Direct Play w/ Fallback", EnumValue: "2", ShortDescriptionLine2: "Always try Direct Play, then transcode." },
        { title: "Direct Stream/Transcode", EnumValue: "3", ShortDescriptionLine2: "Always Direct Stream or transcode." },
        { title: "Always Transcode", EnumValue: "4", ShortDescriptionLine2: "Never Direct Play or Direct Stream." }
    ]
    obj.Prefs["directplay"] = {
        values: directplay,
        heading: "Direct Play preferences",
        default: "0"
    }

    ' Subtitle options
    softsubtitles = [
        { title: "Soft", EnumValue: "1", ShortDescriptionLine2: "Use soft subtitles whenever possible." },
        { title: "Burned In", EnumValue: "0", ShortDescriptionLine2: "Always burn in selected subtitles." }
    ]
    obj.Prefs["softsubtitles"] = {
        values: softsubtitles,
        heading: "Allow Roku to show soft subtitles itself, or burn them in to videos?",
        default: "1"
    }

    ' Screensaver options
    screensaver = [
        { title: "Disabled", EnumValue: "disabled", ShortDescriptionLine2: "Use the system screensaver" },
        { title: "Animated", EnumValue: "animated" },
        { title: "Random", EnumValue: "random" }
    ]
    obj.Prefs["screensaver"] = {
        values: screensaver,
        heading: "Screensaver",
        default: "random"
    }

    obj.myplex = GetGlobalAA().Lookup("myplex")

    return obj
End Function

Sub showPreferencesScreen()
    device = CreateObject("roDeviceInfo")
    versionArr = GetGlobalAA().Lookup("rokuVersionArr")
    major = versionArr[0]

    m.Screen.SetTitle("Preferences v" + GetGlobalAA().Lookup("appVersionStr"))
    m.Screen.SetHeader("Set Plex Channel Preferences")

    m.AddItem({title: "Plex Media Servers"}, "servers")
    m.AddItem({title: getCurrentMyPlexLabel(m.myplex)}, "myplex")
    m.AddItem({title: "Quality"}, "quality", m.GetEnumValue("quality"))
    m.AddItem({title: "Direct Play"}, "directplay", m.GetEnumValue("directplay"))
    m.AddItem({title: "Subtitles"}, "softsubtitles", m.GetEnumValue("softsubtitles"))
    m.AddItem({title: "Slideshow"}, "slideshow")
    m.AddItem({title: "Screensaver"}, "screensaver", m.GetEnumValue("screensaver"))
    m.AddItem({title: "Logging"}, "debug")
    m.AddItem({title: "Advanced Preferences"}, "advanced")

    m.AddItem({title: "Close Preferences"}, "close")

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
                command = m.GetSelectedCommand(msg.GetIndex())
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
                else if command = "quality" OR command = "level" OR command = "fivepointone" OR command = "directplay" OR command = "softsubtitles" OR command = "screensaver" then
                    m.HandleEnumPreference(command, msg.GetIndex())
                else if command = "slideshow" then
                    screen = createSlideshowPrefsScreen(m.ViewController)
                    m.ViewController.InitializeOtherScreen(screen, ["Slideshow Preferences"])
                    screen.Show()
                    screen = invalid
                else if command = "advanced" then
                    screen = createAdvancedPrefsScreen(m.ViewController)
                    m.ViewController.InitializeOtherScreen(screen, ["Advanced Preferences"])
                    screen.Show()
                    screen = invalid
                else if command = "debug" then
                    screen = createDebugLoggingScreen(m.ViewController)
                    m.ViewController.InitializeOtherScreen(screen, ["Logging"])
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

    for each server in GetOwnedPlexMediaServers()
        if server.IsUpdated = true then
            m.Changes["servers"].AddReplace(server.MachineID, "updated")
            server.IsUpdated = invalid
        end if
    next

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

Function createSlideshowPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.Show = showSlideshowPrefsScreen

    ' Photo duration
    values = [
        { title: "Slow", EnumValue: "10" },
        { title: "Normal", EnumValue: "6" },
        { title: "Fast", EnumValue: "3" }
    ]
    obj.Prefs["slideshow_period"] = {
        values: values,
        heading: "Slideshow speed",
        default: "6"
    }

    ' Overlay duration
    values = [
        { title: "None", EnumValue: "0" }
        { title: "Slow", EnumValue: "10000" },
        { title: "Normal", EnumValue: "2500" },
        { title: "Fast", EnumValue: "1000" }
    ]
    obj.Prefs["slideshow_overlay"] = {
        values: values,
        heading: "Text overlay duration",
        default: "2500"
    }

    return obj
End Function

Sub showSlideshowPrefsScreen()
    m.Screen.SetHeader("Slideshow display preferences")

    m.AddItem({title: "Speed"}, "slideshow_period", m.GetEnumValue("slideshow_period"))
    m.AddItem({title: "Text Overlay"}, "slideshow_overlay", m.GetEnumValue("slideshow_overlay"))
    m.AddItem({title: "Close"}, "close")

    m.Screen.Show()

    while true
        msg = wait(m.MsgTimeout, m.Port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roListScreenEvent" then
            if msg.isScreenClosed() then
                m.ViewController.PopScreen(m)
                exit while
            else if msg.isListItemSelected() then
                command = m.GetSelectedCommand(msg.GetIndex())
                if command = "slideshow_period" OR command = "slideshow_overlay" then
                    m.HandleEnumPreference(command, msg.GetIndex())
                else if command = "close" then
                    m.Screen.Close()
                end if
            end if
        end if
    end while
End Sub

Function createAdvancedPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.Show = showAdvancedPrefsScreen

    ' H.264 Level
    levels = [
        { title: "Level 4.0 (Supported)", EnumValue: "40" },
        { title: "Level 4.1", EnumValue: "41", ShortDescriptionLine2: "This level may not be supported well." },
        { title: "Level 4.2", EnumValue: "42", ShortDescriptionLine2: "This level may not be supported well." },
        { title: "Level 5.0", EnumValue: "50", ShortDescriptionLine2: "This level may not be supported well." },
        { title: "Level 5.1", EnumValue: "51", ShortDescriptionLine2: "This level may not be supported well." }
    ]
    obj.Prefs["level"] = {
        values: levels,
        heading: "Use specific H264 level. Only 4.0 is officially supported.",
        default: "40"
    }

    ' 5.1 Support
    fiveone = [
        { title: "Enabled", EnumValue: "1", ShortDescriptionLine2: "Try to copy 5.1 audio streams when transcoding." },
        { title: "Disabled", EnumValue: "2", ShortDescriptionLine2: "Always use 2-channel audio when transcoding." }
    ]
    obj.Prefs["fivepointone"] = {
        values: fiveone,
        heading: "5.1 audio support for transcoded content",
        default: "1"
    }

    ' HLS seconds per segment
    lengths = [
        { title: "Automatic", EnumValue: "auto", ShortDescriptionLine2: "Chooses based on quality." },
        { title: "4 seconds", EnumValue: "4" },
        { title: "10 seconds", EnumValue: "10" }
    ]
    obj.Prefs["segment_length"] = {
        values: lengths,
        heading: "Seconds per HLS segment. Longer segments may load faster.",
        default: "10"
    }

    ' Subtitle size (burned in only)
    sizes = [
        { title: "Tiny", EnumValue: "75" },
        { title: "Small", EnumValue: "90" },
        { title: "Normal", EnumValue: "125" },
        { title: "Large", EnumValue: "175" },
        { title: "Huge", EnumValue: "250" }
    ]
    obj.Prefs["subtitle_size"] = {
        values: sizes,
        heading: "Burned-in subtitle size",
        default: "125"
    }

    ' Audio boost for transcoded content. Transcoded content is quiet by
    ' default, but if we set a default boost then audio will never be remuxed.
    ' These values are based on iOS.
    values = [
        { title: "None", EnumValue: "100" },
        { title: "Small", EnumValue: "175" },
        { title: "Large", EnumValue: "225" },
        { title: "Huge", EnumValue: "300" }
    ]
    obj.Prefs["audio_boost"] = {
        values: values,
        heading: "Audio boost for transcoded video",
        default: "100"
    }

    return obj
End Function

Sub showAdvancedPrefsScreen()
    device = CreateObject("roDeviceInfo")
    versionArr = GetGlobalAA().Lookup("rokuVersionArr")
    major = versionArr[0]

    m.Screen.SetHeader("Advanced preferences don't usually need to be changed")

    m.AddItem({title: "H.264"}, "level", m.GetEnumValue("level"))

    if major >= 4 AND device.hasFeature("5.1_surround_sound") then
        m.AddItem({title: "5.1 Support"}, "fivepointone", m.GetEnumValue("fivepointone"))
    end if

    if major < 4  and device.hasFeature("1080p_hardware") then
        m.AddItem({title: "1080p Settings"}, "1080p")
    end if

    m.AddItem({title: "HLS Segment Length"}, "segment_length", m.GetEnumValue("segment_length"))
    m.AddItem({title: "Subtitle Size"}, "subtitle_size", m.GetEnumValue("subtitle_size"))
    m.AddItem({title: "Audio Boost"}, "audio_boost", m.GetEnumValue("audio_boost"))
    m.AddItem({title: "Close"}, "close")

    m.Screen.Show()

    while true
        msg = wait(m.MsgTimeout, m.Port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roListScreenEvent" then
            if msg.isScreenClosed() then
                m.ViewController.PopScreen(m)
                exit while
            else if msg.isListItemSelected() then
                command = m.GetSelectedCommand(msg.GetIndex())
                if command = "level" OR command = "fivepointone" OR command = "segment_length" OR command = "subtitle_size" OR command = "audio_boost" then
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
End Sub

Function create1080PreferencesScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.Show = show1080PreferencesScreen

    ' Legacy 1080p enabled
    options = [
        { title: "Enabled", EnumValue: "enabled" },
        { title: "Disabled", EnumValue: "disabled" }
    ]
    obj.Prefs["legacy1080p"] = {
        values: options,
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
        heading: "Select a frame rate to use with 1080p content.",
        default: "auto"
    }

    return obj
End Function

Sub show1080PreferencesScreen()
    m.Screen.SetHeader("1080p settings (Roku 1 only)")

    m.AddItem({title: "1080p Support"}, "legacy1080p", m.GetEnumValue("legacy1080p"))
    m.AddItem({title: "Frame Rate Override"}, "legacy1080pframerate", m.GetEnumValue("legacy1080pframerate"))
    m.AddItem({title: "Close"}, "close")

    m.Screen.Show()

    while true
        msg = wait(m.MsgTimeout, m.Port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roListScreenEvent" then
            if msg.isScreenClosed() then
                m.ViewController.PopScreen(m)
                exit while
            else if msg.isListItemSelected() then
                command = m.GetSelectedCommand(msg.GetIndex())
                if command = "legacy1080p" OR command = "legacy1080pframerate" then
                    m.HandleEnumPreference(command, msg.GetIndex())
                else if command = "close" then
                    m.Screen.Close()
                end if
            end if
        end if
    end while
End Sub

Function createDebugLoggingScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.Show = showDebugLoggingScreen

    obj.RefreshItems = debugRefreshItems
    obj.Logger = GetGlobalAA()["logger"]

    return obj
End Function

Sub debugRefreshItems()
    m.contentArray.Clear()
    m.Screen.ClearContent()

    if m.Logger.Enabled then
        m.AddItem({title: "Disable Logging"}, "disable")

        myPlex = GetGlobalAA().Lookup("myplex")
        if myPlex <> invalid AND myPlex.IsSignedIn then
            m.AddItem({title: "Enable Remote Logging"}, "remote")
        end if

        m.AddItem({title: "Download Logs"}, "download")
    else
        m.AddItem({title: "Enable Logging"}, "enable")
    end if

    m.AddItem({title: "Close"}, "close")
End Sub

Sub showDebugLoggingScreen()
    m.Screen.SetHeader("Logging")

    m.RefreshItems()
    m.Screen.Show()

    while true
        msg = wait(m.MsgTimeout, m.Port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roListScreenEvent" then
            if msg.isScreenClosed() then
                m.ViewController.PopScreen(m)
                exit while
            else if msg.isListItemSelected() then
                command = m.GetSelectedCommand(msg.GetIndex())
                if command = "enable" then
                    m.Logger.Enable()
                    m.RefreshItems()
                else if command = "disable" then
                    m.Logger.Disable()
                    m.RefreshItems()
                else if command = "download" then
                    screen = createLogDownloadScreen(m.ViewController)
                    screen.Show()
                    screen = invalid
                else if command = "remote" then
                    ' TODO(schuyler) What if we want to debug something related
                    ' to a non-primary server?
                    m.Logger.EnablePapertrail(20, GetPrimaryServer())
                else if command = "close" then
                    m.Screen.Close()
                end if
            end if
        end if
    end while
End Sub

Sub prefsHandleEnumPreference(regKey, index)
    label = m.contentArray[index].OrigTitle
    pref = m.Prefs[regKey]
    screen = m.ViewController.CreateEnumInputScreen(pref.values, RegRead(regKey, "preferences", pref.default), pref.heading, [label])
    if screen.SelectedIndex <> invalid then
        Debug("Set " + label + " to " + screen.SelectedValue)
        RegWrite(regKey, screen.SelectedValue, "preferences")
        m.Changes.AddReplace(regKey, screen.SelectedValue)
        m.AppendValue(index, screen.SelectedLabel)
    end if
End Sub

Function createManageServersScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.Show = showManageServersScreen

    obj.RefreshServerList = manageRefreshServerList

    ' Automatic discovery
    options = [
        { title: "Enabled", EnumValue: "1" },
        { title: "Disabled", EnumValue: "0" }
    ]
    obj.Prefs["autodiscover"] = {
        values: options,
        heading: "Automatically discover Plex Media Servers at startup.",
        default: "1"
    }

    return obj
End Function

Sub showManageServersScreen()
    m.Screen.SetHeader("Manage Plex Media Servers")

    m.AddItem({title: "Add Server Manually"}, "manual")
    m.AddItem({title: "Discover Servers"}, "discover")
    m.AddItem({title: "Discover at Startup"}, "autodiscover", m.GetEnumValue("autodiscover"))
    m.AddItem({title: "Remove All Servers"}, "removeall")

    removeOffset = m.contentArray.Count()
    m.RefreshServerList(removeOffset)

    m.Screen.Show()

    while true
        msg = wait(m.MsgTimeout, m.Port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roListScreenEvent" then
            if msg.isScreenClosed() then
                Debug("Manage servers closed event")
                m.ViewController.PopScreen(m)
                exit while
            else if msg.isListItemSelected() then
                command = m.GetSelectedCommand(msg.GetIndex())
                if command = "manual" then
                    screen = m.ViewController.CreateTextInputScreen("Enter Host Name or IP without http:// or :32400", ["Add Server Manually"], false)
                    screen.Screen.SetMaxLength(80)
                    screen.ValidateText = AddUnnamedServer
                    screen.Show()

                    if screen.Text <> invalid then
                        m.RefreshServerList(removeOffset)
                    end if

                    screen = invalid
                else if command = "discover" then
                    DiscoverPlexMediaServers()
                    m.RefreshServerList(removeOffset)
                else if command = "autodiscover" then
                    m.HandleEnumPreference(command, msg.GetIndex())
                else if command = "removeall" then
                    RemoveAllServers()
                    ClearPlexMediaServers()
                    m.RefreshServerList(removeOffset)
                else if command = "remove" then
                    RemoveServer(msg.GetIndex() - removeOffset)
                    m.contentArray.Delete(msg.GetIndex())
                    m.Screen.RemoveContent(msg.GetIndex())
                else if command = "close" then
                    m.Screen.Close()
                end if
            end if
        end if
    end while
End Sub

Sub manageRefreshServerList(removeOffset)
    while m.contentArray.Count() > removeOffset
        m.contentArray.Pop()
        m.Screen.RemoveContent(removeOffset)
    end while

    servers = ParseRegistryServerList()
    for each server in servers
        m.AddItem({title: "Remove " + server.Name + " (" + server.Url + ")"}, "remove")
    next

    m.AddItem({title: "Close"}, "close")
End Sub

Function prefsGetEnumValue(regKey)
    pref = m.Prefs[regKey]
    value = RegRead(regKey, "preferences", pref.default)
    for each item in pref.values
        if value = item.EnumValue then
            return item.title
        end if
    next

    return invalid
End Function

