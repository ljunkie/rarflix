'*****************************************************************
'**  Home screen: the entry display of the application
'**
'*****************************************************************

Function createHomeScreen(viewController) As Object
    ' At the end of the day, the home screen is just a grid with a custom loader.
    ' So create a regular grid screen and override/extend as necessary.
    obj = createGridScreen(viewController, "flat-square", "stop")


    di=createobject("rodeviceinfo")
    ' only use custom loading image on the black theme - conserve space
    if mid(di.getversion(),3,1).toint() > 3 and RegRead("rf_theme", "preferences", "black") = "black" then
        imageDir = GetGlobalAA().Lookup("rf_theme_dir")
        SDPosterURL = imageDir + "black-loading-poster.png"
        HDPosterURL = imageDir + "black-loading-poster.png"
        obj.screen.setloadingposter(SDPosterURL,HDPosterURL)
    end if

    ' ljunkie - adding this comment for others if they think it's a good idea 
    ' to change the DisplayMode sway from "photo-fit" on 7x3 rows
    ' If we don't know exactly what we're displaying, photo-fit looks the
    ' best. Anything else makes something look horrible when the grid has
    ' has posters or anything else that isn't a square

    displaymode_home = RegRead("rf_home_displaymode", "preferences", "photo-fit")
    obj.Screen.SetDisplayMode(displaymode_home)

    obj.createNowPlayingRequest = homeCreateNowPlayingRequest
    obj.OnUrlEvent = homeScreenOnUrlEvent

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

    ' printAny(5,"1",changes) ' this prints better than printAA
    ' ljunkie Enum Changes - we could just look at changes ( but without _previous_ ) we don't know if this really changed.
    ' example of what can be done -- the clock routines have been changed ( so this is deprecated )
    '    if changes.DoesExist("rf_hs_clock") and changes.DoesExist("_previous_rf_hs_clock") and changes["rf_hs_clock"] <> changes["_previous_rf_hs_clock"] then
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

Sub homeScreenOnTimerExpired(timer)
    if timer.Name = "clock" AND m.ViewController.IsActiveScreen(m) then
        RRHomeScreenBreadcrumbs()
    end if

    ' Now Playing and Notify Section
    if timer.Name = "nowplaying" then

        m.createNowPlayingRequest() ' set the now playing globals - mainly for notification logic, but we might use for now playing row
        notify = getNowPlayingNotifications()
        screen = GetViewController().screens.peek()

        ' hack to clean up screens - probably better elsewhere or to figure out why we have invalid screens
        if type(screen.screen) = invalid then 
            Debug("screen invalid - popping screen during nowplaying timer")
            m.viewcontroller.popscreen(screen)
        end if 

        if m.ViewController.IsActiveScreen(m) then
            ' refresh now playing row -- it will only update if available to eu
            m.loader.NowPlayingChange()
        else if type(screen.screen) = "roSpringboardScreen" and screen.metadata <> invalid and screen.metadata.nowplaying_user <> invalid  then 
            ' SB screen, we should update it (assuming so since we have the metadata ) - TODO we should verify the screen type/name
            rf_updateNowPlayingSB(screen)
        end if
     
        ' Notification routine
        if notify <> invalid then ' we only get here if we have enabled notifications and we HAVE a notification
            ' slideshows do not get notifications (yet)
            ' TODO(ljunkie) add preference to allow notifitions in a slide show. We *should* to use an roImageCanvas to be less intrusive
            if GetViewController().IsSlideShowPlaying() then return

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
    m.createNowPlayingRequest()
    RRHomeScreenBreadcrumbs()
    'm.Screen.SetBreadcrumbText("", CurrentTimeAsString())
    m.SuperActivate(priorScreen)
End Sub 

Sub homeScreenOnUrlEvent(msg, requestContext)

    ' nowplaying_sessions requests
    if requestContext <> invalid and tostr(requestContext.key) = "nowplaying_sessions" then 
        setNowPlayingGlobals(msg, requestContext)
    end if

End Sub
