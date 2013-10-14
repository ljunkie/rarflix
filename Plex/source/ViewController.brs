'*
'* A controller for managing the stack of screens that have been displayed.
'* By centralizing this we can better support things like destroying and
'* recreating views and breadcrumbs. It also provides a single place that
'* can take an item and figure out which type of screen should be shown
'* so that logic doesn't have to be in each individual screen type.
'*

Function createViewController() As Object
    controller = CreateObject("roAssociativeArray")

    controller.breadcrumbs = CreateObject("roArray", 10, true)
    controller.screens = CreateObject("roArray", 10, true)

    controller.GlobalMessagePort = CreateObject("roMessagePort")

    controller.CreateHomeScreen = vcCreateHomeScreen
    controller.CreateScreenForItem = vcCreateScreenForItem
    controller.CreateTextInputScreen = vcCreateTextInputScreen
    controller.CreateEnumInputScreen = vcCreateEnumInputScreen
    controller.CreateReorderScreen = vcCreateReorderScreen
    controller.CreateContextMenu = vcCreateContextMenu

    controller.CreatePhotoPlayer = vcCreatePhotoPlayer
    controller.CreateVideoPlayer = vcCreateVideoPlayer
    controller.CreatePlayerForItem = vcCreatePlayerForItem
    controller.IsVideoPlaying = vcIsVideoPlaying

    controller.ShowReleaseNotes = vcShowReleaseNotes

    controller.InitializeOtherScreen = vcInitializeOtherScreen
    controller.AssignScreenID = vcAssignScreenID
    controller.PushScreen = vcPushScreen
    controller.PopScreen = vcPopScreen
    controller.IsActiveScreen = vcIsActiveScreen

    controller.afterCloseCallback = invalid
    controller.CloseScreenWithCallback = vcCloseScreenWithCallback

    controller.Show = vcShow
    controller.UpdateScreenProperties = vcUpdateScreenProperties
    controller.AddBreadcrumbs = vcAddBreadcrumbs

    controller.DestroyGlitchyScreens = vcDestroyGlitchyScreens

    ' Even with the splash screen, we still need a facade for memory purposes
    ' and a clean exit.
    controller.facade = CreateObject("roGridScreen")
    controller.facade.Show()

    controller.nextScreenId = 1
    controller.nextTimerId = 1

    controller.InitThemes = vcInitThemes
    controller.PushTheme = vcPushTheme
    controller.PopTheme = vcPopTheme
    controller.ApplyThemeAttrs = vcApplyThemeAttrs

    controller.InitThemes()

    controller.PendingRequests = {}
    controller.RequestsByScreen = {}
    controller.StartRequest = vcStartRequest
    controller.CancelRequests = vcCancelRequests

    controller.SocketListeners = {}
    controller.AddSocketListener = vcAddSocketListener

    controller.Timers = {}
    controller.TimersByScreen = {}
    controller.AddTimer = vcAddTimer

    controller.SystemLog = CreateObject("roSystemLog")
    controller.SystemLog.SetMessagePort(controller.GlobalMessagePort)
    controller.SystemLog.EnableType("bandwidth.minute")


    ' Stuff the controller into the global object
    m.ViewController = controller
    controller.myplex = createMyPlexManager(controller)

    ' Initialize things that run in the background
    InitWebServer(controller)
    controller.GdmAdvertiser = createGDMAdvertiser(controller)
    controller.AudioPlayer = createAudioPlayer(controller)
    controller.Analytics = createAnalyticsTracker()

    return controller
End Function

Function GetViewController()
    return m.ViewController
End Function

Function GetMyPlexManager()
    return GetViewController().myplex
End Function

Function vcCreateHomeScreen()
    screen = createHomeScreen(m)
    screen.ScreenID = -1
    screen.ScreenName = "Home"
    m.InitializeOtherScreen(screen, invalid)
    screen.Show()
    RRbreadcrumbDate(screen) 'ljunkie - homescreen data/time
    return screen
End Function

Function vcCreateScreenForItem(context, contextIndex, breadcrumbs, show=true) As Dynamic
    if type(context) = "roArray" then
        item = context[contextIndex]
    else
        item = context
    end if

    ' ljunkie - reset breadcrumb for TV show if tv watched status enabled and title <> umtitle (post and grid view supported)
    if RegRead("rf_tvwatch", "preferences", "enabled") = "enabled" and (item.type = "show" or item.viewgroup = "season" or item.viewgroup = "show" or item.viewgroup = "episode") then
        if item.umtitle <> invalid and ( type(breadcrumbs) = "roArray" and breadcrumbs[0] <> invalid and breadcrumbs[0] = item.title) or (breadcrumbs = invalid) then 
	    Debug("tv watched status enabled: setting breadcrumb back to original title; change from " + breadcrumbs[0] + " -to- " + item.umtitle)
            breadcrumbs[0] = item.umtitle
        else if item.parentindex <> invalid and item.viewgroup = "episode" then 
	    Debug("tv watched status enabled: setting breadcrumb back to original title (tv gridview?); change from " + breadcrumbs[0] + " -to- " + item.umtitle)
            breadcrumbs[0] = "Season " + tostr(item.parentindex)
            breadcrumbs[1] = ""
	else 
            Debug("tv watched status enabled: DID not match criteria(1) -- NOT setting breadcrumb back to original title; change from " + breadcrumbs[0] + " -to- " + item.umtitle)
        end if
    ' this causes a crash in playing Photos from Year with the play button -- not need for this anyways..
    'else if RegRead("rf_tvwatch", "preferences", "enabled") = "enabled" and item.umtitle <> invalid and breadcrumbs[0] <> invalid and breadcrumbs[0] = item.title then 
    '	 Debug("tv watched status enabled: DID not match criteria(2) -- NOT setting breadcrumb back to original title; change from " + breadcrumbs[0] + " -to- " + item.umtitle)
    end if

    contentType = item.ContentType
    viewGroup = item.viewGroup
    if viewGroup = invalid then viewGroup = ""

    screen = CreateObject("roAssociativeArray")

    ' NOTE: We don't support switching between them as a preference, but
    ' the poster screen can be used anywhere the grid is used below. By
    ' default the poster screen will try to decide whether or not to
    ' include the filter bar that makes it more grid like, but it can
    ' be forced by setting screen.FilterMode = true.

    screenName = invalid
    poster_grid = RegRead("rf_poster_grid", "preferences", "grid")

    if contentType = "movie" OR contentType = "episode" OR contentType = "clip" then
        screen = createVideoSpringboardScreen(context, contextIndex, m)
        screenName = "Preplay " + contentType
    else if contentType = "series" then
        if RegRead("use_grid_for_series", "preferences", "") <> "" then
            screen = createGridScreenForItem(item, m, "flat-16X9")
            screenName = "Series Grid"
        else
            screen = createPosterScreen(item, m)
            screenName = "Series Poster"
        end if
    else if contentType = "artist" then
        if poster_grid = "grid" then 
            screen = createFULLGridScreen(item, m, "Invalid")
        else 
            screen = createPosterScreen(item, m)
        end if
        screenName = "Artist Poster"
    else if contentType = "album" then
        ' grid looks horrible in this view. - do not enable FULL grid
        screen = createPosterScreen(item, m)
        screen.SetListStyle("flat-episodic", "zoom-to-fill")
        screenName = "Album Poster"
    else if item.key = "nowplaying" then
        m.AudioPlayer.ContextScreenID = m.nextScreenId
        screen = createAudioSpringboardScreen(m.AudioPlayer.Context, m.AudioPlayer.CurIndex, m)
        screenName = "Now Playing"
        if screen = invalid then return invalid
    else if contentType = "audio" then
        screen = createAudioSpringboardScreen(context, contextIndex, m)
        if screen = invalid then return invalid
        screenName = "Audio Springboard"
    else if contentType = "section" then
        RegWrite("lastMachineID", item.server.machineID)
        RegWrite("lastSectionKey", item.key)

        screenName = "Section: " + tostr(item.type)
        if tostr(item.type) = "artist" then 
            Debug("---- override photo-fit/flat-square for section with content of " + tostr(item.type))
            screen = createGridScreenForItem(item, m, "flat-square")
            screen.screen.SetDisplayMode("Photo-Fit")
            screen.screen.SetListPosterStyles("landscape")
        else if tostr(item.type) = "photo" then 
            Debug("---- override photo-fit/flat-16x9 for section with content of " + tostr(item.type))
            screen = createGridScreenForItem(item, m, "flat-16X9")
            screen.screen.SetDisplayMode("Photo-Fit")
        else 
            screen = createGridScreenForItem(item, m, "flat-movie") ' some might fair better with flat-square? (TODO)
        end if
    else if contentType = "playlists" then
        screen = createGridScreenForItem(item, m, "flat-16X9")
        screenName = "Playlist Grid"
    else if contentType = "photo" then
        if right(item.key, 8) = "children" then
            if poster_grid = "grid" then 
                screen = createFULLGridScreen(item, m, "Invalid")
            else 
                screen = createPosterScreen(item, m)
            end if
            screenName = "Photo Poster"
        else
            screen = createPhotoSpringboardScreen(context, contextIndex, m)
            screenName = "Photo Springboard"
        end if
    else if contentType = "keyboard" then
        screen = createKeyboardScreen(m, item)
        screenName = "Keyboard"
    else if contentType = "search" then
        screen = createSearchScreen(item, m)
        screenName = "Search"
    else if item.key = "/system/appstore" then
        screen = createGridScreenForItem(item, m, "flat-square")
        screenName = "Channel Directory"
    else if viewGroup = "Store:Info" then
        dialog = createPopupMenu(item)
        dialog.Show()
        return invalid
    else if viewGroup = "secondary" then
        if poster_grid = "grid" then 
            screen = createFULLGridScreen(item, m, "Invalid")
        else 
            screen = createPosterScreen(item, m)
        end if
    else if item.key = "globalprefs" then
        screen = createPreferencesScreen(m)
        screenName = "Preferences Main"
    else if item.key = "/channels/all" then
        ' Special case for all channels to force it into a special grid view
        screen = createGridScreen(m, "flat-square")
        names = ["Video Channels", "Music Channels", "Photo Channels"]
        keys = ["/video", "/music", "/photos"]
        fakeContainer = createFakePlexContainer(item.server, names, keys)
        screen.Loader = createPaginatedLoader(fakeContainer, 8, 25)
        screen.Loader.Listener = screen
        screen.Loader.Port = screen.Port
        screenName = "All Channels"
    else if item.searchTerm <> invalid AND item.server = invalid then
        screen = createGridScreen(m, "flat-square")
        screen.Loader = createSearchLoader(item.searchTerm)
        screen.Loader.Listener = screen
        screenName = "Search Results"
    else if item.settings = "1"
        screen = createSettingsScreen(item, m)
        screenName = "Settings"
    else if tostr(item.type) = "season" or tostr(item.type) = "channel" then 
        ' others we want to fost into a poster screen
        screen = createPosterScreen(item, m)
    else
        ' Where do we capture channel directory?
        Debug("---- Creating a default " + poster_grid + " view for contentType=" + tostr(contentType) + ", viewGroup=" + tostr(viewGroup))
        if poster_grid = "grid" then 
            screen = createFULLGridScreen(item, m, "Invalid")
            print  item
            print tostr(item.type)
        else 
            screen = createPosterScreen(item, m)
        end if
    end if

    if screenName = invalid then
        screenName = type(screen.Screen) + " " + firstOf(contentType, "unknown")
    end if

    screen.ScreenName = screenName

    m.AddBreadcrumbs(screen, breadcrumbs)
    m.UpdateScreenProperties(screen)
    m.PushScreen(screen)

    if show then screen.Show()

    return screen
End Function

Function vcCreateTextInputScreen(heading, breadcrumbs, show=true) As Dynamic
    screen = createKeyboardScreen(m)
    screen.ScreenName = "Keyboard: " + tostr(heading)

    if heading <> invalid then
        screen.Screen.SetDisplayText(heading)
    end if

    m.AddBreadcrumbs(screen, breadcrumbs)
    m.UpdateScreenProperties(screen)
    m.PushScreen(screen)

    if show then screen.Show()

    return screen
End Function

Function vcCreateEnumInputScreen(options, selected, heading, breadcrumbs, show=true) As Dynamic
    screen = createEnumScreen(options, selected, m)
    screen.ScreenName = "Enum: " + tostr(heading)

    if heading <> invalid then
        screen.Screen.SetHeader(heading)
    end if

    m.AddBreadcrumbs(screen, breadcrumbs)
    m.UpdateScreenProperties(screen)
    m.PushScreen(screen)

    if show then screen.Show()

    return screen
End Function

Function vcCreateReorderScreen(items, breadcrumbs, show=true) As Dynamic
    screen = createReorderScreen(items, m)
    screen.ScreenName = "Reorder"

    m.AddBreadcrumbs(screen, breadcrumbs)
    m.UpdateScreenProperties(screen)
    m.PushScreen(screen)

    if show then screen.Show()

    return screen
End Function

Function vcCreateContextMenu()
    ' Our context menu is only relevant if the audio player has content.
    ' ljunkie -- we need some more checks here -- if audio is not playing/etc and we want to use the asterisk button for other things.. how do we work this?
    if m.AudioPlayer.ContextScreenID = invalid then return invalid

    screen = m.screens.peek()
    showDialog = false

    if type(screen.screen) = "roMessageDialog" then  ' if we already have a new dialog - lets not replace it
           Debug( "---disabling audio dialog for a new DIALOG" + screen.screenname + " type:" + type(screen.screen))
           return invalid
    end if

    itype = "invalid"
    ctype = "invalid"
    vtype = "invalid"
    if screen.selectedrow <> invalid and screen.focusedindex <> invalid and type(screen.contentarray[screen.selectedrow][screen.focusedindex]) = "roAssociativeArray" then
        itype = tostr(screen.contentarray[screen.selectedrow][screen.focusedindex].type) ' movie, show, photo, episode, etc..
        ctype = tostr(screen.contentarray[screen.selectedrow][screen.focusedindex].contenttype) ' section
        vtype = tostr(screen.contentarray[screen.selectedrow][screen.focusedindex].viewgroup)
    end if

    ' Audios is playing - we should show it if the selected type is a "section" -- maybe we should look at secondary? -- also allow invalids
    if m.audioplayer.ispaused or m.audioplayer.isplaying then 
        r = CreateObject("roRegex", "section|secondary", "i") ' section too - those are not special
        'showDialog = (   (r.IsMatch(itype) or r.IsMatch(ctype) or r.IsMatch(vtype)) or (itype = "invalid" and ctype = "invalid" and vtype = "invalid") )
        showDialog = ( (r.IsMatch(itype) or r.IsMatch(ctype) or r.IsMatch(vtype)) or (itype = "invalid"))
    end if

    ' always show dialog if audio/artist/album/track
    ' we will also show if channel, preferences, search, playlists, clip as they have not special actions
    if NOT showDialog then 
        r = CreateObject("roRegex", "audio|artist|album|track|channel|pref|search|playlists|clip", "i") 
        showDialog = (r.IsMatch(itype) or r.IsMatch(ctype) or r.IsMatch(vtype) or r.IsMatch(tostr(screen.screenname)))
    end if

    Debug("show audio dialog:" + tostr(showDialog) + "; itype:" +  tostr(itype) + "; ctype:" +  tostr(ctype) + "; vtype:" +  tostr(vtype) + "; screenname:" +  tostr(screen.screenname))
    if NOT showDialog then return invalid
    return m.AudioPlayer.ShowContextMenu()
End Function

Function vcCreatePhotoPlayer(context, contextIndex=invalid, show=true)
    screen = createPhotoPlayerScreen(context, contextIndex, m)
    screen.ScreenName = "Photo Player"

    m.AddBreadcrumbs(screen, invalid)
    m.UpdateScreenProperties(screen)
    m.PushScreen(screen)

    if show then screen.Show()

    return screen
End Function

Function vcCreateVideoPlayer(metadata, seekValue=0, directPlayOptions=0, show=true)
    ' Stop any background audio first
    m.AudioPlayer.Stop()

    ' Make sure we have full details before trying to play.
    metadata.ParseDetails()

    ' Prompt about resuming if there's an offset and the caller didn't specify a seek value.
    if seekValue = invalid then
        if metadata.viewOffset <> invalid then
            ' check to see if this is from the /status/session source -- if so we are trying to resume with someone else ( so let's get new data )
            
            offsetSeconds = fix(val(metadata.viewOffset)/1000)

            ' ljunkie - resume video from Now Playing? we should set metadata in VideoMetatdata to more useful info TODO

            resume_with_user = invalid
            if metadata.nowPlaying_maid <> invalid and metadata.isStopped = invalid then
                resume_with_user = 1 ' flag for later
            end if

            dlg = createBaseDialog()
            dlg.Title = "Play Video"

            if resume_with_user = invalid then 
                dlg.SetButton("resume", "Resume from " + TimeDisplay(offsetSeconds))
            else 
                user = "User"
                if metadata.nowPlaying_user <> invalid then user = UCasefirst(metadata.nowPlaying_user,true)
                dlg.SetButton("resume", "Sync Video with " + user)
            end if

            dlg.SetButton("play", "Play from beginning")
            dlg.Show(true)

            if resume_with_user <> invalid and dlg.Result = "resume"
                ' sync called - we should get the most recent offset and resume
                metadata = rfUpdateNowPlayingMetadata(metadata,10000)
                ' if the viewOffset return is invalid - user has stopped playing
                if metadata.viewOffset = invalid then
                    Debug("---- Sync Playback failed: key:" + tostr(metadata.key) + ", machineID:" + tostr(metadata.nowPlaying_maid) + " DO not exist @ " + tostr(metadata.sourceurl))
                    dlg = createBaseDialog()
                    dlg.Title = "Sorry... Cannot Sync Playback"
                    dlg.text = "The user has stopped playing the content" + chr(10)
                    dlg.SetButton("invalid", "close")
                    dlg.Show(true)
                end if
            end if

            if dlg.Result = invalid or dlg.Result = "invalid" then return invalid
            if dlg.Result = "resume" then
                seekValue = int(val(metadata.viewOffset))
            else
                seekValue = 0
            end if
        else
            seekValue = 0
        end if
    end if

    screen = createVideoPlayerScreen(metadata, seekValue, directPlayOptions, m)
    screen.ScreenName = "Video Player"

    m.AddBreadcrumbs(screen, invalid)
    m.UpdateScreenProperties(screen)
    m.PushScreen(screen)

    if show then screen.Show()

    return screen
End Function

Function vcCreatePlayerForItem(context, contextIndex, seekValue=invalid)
    item = context[contextIndex]

    if item.ContentType = "photo" then
        return m.CreatePhotoPlayer(context, contextIndex)
    else if item.ContentType = "audio" then
        m.AudioPlayer.Stop()
        return m.CreateScreenForItem(context, contextIndex, invalid)
    else if item.ContentType = "movie" OR item.ContentType = "episode" OR item.ContentType = "clip" then
        directplay = RegRead("directplay", "preferences", "0").toint()
        return m.CreateVideoPlayer(item, seekValue, directplay)
    else
        Debug("Not sure how to play item of type " + tostr(item.ContentType))
 	' ljunkie - try to fix the breadcrumbs for gridScreens
        screen = m.screens.peek()
	breadcrumbs = invalid
        if tostr(type(screen.screen)) = "roGridScreen" and screen.Loader <> invalid and type(screen.Loader.GetNames) = "roFunction" and screen.selectedrow <> invalid then
           if item.ContentType = "section" then
               breadcrumbs = [item.server.name, firstof(item.umTitle, item.Title)]
           else
               breadcrumbs = [screen.Loader.GetNames()[screen.selectedrow], firstof(item.umTitle, item.Title)]
           end if
        end if
        return m.CreateScreenForItem(context, contextIndex, breadcrumbs)
    end if
End Function

Function vcIsVideoPlaying() As Boolean
    return type(m.screens.Peek().Screen) = "roVideoScreen"
End Function

Sub vcShowReleaseNotes()
    header = ""
    title = GetGlobal("appName") + " updated to " + GetGlobal("appVersionStr")
    paragraphs = []
    if isRFtest() then 
        paragraphs.Push("New: Now Playing Notifications!")
        paragraphs.Push("New: Now Playing on the Home Screen (with periodic updates)")
    end if
    paragraphs.Push("New: Cast & Crew works for more content")
    paragraphs.Push(chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+ "+ Show All content [movie/tv/other] for selected Cast Member")
    paragraphs.Push(" ( * ) Remote Button works is most areas - try it!")
    paragraphs.Push(" Hide some rows per section type [movie,tv,music]")
    paragraphs.Push(" RARFflix preferences - toggles for mods")
    paragraphs.Push(chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+" Hide Rows, Clock, Dynamic Headers, Search Title, etc.. ")
    paragraphs.Push("+ Movie Trailers, Rotten Tomatoes Ratings, HUD mods, other misc updates")
    if NOT isRFtest() then paragraphs.Push(" ")
    paragraphs.Push(chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+" ** Donate @ www.rarflix.com **")

    screen = createParagraphScreen(header, paragraphs, m)
    screen.ScreenName = "Release Notes"
    screen.Screen.SetTitle(title)
    m.InitializeOtherScreen(screen, invalid)

    ' As a one time fix, if the user is just updating and previously specifically
    ' set the H.264 level preference to 4.0, update it to 4.1.
    if RegRead("level", "preferences", "41") = "40" then
        RegWrite("level", "41", "preferences")
    end if

    screen.Show()
End Sub

Sub vcInitializeOtherScreen(screen, breadcrumbs)
    m.AddBreadcrumbs(screen, breadcrumbs)
    m.UpdateScreenProperties(screen)
    m.PushScreen(screen)
End Sub

Sub vcAssignScreenID(screen)
    if screen.ScreenID = invalid then
        screen.ScreenID = m.nextScreenId
        m.nextScreenId = m.nextScreenId + 1
    end if
End Sub

Sub vcPushScreen(screen)
    m.AssignScreenID(screen)
    screenName = firstOf(screen.ScreenName, type(screen.Screen))
    m.Analytics.TrackScreen(screenName)
    Debug("Pushing screen " + tostr(screen.ScreenID) + " onto view controller stack - " + screenName)
    m.screens.Push(screen)
End Sub

Sub vcPopScreen(screen)
    if screen.ScreenID = -1 then
        Debug("Popping home screen, cleaning up")

        while m.screens.Count() > 1
            m.PopScreen(m.screens.Peek())
        end while
        m.screens.Pop()

        screen.Loader.Listener = invalid
        screen.Loader = invalid
        return
    end if

    if screen.Cleanup <> invalid then screen.Cleanup()

    ' Try to clean up some potential circular references
    screen.Listener = invalid
    if screen.Loader <> invalid then
        screen.Loader.Listener = invalid
        screen.Loader = invalid
    end if

    if screen.ScreenID = invalid OR m.screens.Peek().ScreenID = invalid then
        Debug("Trying to pop screen a screen without a screen ID!")
        Return
    end if

    callActivate = true
    screenID = screen.ScreenID.tostr()
    if screen.ScreenID <> m.screens.Peek().ScreenID then
        Debug("Trying to pop screen that doesn't match the top of our stack!")

        ' This is potentially indicative of something very wrong, which we may
        ' not be able to recover from. But it also happens when we launch a new
        ' screen from a dialog and try to pop the dialog after the new screen
        ' has been put on the stack. If we don't remove the screen from the
        ' stack, things will almost certainly go wrong (seen one crash report
        ' likely caused by this). So we might as well give it a shot.

        for i = m.screens.Count() - 1 to 0 step -1
            if screen.ScreenID = m.screens[i].ScreenID then
                Debug("Removing screen " + screenID + " from middle of stack!")
                m.screens.Delete(i)
                exit for
            end if
        next
        callActivate = false
    else
        Debug("Popping screen " + screenID + " and cleaning up " + tostr(screen.NumBreadcrumbs) + " breadcrumbs")
        m.screens.Pop()
        for i = 0 to screen.NumBreadcrumbs - 1
            m.breadcrumbs.Pop()
        next
    end if

    ' Clean up any requests initiated by this screen
    m.CancelRequests(screen.ScreenID)

    ' Clean up any timers initiated by this screen
    timers = m.TimersByScreen[screenID]
    if timers <> invalid then
        for each timerID in timers
            timer = m.Timers[timerID]
            timer.Active = false
            timer.Listener = invalid
            m.Timers.Delete(timerID)
        next
        m.TimersByScreen.Delete(screenID)
    end if

    ' Let the new top of the stack know that it's visible again. If we have
    ' no screens on the stack, but we didn't just close the home screen, then
    ' we haven't shown the home screen yet. Show it now.
    if m.screens.Count() = 0 then
        m.Home = m.CreateHomeScreen()
    else if callActivate then
        newScreen = m.screens.Peek()
        ' ljunkie - extra hack to cleanup the screen we are entering when invalid or if trying to re-enter a dialog
        if type(newScreen.Screen) = invalid then
            ' this should never happen
            Debug("---- Top screen invalid - popping ")
            m.popscreen(newScreen)
            newScreen = m.screens.Peek()
        else if type(newScreen.Screen) = "roMessageDialog" then 
            ' bug in the notifications dialog - when multiple come in, they are not tracked? these is just some hacky GC
            Debug("---- Top screen is a Dialog -- that can't happen!")
            m.popscreen(newScreen)
            newScreen = m.screens.Peek()
            print newScreen
            print type(newScreen.Screen)
        end if

        screenName = firstOf(newScreen.ScreenName, type(newScreen.Screen))
        Debug("Top of stack is once again: " + screenName)
        m.Analytics.TrackScreen(screenName)
        newScreen.Activate(screen)
        'RRbreadcrumbDate(newScreen) ' ljunkie - clock
    end if

    ' If some other screen requested this close, let it know.
    if m.afterCloseCallback <> invalid then
        callback = m.afterCloseCallback
        m.afterCloseCallback = invalid
        callback.OnAfterClose()
    end if
End Sub

Function vcIsActiveScreen(screen) As Boolean
    return m.screens.Peek().ScreenID = screen.ScreenID
End Function

Sub vcCloseScreenWithCallback(callback)
    m.afterCloseCallback = callback
    m.screens.Peek().Screen.Close()
End Sub

Sub vcShow()
    if RegRead("last_run_version", "misc", "") <> GetGlobal("appVersionStr") then
        m.ShowReleaseNotes()
        RegWrite("last_run_version", GetGlobal("appVersionStr"), "misc")
    else
        m.Home = m.CreateHomeScreen()
    end if

    Debug("Starting global message loop")

    timeout = 0
    lastmin = -1 'container to update every minute
    while m.screens.Count() > 0
        m.WebServer.prewait()
        msg = wait(timeout, m.GlobalMessagePort)

        if msg <> invalid then
            ' Printing debug information about every message may be overkill
            ' regardless, but note that URL events don't play by the same rules,
            ' and there's no ifEvent interface to check for. Sigh.
            'if GetInterface(msg, "ifUrlEvent") = invalid AND GetInterface(msg, "ifSocketEvent") = invalid then
                'Debug("Processing " + type(msg) + " (top of stack " + type(m.screens.Peek().Screen) + "): " + tostr(msg.GetType()) + ", " + tostr(msg.GetIndex()) + ", " + tostr(msg.GetMessage()))
            'end if

            for i = m.screens.Count() - 1 to 0 step -1
                if m.screens[i].HandleMessage(msg) then exit for
            end for

            ' Process URL events. Look up the request context and call a
            ' function on the listener.
            if type(msg) = "roUrlEvent" AND msg.GetInt() = 1 then
                id = msg.GetSourceIdentity().tostr()
                requestContext = m.PendingRequests[id]
                if requestContext <> invalid then
                    m.PendingRequests.Delete(id)
                    requestContext.Listener.OnUrlEvent(msg, requestContext)
                    requestContext = invalid
                end if
            else if type(msg) = "roSocketEvent" then
                listener = m.SocketListeners[msg.getSocketID().tostr()]
                if listener <> invalid then
                    listener.OnSocketEvent(msg)
                    listener = invalid
                else
                    ' Assume it was for the web server (it won't hurt if it wasn't)
                    m.WebServer.postwait()
                end if
            else if type(msg) = "roAudioPlayerEvent" then
                m.AudioPlayer.HandleMessage(msg)
            else if type(msg) = "roSystemLogEvent" then
                msgInfo = msg.GetInfo()
                if msgInfo.LogType = "bandwidth.minute" then
                    GetGlobalAA().AddReplace("bandwidth", msgInfo.Bandwidth)
                end if
            else if msg.isRemoteKeyPressed() and msg.GetIndex() = 10 then
                m.CreateContextMenu()
            end if
        end if

        ' Check for any expired timers
        timeout = 0
        for each timerID in m.Timers
            timer = m.Timers[timerID]
            if timer.IsExpired() then
                timer.Listener.OnTimerExpired(timer)
            end if

            ' Make sure we set a timeout on the wait so we'll catch the next timer
            remaining = timer.RemainingMillis()
            if remaining > 0 AND (timeout = 0 OR remaining < timeout) then
                timeout = remaining
            end if
        next
    end while

    ' Clean up some references on the way out
    m.Home = invalid
    m.myplex = invalid
    m.GdmAdvertiser = invalid
    m.WebServer = invalid
    m.Analytics.Cleanup()
    m.Analytics = invalid
    m.AudioPlayer = invalid
    m.Timers.Clear()
    m.PendingRequests.Clear()
    m.SocketListeners.Clear()

    Debug("Finished global message loop")
End Sub

Sub vcAddBreadcrumbs(screen, breadcrumbs)
    ' Add the breadcrumbs to our list and set them for the current screen.
    ' If the current screen specified invalid for the breadcrubms then it
    ' doesn't want any breadcrumbs to be shown. If it specified an empty
    ' array, then the current breadcrumbs will be shown again.
    screenType = type(screen.Screen)
    if breadcrumbs = invalid then
        screen.NumBreadcrumbs = 0
        return
    end if

    ' Special case for springboard screens, don't show the current title
    ' in the breadcrumbs.
    if screenType = "roSpringboardScreen" AND breadcrumbs.Count() > 0 then
        breadcrumbs.Pop()
    end if

    if breadcrumbs.Count() = 0 AND m.breadcrumbs.Count() > 0 then
        count = m.breadcrumbs.Count()
        if count >= 2 then
            breadcrumbs = [m.breadcrumbs[count-2], m.breadcrumbs[count-1]]
        else
            breadcrumbs = m.breadcrumbs[0]
        end if

        m.breadcrumbs.Append(breadcrumbs)
        screen.NumBreadcrumbs = breadcrumbs.Count()
    else
        for each b in breadcrumbs
            m.breadcrumbs.Push(tostr(b))
        next
        screen.NumBreadcrumbs = breadcrumbs.Count()
    end if
End Sub

Sub vcUpdateScreenProperties(screen)
    ' Make sure that metadata requests from the screen carry an auth token.
    if GetInterface(screen.Screen, "ifHttpAgent") <> invalid AND screen.Item <> invalid AND screen.Item.server <> invalid AND screen.Item.server.AccessToken <> invalid then
        screen.Screen.SetCertificatesDepth(5)
        screen.Screen.SetCertificatesFile("common:/certs/ca-bundle.crt")
        AddAccountHeaders(screen.Screen, screen.Item.server.AccessToken)
    end if

    ' ljunkie - current time -- removed from this - ONLY on home screen for now.

    if screen.NumBreadcrumbs <> 0 then
        count = m.breadcrumbs.Count()
        if count >= 2 then
            enableBreadcrumbs = true
            bread1 = m.breadcrumbs[count-2]
            bread2 = m.breadcrumbs[count-1]
        else if count = 1 then
            enableBreadcrumbs = true
            bread1 = ""
            bread2 = m.breadcrumbs[0]
        else
            enableBreadcrumbs = false
        end if
    else
        enableBreadcrumbs = false
    end if

    screenType = type(screen.Screen)
    ' Sigh, different screen types don't support breadcrumbs with the same functions

    if screenType = "roGridScreen" OR screenType = "roPosterScreen" OR screenType = "roSpringboardScreen" then
        if enableBreadcrumbs then
            screen.Screen.SetBreadcrumbEnabled(true)
            screen.Screen.SetBreadcrumbText(bread1, bread2)
        else
            screen.Screen.SetBreadcrumbEnabled(false)
        end if
    else if screenType = "roSearchScreen" then
        if enableBreadcrumbs then
            screen.Screen.SetBreadcrumbText(bread1, bread2)
        end if
    else if screenType = "roListScreen" OR screenType = "roKeyboardScreen" OR screenType = "roParagraphScreen" then
        if enableBreadcrumbs then
            screen.Screen.SetTitle(bread2)
        end if
    else
        Debug("Not sure what to do with breadcrumbs on screen type: " + tostr(screenType))
    end if
End Sub

Sub vcInitThemes()
    m.ThemeStack = CreateObject("roList")
    m.ThemeApplyParams = CreateObject("roAssociativeArray")
    m.ThemeRevertParams = CreateObject("roAssociativeArray")
End Sub

Sub vcPushTheme(name)
    if NOT m.ThemeApplyParams.DoesExist(name) then return

    if name <> m.ThemeStack.GetTail() then
        m.ApplyThemeAttrs(m.ThemeApplyParams[name])
    end if

    m.ThemeStack.AddTail(name)
End Sub

Sub vcPopTheme()
    name = m.ThemeStack.RemoveTail()

    if name <> m.ThemeStack.GetTail() then
        m.ApplyThemeAttrs(m.ThemeRevertParams[name])
        m.ApplyThemeAttrs(m.ThemeApplyParams[m.ThemeStack.GetTail()])
    end if
End Sub

Sub vcApplyThemeAttrs(attrs)
    app = CreateObject("roAppManager")
    for each attr in attrs
        if attrs[attr] <> invalid then
            app.SetThemeAttribute(attr, attrs[attr])
        else
            app.ClearThemeAttribute(attr)
        end if
    next
End Sub

Sub vcDestroyGlitchyScreens()
    ' The audio player / grid screen glitch only affects older firmware versions.
    versionArr = GetGlobal("rokuVersionArr", [0])
    if versionArr[0] >= 4 then return

    for each screen in m.screens
        if screen.DestroyAndRecreate <> invalid then
            Debug("Destroying screen " + tostr(screen.ScreenID) + " to work around glitch")
            screen.DestroyAndRecreate()
        end if
    next
End Sub

Function vcStartRequest(request, listener, context, body=invalid) As Boolean
    request.SetPort(m.GlobalMessagePort)
    context.Listener = listener
    context.Request = request

    if body = invalid then
        started = request.AsyncGetToString()
    else
        started = request.AsyncPostFromString(body)
    end if

    if started then
        id = request.GetIdentity().tostr()
        m.PendingRequests[id] = context
        screenID = listener.ScreenID.tostr()
        if NOT m.RequestsByScreen.DoesExist(screenID) then
            m.RequestsByScreen[screenID] = []
        end if
        ' Screen ID's less than 0 are fake screens that won't be popped until
        ' the app is cleaned up, so no need to waste the bytes tracking them
        ' here.
        if listener.ScreenID >= 0 then m.RequestsByScreen[screenID].Push(id)
        return true
    else
        return false
    end if
End Function

Sub vcCancelRequests(screenID)
    requests = m.RequestsByScreen[screenID.tostr()]
    if requests <> invalid then
        for each requestID in requests
            request = m.PendingRequests[requestID]
            if request <> invalid then request.Request.AsyncCancel()
            m.PendingRequests.Delete(requestID)
        next
        m.RequestsByScreen.Delete(screenID.tostr())
    end if
End Sub

Sub vcAddSocketListener(socket, listener)
    m.SocketListeners[socket.GetID().tostr()] = listener
End Sub

Sub vcAddTimer(timer, listener)
    timer.ID = m.nextTimerId.tostr()
    m.nextTimerId = m.NextTimerId + 1
    timer.Listener = listener
    m.Timers[timer.ID] = timer

    screenID = listener.ScreenID.tostr()
    if NOT m.TimersByScreen.DoesExist(screenID) then
        m.TimersByScreen[screenID] = []
    end if
    m.TimersByScreen[screenID].Push(timer.ID)
End Sub

Sub InitWebServer(vc)
    ' Initialize some globals for the web server
    globals = CreateObject("roAssociativeArray")
    globals.pkgname = "Plex/Roku"
    globals.maxRequestLength = 4000
    globals.idletime = 60
    globals.wwwroot = "tmp:/"
    globals.index_name = "index.html"
    globals.serverName = "Plex/Roku"
    AddGlobals(globals)
    MimeType()
    HttpTitle()
    ClassReply().AddHandler("/logs", ProcessLogsRequest)
    ClassReply().AddHandler("/application/PlayMedia", ProcessPlayMediaRequest)
    ClassReply().AddHandler("/application/Stop", ProcessStopMediaRequest)

    vc.WebServer = InitServer({msgPort: vc.GlobalMessagePort, port: 8324})
End Sub

Sub createScreenForItemCallback()
    GetViewController().CreateScreenForItem(m.Item, invalid, [firstOf(m.Heading, "")])
End Sub
