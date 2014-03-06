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
    m.AddItem({title: tr("Close")}, "close")

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
                    screen = m.ViewController.CreateTextInputScreen("Enter " + setting.label, [], false, setting.value, (setting.hidden OR setting.secure))
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
    screen = m.ViewController.CreateEnumInputScreen(pref.values, RegRead(regKey, "preferences", pref.default, m.currentUser), pref.heading, [label], false)
    m.Changes.AddReplace("_previous_"+regKey, RegRead(regKey, "preferences", pref.default, m.currentUser)) ' ljunkie - set _previous_ value to key off of later
    screen.Listener = m
    screen.Show()
End Sub

Sub prefsHandleTextPreference(regKey, index)
    m.currentIndex = index
    m.currentRegKey = regKey
    label = m.contentArray[index].OrigTitle
    pref = m.Prefs[regKey]
    value = RegRead(regKey, "preferences", pref.default)
    screen = m.ViewController.CreateTextInputScreen(pref.heading, [label], false, value)
    screen.Text = value
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
    screen.InitializeOrder(RegRead(regKey, "preferences", pref.default, m.currentUser))  'm.currentUser may be "invalid" and RegRead will use global currentUser
    screen.Listener = m
    screen.Show()
End Sub

Sub prefsOnUserInput(value, screen)
    if type(screen.Screen) = "roKeyboardScreen" then
        RegWrite(m.currentRegKey, value, "preferences", m.currentUser)  'm.currentUser may be "invalid" and RegWrite will use the global currentUser
        m.Changes.AddReplace(m.currentRegKey, value)
        m.AppendValue(m.currentIndex, value)
    else if type(screen.Screen) = "roListScreen" AND screen.ListScreenType = "reorder" then
        RegWrite(m.currentRegKey, value, "preferences", m.currentUser)  'm.currentUser may be "invalid" and RegWrite will use the global currentUser
        m.Changes.AddReplace(m.currentRegKey, value)
    else
        label = m.contentArray[m.currentIndex].OrigTitle
        if screen.SelectedIndex <> invalid then
            ' instead of having to close/open the channel again - we can dynamically fix some settings through the channel. 
            ' As of now (2013-11-09) if someone disables/enables the Description Pop Out on a grid screen, we will set that on any open grid screen
            ' update (2013-11-12) the only screen we need to upate is the HOME screen since we are in settings
            if m.currentRegKey = "rf_grid_description_home" then 
                selection = (tostr(screen.SelectedValue) = "enabled")
                for each resetscreen in m.viewcontroller.screens
                    if resetscreen <> invalid and type(resetscreen.screen) = "roGridScreen" and resetscreen.ScreenID = -1 then 
                        resetscreen.screen.SetDescriptionVisible(selection)
                        exit for
                    end if
                end for
            end if
            ' end dynmamic set

            Debug("Set " + label + " to " + screen.SelectedValue)
            RegWrite(m.currentRegKey, screen.SelectedValue, "preferences", m.currentUser)  'm.currentUser may be "invalid" and RegWrite will use the global currentUser

            ' reset timer or remove based on settings
            if m.currentRegKey = "locktime" then m.ViewController.CreateIdleTimer()

            m.Changes.AddReplace(m.currentRegKey, screen.SelectedValue)
            m.AppendValue(m.currentIndex, screen.SelectedLabel)
        end if
    end if
End Sub

Function prefsGetEnumValue(regKey, currentUser = invalid)
    pref = m.Prefs[regKey]
    if currentUser = invalid then currentUser = m.currentUser
    value = RegRead(regKey, "preferences", pref.default, currentUser)  'currentUser may be "invalid" and RegRead will use global currentUser
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
    value = RegRead(regKey, "preferences", pref.default, m.currentUser)  'm.currentUser may be "invalid" and RegRead will use global currentUser
    return value
End Function
'*** Main Preferences ***

Function createPreferencesScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.Show = showPreferencesScreen
    obj.HandleMessage = prefsMainHandleMessage
    obj.Activate = prefsMainActivate

    ' Quality settings
    qualities = [
        { title: "208 kbps, 160p", EnumValue: "2" },
        { title: "320 kbps, 240p", EnumValue: "3" },
        { title: "720 kbps, 320p", EnumValue: "4" },
        { title: "1.5 Mbps, 480p", EnumValue: "5" },
        { title: "2.0 Mbps, 720p", EnumValue: "6" },
        { title: "3.0 Mbps, 720p", EnumValue: "7", ShortDescriptionLine2: tr("Default") },
        { title: "4.0 Mbps, 720p", EnumValue: "8" },
        { title: "8.0 Mbps, 1080p", EnumValue: "9", ShortDescriptionLine2: tr("Pushing the limits, requires fast connection.") }
        { title: "10.0 Mbps, 1080p", EnumValue: "10", ShortDescriptionLine2: tr("May be unstable, not recommended.") }
        { title: "12.0 Mbps, 1080p", EnumValue: "11", ShortDescriptionLine2: tr("May be unstable, not recommended.") }
        { title: "20.0 Mbps, 1080p", EnumValue: "12", ShortDescriptionLine2: tr("May be unstable, not recommended.") }
    ]
    bw_text = chr(32) + " * Current bandwidth is unavailable. Please check back in a minute. "
    if GetGlobalAA().Lookup("bandwidth") <> invalid then
        rawBW = GetGlobalAA().Lookup("bandwidth")
        if rawBW > 1000 then 
            bandwidth = tostr(rawBW/1000) + " Mbps"
        else 
            bandwidth = tostr(rawBW) + " kbps"
        end if
        bw_text = chr(32) + " * Current reported bandwidth is " + bandwidth
    end if
    obj.Prefs["quality"] = {
        values: qualities,
        heading: "Higher settings produce better video quality but require more bandwidth." + chr(10) + bw_text,
        default: "7"
    }
    obj.Prefs["quality_remote"] = {
        values: qualities,
        heading: "Higher settings produce better video quality but require more bandwidth." + chr(10) + bw_text,
        default: RegRead("quality", "preferences", "7")
    }

    ' Direct play options
    directplay = [
        { title: tr("Automatic (recommended)"), EnumValue: "0" },
        { title: tr("Direct Play"), EnumValue: "1", ShortDescriptionLine2: tr("Always Direct Play, no matter what.") },
        { title: tr("Direct Play w/ Fallback"), EnumValue: "2", ShortDescriptionLine2: tr("Always try Direct Play, then transcode.") },
        { title: tr("Direct Stream/Transcode"), EnumValue: "3", ShortDescriptionLine2: tr("Always Direct Stream or transcode.") },
        { title: tr("Always Transcode"), EnumValue: "4", ShortDescriptionLine2: tr("Never Direct Play or Direct Stream.") }
    ]
    obj.Prefs["directplay"] = {
        values: directplay,
        heading: tr("Direct Play preferences"),
        default: "0"
    }

    ' Screensaver options
    screensaver = [
        { title: tr("Disabled"), EnumValue: "disabled", ShortDescriptionLine2: tr("Use the system screensaver") },
        { title: tr("Animated"), EnumValue: "animated" },
        { title: tr("Random"), EnumValue: "random" }
    ]
    obj.Prefs["screensaver"] = {
        values: screensaver,
        heading: tr("Screensaver"),
        default: "random"
    }

    obj.checkMyPlexOnActivate = false
    obj.checkStatusOnActivate = false

    return obj
End Function

Sub showPreferencesScreen()
    versionArr = GetGlobalAA().Lookup("rokuVersionArr")
    major = versionArr[0]

    m.Screen.SetTitle("Preferences v" + GetGlobalAA().Lookup("appVersionStr"))
    m.Screen.SetHeader("Set Plex Channel Preferences")

    ' re-ordered - RR
    m.AddItem({title: tr("About RARflix")}, tr("ShowReleaseNotes"))
    m.AddItem({title: tr("RARflix Preferences"), ShortDescriptionLine2: tr("the goods")}, "rarflix_prefs")
    m.AddItem({title: getCurrentMyPlexLabel()}, "myplex")
    m.AddItem({title: tr("User Profiles"), ShortDescriptionLine2: tr("Fast user switching")}, "userprofiles")
    m.AddItem({title: tr("Security PIN"), ShortDescriptionLine2: tr("Require a PIN to access (multi-user supported)")}, "securitypin")
    m.AddItem({title: tr("Plex Media Servers")}, "servers")
    m.AddItem({title: tr("Quality")}, "quality", m.GetEnumValue("quality"))
    m.AddItem({title: tr("Remote Quality")}, "quality_remote", m.GetEnumValue("quality_remote"))
    m.AddItem({title: tr("Direct Play")}, "directplay", m.GetEnumValue("directplay"))
    m.AddItem({title: tr("Audio Preferences")}, "audio_prefs")
    m.AddItem({title: tr("Home Screen")}, "homescreen")
    m.AddItem({title: tr("Section Display")}, "sections")
    m.AddItem({title: tr("Remote Control/Name")}, "remotecontrol")
    m.AddItem({title: tr("Subtitles")}, "subtitles")
    m.AddItem({title: tr("Slideshow & Photos")}, "slideshow")
    m.AddItem({title: tr("Screensaver")}, "screensaver", m.GetEnumValue("screensaver"))
    m.AddItem({title: tr("Logging")}, "debug")
    m.AddItem({title: tr("Advanced Preferences")}, "advanced")
    m.AddItem({title: tr("Channel Status: ") + AppManager().State}, "status")

    m.AddItem({title: tr("Close Preferences")}, "close")

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
                if MyPlexManager().IsSignedIn then
                    MyPlexManager().Disconnect()
                    m.Changes["myplex"] = "disconnected"
                    m.SetTitle(msg.GetIndex(), getCurrentMyPlexLabel())
                else
                    m.checkMyPlexOnActivate = true
                    m.myPlexIndex = msg.GetIndex()
                    screen = createMyPlexPinScreen(m.ViewController)
                    m.ViewController.InitializeOtherScreen(screen, invalid)
                    screen.Show()
                end if
            else if command = "status" then
                m.checkStatusOnActivate = true
                m.statusIndex = msg.GetIndex()

                dialog = createBaseDialog()
                dialog.Title = tr("Channel Status")

                manager = AppManager()
                if manager.State = "PlexPass" then
                    dialog.Text = tr("Plex is fully unlocked since you're a PlexPass member.")
                else if manager.State = "Exempt" then
                    dialog.Text = tr("Plex is fully unlocked.")
                else if manager.State = "Purchased" then
                    dialog.Text = ("Plex has been purchased and is fully unlocked.")
                else if manager.State = "Trial" then
                    dialog.Text = tr("Plex is currently in a trial period. To fully unlock the channel, you can purchase it or connect a PlexPass account.")
                    dialog.SetButton("purchase", tr("Purchase the channel"))
                else if manager.State = "Limited" then
                    dialog.Text = tr("Your Plex trial has expired and playback is currently disabled. To fully unlock the channel, you can purchase it or connect a PlexPass account.")
                    dialog.SetButton("purchase", tr("Purchase the channel"))
                end if
                rarflixText = tr("You are using the ") + GetGlobal("appName") + " v" + GetGlobal("appVersionStr") + tr(" (Private) channel.")
                if dialog.Text <> invalid then 
                    dialog.Text = dialog.Text + chr(10) + rarflixText
                else 
                    dialog.Text = rarflixText
                end if

                dialog.SetButton("close", tr("Close"))
                dialog.HandleButton = channelStatusHandleButton
                dialog.Show()
            else if command = "quality" OR command = "quality_remote" OR command = "level" OR command = "fivepointone" OR command = "directplay" OR command = "screensaver" then
                m.HandleEnumPreference(command, msg.GetIndex())
            else if command = "slideshow" then
                screen = createSlideshowPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, [tr("Slideshow & Photo Preferences")])
                screen.Show()
            else if command = "securitypin" then
                screen = createSecurityPinPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, [tr("Security PIN")])
                screen.Show()            
            else if command = "userprofiles" then
                screen = createUserProfilesPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, [tr("User Profiles")])
                screen.Show()            
            else if command = "subtitles" then
                screen = createSubtitlePrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, [tr("Subtitle Preferences")])
                screen.Show()
            else if command = "sections" then
                screen = createSectionDisplayPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, [tr("Section Display Preferences")])
                screen.Show()
            else if command = "remotecontrol" then
                screen = createRemoteControlPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, [tr("Remote Control Preferences")])
                screen.Show()
            else if command = "homescreen" then
                screen = createHomeScreenPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, [tr("Home Screen")])
                screen.Show()
            else if command = "advanced" then
                screen = createAdvancedPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, [tr("Advanced Preferences")])
                screen.Show()
            else if command = "debug" then
                screen = createDebugLoggingScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, [tr("Logging")])
                screen.Show()
            else if command = "audio_prefs" then
                screen = createAudioPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, [tr("Audio Preferences")])
                screen.Show()
            else if command = "ShowReleaseNotes" then
                m.ViewController.ShowReleaseNotes("about")
            else if command = "rarflix_prefs" then
                screen = createRARflixPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, [tr("RARflix Preferences")])
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
        if MyPlexManager().IsSignedIn then
            m.Changes["myplex"] = "connected"
        end if
        m.SetTitle(m.myPlexIndex, getCurrentMyPlexLabel())
    else if m.checkStatusOnActivate then
        m.checkStatusOnActivate = false
        m.SetTitle(m.statusIndex, tr("Channel Status: ") + AppManager().State)
    end if
End Sub

Function channelStatusHandleButton(key, data) As Boolean
    if key = "purchase" then
        AppManager().StartPurchase()
    end if
    return true
End Function

'*** Slideshow Preferences ***

Function createSlideshowPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.HandleMessage = prefsSlideshowHandleMessage

    ' Photo duration
    values = [
        { title: tr("Slow (10 sec)"), EnumValue: "10" },
        { title: tr("Normal (6 sec)"), EnumValue: "6" },
        { title: tr("Fast (3 sec)"), EnumValue: "3" }
    ]
    obj.Prefs["slideshow_period"] = {
        values: values,
        heading: tr("Slideshow speed"),
        default: "6"
    }

    ' Overlay duration
    values = [
        { title: tr("Slow (10 sec)"), EnumValue: "10000" },
        { title: tr("Normal (2.5 sec)"), EnumValue: "2500" },
        { title: tr("Fast (1.5 sec)"), EnumValue: "1500" }
    ]
    obj.Prefs["slideshow_overlay"] = {
        values: values,
        heading: tr("Text overlay duration"),
        default: "2500"
    }

    ' Overlay Shared Values
    values = [
        { title: tr("Manual"), EnumValue: "manual", ShortDescriptionLine2: tr("Only show Overlay with remote buttons"),  }
        { title: tr("Enabled"), EnumValue: "enabled", ShortDescriptionLine2: tr("Automatically show Overlay on change"),  }
        { title: tr("Disabled"), EnumValue: "disabled",ShortDescriptionLine2: tr("Never show the overlay"),}
    ]

    ' Photo Info Overlay
    obj.Prefs["slideshow_photo_overlay"] = {
        values: values,
        heading: tr("Display Photo Info on the Overlay"),
        default: "enabled"
    }

    ' Audio Info Overlay
    obj.Prefs["slideshow_audio_overlay"] = {
        values: values,
        heading: tr("Display Audio Info on the Overlay"),
        default: "enabled"
    }

    ' Error/Debug Info Overlay
    obj.Prefs["slideshow_error_overlay"] = {
        values: values,
        heading: tr("Enable Debug Overlay"),
        default: "disabled"
    }

    ' overscan/underscan correction
    values = [
        { title: tr("TV"), EnumValue: "5" }
        { title: tr("Monitor"), EnumValue: "0" },
    ]
    obj.Prefs["slideshow_underscan"] = {
        values: values,
        heading: tr("Display Type Correction"),
        default: "5"
    }


    ' reload slideshow after every full run
    values = [
        { title: tr("Disabled"), EnumValue: "disabled", ShortDescriptionLine2: tr("Do not check for new Photos"), },
        { title: tr("Enabled"), EnumValue: "enabled", ShortDescriptionLine2: tr("Check for new Photos") },
    ]
    obj.Prefs["slideshow_reload"] = {
        values: values,
        heading: tr("Reload Slideshow after Completion (check for new photos)"),
        default: "disabled"
    }

    display_modes = [
        { title: tr("Fit"), EnumValue: "scale-to-fit", ShortDescriptionLine2: tr("scale to fit [no crop]")  },
        { title: tr("Smart"), EnumValue: "photo-fit", ShortDescriptionLine2: tr("smart scale+zoom to fit") },
        { title: tr("Fill"), EnumValue: "scale-to-fill", ShortDescriptionLine2: tr("stretch to fill") },
        { title: tr("Zoom"), EnumValue: "zoom-to-fill", ShortDescriptionLine2: tr("zoom to fill") },
    ]
    obj.Prefs["photoicon_displaymode"] = {
        values: display_modes,
        heading: tr("How should photos icons be displayed"),
        default: "photo-fit"
    }
    ' unadulterated -- we don't want cropping/zooming/etc by default
    obj.Prefs["slideshow_displaymode"] = {
        values: display_modes,
        heading: tr("How should images be displayed"),
        default: "scale-to-fit"
    }

    ' Prefer Grid or Poster view for most?
    rf_photos_grid_style = [
        { title: tr("Portrait"), EnumValue: "flat-movie", ShortDescriptionLine2: tr("Grid 5x2")  },
        { title: tr("Landscape 16x9"), EnumValue: "flat-16x9", ShortDescriptionLine2: tr("Grid 5x3")  },
        { title: tr("Landscape"), EnumValue: "flat-landscape", ShortDescriptionLine2: tr("Grid 5x3")  },
    ]
    obj.Prefs["rf_photos_grid_style"] = {
        values: rf_photos_grid_style,
        heading: tr("Size of the Grid"),
        default: "flat-movie"
    }

    obj.Screen.SetHeader(tr("Slideshow display preferences"))

    obj.AddItem({title: tr("Speed")}, "slideshow_period", obj.GetEnumValue("slideshow_period"))
    obj.AddItem({title: tr("Overlay Speed")}, "slideshow_overlay", obj.GetEnumValue("slideshow_overlay"))
    obj.AddItem({title: tr("Photo Overlay"), ShortDescriptionLine2: tr("Photo Info overlay on the photo")}, "slideshow_photo_overlay", obj.GetEnumValue("slideshow_photo_overlay"))
    obj.AddItem({title: tr("Audio Overlay"), ShortDescriptionLine2: tr("Audio Info overlay on the photo")}, "slideshow_audio_overlay", obj.GetEnumValue("slideshow_audio_overlay"))
    obj.AddItem({title: tr("Display Mode"),ShortDescriptionLine2: tr("How should photos 'fit' the screen")}, "slideshow_displaymode", obj.GetEnumValue("slideshow_displaymode"))
    obj.AddItem({title: tr("Display Type"),ShortDescriptionLine2: tr("Connected Display Type")}, "slideshow_underscan", obj.GetEnumValue("slideshow_underscan"))
    obj.AddItem({title: tr("Reload"),ShortDescriptionLine2: tr("check for new images after every completion")}, "slideshow_reload", obj.GetEnumValue("slideshow_reload"))
    obj.AddItem({title: tr("Grid Style/Size"),ShortDescriptionLine2: tr("Grid Display Mode")}, "rf_photos_grid_style", obj.GetEnumValue("rf_photos_grid_style"))
    obj.AddItem({title: tr("Icons Display Mode"),ShortDescriptionLine2: tr("How should thumbnails 'fit' the screen")}, "photoicon_displaymode", obj.GetEnumValue("photoicon_displaymode"))
    obj.AddItem({title: tr("Debug Info"), ShortDescriptionLine2: tr("Show Debug info if there are errors")}, "slideshow_error_overlay", obj.GetEnumValue("slideshow_error_overlay"))
    obj.AddItem({title: tr("Close")}, "close")

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
            if command = "slideshow_period" OR command = "slideshow_overlay" or command = "slideshow_reload" or command = "slideshow_displaymode" or command = "slideshow_underscan" or command = "photoicon_displaymode" or command = "rf_photos_grid_style" or command = "slideshow_audio_overlay" or command = "slideshow_photo_overlay" or command = "slideshow_error_overlay" then
                m.HandleEnumPreference(command, msg.GetIndex())
            else if command = "close" then
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function

'*** SecurityPin Preferences ***
'Create initiation screen and setup
Function createSecurityPinPrefsScreen(viewController) As Object
    'Debug("createSecurityPinPrefsScreen")
    obj = createBasePrefsScreen(viewController)
    prefsSecurityPinRefresh(obj)
    obj.Screen.SetHeader(tr("Security PIN preferences"))
    obj.HandleMessage = prefsSecurityPinHandleMessage
    obj.EnteredPin = false  'true when user has already entered PIN so we don't ask for it again
    obj.BaseActivate = obj.Activate
    return obj
End Function

'Determine if we're setting a new PIN or need to change/clear an existing PIN
sub prefsSecurityPinRefresh(screen)
    ' Subtitle size (burned in only)
    lockTimes = [
        { title: tr("Never"), EnumValue: "0" },
'        { title: "fast", EnumValue: "5" },
        { title: tr("5 Minutes"), EnumValue: "300" },
        { title: tr("10 Minutes"), EnumValue: "600" },
        { title: tr("15 Minutes"), EnumValue: "900" },
        { title: tr("20 Minutes"), EnumValue: "1200" },
        { title: tr("30 Minutes"), EnumValue: "1800" },
        { title: tr("45 Minutes"), EnumValue: "2700" },
        { title: tr("1 Hour"), EnumValue: "3600" },
        { title: tr("2 Hours"), EnumValue: "7200" },
        { title: tr("3 Hours"), EnumValue: "10800" },
        { title: tr("4 Hours"), EnumValue: "14400" },
        { title: tr("6 Hours"), EnumValue: "36000" },
        { title: tr("12 Hours"), EnumValue: "43200" }
    ]
    screen.Prefs["locktime"] = {
        values: lockTimes,
        heading: tr("Lock screen after inactivity"),
        default: "10800"
    }

    values = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: tr("Lock screen if inactive")+chr(10)+tr("while music is playing") },
        { title: "Disabled", EnumValue: "disabled", ShortDescriptionLine2: tr("Do not lock screen if inactive") + chr(10) +tr("while music is playing") },
    ]
    screen.Prefs["locktime_music"] = {
        values: values,
        heading: tr("Lock screen while music is playing"),
        default: "enabled"
    }

    screen.contentArray.Clear() 
    screen.Screen.ClearContent()
    if RegRead("securityPincode","preferences",invalid) = invalid  then
        screen.AddItem({title: tr("Set Security PIN")}, "set")
        screen.EnteredPin = true    'don't ask for PIN from now on
    else
        if screen.EnteredPin = true then
            screen.AddItem({title: tr("Change Security PIN")}, "set")
            screen.AddItem({title: tr("Clear Security PIN")}, "clear")
            screen.AddItem({title: tr("Inactivity Lock Time")}, "locktime", screen.GetEnumValue("locktime"))
            screen.AddItem({title: tr("Inactivity Lock [music]"),  ShortDescriptionLine2: "Lock Screen if inactive"+chr(10)+"while music is playing"}, "locktime_music", screen.GetEnumValue("locktime_music"))
        else
            screen.AddItem({title: tr("Enter current PIN to make changes")}, "unlock")
        end if
    end if
    screen.AddItem({title: tr("Close")}, "close")
end sub 


Function prefsSecurityPinHandleMessage(msg) As Boolean
    handled = false
    if type(msg) = "roListScreenEvent" then
        handled = true
        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "clear" then
                RegDelete("securityPincode", "preferences")
                prefsSecurityPinRefresh(m)
                m.ViewController.CreateIdleTimer()
            else if command = "set" then 'create screen to enter PIN
                pinScreen = SetSecurityPin(m.ViewController)
                m.Activate = prefsSecurityPinHandleSetPin
                m.ViewController.InitializeOtherScreen(pinScreen, ["Set New PIN"])
                pinScreen.txtTop = "The PIN code is any sequence of the direction arrows on your remote control.  Press up to 20 arrows to set the PIN."
                pinScreen.txtBottom = "Press Back to cancel setting the PIN.  When complete press the OK button on your remote control."  
                pinScreen.Show(true)
            else if command = "unlock" then 'create unlock screen
                pinScreen = VerifySecurityPin(m.ViewController, RegRead("securityPincode","preferences",invalid), false, 0)
                m.ViewController.InitializeOtherScreen(pinScreen, ["Unlock PIN Changes"])
                m.Activate = prefsSecurityPinHandleUnlock
                pinScreen.Show()
            else if command = "locktime" then
                m.HandleEnumPreference(command, msg.GetIndex())
                m.ViewController.CreateIdleTimer()
            else if command = "locktime_music" then
                m.HandleEnumPreference(command, msg.GetIndex())
            else if command = "close" then
                m.Screen.Close()
            end if
        end if
    end if
    return handled
End Function

'Called when list screen pops to top after the PIN verification completes
sub prefsSecurityPinHandleUnlock(priorScreen)
    m.Activate = m.BaseActivate    'dont call this routine again
    if (priorScreen.pinOK = invalid) or (priorScreen.pinOK <> true) then    'either no code was entered, was cancelled or wrong code
    else
        m.EnteredPin = true    
    endif
    prefsSecurityPinRefresh(m)
End sub

'Called when list screen pops to top after setting a new PIN
sub prefsSecurityPinHandleSetPin(priorScreen)
    m.Activate = m.BaseActivate    'dont call this routine again
    if (priorScreen.newPinCode = invalid) or (priorScreen.newPinCode = "")  then    'either no code was entered, was cancelled or wrong code
        'dialog = createBaseDialog()    'BUG: couldn't get this to work.  screen does not display.  Just return to menu when it's entered wrong
        'dialog.Title = "PIN Mismatch"
        'dialog.Text = "Security PIN's didn't match.  PIN not changed."
        'dialog.Show()
    else
        m.EnteredPin = true    
        'Debug("Set new pincode:" + tostr(priorScreen.newPinCode ))
        RegWrite("securityPincode", priorScreen.newPinCode, "preferences")
        prefsSecurityPinRefresh(m)
        m.ViewController.CreateIdleTimer()
    endif
End sub

'*** User Profile Preferences ***

sub refreshUserProfilesPrefsScreen(p) 
 ' TODO: need to work on a better way to refresh the current roListScreens
 curscreen = m
 screen = createUserProfilesPrefsScreen(m.ViewController)
 m.ViewController.InitializeOtherScreen(screen, ["User Profiles"])
 if m.focusedlistitem <> invalid then screen.screen.SetFocusedListItem(m.focusedlistitem)
 screen.Show()            
 m.ViewController.popscreen(m)
end sub

Function createUserProfilesPrefsScreen(viewController) As Object
    'TraceFunction("createUserProfilesPrefsScreen", viewController)

    obj = createBasePrefsScreen(viewController)
    obj.Activate = refreshUserProfilesPrefsScreen
    obj.HandleMessage = prefsUserProfilesHandleMessage
    obj.Screen.SetHeader("User Selection & Profile Preferences")
    ' Icon Color for the User Selection Arrows
    ' not sure this is the best place for this. It's a "global" setting
    arrowUpPO = "pkg:/images/arrow-up-po-gray.png"
    arrowUp = "pkg:/images/arrow-up-gray.png"
    if RegRead("rf_theme", "preferences", "black", 0) = "black" then 
        arrowUpPO = "pkg:/images/arrow-up-po.png"
        arrowUp = "pkg:/images/arrow-up.png"
    end if

    values = [
        { title: tr("Orange (Plex)"), EnumValue: "orange", SDPosterUrl: arrowUpPO, HDPosterUrl: arrowUpPO, },
        { title: tr("Purple (Roku)"), EnumValue: "purple", SDPosterUrl: arrowUp, HDPosterUrl: arrowUp, },
    ]
    obj.Prefs["userprofile_icon_color"] = {
        values: values,
        heading: tr("Icon Color for the User Sections Screen"),
        default: "orange"
    }
    poster = arrowUpPO
    if RegRead("userprofile_icon_color", "preferences", "orange", 0) <> "orange" then poster = arrowUp
    obj.AddItem({title: tr("User Selection Icon Color"), ShortDescriptionLine2: tr("Global Setting"), SDPosterUrl: poster, HDPosterUrl: poster  }, "userprofile_icon_color", obj.GetEnumValue("userprofile_icon_color",0)) ' this is a global option

    'These must be the first 8 entries for easy parsing for the createUserEditPrefsScreen()
    fn = firstof(RegRead("friendlyName", "preferences", invalid, 0),"")
    if fn <> "" then fn = " [" + fn + "]"
    obj.AddItem({title: tr("Default User Profile ") + fn}, "userActive0")
    for ucount = 1 to 7
        enaText = "Disabled"
        if RegRead("userActive", "preferences", "0", ucount) = "1" then enaText = "Enabled"
        fn = firstof(RegRead("friendlyName", "preferences", invalid, ucount),"")
        if fn <> "" then enaText = enaText + " [" + fn + "]"
        obj.AddItem({title: tr("User Profile ") + tostr(ucount)}, "userActive" + tostr(ucount), enaText)
    end for
    obj.AddItem({title: tr("Close")}, "close")
    return obj
End Function

Function prefsUserProfilesHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true
        if msg.isScreenClosed() then
            Debug("User Profiles closed event")
            GDMAdvertiser().Refresh()
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            m.FocusedListItem = msg.GetIndex()
            re = CreateObject("roRegex", "userActive\d", "i") ' modified so we can add other buttons on previous screen
            if command = "close" then
                m.Screen.Close()
            else if command = "userprofile_icon_color" then 
                m.currentUser = 0 ' set to write this as a global setting
                m.HandleEnumPreference(command, msg.GetIndex())
            else if re.IsMatch(command) then    'must be a user edit
                rep = CreateObject("roRegex", "userActive", "i")
                userNum = rep.ReplaceAll(command,"")
                m.editScreen = createUserEditPrefsScreen(m.ViewController,userNum.toInt()) 'msg.GetIndex() be 0-3 because that's the order of the text entries
                if userNum = "0" then
                    name = "Default User"
                else 
                    name = "User Profile " + userNum
                end if
                if RegRead("friendlyName", "preferences", invalid, userNum.toInt()) <> invalid then
                    name = RegRead("friendlyName", "preferences", invalid, userNum.toInt())
                end if 
                m.ViewController.InitializeOtherScreen(m.editScreen, [name])
                m.editScreen.Show()            
            end if
        end if
    end if

    return handled
End Function

'*** User Profile Edit ***
Function createUserEditPrefsScreen(viewController, currentUser as integer) As Object
    'TraceFunction("createUserEditPrefsScreen", viewController, currentUser)
    obj = createBasePrefsScreen(viewController)
    obj.currentUser = currentUser

    obj.HandleMessage = prefsUserEditHandleMessage

    ' Enabled
    options = [
        { title: tr("Enabled"), EnumValue: "1" },
        { title: tr("Disabled"), EnumValue: "0" }
    ]
    obj.Prefs["userActive"] = {
        values: options,
        heading: tr("Show this User Profile on selection screen"),
        default: "0"
    }
    obj.Prefs["friendlyName"] = {
        heading: tr("Name to show on the User Profile selection screen"),
        default: ""
    }
    obj.AddItem({title: tr("User Profile Name ")}, "friendlyName", obj.GetPrefValue("friendlyName"))
    if currentUser = 0 then
        obj.Screen.SetHeader(tr("Default User profile preferences"))
    else
        obj.Screen.SetHeader(tr("User ") + numtostr(currentUser) + tr(" profile preferences"))
        obj.AddItem({title: tr("Show User on selection screen ")}, "userActive", obj.GetEnumValue("userActive"))
    end if
    if currentUser <> GetGlobalAA().userNum then   'can't erase preferences for the current user
        obj.AddItem({title: tr("Erase all preferences for this user")}, "erase")
    end if
    obj.AddItem({title: tr("Close")}, "close")
    return obj
End Function


Function prefsUserEditHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true
        if msg.isScreenClosed() then
            Debug("User Edit closed event")
            GDMAdvertiser().Refresh()
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "friendlyName" then
                m.HandleTextPreference(command, msg.GetIndex())
            else if command = "userActive" then
                m.HandleEnumPreference(command, msg.GetIndex())
            else if command = "erase" then
                'm.HandleEnumPreference(command, msg.GetIndex())
                dialog = createBaseDialog()    
                dialog.Title = tr("Confirm Erase")
                dialog.Text = tr("Are you sure you want to erase all the preferences for this user profile?  This will forever delete all the configuration for this user profile.  Other profiles will not changed.")
                dialog.SetButton("erase", tr("Erase All Preferences"))
                dialog.SetButton("close", tr("Cancel"))
                dialog.HandleButton = prefsUserEditHandleDialogButton    
                dialog.ParentScreen = m
                dialog.Show()   
            else if command = "close" then
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function

'Handles the confirmation dialog button when erasing the preferences. If erasing, it sets the parent preference screen to close
Function prefsUserEditHandleDialogButton(command, data) As Boolean
    obj = m.ParentScreen    ' We're evaluated in the context of the dialog, but we want to pull from the parent.
    if command = "erase" then
        RegEraseUser(obj.currentUser)
        obj.closeOnActivate = true  'queue up the parent prefs screen to close
    end if
    'm.screen.Close() 'close the dialog now
    return true 'returning true will close the dialog
End Function


'*** Subtitle Preferences ***

Function createSubtitlePrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.HandleMessage = prefsSubtitleHandleMessage

    ' Enable soft subtitles
    softsubtitles = [
        { title: tr("Soft"), EnumValue: "1", ShortDescriptionLine2: tr("Use soft subtitles whenever possible.") },
        { title: tr("Burned In"), EnumValue: "0", ShortDescriptionLine2: tr("Always burn in selected subtitles.") }
    ]
    obj.Prefs["softsubtitles"] = {
        values: softsubtitles,
        heading: tr("Allow Roku to show soft subtitles itself, or burn them in to videos?"),
        default: "1"
    }

    ' Subtitle size (burned in only)
    sizes = [
        { title: tr("Tiny"), EnumValue: "75" },
        { title: tr("Small"), EnumValue: "90" },
        { title: tr("Normal"), EnumValue: "125" },
        { title: tr("Large"), EnumValue: "175" },
        { title: tr("Huge"), EnumValue: "250" }
    ]
    obj.Prefs["subtitle_size"] = {
        values: sizes,
        heading: tr("Burned-in subtitle size"),
        default: "125"
    }

    ' Subtitle color (soft only)
    colors = [
        { title: tr("Default"), EnumValue: "" },
        { title: tr("Yellow"), EnumValue: "#FFFF00" },
        { title: tr("White"), EnumValue: "#FFFFFF" },
        { title: tr("Black"), EnumValue: "#000000" }
    ]
    obj.Prefs["subtitle_color"] = {
        values: colors,
        heading: tr("Soft subtitle color"),
        default: ""
    }

    obj.Screen.SetHeader(tr("Subtitle Preferences"))

    obj.AddItem({title: tr("Subtitles")}, "softsubtitles", obj.GetEnumValue("softsubtitles"))
    obj.AddItem({title: tr("Subtitle Size")}, "subtitle_size", obj.GetEnumValue("subtitle_size"))
    obj.AddItem({title: tr("Subtitle Color")}, "subtitle_color", obj.GetEnumValue("subtitle_color"))
    obj.AddItem({title: tr("Close")}, "close")

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

    ' Exit Confirmation
    values = [
        { title: tr("Enabled"), EnumValue: "enabled",  },
        { title: tr("Disabled"), EnumValue: "disabled" }
    ]
    obj.Prefs["exit_confirmation"] = {
        values: values,
        heading: tr("Prompt for confirmation when exiting RARflix"),
        default: "enabled"
    }

    ' Advance to Next
    values = [
        { title: tr("Enabled"), EnumValue: "enabled",  },
        { title: tr("Disabled"), EnumValue: "disabled" }
    ]
    obj.Prefs["advanceToNextItem"] = {
        values: values,
        heading: tr("Display the next available TV episode after watching"),
        default: "enabled"
    }

    ' Transcoder version. We'll default to the "universal" transcoder, but
    ' there's also a server version check.
    transcoder_version = [
        { title: tr("Legacy"), EnumValue: "classic", ShortDescriptionLine2: tr("Use the older, legacy transcoder.") },
        { title: tr("Universal"), EnumValue: "universal" }
    ]
    obj.Prefs["transcoder_version"] = {
        values: transcoder_version,
        heading: tr("Transcoder version"),
        default: "universal"
    }

    ' Continuous play
    continuous_play = [
        { title: tr("Enabled"), EnumValue: "1", ShortDescriptionLine2: tr("Experimental") },
        { title: tr("Disabled"), EnumValue: "0" }
    ]
    obj.Prefs["continuous_play"] = {
        values: continuous_play,
        heading: tr("Automatically start playing the next video"),
        default: "0"
    }

    ' legacy remote with no back button
    legacy_remote = [
        { title: tr("No"), enumvalue: "0", ShortDescriptionLine2: tr("Remote includes a Back Button") },
        { title: tr("Yes"), EnumValue: "1", ShortDescriptionLine2: tr("Remote has no Back Button") },
    ]
    obj.Prefs["legacy_remote"] = {
        values: legacy_remote,
        heading: tr("Are you using a remote without a physical Back Button?"),
        default: "0"
    }


    ' Continuous+shuffle play
    shuffle_play = [
        { title: tr("Enabled"), EnumValue: "1", ShortDescriptionLine2: tr("Very Experimental") },
        { title: tr("Disabled"), EnumValue: "0" }
    ]
    obj.Prefs["shuffle_play"] = {
        values: shuffle_play,
        heading: tr("Continuous Play + Shuffle"),
        default: "0"
    }

    ' H.264 Level
    levels = [
        { title: "Level 4.0 (Supported)", EnumValue: "40" },
        { title: "Level 4.1 (Supported)", EnumValue: "41" },
        { title: "Level 4.2", EnumValue: "42", ShortDescriptionLine2: tr("This level may not be supported well.") },
        { title: "Level 5.0", EnumValue: "50", ShortDescriptionLine2: tr("This level may not be supported well.") },
        { title: "Level 5.1", EnumValue: "51", ShortDescriptionLine2: tr("This level may not be supported well.") }
    ]
    obj.Prefs["level"] = {
        values: levels,
        heading: tr("Use specific H264 level. Up to 4.1 is officially supported."),
        default: "41"
    }

    ' HLS seconds per segment
    lengths = [
        { title: tr("Automatic"), EnumValue: "auto", ShortDescriptionLine2: tr("Chooses based on quality.") },
        { title: tr("4 seconds"), EnumValue: "4" },
        { title: tr("10 seconds"), EnumValue: "10" }
    ]
    obj.Prefs["segment_length"] = {
        values: lengths,
        heading: tr("Seconds per HLS segment. Longer segments may load faster."),
        default: "10"
    }

    ' Analytics (opt-out)
    values = [
        { title: tr("Enabled"), EnumValue: "1" },
        { title: tr("Disabled"), EnumValue: "0" }
    ]
    obj.Prefs["analytics"] = {
        values: values,
        heading: tr("Send anonymous usage data to help improve Plex"),
        default: "1"
    }

    versionArr = GetGlobalAA().Lookup("rokuVersionArr")
    major = versionArr[0]

    obj.Screen.SetHeader(tr("Advanced preferences don't usually need to be changed"))

    obj.AddItem({title: tr("Confirm Exit"), shortDescriptionLine2: tr("prompt before exiting RARflix")}, "exit_confirmation", obj.GetEnumValue("exit_confirmation"))
    obj.AddItem({title: tr("Auto Episode Advance"), shortDescriptionLine2: tr("show episode next up after watching")}, "advanceToNextItem", obj.GetEnumValue("advanceToNextItem"))
    obj.AddItem({title: tr("Transcoder")}, "transcoder_version", obj.GetEnumValue("transcoder_version"))
    obj.AddItem({title: tr("Continuous Play")}, "continuous_play", obj.GetEnumValue("continuous_play"))
    obj.AddItem({title: tr("Shuffle Play")}, "shuffle_play", obj.GetEnumValue("shuffle_play"))
    obj.AddItem({title: tr("Legacy Remote")}, "legacy_remote", obj.GetEnumValue("legacy_remote"))
    obj.AddItem({title: "H.264"}, "level", obj.GetEnumValue("level"))

    if GetGlobal("legacy1080p") then
        obj.AddItem({title: tr("1080p Settings")}, "1080p")
    end if

    obj.AddItem({title: tr("HLS Segment Length")}, "segment_length", obj.GetEnumValue("segment_length"))
    obj.AddItem({title: tr("Analytics")}, "analytics", obj.GetEnumValue("analytics"))
    obj.AddItem({title: tr("Close")}, "close")

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
        { title: tr("Enabled"), EnumValue: "enabled" },
        { title: tr("Disabled"), EnumValue: "disabled" }
    ]
    obj.Prefs["legacy1080p"] = {
        values: options,
        heading: tr("1080p support (Roku 1 only)"),
        default: "disabled"
    }

    ' Framerate override
    options = [
        { title: tr("auto"), EnumValue: "auto" },
        { title: "24", EnumValue: "24" },
        { title: "30", EnumValue: "30" }
    ]
    obj.Prefs["legacy1080pframerate"] = {
        values: options,
        heading: tr("Select a frame rate to use with 1080p content."),
        default: "auto"
    }

    obj.Screen.SetHeader(tr("1080p settings (Roku 1 only)"))

    obj.AddItem({title: tr("1080p Support")}, "legacy1080p", obj.GetEnumValue("legacy1080p"))
    obj.AddItem({title: tr("Frame Rate Override")}, "legacy1080pframerate", obj.GetEnumValue("legacy1080pframerate"))
    obj.AddItem({title: tr("Close")}, "close")

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
        { title: tr("Always"), EnumValue: "always" },
        { title: tr("Never"), EnumValue: "never" },
        { title: tr("Sometimes"), EnumValue: "sometimes", ShortDescriptionLine2: tr("Loop playback when there are multiple songs.") }
    ]
    obj.Prefs["loopalbums"] = {
        values: loopalbums,
        heading: tr("Loop when playing music"),
        default: "sometimes"
    }

    ' Theme music
    theme_music = [
        { title: tr("Loop"), EnumValue: "loop" },
        { title: tr("Play Once"), EnumValue: "once" },
        { title: tr("Disabled"), EnumValue: "disabled" }
    ]
    obj.Prefs["theme_music"] = {
        values: theme_music,
        heading: tr("Play theme music in the background while browsing"),
        default: "disabled"
    }

    ' 5.1 Support - AC-3
    fiveone = [
        { title: tr("Enabled"), EnumValue: "1", ShortDescriptionLine2: tr("Try to copy 5.1 audio streams when transcoding.") },
        { title: tr("Disabled"), EnumValue: "2", ShortDescriptionLine2: tr("Always use 2-channel audio when transcoding.") }
    ]
    obj.Prefs["fivepointone"] = {
        values: fiveone,
        heading: tr("5.1 AC-3 support"),
        default: "1"
    }

    ' 5.1 Support - DTS
    fiveoneDCA = [
        { title: tr("Enabled"), EnumValue: "1", ShortDescriptionLine2: tr("Try to Direct Play DTS in MKVs.") },
        { title: tr("Disabled"), EnumValue: "2", ShortDescriptionLine2: tr("Never Direct Play DTS.") }
    ]
    obj.Prefs["fivepointoneDCA"] = {
        values: fiveoneDCA,
        heading: tr("5.1 DTS support"),
        default: "1"
    }

    ' Audio boost for transcoded content. Transcoded content is quiet by
    ' default, but if we set a default boost then audio will never be remuxed.
    ' These values are based on iOS.
    values = [
        { title: tr("None"), EnumValue: "100" },
        { title: tr("Small"), EnumValue: "175" },
        { title: tr("Large"), EnumValue: "225" },
        { title: tr("Huge"), EnumValue: "300" }
    ]
    obj.Prefs["audio_boost"] = {
        values: values,
        heading: tr("Audio boost for transcoded video"),
        default: "100"
    }

    obj.Screen.SetHeader(tr("Audio Preferences"))

    obj.AddItem({title: tr("Loop Playback")}, "loopalbums", obj.GetEnumValue("loopalbums"))
    obj.AddItem({title: tr("Theme Music")}, "theme_music", obj.GetEnumValue("theme_music"))

    if SupportsSurroundSound(true) then
        obj.AddItem({title: tr("5.1 AC-3 Support")}, "fivepointone", obj.GetEnumValue("fivepointone"))
        obj.AddItem({title: tr("5.1 DTS Support")}, "fivepointoneDCA", obj.GetEnumValue("fivepointoneDCA"))
    end if

    obj.AddItem({title: tr("Audio Boost")}, "audio_boost", obj.GetEnumValue("audio_boost"))

    obj.AddItem({title: tr("Close")}, "close")

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

    obj.Screen.SetHeader(tr("Logging"))
    obj.RefreshItems()

    return obj
End Function

Sub debugRefreshItems()
    m.contentArray.Clear()
    m.Screen.ClearContent()

    if m.Logger.Enabled then
        m.AddItem({title: tr("Disable Logging")}, "disable")

        if MyPlexManager().IsSignedIn then
            if m.Logger.RemoteLoggingTimer <> invalid then
                remainingMinutes = int(0.5 + (m.Logger.RemoteLoggingSeconds - m.Logger.RemoteLoggingTimer.TotalSeconds()) / 60)
                if remainingMinutes > 1 then
                    extraLabel = " (" + tostr(remainingMinutes) + " minutes)"
                else
                    extraLabel = ""
                end if
                m.AddItem({title: tr("Remote Logging Enabled") + extraLabel}, "null")
            else
                m.AddItem({title: tr("Enable Remote Logging")}, "remote")
            end if
        end if

        m.AddItem({title: tr("Download Logs")}, "download")
    else
        m.AddItem({title: tr("Enable Logging")}, "enable")
    end if

    m.AddItem({title: tr("Close")}, "close")
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
        { title: tr("Enabled"), EnumValue: "1" },
        { title: tr("Disabled"), EnumValue: "0" }
    ]
    obj.Prefs["autodiscover"] = {
        values: options,
        heading: tr("Automatically discover Plex Media Servers at startup."),
        default: "1"
    }

    obj.Screen.SetHeader(tr("Manage Plex Media Servers"))

    obj.AddItem({title: tr("Add Server Manually")}, "manual")
    obj.AddItem({title: tr("Discover Servers")}, "discover")
    obj.AddItem({title: tr("Discover at Startup")}, "autodiscover", obj.GetEnumValue("autodiscover"))
    obj.AddItem({title: tr("Remove All Servers")}, "removeall")

    obj.listOffset = obj.contentArray.Count()
    obj.RefreshServerList(obj.listOffset)

    obj.RefreshOnActivate = true

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
                m.RefreshServerList(m.listOffset)
            else if command = "autodiscover" then
                m.HandleEnumPreference(command, msg.GetIndex())
            else if command = "removeall" then
                RemoveAllServers()
                ClearPlexMediaServers()
                m.RefreshServerList(m.listOffset)
            else if command = "edit" then
                screen = createEditServerScreen(m.ViewController,GetServerFromIndex(msg.GetIndex() - m.listOffset),m,m.listOffset)
                m.ViewController.InitializeOtherScreen(screen, ["Edit Server"])
                screen.Show()          
            else if command = "close" then
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function

Sub prefsServersOnUserInput(value, screen)
    if type(screen.Screen) = "roKeyboardScreen" then
        m.RefreshServerList(m.listOffset)
    else
        m.superOnUserInput(value, screen)
    end if
End Sub

Sub prefsServersActivate(priorScreen)
    if m.RefreshOnActivate then
        ' ljunkie - why would we stop this action? If someone continues to
        ' add/remove/update, we still want to refresh
        ' -- removed -- m.RefreshOnActivate = false
        m.RefreshServerList(m.listOffset)
    end if
End Sub

Sub manageRefreshServerList(listOffset,obj=invalid)
    if obj = invalid then
        obj = m
    end if
    while obj.contentArray.Count() > listOffset
        obj.contentArray.Pop()
        obj.Screen.RemoveContent(listOffset)
    end while

    servers = ParseRegistryServerList()
    for each server in servers
        obj.AddItem({title: tr("Edit ") + server.Name + " (" + server.Url + ")"}, "edit")
    next

    obj.AddItem({title: tr("Close")}, "close")
End Sub

'*** Edit Server screen ***
sub refreshEditServerScreen(p)  'A copy of ljunkie's ingenius hack to update the screen after changing settings.  Wish i figured this out sooner!
    server = GetPlexMediaServer(m.server.MachineID)
    ' ljunkie - we may have removed the server -- verify it exists before we create the edit screen again
    if server <> invalid 
        screen = createEditServerScreen(m.ViewController,GetServerFromMachineID(m.server.MachineID),m.ParentScreen,m.listOffset) 'Get a new pointer for our new screen
        m.ViewController.InitializeOtherScreen(screen, ["Edit Server"])
        if m.FocusedListItem <> invalid then screen.screen.SetFocusedListItem(m.FocusedListItem)
        screen.Show()            
    end if
    m.ViewController.popscreen(m)
end sub
  
Function createEditServerScreen(viewController, server, parentScreen, listOffset) As Object
    obj = createBasePrefsScreen(viewController)
    obj.Activate = refreshEditServerScreen
    obj.HandleMessage = prefsEditServerHandleMessage
    obj.server = server
    obj.ParentScreen = parentScreen
    obj.listOffset = listOffset

    obj.AddItem({title: tr("Edit address"),ShortDescriptionLine2: tr("The address at which this server is located")}, "url", obj.server.Url )
    obj.AddItem({title: tr("Edit WOL MAC address"),ShortDescriptionLine1:tr("Wake-on-LAN MAC address"),ShortDescriptionLine2: tr("Activates remote server wake up")}, "mac", GetServerData(obj.server.MachineID,"Mac") )
    WOLPass = GetServerData(obj.server.MachineID,"WOLPass")
    if WOLPass = invalid or Len(WOLPass) <> 12 then
        obj.AddItem({title: tr("Edit WOL SecureOn Password"),ShortDescriptionLine1: tr("12-Digit hexadecimal password "),ShortDescriptionLine2: tr("for a Wake-on-LAN request")}, "WOLPass" )
    else
        obj.AddItem({title: tr("Edit WOL SecureOn Password"),ShortDescriptionLine1: tr("12-Digit hexadecimal password "),ShortDescriptionLine2: tr("for a Wake-on-LAN request")}, "WOLPass", "************" )
    end if
    obj.AddItem({title: tr("Remove ") + server.Name }, "remove" )
    obj.AddItem({title: tr("Close")}, "close")
      
    return obj
End Function

Function prefsEditServerHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true
        if msg.isScreenClosed() then
            Debug("Edit server closed event")
            GDMAdvertiser().Refresh()
            manageRefreshServerList(m.listOffset,m.ParentScreen)
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            m.FocusedListItem = msg.GetIndex()
            if command = "url" then
                screen = m.ViewController.CreateTextInputScreen("Enter Host Name or IP without http:// or :32400", ["Edit Server address"], false)
                screen.Screen.SetMaxLength(80)
                screen.ValidateText = AddUnnamedServer
                screen.Show()
            else if command = "WOLPass" then
                m.currentIndex = msg.GetIndex()
                initialText = GetServerData(m.server.MachineID,"WOLPass")
                if initialText = invalid then initialText = ""
                screen = m.ViewController.CreateTextInputScreen("12-digit hexadecimal password for WOL.  Leave blank if unsure.", ["Edit SecureOn Password"], false, initialText, true )
                screen.Screen.SetMaxLength(12)
                screen.MachineID = m.server.MachineID
                screen.Listener = m
                screen.Listener.OnUserInput = EditSecureOnPass
                screen.Show()
            else if command = "mac" then
                m.currentIndex = msg.GetIndex()
                screen = m.ViewController.CreateTextInputScreen("Enter MAC address. 12 Alphanumber characters [no colons]", ["Edit MAC address"], false, GetServerData(m.server.MachineID,"Mac"))
                screen.Screen.SetMaxLength(12)
                screen.MachineID = m.server.MachineID
                screen.Listener = m
                screen.Listener.OnUserInput = EditMacAddress
                screen.Show()
            else if command = "remove" then
                dialog = createBaseDialog()    
                dialog.Title = tr("Confirm Remove")
                dialog.Text = tr("Are you sure you want to remove this server?")
                dialog.SetButton("remove", tr("Remove Server"))
                dialog.SetButton("close", tr("Cancel"))
                dialog.HandleButton = prefsRemoveServerHandleDialogButton    
                dialog.ParentScreen = m
                dialog.index = msg.GetIndex()
                dialog.Show()
            else if command = "close" then
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function

'Handles the confirmation dialog button when removing a server
Function prefsRemoveServerHandleDialogButton(command, data) As Boolean
    obj = m.ParentScreen    ' We're evaluated in the context of the dialog, but we want to pull from the parent.
    if command = "remove" then
        RemoveServer(obj.server)
        obj.contentArray.Delete(m.index)
        obj.Screen.RemoveContent(m.index)
    end if
    return true 'returning true will close the dialog
End Function

'*** Video Playback Options ***

Function createVideoOptionsScreen(item, viewController, continuousPlay, shufflePlay, continuousContextPlay) As Object
    obj = createBasePrefsScreen(viewController)

    obj.Item = item

    obj.OnUserInput = videoOptionsOnUserInput
    obj.HandleMessage = videoOptionsHandleMessage
    obj.GetEnumValue = videoOptionsGetEnumValue

    ' Transcoding vs. direct play
    options = [
        { title: tr("Automatic"), EnumValue: "0" },
        { title: tr("Direct Play"), EnumValue: "1" },
        { title: tr("Direct Play w/ Fallback"), EnumValue: "2" },
        { title: tr("Direct Stream/Transcode"), EnumValue: "3" },
        { title: tr("Transcode"), EnumValue: "4" }
    ]
    obj.Prefs["playback"] = {
        values: options,
        label: tr("Transcoding"),
        heading: tr("Should this video be transcoded or use Direct Play?"),
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
        label: tr("Quality"),
        heading: tr("Higher settings require more bandwidth and may buffer"),
        default: tostr(GetQualityForItem(item))
    }

    audioStreams = []
    subtitleStreams = []
    defaultAudio = ""
    defaultSubtitle = ""

    subtitleStreams.Push({ title: tr("No Subtitles"), EnumValue: "" })

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
            label: tr("Audio Stream"),
            heading: tr("Select an audio stream"),
            default: defaultAudio
        }
    end if

    ' Subtitle streams
    Debug("Found subtitle streams: " + tostr(subtitleStreams.Count() - 1))
    if subtitleStreams.Count() > 1 then
        obj.Prefs["subtitles"] = {
            values: subtitleStreams,
            label: tr("Subtitle Stream"),
            heading: tr("Select a subtitle stream"),
            default: defaultSubtitle
        }
    end if

    ' TODO(ljunkie) better name for "this context" ( same as continuous play unless the item is an episode - it will say in the same context instead of finding the next episode )
    ' plaback type all rolled into one option. They conflict with eachother, so it doesn't make sense to have them separate.
    defaultPlayBack = "default"
    if continuousContextPlay = true then
        defaultplayBack = "continuous_context_play"
    else if shufflePlay = true then
        defaultplayBack = "shuffle_play"
    else if continuousPlay = true then
        defaultplayBack = "continuous_play"
    end if

    advancedToNext = (RegRead("advanceToNextItem", "preferences", "enabled") = "enabled")
    playBack_types = [{ title: tr("Default"),    EnumValue: "default", ShortDescriptionLine2: tr("Single Video Playback") }]
    if advancedToNext then 
        playBack_types.Push({ title: tr("Continuous"), EnumValue: "continuous_play", ShortDescriptionLine2: tr("Automatically play the next video") + chr(10) + tr("* Next available Episode if applicable") })
        playBack_types.Push({ title: tr("Continuous [this context]"), EnumValue: "continuous_context_play", ShortDescriptionLine2: tr("Automatically play the next video") + chr(10) + tr(" * Use the existing context ")})
    else 
        ' if one hasn't enable advancedToNext - then we don't need two Continuous options ( continuous will function the original way ) + it has a different desctiption
        playBack_types.Push({ title: tr("Continuous"), EnumValue: "continuous_play", ShortDescriptionLine2: tr("Automatically play the next video") + chr(10) + tr(" * Use the existing context ") })
    end if
    playBack_types.Push({ title: tr("Shuffle"), EnumValue: "shuffle_play", ShortDescriptionLine2: tr("Shuffle+Automatically play the next video") + chr(10) + tr(" * Use the existing context ") })
    obj.Prefs["playBack_type"] = {
        values: playBack_types,
        label: tr("Playback"),
        heading: tr("Playback: default, play continuous, play shuffle or play this context continuous"),
        default: defaultplayBack
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
            label: tr("Media"),
            heading: tr("Select a source"),
            default: defaultMedia
        }
    end if

    obj.Screen.SetHeader(tr("Video playback options"))

    possiblePrefs = ["playback", "playBack_type", "quality", "audio", "subtitles", "media"]
    for each key in possiblePrefs
        pref = obj.Prefs[key]
        if pref <> invalid and pref.values <> invalid then 
            for index = 0 to pref.values.count()-1
               if pref.values[index].ShortDescriptionLine2 <> invalid and  pref.values[index].enumvalue = pref.default then 
                   pref.ShortDescriptionLine2 = pref.values[index].ShortDescriptionLine2
                   exit for
               end if
            end for
        end if


        if pref <> invalid then
            obj.AddItem({title: pref.label, ShortDescriptionLine2: pref.ShortDescriptionLine2}, key)
            obj.AppendValue(invalid, obj.GetEnumValue(key))
        end if
    next

    obj.AddItem({title: tr("Close")}, "close")

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

                if command = "playBack_type" then 
                    ' ljunkie - toggle playback types (iterate)
                    for index = 0 to pref.values.count()
                        if pref.values[index].enumvalue = pref.default then
                            index = index+1
                            exit for
                        end if
                    end for
                    if index > pref.values.count()-1 then index = 0

                    m.Changes.AddReplace(command, pref.values[index].enumvalue)
                    m.Prefs[command].default = pref.values[index].enumvalue
                    ' might want to make this an options for AppendValue?
                    'm.contentarray[m.currentIndex].ShortDescriptionLine2 = pref.values[index].ShortDescriptionLine2
                    m.AppendValue(m.currentIndex, pref.values[index].title, pref.values[index].ShortDescriptionLine2)
                else 
                    screen = m.ViewController.CreateEnumInputScreen(pref.values, pref.default, pref.heading, [pref.label], false)
                    screen.Listener = m
                    screen.Show()
                end if
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
        { title: tr("Enabled"), EnumValue: "1" },
        { title: tr("Disabled"), EnumValue: "0" }
    ]
    obj.Prefs["remotecontrol"] = {
        values: options,
        heading: tr("Allow other clients to control this Roku."),
        default: "1"
    }

    obj.Prefs["player_name"] = {
        heading: tr("A name that will identify this Roku on your remote controls"),
        default: GetGlobalAA().Lookup("rokuModel")
    }

    obj.Screen.SetHeader(tr("Remote control preferences"))

    obj.AddItem({title: tr("Remote Control")}, "remotecontrol", obj.GetEnumValue("remotecontrol"))
    obj.AddItem({title: tr("Name")}, "player_name", obj.GetPrefValue("player_name"))
    obj.AddItem({title: tr("Close")}, "close")

    return obj
End Function

Function prefsRemoteControlHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            Debug("Remote control closed event")
            GDMAdvertiser().Refresh()
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
        { title: tr("All"), EnumValue: "all" },
        { title: tr("Unwatched"), EnumValue: "unwatched" },
        { title: tr("Watched"), EnumValue: "watched" },
        { title: tr("Hidden"), EnumValue: "hidden" }
    ]
    obj.Prefs["playlist_view_queue"] = {
        values: values,
        heading: tr("Default view for Queue on the home screen"),
        default: "unwatched"
    }
    obj.Prefs["playlist_view_recommendations"] = {
        values: values,
        heading: tr("Default view for Recommendations on the home screen"),
        default: "unwatched"
    }

    ' Visibility for on deck and recently added
    valuesShared = [
        { title: tr("Enabled"), EnumValue: "" },
        { title: tr("Enabled (exclude shared libraries)"), EnumValue: "owned" },
        { title: tr("Hidden"), EnumValue: "hidden" }
    ]
    values = [
        { title: tr("Enabled"), EnumValue: "" },
        { title: tr("Hidden"), EnumValue: "hidden" }
    ]
    obj.Prefs["row_visibility_ondeck"] = {
        values: valuesShared,
        heading: tr("Show On Deck items on the home screen"),
        default: ""
    }
    obj.Prefs["row_visibility_recentlyadded"] = {
        values: valuesShared,
        heading: tr("Show recently added items on the home screen"),
        default: ""
    }
    obj.Prefs["row_visibility_channels"] = {
        values: values,
        heading: tr("Show channels on the home screen"),
        default: ""
    }
    obj.Prefs["row_visibility_now_playing"] = {
        values: values,
        heading: tr("Show Now Playing on the home screen"),
        default: ""
    }

    ' Home screen rows that can be reordered
    values = [
        { title: tr("Channels"), key: "channels" },
        { title: tr("Library Sections"), key: "sections" },
        { title: tr("On Deck"), key: "on_deck" },
        { title: tr("Now Playing"), key: "now_playing" },
        { title: tr("Recently Added"), key: "recently_added" },
        { title: tr("Queue"), key: "queue" },
        { title: tr("Recommendations"), key: "recommendations" },
        { title: tr("Shared Library Sections"), key: "shared_sections" },
        { title: tr("Miscellaneous"), key: "misc" }
    ]
    obj.Prefs["home_row_order"] = {
        values: values,
        default: ""
    }

    '{ title: "Zoom", EnumValue: "zoom-to-fill", ShortDescriptionLine2: "zoom image to fill boundary" }, NO ONE wants this
    display_modes = [
        { title: tr("Photo [default]"), EnumValue: "photo-fit", ShortDescriptionLine2: tr("Default") },
        { title: tr("Fit"), EnumValue: "scale-to-fit", ShortDescriptionLine2: tr("scaled to fit")  },
        { title: tr("Fill"), EnumValue: "scale-to-fill", ShortDescriptionLine2: tr("stretch image to fill boundary") },
    ]
    obj.Prefs["rf_home_displaymode"] = {
        values: display_modes,
        heading: tr("How should images be displayed on the home screen (channel restart required)"),
        default: "photo-fit"
    }

    ' Home Screen clock
    rf_hs_clock_prefs = [
        { title: tr("12 Hour"), EnumValue: "enabled", ShortDescriptionLine2: "Show clock on Home Screen" },
        { title: tr("24 Hour"), EnumValue: "24hour", ShortDescriptionLine2: "Show clock on Home Screen" },
        { title: tr("Disabled"), EnumValue: "disabled", ShortDescriptionLine2: "Show clock on Home Screen" },
    ]
    obj.Prefs["rf_hs_clock"] = {
        values: rf_hs_clock_prefs,
        heading: tr("Time"),
        default: "enabled"
    }

    ' Home Screen clock
    rf_hs_date_prefs = [
        { title: tr("Long Date"), EnumValue: "enabled", ShortDescriptionLine2: tr("Date on Home Screen") },
        { title: tr("Short Date"), EnumValue: "short-date", ShortDescriptionLine2: tr("Date on Home Screen") },
        { title: tr("Disabled"), EnumValue: "disabled", ShortDescriptionLine2: tr("Date on Home Screen") },
    ]
    obj.Prefs["rf_hs_date"] = {
        values: rf_hs_date_prefs,
        heading: tr("Date"),
        default: "enabled"
    }

    obj.Screen.SetHeader(tr("Change the appearance of the home screen"))
    obj.AddItem({title: tr("Reorder Home Rows"), ShortDescriptionLine2: tr("A restart of the Channel is required")}, "home_row_order")
    obj.AddItem({title: tr("Display Mode"), ShortDescriptionLine2: tr("Stretch or Fit images to fill the focus box")}, "rf_home_displaymode", obj.GetEnumValue("rf_home_displaymode"))
    obj.AddItem({title: tr("Queue")}, "playlist_view_queue", obj.GetEnumValue("playlist_view_queue"))
    obj.AddItem({title: tr("Recommendations")}, "playlist_view_recommendations", obj.GetEnumValue("playlist_view_recommendations"))
    obj.AddItem({title: tr("On Deck")}, "row_visibility_ondeck", obj.GetEnumValue("row_visibility_ondeck"))
    obj.AddItem({title: tr("Recently Added")}, "row_visibility_recentlyadded", obj.GetEnumValue("row_visibility_recentlyadded"))
    obj.AddItem({title: tr("Now Playing"), ShortDescriptionLine2: "rarflix pref"}, "row_visibility_now_playing", obj.GetEnumValue("row_visibility_now_playing"))
    obj.AddItem({title: tr("Channels")}, "row_visibility_channels", obj.GetEnumValue("row_visibility_channels"))
    obj.AddItem({title: tr("Clock")}, "rf_hs_clock", obj.GetEnumValue("rf_hs_clock"))
    obj.AddItem({title: tr("Date")}, "rf_hs_date", obj.GetEnumValue("rf_hs_date"))
    obj.AddItem({title: tr("Close")}, "close")

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
            if command = "playlist_view_queue" OR command = "playlist_view_recommendations" OR command = "row_visibility_ondeck" OR command = "row_visibility_recentlyadded" OR command = "row_visibility_channels" or command = "row_visibility_now_playing" or command = "rf_home_displaymode" or command = "rf_hs_clock" or command = "rf_hs_date" then
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
        { title: tr("Grid"), EnumValue: "1" },
        { title: tr("Poster"), EnumValue: "" }
    ]
    obj.Prefs["use_grid_for_series"] = {
        values: values,
        heading: tr("Which screen type should be used for TV series?"),
        default: ""
    }

    ' Episodic Poster Screen for TV Series: 4x3 or 16x9
    values = [
        { title: tr("16x9 Widescreen"), EnumValue: "flat-episodic-16x9" },
        { title: tr("4x3 Standard"), EnumValue: "flat-episodic" }
    ]
    obj.Prefs["rf_episode_episodic_style"] = {
        values: values,
        heading: tr("Size of episode images"),
        default: "flat-episodic-16x9"
    }

' -- forcing the view of images instead of a blank image with a number
' -- deprecated as of v3.1.2
'    ' Episodic Poster Screen: show Numbers or Images
'    values = [
'        { title: "Image", EnumValue: "enabled" },
'        { title: "Number", EnumValue: "disabled" }
'    ]
'    obj.Prefs["rf_episode_episodic_thumbnail"] = {
'        values: values,
'        heading: "Show episode preview image or episode number",
'        default: "disabled"
'    }

    ' Prefer Grid or Poster view for most?

    values = [
        { title: tr("Title"), EnumValue: "titleSort:asc",  ShortDescriptionLine2: tr("Sort by Title"),  },
        { title: tr("Date Added"), EnumValue: "addedAt:desc",  ShortDescriptionLine2: tr("Sort by Date Added") },
        { title: tr("Date Released/Taken"), EnumValue: "originallyAvailableAt:desc",  ShortDescriptionLine2: tr("Sort by Date Released/Taken") },
    ]
    obj.Prefs["section_sort"] = {
        values: values,
        heading: tr("Sort Items (when not specifically sorted)"),
        default: "titleSort:asc"
    }

    rf_poster_grid = [
        { title: tr("Grid"), EnumValue: "grid", ShortDescriptionLine2: tr("Prefer FULL grid when viewing items")  },
        { title: tr("Poster"), EnumValue: "poster", ShortDescriptionLine2: tr("Prefer Poster (one row) when viewing items")  },


    ]
    obj.Prefs["rf_poster_grid"] = {
        values: rf_poster_grid,
        heading: tr("Which screen type should be used for Movies & Other content?"),
        default: "grid"
    }

    ' Prefer Grid or Poster view for most?
    rf_grid_style = [
        { title: tr("Portrait"), EnumValue: "flat-movie", ShortDescriptionLine2: tr("Grid 5x2 - Short Portrait")  },
        { title: tr("Square"), EnumValue: "flat-square", ShortDescriptionLine2: tr("Grid 7x3 - Square") },
    ]

    ' We don't want to show the Portrait options for SD.. it's even short than flat-movie - odd
    if GetGlobal("IsHD") = true then 
        rf_grid_style.Unshift({ title: tr("Portrait (tall)"), EnumValue: "flat-portrait", ShortDescriptionLine2: tr("Grid 5x2 - Tall Portrait")  })
    end if

    obj.Prefs["rf_grid_style"] = {
        values: rf_grid_style,
        heading: tr("Style and Size of the Grid"),
        default: "flat-movie"
    }
    ' Grid Descriptions Pop Out
    rf_grid_description = [
        { title: tr("Enabled"), EnumValue: "enabled"  },
        { title: tr("Disabled"), EnumValue: "disabled"  },

    ]
    obj.Prefs["rf_grid_description"] = {
        values: rf_grid_description,
        heading: tr("Grid Pop Out Description"),
        default: "enabled"
    }

    ' Hide the header text for Rows on the GridScreen ( full grid )
    values = [
        { title: tr("Enabled"), EnumValue: "enabled"  },
        { title: tr("Disabled"), EnumValue: "disabled"  },

    ]
    obj.Prefs["rf_fullgrid_hidetext"] = {
        values: values
        heading: tr("Hide text above each row in the Full Grid"),
        default: "disabled"
    }

    values = [
        { title: tr("Enabled"), EnumValue: "enabled"  },
        { title: tr("Disabled"), EnumValue: "disabled"  },

    ]
    obj.Prefs["rf_fullgrid_spacer"] = {
        values: values
        heading: tr("Insert a blank poster between the first and last item in a row"),
        default: "disabled"
    }

    ' Display Mode for Grid or Poster views
    ' { title: "Zoom", EnumValue: "zoom-to-fill", ShortDescriptionLine2: "zoom image to fill boundary" }, again, no one wants this
    display_modes = [
        { title: "Fit [default]", EnumValue: "scale-to-fit", ShortDescriptionLine2: "Default"  },
        { title: "Photo", EnumValue: "photo-fit", ShortDescriptionLine2: "all the above to fit boundary" + chr(10) + " no stretching " },
        { title: "Fill", EnumValue: "scale-to-fill", ShortDescriptionLine2: "stretch image to fill boundary" },
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
        { initialOrder: 0, title: "Filters", key: "_section_filters_" },
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
    values.Unshift({ title: "[tv] Recently Added Season", key: "recentlyAdded?stack=1" })
    values.Unshift({ title: "[tv] Recently Aired Episode (uw)", key: "all?timelineState=1&type=4&unwatched=1&sort=originallyAvailableAt:desc" })
    values.Unshift({ title: "[tv] Recently Added Episode (uw)", key: "all?timelineState=1&type=4&unwatched=1&sort=addedAt:desc" })

    obj.Prefs["section_row_order"] = {
        values: values,
        default: ""
    }

    obj.Screen.SetHeader("Change the appearance of your sections")

    obj.AddItem({title: "Sorting",ShortDescriptionLine2: "Sorting of Content"}, "section_sort", obj.GetEnumValue("section_sort"))
    obj.AddItem({title: "Reorder Rows"}, "section_row_order")
    obj.AddItem({title: "Full Grid", ShortDescriptionLine2: "Choose Sections to use the Full Grid"}, "rf_default_full_grid")
    obj.AddItem({title: "TV Series"}, "use_grid_for_series", obj.GetEnumValue("use_grid_for_series"))
    obj.AddItem({title: "TV Episode Size"}, "rf_episode_episodic_style", obj.GetEnumValue("rf_episode_episodic_style"))
' deprecated as of v3.1.2
'    obj.AddItem({title: "TV Episode Image"}, "rf_episode_episodic_thumbnail", obj.GetEnumValue("rf_episode_episodic_thumbnail"))
    obj.AddItem({title: "Movie & Others", ShortDescriptionLine2: "Posters or Grid"}, "rf_poster_grid", obj.GetEnumValue("rf_poster_grid"))
    obj.AddItem({title: "Grid Style/Size", ShortDescriptionLine2: "Size of Grid"}, "rf_grid_style", obj.GetEnumValue("rf_grid_style"))
    obj.AddItem({title: "Grid Display Mode", ShortDescriptionLine2: "Stretch or Fit images to fill the focus box"}, "rf_grid_displaymode", obj.GetEnumValue("rf_grid_displaymode"))
    obj.AddItem({title: "Grid Pop Out", ShortDescriptionLine2: "Description on bottom right"}, "rf_grid_description")
    obj.AddItem({title: "Full Grid Hide Header", ShortDescriptionLine2: "Hide text on top of each row"}, "rf_fullgrid_hidetext", obj.GetEnumValue("rf_fullgrid_hidetext"))
    obj.AddItem({title: "Full Grid Spacer", ShortDescriptionLine2: "Hide text on top of each row"}, "rf_fullgrid_spacer", obj.GetEnumValue("rf_fullgrid_spacer"))
    'we can add this.. but it doesn't do much yet.. let's not totally confuse people.. yet.
    'obj.AddItem({title: "Poster Display Mode", ShortDescriptionLine2: "Stretch or Fit images to fill the focus box"}, "rf_poster_displaymode", obj.GetEnumValue("rf_poster_displaymode"))
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
            if command = "use_grid_for_series" or command = "rf_poster_grid" or command = "rf_grid_style" or command = "rf_grid_displaymode" or command = "rf_poster_displaymode" or command = "rf_fullgrid_hidetext" or command = "rf_episode_episodic_style" or command = "section_sort" or command = "rf_fullgrid_spacer" then
                m.HandleEnumPreference(command, msg.GetIndex())
            else if command = "rf_grid_description" then
                screen = createGridDescriptionPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Grid Description Option"])
                screen.Show()
            else if command = "rf_default_full_grid" then
                screen = createDefaultFullGridViewPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Full Grid Sections"])
                screen.Show()
            else if command = "section_row_order" then
                m.HandleReorderPreference(command, msg.GetIndex())
            else if command = "close" then
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function


Function createGridDescriptionPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.HandleMessage = prefsGridDescriptionHandleMessage

    ' Grid Descriptions Pop Out
    values = [
        { title: "Enabled", EnumValue: "enabled"  },
        { title: "Disabled", EnumValue: "disabled"  },

    ]
    obj.Prefs["rf_grid_description_movie"] = {
        values: values,
        heading: "Grid Pop Out: Movie Section",
        default: "enabled"
    }
    obj.Prefs["rf_grid_description_show"] = {
        values: values,
        heading: "Grid Pop Out: TV Show Section",
        default: "enabled"
    }
    obj.Prefs["rf_grid_description_photo"] = {
        values: values,
        heading: "Grid Pop Out: Photo Section",
        default: "enabled"
    }
    obj.Prefs["rf_grid_description_artist"] = {
        values: values,
        heading: "Grid Pop Out: Music Section",
        default: "enabled"
    }
    obj.Prefs["rf_grid_description_other"] = {
        values: values,
        heading: "Grid Pop Out: All other sections",
        default: "enabled"
    }
    obj.Prefs["rf_grid_description_home"] = {
        values: values,
        heading: "Grid Pop Out: Home Screen",
        default: "enabled"
    }

    obj.Screen.SetHeader("Grid Pop Out Description")

    obj.AddItem({title: "Home"  }, "rf_grid_description_home",  obj.GetEnumValue("rf_grid_description_home"))
    obj.AddItem({title: "Movie" }, "rf_grid_description_movie", obj.GetEnumValue("rf_grid_description_movie"))
    obj.AddItem({title: "TV"    }, "rf_grid_description_show",  obj.GetEnumValue("rf_grid_description_show"))
    obj.AddItem({title: "Photo" }, "rf_grid_description_photo", obj.GetEnumValue("rf_grid_description_photo"))
    obj.AddItem({title: "Music" }, "rf_grid_description_artist", obj.GetEnumValue("rf_grid_description_artist"))
    obj.AddItem({title: "Other" }, "rf_grid_description_other", obj.GetEnumValue("rf_grid_description_other"))
    obj.AddItem({title: "Close" }, "close")

    return obj
End Function

Function createDefaultFullGridViewPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)

    obj.HandleMessage = prefsGridDescriptionHandleMessage

    ' Grid Descriptions Pop Out
    values = [
        { title: "Enabled", EnumValue: "enabled"  },
        { title: "Disabled", EnumValue: "disabled"  },

    ]
    obj.Prefs["rf_full_grid_movie"] = {
        values: values,
        heading: "Full Grid: Movie Section",
        default: "disabled"
    }
    obj.Prefs["rf_full_grid_homevideo"] = {
        values: values,
        heading: "Full Grid: Home Video Section",
        default: "disabled"
    }
    obj.Prefs["rf_full_grid_show"] = {
        values: values,
        heading: "Full Grid: TV Show Section",
        default: "disabled"
    }
    obj.Prefs["rf_full_grid_photo"] = {
        values: values,
        heading: "Full Grid: Photo Section",
        default: "disabled"
    }
    obj.Prefs["rf_full_grid_artist"] = {
        values: values,
        heading: "Full Grid: Music Section",
        default: "disabled"
    }
    obj.Prefs["rf_full_grid_other"] = {
        values: values,
        heading: "Full Grid: All other sections",
        default: "disabled"
    }

    obj.Screen.SetHeader("Default to Full Grid for these Sections")

    obj.AddItem({title: "Movie" }, "rf_full_grid_movie", obj.GetEnumValue("rf_full_grid_movie"))
    obj.AddItem({title: "TV"    }, "rf_full_grid_show",  obj.GetEnumValue("rf_full_grid_show"))
    obj.AddItem({title: "Photo" }, "rf_full_grid_photo", obj.GetEnumValue("rf_full_grid_photo"))
    obj.AddItem({title: "Music" }, "rf_full_grid_artist", obj.GetEnumValue("rf_full_grid_artist"))
    obj.AddItem({title: "Home Video" }, "rf_full_grid_homevideo", obj.GetEnumValue("rf_full_grid_homevideo"))
    obj.AddItem({title: "Other" }, "rf_full_grid_other", obj.GetEnumValue("rf_full_grid_other"))
    obj.AddItem({title: "Close" }, "close")

    return obj
End Function

Function prefsGridDescriptionHandleMessage(msg) As Boolean
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

'*** Helper functions ***

Function getCurrentMyPlexLabel() As String
    myplex = MyPlexManager()
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
