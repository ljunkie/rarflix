Function createSettingsScreen(item, viewController) As Object
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    screen = CreateObject("roListScreen")
    screen.SetMessagePort(obj.Port)
    screen.SetHeader(item.Title)

    ' Standard properties for all our screen types
    obj.Item = item
    obj.Screen = screen

    obj.Show = settingsShow
    obj.HandleMessage = settingsHandleMessage
    obj.OnUserInput = settingsOnUserInput

    lsInitBaseListScreen(obj)

    return obj
End Function

Sub settingsShow()
    server = m.Item.server
    container = createPlexContainerForUrl(server, m.Item.sourceUrl, m.Item.key)
    settings = container.GetSettings()

    for each setting in settings
        setting.title = setting.label
        m.AddItem(setting, "setting", setting.GetValueString())
    next
    m.AddItem({title: "Close"}, "close")

    m.Screen.Show()
End Sub

Function settingsHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            Debug("Exiting settings screen")
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "setting" then
                m.currentIndex = msg.GetIndex()
                setting = m.contentArray[msg.GetIndex()]

                if setting.type = "text" then
                    screen = m.ViewController.CreateTextInputScreen("Enter " + setting.label, [], false)
                    screen.Screen.SetText(setting.value)
                    screen.Screen.SetSecureText(setting.hidden OR setting.secure)
                    screen.Listener = m
                    screen.Show()
                else if setting.type = "bool" then
                    screen = m.ViewController.CreateEnumInputScreen(["true", "false"], setting.value, setting.label, [], false)
                    screen.Listener = m
                    screen.Show()
                else if setting.type = "enum" then
                    screen = m.ViewController.CreateEnumInputScreen(setting.values, setting.value.toint(), setting.label, [], false)
                    screen.Listener = m
                    screen.Show()
                end if
            else if command = "close" then
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function

Sub settingsOnUserInput(value, screen)
    setting = m.contentArray[m.currentIndex]
    if setting.type = "enum" then
        setting.value = screen.SelectedIndex.tostr()
    else
        setting.value = value
    end if

    m.Item.server.SetPref(m.Item.key, setting.id, setting.value)
    m.AppendValue(m.currentIndex, setting.GetValueString())
End Sub

'#######################################################
'Below are the preference Functions for the Global
' Roku channel settings
'#######################################################
Function createBasePrefsScreen(viewController) As Object
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    screen = CreateObject("roListScreen")
    screen.SetMessagePort(obj.Port)

    ' Standard properties for all our Screen types
    obj.Screen = screen

    obj.Changes = CreateObject("roAssociativeArray")
    obj.Prefs = CreateObject("roAssociativeArray")

    lsInitBaseListScreen(obj)

    obj.HandleEnumPreference = prefsHandleEnumPreference
    obj.HandleTextPreference = prefsHandleTextPreference
    obj.HandleReorderPreference = prefsHandleReorderPreference
    obj.OnUserInput = prefsOnUserInput
    obj.GetEnumValue = prefsGetEnumValue
    obj.GetPrefValue = prefsGetPrefValue

    return obj
End Function

Sub prefsHandleEnumPreference(regKey, index)
    m.currentIndex = index
    m.currentRegKey = regKey
    label = m.contentArray[index].OrigTitle
    pref = m.Prefs[regKey]
    m.Changes.AddReplace("_previous_"+regKey, RegRead(regKey, "preferences", pref.default)) ' ljunkie - set _previous_ value to key off of later
    screen = m.ViewController.CreateEnumInputScreen(pref.values, RegRead(regKey, "preferences", pref.default), pref.heading, [label], false)
    screen.Listener = m
    screen.Show()
End Sub

Sub prefsHandleTextPreference(regKey, index)
    m.currentIndex = index
    m.currentRegKey = regKey
    label = m.contentArray[index].OrigTitle
    pref = m.Prefs[regKey]
    screen = m.ViewController.CreateTextInputScreen(pref.heading, [label], false)
    screen.Text = RegRead(regKey, "preferences", pref.default)
    screen.Screen.SetMaxLength(80)
    screen.Listener = m
    screen.Show()
End Sub

Sub prefsHandleReorderPreference(regKey, index)
    m.currentIndex = index
    m.currentRegKey = regKey
    label = m.contentArray[index].OrigTitle
    pref = m.Prefs[regKey]

    screen = m.ViewController.CreateReorderScreen(pref.values, [label], false)
    screen.InitializeOrder(RegRead(regKey, "preferences", pref.default))
    screen.Listener = m
    screen.Show()
End Sub

Sub prefsOnUserInput(value, screen)
    if type(screen.Screen) = "roKeyboardScreen" then
        RegWrite(m.currentRegKey, value, "preferences")
        m.Changes.AddReplace(m.currentRegKey, value)
        m.AppendValue(m.currentIndex, value)
    else if type(screen.Screen) = "roListScreen" AND screen.ListScreenType = "reorder" then
        RegWrite(m.currentRegKey, value, "preferences")
        m.Changes.AddReplace(m.currentRegKey, value)
    else
        label = m.contentArray[m.currentIndex].OrigTitle
        if screen.SelectedIndex <> invalid then
            Debug("Set " + label + " to " + screen.SelectedValue)
            RegWrite(m.currentRegKey, screen.SelectedValue, "preferences")
            m.Changes.AddReplace(m.currentRegKey, screen.SelectedValue)
            m.AppendValue(m.currentIndex, screen.SelectedLabel)
        end if
    end if
End Sub

Function prefsGetEnumValue(regKey)
    pref = m.Prefs[regKey]
    value = RegRead(regKey, "preferences", pref.default)
    m.Changes.AddReplace(regKey, value) ' ljunkie add changes, we can key of changes: 'm.Changes["_prev_{regKey}"] will have the previously selection
    for each item in pref.values
        if value = item.EnumValue then
            return item.title
        end if
    next

    return invalid
End Function

Function prefsGetPrefValue(regKey)
    pref = m.Prefs[regKey]
    return RegRead(regKey, "preferences", pref.default)
End Function

'*** Main Preferences ***

Function createPreferencesScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.Show = showPreferencesScreen
    obj.HandleMessage = prefsMainHandleMessage
    obj.Activate = prefsMainActivate

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
        heading: "Higher settings produce better video quality but require more" + Chr(10) + "network bandwidth. (Current reported bandwidth is " + tostr(GetGlobalAA().Lookup("bandwidth")) + "kbps)",
        default: "7"
    }
    obj.Prefs["quality_remote"] = {
        values: qualities,
        heading: "Higher settings produce better video quality but require more" + Chr(10) + "network bandwidth. (Current reported bandwidth is " + tostr(GetGlobalAA().Lookup("bandwidth")) + "kbps)",
        default: RegRead("quality", "preferences", "7")
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
    obj.checkMyPlexOnActivate = false

    return obj
End Function

Sub showPreferencesScreen()
    versionArr = GetGlobalAA().Lookup("rokuVersionArr")
    major = versionArr[0]

    m.Screen.SetTitle("Preferences v" + GetGlobalAA().Lookup("appVersionStr"))
    m.Screen.SetHeader("Set Plex Channel Preferences")

    ' re-ordered - RR
    m.AddItem({title: "Plex Media Servers"}, "servers")
    m.AddItem({title: getCurrentMyPlexLabel()}, "myplex")
    m.AddItem({title: "RARflix Preferences", ShortDescriptionLine2: "the goods"}, "rarflix_prefs")
    m.AddItem({title: "Quality"}, "quality", m.GetEnumValue("quality"))
    m.AddItem({title: "Remote Quality"}, "quality_remote", m.GetEnumValue("quality_remote"))
    m.AddItem({title: "Direct Play"}, "directplay", m.GetEnumValue("directplay"))
    m.AddItem({title: "Audio Preferences"}, "audio_prefs")
    m.AddItem({title: "Home Screen"}, "homescreen")
    m.AddItem({title: "Section Display"}, "sections")
    m.AddItem({title: "Remote Control/Name"}, "remotecontrol")
    m.AddItem({title: "Subtitles"}, "subtitles")
    m.AddItem({title: "Slideshow"}, "slideshow")
    m.AddItem({title: "Screensaver"}, "screensaver", m.GetEnumValue("screensaver"))
    m.AddItem({title: "Logging"}, "debug")
    m.AddItem({title: "Advanced Preferences"}, "advanced")
    m.AddItem({title: "Close Preferences"}, "close")

    m.serversBefore = {}
    for each server in PlexMediaServers()
        if server.machineID <> invalid then
            m.serversBefore[server.machineID] = ""
        end if
    next

    m.Screen.Show()
End Sub

Function prefsMainHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            ' Figure out everything that changed and refresh the home screen.
            serversBefore = m.serversBefore
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

            m.ViewController.PopScreen(m)
            m.ViewController.Home.Refresh(m.Changes)
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "servers" then
                screen = createManageServersScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Plex Media Servers"])
                screen.Changes = m.Changes
                screen.Show()
            else if command = "myplex" then
                if m.myplex.IsSignedIn then
                    m.myplex.Disconnect()
                    m.Changes["myplex"] = "disconnected"
                    m.SetTitle(msg.GetIndex(), getCurrentMyPlexLabel())
                else
                    m.checkMyPlexOnActivate = true
                    m.myPlexIndex = msg.GetIndex()
                    screen = createMyPlexPinScreen(m.ViewController)
                    m.ViewController.InitializeOtherScreen(screen, invalid)
                    screen.Show()
                end if
            else if command = "quality" OR command = "quality_remote" OR command = "level" OR command = "directplay" OR command = "screensaver" then
                m.HandleEnumPreference(command, msg.GetIndex())
            else if command = "slideshow" then
                screen = createSlideshowPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Slideshow Preferences"])
                screen.Show()
            else if command = "subtitles" then
                screen = createSubtitlePrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Subtitle Preferences"])
                screen.Show()
            else if command = "sections" then
                screen = createSectionDisplayPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Section Display Preferences"])
                screen.Show()
            else if command = "remotecontrol" then
                screen = createRemoteControlPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Remote Control Preferences"])
                screen.Show()
            else if command = "homescreen" then
                screen = createHomeScreenPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Home Screen"])
                screen.Show()
            else if command = "advanced" then
                screen = createAdvancedPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Advanced Preferences"])
                screen.Show()
            else if command = "debug" then
                screen = createDebugLoggingScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Logging"])
                screen.Show()
            else if command = "audio_prefs" then
                screen = createAudioPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Audio Preferences"])
                screen.Show()
            else if command = "rarflix_prefs" then
                screen = createRARFlixPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["RARFlix Preferences"])
                screen.Show()
            else if command = "close" then
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function

Sub prefsMainActivate(priorScreen)
    if m.checkMyPlexOnActivate then
        m.checkMyPlexOnActivate = false
        if m.myplex.IsSignedIn then
            m.Changes["myplex"] = "connected"
        end if
        m.SetTitle(m.myPlexIndex, getCurrentMyPlexLabel())
    end if
End Sub

'*** Slideshow Preferences ***

Function createSlideshowPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.HandleMessage = prefsSlideshowHandleMessage

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

    obj.Screen.SetHeader("Slideshow display preferences")

    obj.AddItem({title: "Speed"}, "slideshow_period", obj.GetEnumValue("slideshow_period"))
    obj.AddItem({title: "Text Overlay"}, "slideshow_overlay", obj.GetEnumValue("slideshow_overlay"))
    obj.AddItem({title: "Close"}, "close")

    return obj
End Function

Function prefsSlideshowHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "slideshow_period" OR command = "slideshow_overlay" then
                m.HandleEnumPreference(command, msg.GetIndex())
            else if command = "close" then
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function

'*** Subtitle Preferences ***

Function createSubtitlePrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.HandleMessage = prefsSubtitleHandleMessage

    ' Enable soft subtitles
    softsubtitles = [
        { title: "Soft", EnumValue: "1", ShortDescriptionLine2: "Use soft subtitles whenever possible." },
        { title: "Burned In", EnumValue: "0", ShortDescriptionLine2: "Always burn in selected subtitles." }
    ]
    obj.Prefs["softsubtitles"] = {
        values: softsubtitles,
        heading: "Allow Roku to show soft subtitles itself, or burn them in to videos?",
        default: "1"
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

    ' Subtitle color (soft only)
    colors = [
        { title: "Default", EnumValue: "" },
        { title: "Yellow", EnumValue: "#FFFF00" },
        { title: "White", EnumValue: "#FFFFFF" },
        { title: "Black", EnumValue: "#000000" }
    ]
    obj.Prefs["subtitle_color"] = {
        values: colors,
        heading: "Soft subtitle color",
        default: ""
    }

    obj.Screen.SetHeader("Subtitle Preferences")

    obj.AddItem({title: "Subtitles"}, "softsubtitles", obj.GetEnumValue("softsubtitles"))
    obj.AddItem({title: "Subtitle Size"}, "subtitle_size", obj.GetEnumValue("subtitle_size"))
    obj.AddItem({title: "Subtitle Color"}, "subtitle_color", obj.GetEnumValue("subtitle_color"))
    obj.AddItem({title: "Close"}, "close")

    return obj
End Function

Function prefsSubtitleHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
            if m.Changes.DoesExist("subtitle_color") then
                app = CreateObject("roAppManager")
                app.SetThemeAttribute("SubtitleColor", m.Changes["subtitle_color"])
            end if
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "softsubtitles" OR command = "subtitle_size" OR command = "subtitle_color" then
                m.HandleEnumPreference(command, msg.GetIndex())
            else if command = "close" then
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function

'*** Advanced Preferences ***

Function createAdvancedPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.HandleMessage = prefsAdvancedHandleMessage

    ' Transcoder version. We'll default to the "universal" transcoder, but
    ' there's also a server version check.
    transcoder_version = [
        { title: "Legacy", EnumValue: "classic", ShortDescriptionLine2: "Use the older, legacy transcoder." },
        { title: "Universal", EnumValue: "universal" }
    ]
    obj.Prefs["transcoder_version"] = {
        values: transcoder_version,
        heading: "Transcoder version",
        default: "universal"
    }

    ' Continuous play
    continuous_play = [
        { title: "Enabled", EnumValue: "1", ShortDescriptionLine2: "Experimental" },
        { title: "Disabled", EnumValue: "0" }
    ]
    obj.Prefs["continuous_play"] = {
        values: continuous_play,
        heading: "Automatically start playing the next video",
        default: "0"
    }

    ' H.264 Level
    levels = [
        { title: "Level 4.0 (Supported)", EnumValue: "40" },
        { title: "Level 4.1 (Supported)", EnumValue: "41" },
        { title: "Level 4.2", EnumValue: "42", ShortDescriptionLine2: "This level may not be supported well." },
        { title: "Level 5.0", EnumValue: "50", ShortDescriptionLine2: "This level may not be supported well." },
        { title: "Level 5.1", EnumValue: "51", ShortDescriptionLine2: "This level may not be supported well." }
    ]
    obj.Prefs["level"] = {
        values: levels,
        heading: "Use specific H264 level. Up to 4.1 is officially supported.",
        default: "41"
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

    ' Analytics (opt-out)
    values = [
        { title: "Enabled", EnumValue: "1" },
        { title: "Disabled", EnumValue: "0" }
    ]
    obj.Prefs["analytics"] = {
        values: values,
        heading: "Send anonymous usage data to help improve Plex",
        default: "1"
    }

    versionArr = GetGlobalAA().Lookup("rokuVersionArr")
    major = versionArr[0]

    obj.Screen.SetHeader("Advanced preferences don't usually need to be changed")

    obj.AddItem({title: "Transcoder"}, "transcoder_version", obj.GetEnumValue("transcoder_version"))
    obj.AddItem({title: "Continuous Play"}, "continuous_play", obj.GetEnumValue("continuous_play"))
    obj.AddItem({title: "H.264"}, "level", obj.GetEnumValue("level"))

    if GetGlobal("legacy1080p") then
        obj.AddItem({title: "1080p Settings"}, "1080p")
    end if

    obj.AddItem({title: "HLS Segment Length"}, "segment_length", obj.GetEnumValue("segment_length"))
    obj.AddItem({title: "Analytics"}, "analytics", obj.GetEnumValue("analytics"))
    obj.AddItem({title: "Close"}, "close")

    return obj
End Function

Function prefsAdvancedHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "1080p" then
                screen = create1080PreferencesScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["1080p Settings"])
                screen.Show()
            else if command = "close" then
                m.Screen.Close()
            else
                m.HandleEnumPreference(command, msg.GetIndex())
            end if
        end if
    end if

    return handled
End Function

'*** Legacy 1080p Preferences ***

Function create1080PreferencesScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.HandleMessage = prefs1080HandleMessage

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

    obj.Screen.SetHeader("1080p settings (Roku 1 only)")

    obj.AddItem({title: "1080p Support"}, "legacy1080p", obj.GetEnumValue("legacy1080p"))
    obj.AddItem({title: "Frame Rate Override"}, "legacy1080pframerate", obj.GetEnumValue("legacy1080pframerate"))
    obj.AddItem({title: "Close"}, "close")

    return obj
End Function

Function prefs1080HandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "legacy1080p" OR command = "legacy1080pframerate" then
                m.HandleEnumPreference(command, msg.GetIndex())
            else if command = "close" then
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function

'*** Audio Preferences ***

Function createAudioPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.HandleMessage = prefsAudioHandleMessage

    ' Loop album playback
    loopalbums = [
        { title: "Always", EnumValue: "always" },
        { title: "Never", EnumValue: "never" },
        { title: "Sometimes", EnumValue: "sometimes", ShortDescriptionLine2: "Loop playback when there are multiple songs." }
    ]
    obj.Prefs["loopalbums"] = {
        values: loopalbums,
        heading: "Loop when playing music",
        default: "sometimes"
    }

    ' Theme music
    theme_music = [
        { title: "Loop", EnumValue: "loop" },
        { title: "Play Once", EnumValue: "once" },
        { title: "Disabled", EnumValue: "disabled" }
    ]
    obj.Prefs["theme_music"] = {
        values: theme_music,
        heading: "Play theme music in the background while browsing",
        default: "loop"
    }

    ' 5.1 Support - AC-3
    fiveone = [
        { title: "Enabled", EnumValue: "1", ShortDescriptionLine2: "Try to copy 5.1 audio streams when transcoding." },
        { title: "Disabled", EnumValue: "2", ShortDescriptionLine2: "Always use 2-channel audio when transcoding." }
    ]
    obj.Prefs["fivepointone"] = {
        values: fiveone,
        heading: "5.1 AC-3 support",
        default: "1"
    }

    ' 5.1 Support - DTS
    fiveoneDCA = [
        { title: "Enabled", EnumValue: "1", ShortDescriptionLine2: "Try to Direct Play DTS in MKVs." },
        { title: "Disabled", EnumValue: "2", ShortDescriptionLine2: "Never Direct Play DTS." }
    ]
    obj.Prefs["fivepointoneDCA"] = {
        values: fiveoneDCA,
        heading: "5.1 DTS support",
        default: "1"
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

    obj.Screen.SetHeader("Audio Preferences")

    obj.AddItem({title: "Loop Playback"}, "loopalbums", obj.GetEnumValue("loopalbums"))
    obj.AddItem({title: "Theme Music"}, "theme_music", obj.GetEnumValue("theme_music"))

    if SupportsSurroundSound(true) then
        obj.AddItem({title: "5.1 AC-3 Support"}, "fivepointone", obj.GetEnumValue("fivepointone"))
        obj.AddItem({title: "5.1 DTS Support"}, "fivepointoneDCA", obj.GetEnumValue("fivepointoneDCA"))
    end if

    obj.AddItem({title: "Audio Boost"}, "audio_boost", obj.GetEnumValue("audio_boost"))

    obj.AddItem({title: "Close"}, "close")

    return obj
End Function

Function prefsAudioHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "close" then
                m.Screen.Close()
            else
                m.HandleEnumPreference(command, msg.GetIndex())
            end if
        end if
    end if

    return handled
End Function

'*** Debug Logging Preferences ***

Function createDebugLoggingScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.HandleMessage = prefsDebugHandleMessage

    obj.RefreshItems = debugRefreshItems
    obj.Logger = GetGlobalAA()["logger"]

    obj.Screen.SetHeader("Logging")
    obj.RefreshItems()

    return obj
End Function

Sub debugRefreshItems()
    m.contentArray.Clear()
    m.Screen.ClearContent()

    if m.Logger.Enabled then
        m.AddItem({title: "Disable Logging"}, "disable")

        myPlex = GetGlobalAA().Lookup("myplex")
        if myPlex <> invalid AND myPlex.IsSignedIn then
            if m.Logger.RemoteLoggingTimer <> invalid then
                remainingMinutes = int(0.5 + (m.Logger.RemoteLoggingSeconds - m.Logger.RemoteLoggingTimer.TotalSeconds()) / 60)
                if remainingMinutes > 1 then
                    extraLabel = " (" + tostr(remainingMinutes) + " minutes)"
                else
                    extraLabel = ""
                end if
                m.AddItem({title: "Remote Logging Enabled" + extraLabel}, "null")
            else
                m.AddItem({title: "Enable Remote Logging"}, "remote")
            end if
        end if

        m.AddItem({title: "Download Logs"}, "download")
    else
        m.AddItem({title: "Enable Logging"}, "enable")
    end if

    m.AddItem({title: "Close"}, "close")
End Sub

Function prefsDebugHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
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
            else if command = "remote" then
                ' TODO(schuyler) What if we want to debug something related
                ' to a non-primary server?
                m.Logger.EnablePapertrail(20, GetPrimaryServer())
                m.RefreshItems()
            else if command = "close" then
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function

'*** Manage Servers Preferences ***

Function createManageServersScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.superOnUserInput = obj.OnUserInput
    obj.HandleMessage = prefsServersHandleMessage
    obj.OnUserInput = prefsServersOnUserInput
    obj.Activate = prefsServersActivate
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

    obj.Screen.SetHeader("Manage Plex Media Servers")

    obj.AddItem({title: "Add Server Manually"}, "manual")
    obj.AddItem({title: "Discover Servers"}, "discover")
    obj.AddItem({title: "Discover at Startup"}, "autodiscover", obj.GetEnumValue("autodiscover"))
    obj.AddItem({title: "Remove All Servers"}, "removeall")

    obj.removeOffset = obj.contentArray.Count()
    obj.RefreshServerList(obj.removeOffset)

    obj.RefreshOnActivate = false

    return obj
End Function

Function prefsServersHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            Debug("Manage servers closed event")
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "manual" then
                screen = m.ViewController.CreateTextInputScreen("Enter Host Name or IP without http:// or :32400", ["Add Server Manually"], false)
                screen.Screen.SetMaxLength(80)
                screen.ValidateText = AddUnnamedServer
                screen.Show()
                m.RefreshOnActivate = true
            else if command = "discover" then
                DiscoverPlexMediaServers()
                m.RefreshServerList(m.removeOffset)
            else if command = "autodiscover" then
                m.HandleEnumPreference(command, msg.GetIndex())
            else if command = "removeall" then
                RemoveAllServers()
                ClearPlexMediaServers()
                m.RefreshServerList(m.removeOffset)
            else if command = "remove" then
                RemoveServer(msg.GetIndex() - m.removeOffset)
                m.contentArray.Delete(msg.GetIndex())
                m.Screen.RemoveContent(msg.GetIndex())
            else if command = "close" then
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function

Sub prefsServersOnUserInput(value, screen)
    if type(screen.Screen) = "roKeyboardScreen" then
        m.RefreshServerList(m.removeOffset)
    else
        m.superOnUserInput(value, screen)
    end if
End Sub

Sub prefsServersActivate(priorScreen)
    if m.RefreshOnActivate then
        m.RefreshOnActivate = false
        m.RefreshServerList(m.removeOffset)
    end if
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

'*** Video Playback Options ***

Function createVideoOptionsScreen(item, viewController, continuousPlay) As Object
    obj = createBasePrefsScreen(viewController)

    obj.Item = item

    obj.OnUserInput = videoOptionsOnUserInput
    obj.HandleMessage = videoOptionsHandleMessage
    obj.GetEnumValue = videoOptionsGetEnumValue

    ' Transcoding vs. direct play
    options = [
        { title: "Automatic", EnumValue: "0" },
        { title: "Direct Play", EnumValue: "1" },
        { title: "Direct Play w/ Fallback", EnumValue: "2" },
        { title: "Direct Stream/Transcode", EnumValue: "3" },
        { title: "Transcode", EnumValue: "4" }
    ]
    obj.Prefs["playback"] = {
        values: options,
        label: "Transcoding",
        heading: "Should this video be transcoded or use Direct Play?",
        default: RegRead("directplay", "preferences", "0")
    }

    ' Quality
    qualities = [
        { title: "720 kbps, 320p", EnumValue: "4" },
        { title: "1.5 Mbps, 480p", EnumValue: "5" },
        { title: "2.0 Mbps, 720p", EnumValue: "6" },
        { title: "3.0 Mbps, 720p", EnumValue: "7" },
        { title: "4.0 Mbps, 720p", EnumValue: "8" },
        { title: "8.0 Mbps, 1080p", EnumValue: "9"}
        { title: "10.0 Mbps, 1080p", EnumValue: "10" }
        { title: "12.0 Mbps, 1080p", EnumValue: "11" }
        { title: "20.0 Mbps, 1080p", EnumValue: "12" }
    ]
    obj.Prefs["quality"] = {
        values: qualities,
        label: "Quality",
        heading: "Higher settings require more bandwidth and may buffer",
        default: tostr(GetQualityForItem(item))
    }

    audioStreams = []
    subtitleStreams = []
    defaultAudio = ""
    defaultSubtitle = ""

    subtitleStreams.Push({ title: "No Subtitles", EnumValue: "" })

    if (item.server.owned OR item.server.SupportsMultiuser) AND item.preferredMediaItem <> invalid AND item.preferredMediaItem.preferredPart <> invalid AND item.preferredMediaItem.preferredPart.Id <> invalid then
        for each stream in item.preferredMediaItem.preferredPart.streams
            if stream.streamType = "2" then
                language = GetSafeLanguageName(stream)
                format = ucase(firstOf(stream.Codec, ""))
                if format = "DCA" then format = "DTS"
                if stream.Channels <> invalid then
                    if stream.Channels = "2" then
                        format = format + " Stereo"
                    else if stream.Channels = "1" then
                        format = format + " Mono"
                    else if stream.Channels = "6" then
                        format = format + " 5.1"
                    else if stream.Channels = "7" then
                        format = format + " 6.1"
                    else if stream.Channels = "8" then
                        format = format + " 7.1"
                    end if
                end if
                if format <> "" then
                    title = language + " (" + format + ")"
                else
                    title = language
                end if
                if stream.selected <> invalid then
                    defaultAudio = stream.Id
                end if

                audioStreams.Push({ title: title, EnumValue: stream.Id })
            else if stream.streamType = "3" then
                label = GetSafeLanguageName(stream)
                label = label + " (" + UCase(firstOf(stream.Codec, "")) + ")"
                if shouldUseSoftSubs(stream) then
                    label = label + "*"
                end if
                if stream.selected <> invalid then
                    defaultSubtitle = stream.Id
                end if

                subtitleStreams.Push({ title: label, EnumValue: stream.Id })
            end if
        next
    end if

    ' Audio streams
    Debug("Found audio streams: " + tostr(audioStreams.Count()))
    if audioStreams.Count() > 0 then
        obj.Prefs["audio"] = {
            values: audioStreams,
            label: "Audio Stream",
            heading: "Select an audio stream",
            default: defaultAudio
        }
    end if

    ' Subtitle streams
    Debug("Found subtitle streams: " + tostr(subtitleStreams.Count() - 1))
    if subtitleStreams.Count() > 1 then
        obj.Prefs["subtitles"] = {
            values: subtitleStreams,
            label: "Subtitle Stream",
            heading: "Select a subtitle stream",
            default: defaultSubtitle
        }
    end if

    ' Continuous play
    if continuousPlay = true then
        defaultContinuous = "1"
    else
        defaultContinuous = "0"
    end if
    continuous_play = [
        { title: "Enabled", EnumValue: "1", ShortDescriptionLine2: "Experimental" },
        { title: "Disabled", EnumValue: "0" }
    ]
    obj.Prefs["continuous_play"] = {
        values: continuous_play,
        label: "Continuous Play"
        heading: "Automatically start playing the next video",
        default: defaultContinuous
    }

    ' Media selection
    mediaOptions = []
    defaultMedia = ""

    if item.media <> invalid then
        mediaIndex = 0
        for each media in item.media
            if media.AsString <> invalid then
                mediaName = media.AsString
            else
                mediaName = UCase(firstOf(media.container, "?"))
                mediaName = mediaName + "/" + UCase(firstOf(media.videoCodec, "?"))
                mediaName = mediaName + "/" + UCase(firstOf(media.audioCodec, "?"))
                mediaName = mediaName + "/" + firstOf(media.videoResolution, "?")
                mediaName = mediaName + "/" + tostr(media.bitrate) + "kbps"
                media.AsString = mediaName
            end if

            mediaOptions.Push({ title: mediaName, EnumValue: tostr(mediaIndex) })
            mediaIndex = mediaIndex + 1

            'if media = item.preferredMediaItem then
                'defaultMedia = mediaName
            'end if
        next
    end if

    if mediaOptions.Count() > 1 then
        obj.Prefs["media"] = {
            values: mediaOptions,
            label: "Media",
            heading: "Select a source",
            default: defaultMedia
        }
    end if

    obj.Screen.SetHeader("Video playback options")

    possiblePrefs = ["playback", "quality", "audio", "subtitles", "media", "continuous_play"]
    for each key in possiblePrefs
        pref = obj.Prefs[key]
        if pref <> invalid then
            obj.AddItem({title: pref.label}, key)
            obj.AppendValue(invalid, obj.GetEnumValue(key))
        end if
    next

    obj.AddItem({title: "Close"}, "close")

    return obj
End Function

Function videoOptionsHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            Debug("Closing video options screen")
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "close" then
                m.Screen.Close()
            else
                pref = m.Prefs[command]
                m.currentIndex = msg.GetIndex()
                m.currentEnumKey = command
                screen = m.ViewController.CreateEnumInputScreen(pref.values, pref.default, pref.heading, [pref.label], false)
                screen.Listener = m
                screen.Show()
            end if
        end if
    end if

    return handled
End Function

Sub videoOptionsOnUserInput(value, screen)
    if screen.SelectedIndex <> invalid then
        m.Changes.AddReplace(m.currentEnumKey, screen.SelectedValue)
        m.Prefs[m.currentEnumKey].default = screen.SelectedValue
        m.AppendValue(m.currentIndex, screen.SelectedLabel)
    end if
End Sub

Function videoOptionsGetEnumValue(key)
    pref = m.Prefs[key]
    for each item in pref.values
        if item.EnumValue = pref.default then
            return item.title
        end if
    next

    return invalid
End Function

'*** Remote Control Preferences ***

Function createRemoteControlPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.HandleMessage = prefsRemoteControlHandleMessage

    ' Enabled
    options = [
        { title: "Enabled", EnumValue: "1" },
        { title: "Disabled", EnumValue: "0" }
    ]
    obj.Prefs["remotecontrol"] = {
        values: options,
        heading: "Allow other clients to control this Roku.",
        default: "1"
    }

    obj.Prefs["player_name"] = {
        heading: "A name that will identify this Roku on your remote controls",
        default: GetGlobalAA().Lookup("rokuModel")
    }

    obj.Screen.SetHeader("Remote control preferences")

    obj.AddItem({title: "Remote Control"}, "remotecontrol", obj.GetEnumValue("remotecontrol"))
    obj.AddItem({title: "Name"}, "player_name", obj.GetPrefValue("player_name"))
    obj.AddItem({title: "Close"}, "close")

    return obj
End Function

Function prefsRemoteControlHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            Debug("Remote control closed event")
            m.ViewController.GdmAdvertiser.Refresh()
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "player_name" then
                m.HandleTextPreference(command, msg.GetIndex())
            else if command = "remotecontrol" then
                m.HandleEnumPreference(command, msg.GetIndex())
            else if command = "close" then
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function

'*** Home Screen Preferences ***

Function createHomeScreenPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.HandleMessage = prefsHomeHandleMessage

    ' Default view for queue and recommendations
    values = [
        { title: "All", EnumValue: "all" },
        { title: "Unwatched", EnumValue: "unwatched" },
        { title: "Watched", EnumValue: "watched" },
        { title: "Hidden", EnumValue: "hidden" }
    ]
    obj.Prefs["playlist_view_queue"] = {
        values: values,
        heading: "Default view for Queue on the home screen",
        default: "unwatched"
    }
    obj.Prefs["playlist_view_recommendations"] = {
        values: values,
        heading: "Default view for Recommendations on the home screen",
        default: "unwatched"
    }

    ' Visibility for on deck and recently added
    values = [
        { title: "Enabled", EnumValue: "" },
        { title: "Hidden", EnumValue: "hidden" }
    ]
    obj.Prefs["row_visibility_ondeck"] = {
        values: values,
        heading: "Show On Deck items on the home screen",
        default: ""
    }
    obj.Prefs["row_visibility_recentlyadded"] = {
        values: values,
        heading: "Show recently added items on the home screen",
        default: ""
    }
    obj.Prefs["row_visibility_channels"] = {
        values: values,
        heading: "Show channels on the home screen",
        default: ""
    }
    obj.Prefs["row_visibility_now_playing"] = {
        values: values,
        heading: "Show Now Playing on the home screen",
        default: ""
    }

    ' Home screen rows that can be reordered
    values = [
        { title: "Channels", key: "channels" },
        { title: "Library Sections", key: "sections" },
        { title: "On Deck", key: "on_deck" },
        { title: "Now Playing", key: "now_playing" },
        { title: "Recently Added", key: "recently_added" },
        { title: "Queue", key: "queue" },
        { title: "Recommendations", key: "recommendations" },
        { title: "Shared Library Sections", key: "shared_sections" },
        { title: "Miscellaneous", key: "misc" }
    ]
    obj.Prefs["home_row_order"] = {
        values: values,
        default: ""
    }

    display_modes = [
        { title: "Photo [default]", EnumValue: "photo-fit", ShortDescriptionLine2: "Default" },
        { title: "Fit", EnumValue: "scale-to-fit", ShortDescriptionLine2: "scaled to fit"  },
        { title: "Fill", EnumValue: "scale-to-fill", ShortDescriptionLine2: "stretch image to fill boundary" },
        { title: "Zoom", EnumValue: "zoom-to-fill", ShortDescriptionLine2: "zoom image to fill boundary" },
    ]
    obj.Prefs["rf_home_displaymode"] = {
        values: display_modes,
        heading: "How should images be displayed on the home screen (channel restart required)",
        default: "photo-fit"
    }

    obj.Screen.SetHeader("Change the appearance of the home screen")
    obj.AddItem({title: "Reorder Home Rows", ShortDescriptionLine2: "A restart of the Channel is required"}, "home_row_order")
    obj.AddItem({title: "Display Mode", ShortDescriptionLine2: "Stretch or Fit images to fill the focus box"}, "rf_home_displaymode", obj.GetEnumValue("rf_home_displaymode"))
    obj.AddItem({title: "Queue"}, "playlist_view_queue", obj.GetEnumValue("playlist_view_queue"))
    obj.AddItem({title: "Recommendations"}, "playlist_view_recommendations", obj.GetEnumValue("playlist_view_recommendations"))
    obj.AddItem({title: "On Deck"}, "row_visibility_ondeck", obj.GetEnumValue("row_visibility_ondeck"))
    obj.AddItem({title: "Now Playing", ShortDescriptionLine2: "rarflix pref"}, "row_visibility_now_playing", obj.GetEnumValue("row_visibility_now_playing"))
    obj.AddItem({title: "Recently Added"}, "row_visibility_recentlyadded", obj.GetEnumValue("row_visibility_recentlyadded"))
    obj.AddItem({title: "Channels"}, "row_visibility_channels", obj.GetEnumValue("row_visibility_channels"))
    obj.AddItem({title: "Close"}, "close")

    return obj
End Function

Function prefsHomeHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "playlist_view_queue" OR command = "playlist_view_recommendations" OR command = "row_visibility_ondeck" OR command = "row_visibility_recentlyadded" OR command = "row_visibility_channels" or command = "row_visibility_now_playing" or command = "rf_home_displaymode" then
                m.HandleEnumPreference(command, msg.GetIndex())
            else if command = "home_row_order" then
                m.HandleReorderPreference(command, msg.GetIndex())
            else if command = "close" then
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function

'*** Section Display Preferences ***

Function createSectionDisplayPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.HandleMessage = prefsSectionDisplayHandleMessage

    ' Grids or posters for TV series?
    values = [
        { title: "Grid", EnumValue: "1" },
        { title: "Poster", EnumValue: "" }
    ]
    obj.Prefs["use_grid_for_series"] = {
        values: values,
        heading: "Which screen type should be used for TV series?",
        default: ""
    }


    ' Prefer Grid or Poster view for most?
    rf_poster_grid = [
        { title: "Grid", EnumValue: "grid", ShortDescriptionLine2: "Prefer FULL grid when viewing items"  },
        { title: "Poster", EnumValue: "poster", ShortDescriptionLine2: "Prefer Poster (one row) when viewing items"  },


    ]
    obj.Prefs["rf_poster_grid"] = {
        values: rf_poster_grid,
        heading: "Which screen type should be used for Movies & Other content?",
        default: "grid"
    }

    ' Prefer Grid or Poster view for most?
    rf_grid_style = [
        { title: "Normal", EnumValue: "flat-movie", ShortDescriptionLine2: "5x2"  },
        { title: "Small", EnumValue: "flat-square", ShortDescriptionLine2: "7x3" },

    ]
    obj.Prefs["rf_grid_style"] = {
        values: rf_grid_style,
        heading: "Size of the Grid",
        default: "flat-movie"
    }

    ' Display Mode for Grid or Poster views
    display_modes = [
        { title: "Fit [default]", EnumValue: "scale-to-fit", ShortDescriptionLine2: "Default"  },
        { title: "Fill", EnumValue: "scale-to-fill", ShortDescriptionLine2: "stretch image to fill boundary" },
        { title: "Zoom", EnumValue: "zoom-to-fill", ShortDescriptionLine2: "zoom image to fill boundary" },
        { title: "Photo", EnumValue: "photo-fit", ShortDescriptionLine2: "all the above to fit boundary" },

    ]
    obj.Prefs["rf_grid_displaymode"] = {
        values: display_modes,
        heading: "How should images be displayed on screen",
        default: "scale-to-fit"
    }
    obj.Prefs["rf_poster_displaymode"] = {
        values: display_modes,
        heading: "How should images be displayed on screen",
        default: "scale-to-fit"
    }

    ' Grid rows that can be reordered
    values = [
        { title: "All Items", key: "all" },
        { title: "On Deck", key: "onDeck" },
        { title: "Recently Added", key: "recentlyAdded" },
        { title: "Recently Released/Aired", key: "newest" },
        { title: "Unwatched", key: "unwatched" },
        { title: "Recently Viewed", key: "recentlyViewed" },
        { title: "Recently Viewed Shows", key: "recentlyViewedShows" },
        { title: "By Album", key: "albums" },
        { title: "By Collection", key: "collection" },
        { title: "By Genre", key: "genre" },
        { title: "By Year", key: "year" },
        { title: "By Decade", key: "decade" },
        { title: "By Director", key: "director" },
        { title: "By Actor", key: "actor" },
        { title: "By Country", key: "country" },
        { title: "By Content Rating", key: "contentRating" },
        { title: "By Rating", key: "rating" },
        { title: "By Resolution", key: "resolution" },
        { title: "By First Letter", key: "firstCharacter" },
        { title: "By Folder", key: "folder" },
        { title: "Search", key: "_search_" }
    ]

    ' Unshift these in -- easier to remember to merge with PlexTest
    values.Unshift({ title: "[movie] Recently Added (uw)", key: "all?type=1&unwatched=1&sort=addedAt:desc" })
    values.Unshift({ title: "[movie] Recently Released (uw)", key: "all?type=1&unwatched=1&sort=originallyAvailableAt:desc" })

    obj.Prefs["section_row_order"] = {
        values: values,
        default: ""
    }

    obj.Screen.SetHeader("Change the appearance of your sections")

    obj.AddItem({title: "TV Series"}, "use_grid_for_series", obj.GetEnumValue("use_grid_for_series"))
    obj.AddItem({title: "Movie & Others", ShortDescriptionLine2: "Posters or Grid"}, "rf_poster_grid", obj.GetEnumValue("rf_poster_grid"))
    obj.AddItem({title: "Grid Size", ShortDescriptionLine2: "Size of Grid"}, "rf_grid_style", obj.GetEnumValue("rf_grid_style"))
    obj.AddItem({title: "Grid Display Mode", ShortDescriptionLine2: "Stretch or Fit images to fill the focus box"}, "rf_grid_displaymode", obj.GetEnumValue("rf_grid_displaymode"))
    'we can add this.. but it doesn't do much yet.. let's not totally confuse people.. yet.
    'obj.AddItem({title: "Poster Display Mode", ShortDescriptionLine2: "Stretch or Fit images to fill the focus box"}, "rf_poster_displaymode", obj.GetEnumValue("rf_poster_displaymode"))
    obj.AddItem({title: "Reorder Rows"}, "section_row_order")
    obj.AddItem({title: "Close"}, "close")

    return obj
End Function

Function prefsSectionDisplayHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "use_grid_for_series" or command = "rf_poster_grid" or command = "rf_grid_style" or command = "rf_grid_displaymode" or command = "rf_poster_displaymode" then
                m.HandleEnumPreference(command, msg.GetIndex())
            else if command = "section_row_order" then
                m.HandleReorderPreference(command, msg.GetIndex())
            else if command = "close" then
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function

'*** Helper functions ***

Function getCurrentMyPlexLabel() As String
    myplex = GetMyPlexManager()
    if myplex.IsSignedIn then
        return "Disconnect myPlex account (" + myplex.EmailAddress + ")"
    else
        return "Connect myPlex account"
    end if
End Function

Function GetQualityForItem(item) As Integer
    override = RegRead("quality_override", "preferences")
    if override <> invalid then return override.toint()

    if item <> invalid AND item.server <> invalid AND item.server.local = true AND item.isLibraryContent = true then
        return RegRead("quality", "preferences", "7").toint()
    else
        return RegRead("quality_remote", "preferences", RegRead("quality", "preferences", "7")).toint()
    end if
End Function
