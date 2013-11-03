'*****************************************************************
'**  Home screen: the entry display of the application
'**
'*****************************************************************

Function createHomeScreen(viewController) As Object
    ' At the end of the day, the home screen is just a grid with a custom loader.
    ' So create a regular grid screen and override/extend as necessary.
    obj = createGridScreen(viewController, "flat-square", "stop")

    ' ljunkie - adding this comment for others if they think it's a good idea 
    ' to change the DisplayMode sway from "photo-fit" on 7x3 rows
    ' If we don't know exactly what we're displaying, photo-fit looks the
    ' best. Anything else makes something look horrible when the grid has
    ' has posters or anything else that isn't a square

    displaymode_home = RegRead("rf_home_displaymode", "preferences", "photo-fit")
    obj.Screen.SetDisplayMode(displaymode_home)

    obj.Loader = createHomeScreenDataLoader(obj)

    obj.Refresh = refreshHomeScreen

    obj.OnTimerExpired = homeScreenOnTimerExpired
    obj.SuperActivate = obj.Activate
    obj.Activate = homeScreenActivate

    obj.clockTimer = createTimer()
    obj.clockTimer.Name = "clock"
    obj.clockTimer.SetDuration(20000, true) ' A little lag is fine here
    viewController.AddTimer(obj.clockTimer, obj) 

    'if isRFtest() then 
    ' enabled on main channel for v2.8.2
    obj.npTimer = createTimer()
    obj.npTimer.Name = "nowplaying"
    obj.npTimer.SetDuration(10000, true) ' 10 seconds? too much?
    viewController.AddTimer(obj.npTimer, obj) 
    'end if

    return obj
End Function

Sub refreshHomeScreen(changes)
    if type(changes) = "Boolean" and changes then
        changes = CreateObject("roAssociativeArray") ' hack for info button from grid screen (mark as watched) -- TODO later and find out why this is a Boolean
        'changes["servers"] = "true"
    end if
    ' printAny(5","1",changes) ' this prints better than printAA
    ' ljunkie Enum Changes - we could just look at changes ( but without _previous_ ) we don't know if this really changed.
    if changes.DoesExist("rf_hs_clock") and changes.DoesExist("_previous_rf_hs_clock") and changes["rf_hs_clock"] <> changes["_previous_rf_hs_clock"] then
        if changes["rf_hs_clock"] = "disabled" then
            m.Screen.SetBreadcrumbEnabled(false)
        else
            RRbreadcrumbDate(m)
        end if
    end if
    ' other rarflix changes?
    ' end ljunkie

    ' If myPlex state changed, we need to update the queue, shared sections,
    ' and any owned servers that were discovered through myPlex.
    if changes.DoesExist("myplex") then
        m.Loader.OnMyPlexChange()
    end if

    ' If a server was added or removed, we need to update the sections,
    ' channels, and channel directories.
    if changes.DoesExist("servers") then
        for each server in PlexMediaServers()
            if server.machineID <> invalid AND GetPlexMediaServer(server.machineID) = invalid then
                PutPlexMediaServer(server)
            end if
        next

        servers = changes["servers"]
        didRemove = false
        for each machineID in servers
            Debug("Server " + tostr(machineID) + " was " + tostr(servers[machineID]))
            if servers[machineID] = "removed" then
                DeletePlexMediaServer(machineID)
                didRemove = true
            else
                server = GetPlexMediaServer(machineID)
                if server <> invalid then
                    m.Loader.CreateServerRequests(server, true, false)
                end if
            end if
        next

        if didRemove then
            m.Loader.RemoveInvalidServers()
        end if
    end if

    ' Recompute our capabilities
    Capabilities(true)
End Sub

Sub ShowHelpScreen()
    header = "Welcome to Plex for Roku!"
    paragraphs = []
    paragraphs.Push("Plex for Roku automatically connects to Plex Media Servers on your local network and also works with myPlex to view queued items and connect to your published and shared servers.")
    paragraphs.Push("To download and install Plex Media Server on your computer, visit http://plexapp.com/getplex")
    paragraphs.Push("For more information on getting started, visit http://plexapp.com/roku")

    screen = createParagraphScreen(header, paragraphs, GetViewController())
    GetViewController().InitializeOtherScreen(screen, invalid)

    screen.Show()
End Sub


Sub homeScreenOnTimerExpired(timer)
    if timer.Name = "clock" AND m.ViewController.IsActiveScreen(m) then
        RRbreadcrumbDate(m.viewcontroller.screens[0])
        'm.Screen.SetBreadcrumbText("", CurrentTimeAsString())
    end if

    ' Now Playing and Notify Section (RARflixTest only)
    if timer.Name = "nowplaying" then     ' and isRFtest() then ( enabled on main channel in v2.8.2 )

        setnowplayingGlobals() ' set the now playing globals - mainly for notification logic, but we might use for now playing row
        notify = getNowPlayingNotifications()
        screen = m.viewcontroller.screens.peek()

        ' hack to clean up screens - probably better elsewhere or to figure out why we have invalid screens
        if type(screen.screen) = invalid then 
            print "screen invalid - popping screen during nowplaying timer"
            m.viewcontroller.popscreen(screen)
        end if 

        if m.ViewController.IsActiveScreen(m) then ' HOME screen ( we don't notify, it has a row for this )
            m.loader.NowPlayingChange() ' refresh now playing row -- it will only update if available to eu
        else if type(screen.screen) = "roSpringboardScreen" and screen.metadata <> invalid and screen.metadata.nowplaying_user <> invalid  then 
            ' SB screen, we should update it (assuming so since we have the metadata ) - TODO we should verify the screen type/name
            rf_updateNowPlayingSB(screen)
        end if
     
        ' Notification routine
        if notify <> invalid then ' we only get here if we have enabled notifications and we HAVE a notification
            if type(screen) = "roAssociativeArray" then
                if type(screen.screen) = "roVideoScreen" and RegRead("rf_notify","preferences","enabled") <> "nonvideo" then ' Video Screen - VideoPlayer (playing a video)
                    HUDnotify(screen,notify)
                else if RegRead("rf_notify","preferences","enabled") <> "video" then ' Non Video Screen
                    ShowNotifyDialog(notify,0,true)
                end if
            end if
        end if

    end if ' end nowplaying timer

End Sub 

Sub homeScreenActivate(priorScreen)
    ' on activation - we should run a fiew things
    ' set the now playing globals - mainly for notification logic, but we might use for now playing row
    ' if isRFtest() then setnowplayingGlobals() 
    setnowplayingGlobals() ' enabled in v2.8.2
    RRbreadcrumbDate(m.viewcontroller.screens[0])
    'm.Screen.SetBreadcrumbText("", CurrentTimeAsString())
    m.SuperActivate(priorScreen)
End Sub 


