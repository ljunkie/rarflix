'*
'* A controller for managing the stack of screens that have been displayed.
'* By centralizing this we can better support things like destroying and
'* recreating views and breadcrumbs. It also provides a single place that
'* can take an item and figure out which type of screen should be shown
'* so that logic doesn't have to be in each individual screen type.
'*
'Some screens are hardcoded to a specific ScreenID
'-1 : Home screen
'-2 : Analytics screen (In order to use the view controller for requests.)
'-3 : Plex Media Server screen (For using the view controller for HTTP requests)

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
    controller.CreateICphotoPlayer = vcCreateICphotoPlayer
    controller.CreateVideoPlayer = vcCreateVideoPlayer
    controller.CreatePlayerForItem = vcCreatePlayerForItem
    controller.IsVideoPlaying = vcIsVideoPlaying
    controller.IsSlideShowPlaying = vcIsSlideShowPlaying

    controller.ShowFirstRun = vcShowFirstRun
    controller.ShowReleaseNotes = vcShowReleaseNotes
    controller.ShowHelpScreen = vcShowHelpScreen
    controller.ShowLimitedWelcome = vcShowLimitedWelcome
    controller.ShowPlaybackNotAllowed = vcShowPlaybackNotAllowed

    controller.InitializeOtherScreen = vcInitializeOtherScreen
    controller.AssignScreenID = vcAssignScreenID
    controller.PushScreen = vcPushScreen
    controller.PopScreen = vcPopScreen
    controller.ExitToUserSelection = vcExitToUserSelection
    controller.IsActiveScreen = vcIsActiveScreen

    controller.afterCloseCallback = invalid
    controller.CloseScreenWithCallback = vcCloseScreenWithCallback
    controller.CloseScreen = vcCloseScreen

    controller.Show = vcShow
    controller.Control= vcControl
    controller.OnInitialized = vcOnInitialized
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
    controller.StartRequestIgnoringResponse = vcStartRequestIgnoringResponse
    controller.CancelRequests = vcCancelRequests

    controller.SocketListeners = {}
    controller.AddSocketListener = vcAddSocketListener

    controller.Timers = {}
    controller.TimersByScreen = {}
    controller.AddTimer = vcAddTimer

    controller.SystemLog = CreateObject("roSystemLog")
    controller.SystemLog.SetMessagePort(controller.GlobalMessagePort)
    controller.SystemLog.EnableType("bandwidth.minute")

    controller.backButtonTimer = createTimer()
    controller.backButtonTimer.SetDuration(60000, true)
    
    controller.CreateUserSelectionScreen = vcCreateUserSelectionScreen
    controller.ResetIdleTimer = vcResetIdleTimer
    controller.ResetGenIdleTimer = vcResetGenIdleTimer
    controller.CreateLockScreen = vcCreateLockScreen
    controller.CreateIdleTimer = vcCreateIdleTimer

    ' Figure if we need to show the securityscreen
    'First check if there are multiple users
    controller.RFisMultiUser = false        'true if multi-user is enabled
    controller.ShowSecurityScreen = false   'true to show user selection screen
    controller.SkipUserSelection = false    'true to skip user selection screen and show PIN screen (use case: single user with PIN)
    controller.IsLocked = false             'true when lock screen is up todo:Add method to lock without logging out
    for i = 1 to 7 step 1   'Check for other users enabled
        if RegRead("userActive", "preferences", "0",i) = "1" then 
            controller.ShowSecurityScreen = true
            controller.RFisMultiUser = true
            exit for
        end if
    end for
    ' Finally, check if the default user has a pin 
    if controller.ShowSecurityScreen = false then
        controller.SkipUserSelection = true
        if RegRead("securityPincode","preferences",invalid) <> invalid then 
            controller.ShowSecurityScreen = true
        end if
    end if
    controller.timerIdleTime = invalid  'timer used for detecting idle time

    ' Stuff the controller into the global object
    m.ViewController = controller

    ' Initialize things that run in the background
    AppManager().AddInitializer("viewcontroller")
    InitWebServer(controller)
    AudioPlayer()
    AnalyticsTracker()
    MyPlexManager()
    GDMAdvertiser()

    ' ljunkie Youtube Trailers (extended to TMDB)
    controller.youtube = vcInitYouTube()
    return controller
End Function

Function GetViewController()
    return m.ViewController
End Function

Function vcCreateHomeScreen()
    screen = createHomeScreen(m)
    screen.ScreenName = "Home"
    m.InitializeOtherScreen(screen, invalid)
    RRHomeScreenBreadcrumbs(true)
    screen.createNowPlayingRequest()
    screen.Show()
    'start timer for detecting idle time when the home screen is created.
    m.CreateIdleTimer()
    return screen
End Function


Function vcCreateUserSelectionScreen() 
    screen = createUserSelectionScreen(m)
    screen.ScreenName = "User Profile Selection"
    m.InitializeOtherScreen(screen, invalid)
    screen.Show()
    return screen
End Function

'Assumes that multi-user is enabled
'Lock screen stays on top of everything
' -- new addition: we must close any open dialogs 
Function vcCreateLockScreen() 
    TraceFunction("vcCreateLockScreen")
    currentScreen = m.screens.peek()    'current screen to stack on top of
    
    if currentScreen <> invalid then 
        ' ljunkie - Message Dialog and Video Screen ( playing video ) need to be closed
        '  if not, they will allow backdoor access into channel after lockscreen
        if type(currentScreen.Screen) = "roMessageDialog" or type(currentScreen.Screen) = "roVideoScreen" then 
            Debug("---- Top screen is a " + type(currentScreen.Screen) + " -- need to close before we lock")
            ' close the screen -- vcPopScreen takes care of any other dialogs
            m.popscreen(currentScreen)
            currentScreen = m.screens.Peek()
        end if
    end if

    'this PIN screen will stay up until either the PIN is entered or Back is pressed
    pinScreen = VerifySecurityPin(m, RegRead("securityPincode","preferences",invalid,GetGlobalAA().userNum), true, 0)
    pinScreen.ScreenName = "Locked"
    if GetGlobalAA().userNum = 0 then
        fn = firstof(RegRead("friendlyName", "preferences", invalid, GetGlobalAA().userNum),"Default User")
    else
        fn = firstof(RegRead("friendlyName", "preferences", invalid, GetGlobalAA().userNum),"User Profile " + tostr(GetGlobalAA().userNum))
    end if 
    m.InitializeOtherScreen(pinScreen, [fn])
    currentScreen.OldActivate = invalid 'store previous Activate for whatever the current screen is 
    if currentScreen.Activate <> invalid then currentScreen.OldActivate = currentScreen.Activate          
    currentScreen.Activate = lockScreenActivate     'new Activate routine
    m.IsLocked = true   'global when we're locked
    pinScreen.txtBottom = "RARflix is locked due to inactivity.  Enter PIN Code using direction arrows on your remote control.  Press OK to retry PIN or Back to pick another User."   
    ' create a facade screen below the lock screen -- this will hide closing of screens if one doesn't enter the correct pin ( back button )
    pinScreen.facade = CreateObject("roGridScreen")
    pinScreen.facade.Show()
    ' show the pinScreen now
    pinScreen.Show()
    return pinScreen
End Function

'Called when lock screen has shutdown.  Either the PIN is entered or Back is pressed
sub lockScreenActivate(priorScreen)
    TraceFunction("lockScreenActivate")  

    if (priorScreen.pinOK = invalid) or (priorScreen.pinOK <> true) then    
        'No code was entered.  We need to logout and return to the main user selection screen
        'restore old Activate before calling this
        'm.Activate = m.OldActivate 
        'm.ViewController.PopScreen(invalid)    'invalid will close all screens
        m.ViewController.ExitToUserSelection()
        if m.screen <> invalid then m.screen.close() ' stragler
        if priorScreen.facade <> invalid then priorScreen.facade.close()
    else
        'pin is OK,
        if priorScreen.facade <> invalid then priorScreen.facade.close()
        Debug("Valid PIN entered.  Unlocked.")
        m.ViewController.IsLocked = false   'notify that we're unlocked
        'restart idle timer     
        m.ViewController.CreateIdleTimer()
        'Do any prior screen activations that need to happen.
        m.Activate = m.OldActivate 
        m.OldActivate = invalid
        if m.Activate <> invalid then
            Debug("Calling old Activate")
            m.Activate(priorScreen)
        end if
    endif
End sub


Function vcCreateScreenForItem(context, contextIndex, breadcrumbs, show=true) As Dynamic
    if type(context) = "roArray" then
        item = context[contextIndex]
    else
        item = context
    end if

    ' ljunkie - sorry for the madness ( breadcrumbs dynamic magic ) TODO - research a less hacky way
    ' breadcrumbs for Full Grid.. when we have "1-4 of 565" as a row name --- that is ugly and this is ghetto 
    re = CreateObject("roRegex", "\d+\s*-\s*\d+\s+of\s+\d+", "")
    if type(breadcrumbs) = "roArray" and breadcrumbs.count() > 1 and (re.Ismatch(breadcrumbs[0]) or re.IsMatch(breadcrumbs[1])) then 
        if type(m.screens) = "roArray" and m.screens.count() > 1 and m.screens[1].loader <> invalid and m.screens[1].loader.contentarray <> invalid then  ' nested because I'm lame
            keynames = m.screens[1].loader.contentarray
            if item.contenttype = "appClip" then
                breadcrumbs[0] = ""
            else 
                breadcrumbs[1] = UcaseFirst(firstof(item.umtitle,item.contenttype,item.type,item.viewgroup))
            end if
    
            re = CreateObject("roRegex", "/library/sections/\d+/([^?\/]+)", "")
            reMeta = CreateObject("roRegex", "/library/metadata/\d+/([^?\/]+)", "")

            if (reMeta.isMatch(item.sourceurl)) then
                    breadcrumbs[0] = tostr(item.title)
            else if (re.isMatch(item.sourceurl)) then
                
                
                fkey = re.Match(item.sourceurl)[1]
                key = re.Match(item.sourceurl)[1]
                for each k in keynames
                    if k.key = fkey then
                        fkey = k.name
                        exit for
                    end if
                end for
                if fromFullGrid() then
                     ' special for music - mayb more later
                     if tostr(key) = "albums" and item.album <> invalid then 
                         breadcrumbs[0] = UcaseFirst(item.artist)                     
                         breadcrumbs[1] = UcaseFirst(item.album)                     
                     else 
                         ' else use the Section Name (fkey) and title, etc
                         breadcrumbs[0] = UcaseFirst(fkey)    
                         breadcrumbs[1] = UcaseFirst(firstof(item.umtitle,item.contenttype,item.type,item.viewgroup))
                     end if
                else 
                    breadcrumbs[0] = UcaseFirst(fkey)
                end if
            end if
        end if
    end if
    ' end this madness

    ' madness still continues for other areas ( now PHOTOS )
    if (item.type = "photo") then
         r1=CreateObject("roRegex", "Dir: ", "")
         if type(breadcrumbs) = "roArray" and breadcrumbs.count() > 1 then
            breadcrumbs[0] = r1.ReplaceAll(breadcrumbs[0], ""):breadcrumbs[1] = r1.ReplaceAll(breadcrumbs[1], "")
            if ucase(breadcrumbs[0]) = ucase(breadcrumbs[1]) and item.description <> invalid and tostr(item.nodename) = "Directory" then 
                breadcrumbs[0] = right(item.description,38)
                if len(item.description) > 38 then breadcrumbs[0] = "..." + breadcrumbs[0]
                breadcrumbs[1] = ""
            end if
         end if
    end if

    ' madness still continues for other areas ( now TV )
    ' ljunkie - reset breadcrumb for TV show if tv watched status enabled and title <> umtitle (post and grid view supported)
    if breadcrumbs <> invalid and RegRead("rf_tvwatch", "preferences", "enabled") = "enabled" and (item.type = "show" or item.viewgroup = "season" or item.viewgroup = "show" or item.viewgroup = "episode") then
        if item.umtitle <> invalid and ( type(breadcrumbs) = "roArray" and breadcrumbs[0] <> invalid and breadcrumbs[0] = item.title) or (breadcrumbs = invalid) then 
	    Debug("tv watched status enabled: setting breadcrumb back to original title; change from " + breadcrumbs[0] + " -to- " + item.umtitle)
            breadcrumbs[0] = item.umtitle
        else if item.parentindex <> invalid and item.viewgroup = "episode" then 
	    Debug("tv watched status enabled: setting breadcrumb back to original title (tv gridview?); change from " + breadcrumbs[0] + " -to- " + item.umtitle)
            breadcrumbs[0] = "Season " + tostr(item.parentindex)
            breadcrumbs[1] = ""
	else 
            Debug("tv watched status enabled: DID not match criteria(1) -- NOT setting breadcrumb back to original title")
        end if
    end if

    ' madness still continues for other areas ( remove redundant breadcrumbs )
    if type(breadcrumbs) = "roArray" and breadcrumbs.count() > 1 then
        lastbc = breadcrumbs[0]
        for index = 1 to breadcrumbs.count() - 1
            if ucase(breadcrumbs[index]) = ucase(lastbc) then
                lastbc = breadcrumbs[index]
                breadcrumbs.Delete(index)
            else 
                lastbc = breadcrumbs[index]
            end if
        end for
        ''this would force us to show only 1 bread crumb. instead we will use the previous
        'if breadcrumbs.count() = 1 then 
        'breadcrumbs.Push("")
        'end if
    end if
    ' ljunkie - ok, madness complete
 
    contentType = item.ContentType
    viewGroup = item.viewGroup
    if viewGroup = invalid then viewGroup = "Invalid"

    screen = CreateObject("roAssociativeArray")

    ' NOTE: We don't support switching between them as a preference, but
    ' the poster screen can be used anywhere the grid is used below. By
    ' default the poster screen will try to decide whether or not to
    ' include the filter bar that makes it more grid like, but it can
    ' be forced by setting screen.FilterMode = true.

    screenName = invalid
    poster_grid = RegRead("rf_poster_grid", "preferences", "grid")
    displaymode_poster = RegRead("rf_poster_displaymode", "preferences", "scale-to-fit")
    displaymode_grid = RegRead("rf_grid_displaymode", "preferences", "photo-fit")
    grid_style_photos = RegRead("rf_photos_grid_style", "preferences","flat-landscape")
    grid_style = RegRead("rf_grid_style", "preferences","flat-portrait")

    if contentType = "episode" OR contentType = "clip" then
        screen = createVideoSpringboardScreen(context, contextIndex, m)
        screenName = "Preplay " + contentType
    else if contentType = "movie" then 
        screen = createVideoSpringboardScreen(context, contextIndex, m)
        screenName = "Preplay " + contentType
    else if contentType = "series" then
        ' channel content does not play well in Grid ( unexpected xml result could put the channel content in a grid )
        useGrid = false
        if RegRead("use_grid_for_series", "preferences", "") <> "" then
            sec_metadata = getSectionType()
            if tostr(sec_metadata.contenttype) <> "channel" and tostr(sec_metadata.type) <> "channel" then useGrid = true
        end if

        if useGrid then
            screen = createGridScreenForItem(item, m, "flat-16x9") ' we want 16x9 for series ( maybe flat-landscape when available )
            screenName = "Series Grid"
            if screen.loader.focusrow <> invalid then screen.loader.focusrow = 1 ' override this so we can hide the sub sections ( flat-16x9 is 5x3 )
        else
            screen = createPosterScreen(item, m, "arced-portrait")
            screenName = "Series Poster"
            if fromFullGrid() and (item.umtitle <> invalid or item.title <> invalid) then 
                breadcrumbs[0] = "All Seasons"
                breadcrumbs[1] = firstof(item.umtitle,item.title)
            end if
        end if
    else if contentType = "artist" then
        if poster_grid = "grid" then 
            screen = createFULLGridScreen(item, m, "flat-landscape", displaymode_grid)
        else 
            screen = createPosterScreen(item, m, "arced-square")
            screen.noRefresh = true ' no need to refresh these items (yet)
        end if
        screenName = "Artist Poster"
    else if contentType = "album" then
        ' grid looks horrible in this view. - do not enable FULL grid
        screen = createPosterScreen(item, m, "flat-episodic")
        screen.noRefresh = true ' no need to refresh these items (yet)
        screen.SetListStyle("flat-episodic", "zoom-to-fill")
        screenName = "Album Poster"
    else if item.key = "nowplaying" then
        if AudioPlayer().ContextScreenID = m.screens.Peek().ScreenID then
            screen = invalid
        else
            AudioPlayer().ContextScreenID = m.nextScreenId
            screen = createAudioSpringboardScreen(AudioPlayer().Context, AudioPlayer().PlayIndex, m)
            screenName = "Now Playing"
            breadcrumbs = [screenName," "," "] ' set breadcrumbs for this..
        end if
        if screen = invalid then return invalid
    else if contentType = "audio" then
        Debug("vcCreateScreenForItem:: createAudioSpringboardScreen")
        screen = createAudioSpringboardScreen(context, contextIndex, m)
        if screen = invalid then return invalid
        screenName = "Audio Springboard"
    else if contentType = "section" then
        ' ljunkie - this has been modified quite a bit. Sections have always been a "grid". Users now have an option to use a Full Grid by default
        screenName = "Section: " + tostr(item.type)

        ' check if section has the full grid enabled
        if item.callbackFullGrid = true then 
            ' - special case "item.callbackFullGrid" used when one views the filter items from a nonfull grid
            useFullGrid = true
            item.callbackFullGrid = invalid
        else if item.ishomevideos = true then 
            useFullGrid = (RegRead("rf_full_grid_homevideo", "preferences", "disabled") = "enabled")
        else     
            useFullGrid = (RegRead("rf_full_grid_"+tostr(item.type), "preferences", "disabled") = "enabled")
        end if
        Debug("Full Grid Enabled:"+tostr(useFullGrid) + " : " + tostr(item.type) + ": " + tostr(item.contenttype))

        focusrow = invalid
        if tostr(item.type) = "artist" then 
            grid_style = "flat-landscape"
            displaymode_grid = "photo-fit"
            focusrow = 2
            Debug("---- override " + tostr(displaymode_grid) + "/" + tostr(grid_style) + " for section with content of " + tostr(item.type))
        else if tostr(item.type) = "photo" then 
            ' Photo Section has it's own settings for DisplayMode and GridStyle
            displaymode_grid = RegRead("photoicon_displaymode", "preferences", "photo-fit")
            grid_style = grid_style_photos
            focusrow = 2
            Debug("---- override " + tostr(displaymode_grid) + "/" + tostr(grid_style) + " for section with content of " + tostr(item.type))
        else 
            if item.isHomeVideos = true then grid_style = "flat-16x9"
        end if

        ' focus on the second row if flat16x9 
        ' TODO(ljunkie) add other modes in here to make this logic more sound
        if grid_style = "flat-16x9" then focusrow = 2

        item.defaultFullGrid = useFullGrid
        if NOT item.defaultFullGrid then 
            ' standard Grid screen - multiple rows

            ' reset to original keys -- this will only happen if somone has changed FullGrid prefs during 
            ' the section. We could just reload the HomeScreenRows when toggled - but this doesn't seem bad
            if item.OrigKeys <> invalid then 
                item.key = item.OrigKeys.key
                item.sourceurl = item.OrigKeys.sourceUrl
                item.origkeys= invalid
            end if
            
            print item
            screen = createGridScreenForItem(item, m, grid_style, displaymode_grid)
            if focusrow <> invalid and screen.loader.focusrow <> invalid then screen.loader.focusrow = focusrow
        else 
            ' full grid screen - hoping mGo will become available at some point
            Debug("---- using FULL GRID by default for this section type")
           
            ' show the user a notice about using a full grid (only once)
            noticeRead = (RegRead("default_full_grid_notice", "notices", "0") <> "0")
            if NOT noticeRead then 
                RegWrite("default_full_grid_notice", "1", "notices")
                dlg = createBaseDialog()
                dlg.Title = "Full Grid Information"
                dlg.Text = "You are entering All " + item.title + ". In this section, you can click up to see a hidden row to filter the items or choose a quick filter. The info key (*) on the remote may also be used to change the sorting or items."
                dlg.Show(true)
            end if

            ' shallowCopy the item for the origina key and sourceurl
            if item.origkeys = invalid then item.origkeys = ShallowCopy(item,1)

            ' reset the section to use the /all endpoint 
            ' - make sure we have the base section key ( strip any junk/subsections )
            sectionKey = getBaseSectionKey(item.sourceurl + "/" + item.key)
            item.sourceurl = item.server.serverurl + sectionKey
            item.key = "all"

            screen = createFULLGridScreen(item, m, grid_style, displaymode_grid)
            if focusrow <> invalid and screen.loader.focusrow <> invalid then 
                screen.loader.focusrow = focusrow
            else 
                screen.loader.focusrow = 1
            end if
        end if
    else if contentType = "playlists" then
        screen = createGridScreenForItem(item, m, "flat-16x9") ' not really sure where this is ( maybe the myPlex queue )
        screenName = "Playlist Grid"
        if screen.loader.focusrow <> invalid then screen.loader.focusrow = 2 ' hide header row ( flat-16x9 is 5x3 )
    else if contentType = "photo" then
        if right(item.key, 8) = "children" then
            if poster_grid = "grid" then 
                displayMode = RegRead("photoicon_displaymode", "preferences", "photo-fit")
                Debug("---- override FULL Grid" + tostr(displayMode) + "/" + tostr(grid_style_photos) + "for section with content of " + tostr(item.type))
                screen = createFULLGridScreen(item, m, grid_style_photos, displayMode) ' we override photos to use photo fit -- toggle added later TODO
                screen.loader.focusrow = 1 ' lets fill the screen ( 5x3 ) - no header row ( might be annoying page up for first section.. TODO)
            else 
                screen = createPosterScreen(item, m, "arced-landscape")
                screen.noRefresh = true ' no need to refresh these items (yet)
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
        screen = createGridScreenForItem(item, m, "flat-square","photo-fit")
        screenName = "Channel Directory"
        screen.loader.focusrow = 1 ' lets fill the screen ( 5x3 )
    else if viewGroup = "Store:Info" then
        dialog = createPopupMenu(item)
        dialog.Show()
        return invalid
    else if item.key = "_section_filters_" then
        screen = createFilterSortListScreen(item,m.screens.peek(),item.typeKey)
        breadcrumbs =  ["Filters: " + item.title]
        screenName = "Grid Filters"
    else if viewGroup = "secondary" then
        ' these are subsections of a main section ( secondary )
        Debug("---- Creating secondary " + poster_grid + " view for contentType=" + tostr(contentType) + ", viewGroup=" + tostr(viewGroup))

        sec_metadata = getSectionType()
        if poster_grid = "grid" then 
            DisplayMode = displaymode_grid

            focusrow = 0
            if tostr(sec_metadata.type) = "artist" then 
                grid_style="flat-landscape" ' TODO - create toggle for music grid style
            else if tostr(sec_metadata.type) = "photo" then 
                grid_style=grid_style_photos ' Use GRID style for photos
                displayMode = RegRead("photoicon_displaymode", "preferences", "photo-fit") ' Use Display Mode for Photos
                Debug("---- override " + tostr(displayMode) + "/" + tostr(grid_style_photos) + "for section with content of " + tostr(item.type))
                focusrow = 1 ' lets fill the screen ( 5x3 )
            else if sec_metadata.isHomeVideos = true then 
                grid_style = "flat-16x9"
            end if

            screen = createFULLGridScreen(item, m, grid_style, DisplayMode)
    	    screen.loader.focusrow = focusrow ' lets fill the screen ( 5x3 )
        else 
            posterStyle = "arced-portrait"
            if tostr(sec_metadata.type) = "photo" then posterStyle = "arced-landscape"
            screen = createPosterScreen(item, m, posterStyle)
        end if
    else if item.key = "globalprefs" then
        screen = createPreferencesScreen(m)
        screenName = "Preferences Main"
    else if item.key = "movietrailer" then
        hasWaitDialog = ShowPleaseWait("Please wait","Searching TMDB & YouTube for " + Quote()+tostr(item.SearchTitle)+Quote())
        yt_videos = m.youtube.SearchTrailer(item.searchTitle, item.year)
        playTrailer = false
        if yt_videos.Count() > 0 then
            metadata=GetVideoMetaData(yt_videos)
            screen = createPosterScreenExt(metadata, m, "arced-16x9","scale-to-fill")
            screen.hasWaitDialog = hasWaitDialog
            screen.handlemessage = trailerHandleMessage
            screenName = "Movie Trailer"
            if RegRead("rf_trailerplayfirst", "preferences", "enabled") = "enabled" then DisplayYouTubeVideo(metadata[0],screen.hasWaitDialog)
'            playTrailer = true
        else
            ShowErrorDialog("No videos match your search","Search results")
            hasWaitDialog.close()
            return invalid
        end if
    else if item.key = "switchuser" then
        GetViewController().ExitToUserSelection()
        return invalid
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
        screen = createGridScreen(m, grid_style, RegRead("rf_up_behavior", "preferences", "exit"), displaymode_grid)
        screen.Loader = createSearchLoader(item.searchTerm)
        screen.Loader.Listener = screen
        screenName = "Search Results"
    else if item.settings = "1"
        screen = createSettingsScreen(item, m)
        screenName = "Settings"
    else if tostr(item.type) = "season" then
        ' no full grid
        screen = createPosterScreen(item, m, "arced-portrait")
    else if tostr(item.type) = "channel" then 
        ' no full grid
        screen = createPosterScreen(item, m, "arced-square")
        screen.noRefresh = true ' no need to refresh these items (yet)
    else
        Debug("---- Creating a default " + poster_grid + " view for contentType=" + tostr(contentType) + ", viewGroup=" + tostr(viewGroup) + ", type=" + tostr(item.type))
        ' Where do we capture channel directory?
        ' ljunkie - this doesn't seem to always be channel items ( special checks are needed now )

        ' We need to know if we are in channel content. The Full Grid does not work with channels. 
        ' Some channels do not return valid ( expected xml ) on every query ( ICEfilms - captcha result)
        '  so we will need to query the homescreen to see if we are in a channel section
        forcePoster = false
        noRefresh = false
        sec_metadata = getSectionType()
        if tostr(sec_metadata.contenttype) = "channel" or tostr(sec_metadata.type) = "channel" then 
            forcePoster = true
            noRefresh = true
        else if tostr(contentType) = "appClip" and (tostr(viewGroup) = "Invalid" or tostr(viewGroup) = "InfoList" or tostr(viewGroup) = "List") then 
            forcePoster = true
            noRefresh = true
        end if

        if forcePoster then 
            Debug("---- forcing to Poster view -> viewgroup matches: invalid|InfoList|List or is Channel Content")
            screen = createPosterScreen(item, m, "arced-square")
            screen.noRefresh = noRefresh
        else if poster_grid = "grid" and tostr(viewGroup) <> "season" then
            ' allow the full grid if the content is not a channel or season
            screen = createFULLGridScreen(item, m, "Invalid", displaymode_grid)
        else 
            Debug("---- forcing to Poster view")
            screen = createPosterScreen(item, m, "arced-portrait")
        end if
    end if

    ' an invalid screen could happen if someone clicks on a "loading" item -- return invalid
    if screen = invalid then return invalid

    if screenName = invalid then
        screenName = type(screen.Screen) + " " + firstOf(contentType, "unknown")
    end if

    screen.ScreenName = screenName

    m.AddBreadcrumbs(screen, breadcrumbs)
    m.UpdateScreenProperties(screen)
    m.PushScreen(screen)

    if show then screen.Show()

    ' facades and wait dialogs
    if item <> invalid and item.facade <> invalid then item.facade.close()
    if screen.hasWaitdialog <> invalid then screen.hasWaitdialog.close()

    ' set the inital focus row if we have set it ( normally due to the sub section row being added - look at the createpaginateddataloader )
    if screen.loader <> invalid and screen.loader.focusrow <> invalid then 
        ' take into account that people might hide rows (focusrow is 0 index). If the focusrow is > 1
        ' on 3 row screens, we will want to focus on the second row (1) if we have less than 4 rows 
        style = GetGlobalAA().Lookup("GlobalGridStyle") ' this is set by Grid Creation
        is3Row = screen.loader.focusrow > 1 and style <> invalid and (style = "flat-landscape" or style = "flat-square" or style = "flat-16x9" or style = "four-column-flat-landscape")
        if is3Row and screen.loader.names <> invalid and screen.loader.names.count() < 4 then screen.loader.focusrow = 1
        screen.screen.SetFocusedListItem(screen.loader.focusrow,0)
    end if

    return screen
End Function

Function vcCreateTextInputScreen(heading, breadcrumbs, show=true, initialValue="", secure=false) As Dynamic
    screen = createKeyboardScreen(m, invalid, heading, initialValue, secure)
    screen.ScreenName = "Keyboard: " + tostr(heading)

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
    if AudioPlayer().ContextScreenID = invalid then return invalid

    ' if screen if locked do not show dialog ( we might want to allow this, but we'd need to disable the go to now playing screen )
    ' redundant check - we don't allow option key globally
    if m.IsLocked <> invalid and m.IsLocked then return invalid

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
    if AudioPlayer().ispaused or AudioPlayer().isplaying then 
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
    return AudioPlayer().ShowContextMenu()
End Function

Function vcCreatePhotoPlayer(context, contextIndex=invalid, show=true, shuffled=false)
    if NOT AppManager().IsPlaybackAllowed() then
        m.ShowPlaybackNotAllowed()
        return invalid
    end if

    screen = createPhotoPlayerScreen(context, contextIndex, m, shuffled)
    screen.ScreenName = "Photo Player"

    m.AddBreadcrumbs(screen, invalid)
    m.UpdateScreenProperties(screen)
    m.PushScreen(screen)

    if show then screen.Show()

    return screen
End Function


Function vcCreateICphotoPlayer(obj, contextIndex=invalid, show=true, shuffled=false, slideShow=false)
    ' verify we have all the conext loaded -- possible we create this from a normal row
    dialog = invalid
    if slideShow and obj.context.count() > 100 then 
        dialog=ShowPleaseWait("Starting Photo Player... Please wait...","")
    end if
    PhotoPlayerCheckLoaded(obj,contextIndex)        

    sourceReloadURL = invalid
    if type(obj) = "roArray" then 
         context = obj
    else 
         context = obj.context
         sourceReloadUrl = obj.sourceReloadURL
    end if 

    ' remote clients default to use the "play" button, so we can't always trust slidshow=true -- verify we have more than one item
    if ( ( type(context) = "roArray" and context.count() = 1 ) or (type(context) <> "roArray") ) then slideShow=false

    if NOT AppManager().IsPlaybackAllowed() then
        m.ShowPlaybackNotAllowed()
        return invalid
    end if

    screen = createICphotoPlayerScreen(context, contextIndex, m, shuffled, slideShow)
    screen.ScreenName = "Photo Player Image Canvas"
    screen.FullContext = obj.FullContext

    if sourceReloadUrl <> invalid then screen.sourceReloadUrl = sourceReloadUrl
    Debug("vcCreateICphotoPlayer:: source reload url = " + tostr(sourceReloadUrl))

    m.AddBreadcrumbs(screen, invalid)
    m.UpdateScreenProperties(screen)
    m.PushScreen(screen)

    ' activate the slideshow timer ( we might skip this is we press SHOW instead? )
    if slideShow then 
        Debug("activating slideshow timer")         
        screen.Timer.Active = true
        screen.Timer.Mark()
        screen.isPaused = false
    else 
        screen.isSlideShow = false
    end if

    ' do not wait for the image to download ( user should see a response we are playing the slideshow )
    if show then screen.Show()

    if dialog <> invalid then dialog.close()

    return screen
End Function

Function vcCreateVideoPlayer(metadata, seekValue=0, directPlayOptions=0, show=true, preplayScreen = invalid)
    if NOT AppManager().IsPlaybackAllowed() then
        m.ShowPlaybackNotAllowed()
        return invalid
    end if

    ' Stop any background audio first
    ' ljunkie - we will now stop audio/photos -- but keep the state in the background
    ' this will allow us to resume ( only possible through remote control )
    if GetViewController().IsSlideShowPlaying() and PhotoPlayer() <> invalid then 
        ' for now this only applies to slideshows
        ' we could extend resume audio to other screens.. TODO(ljunkie) another day
        PhotoPlayer().StopKeepState()
        AudioPlayer().StopKeepState() ' always exists
    else 
        AudioPlayer().stop()
    end if

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

            if dlg.Result = invalid or dlg.Result = "invalid" then 
                if preplayscreen <> invalid then 
                    preplayScreen.screen.close()
                    if preplayscreen.facade <> invalid then preplayscreen.facade.close()
                end if
                return invalid
            end if
            if dlg.Result = "resume" and metadata.viewOffset <> invalid then
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
    screen.preplayScreen = preplayScreen

    m.AddBreadcrumbs(screen, invalid)
    m.UpdateScreenProperties(screen)
    m.PushScreen(screen)

    if show then screen.Show()

    return screen
End Function

Function vcCreatePlayerForItem(context, contextIndex, seekValue=invalid, sourceReloadUrl = invalid)
    item = context[contextIndex]

    ' ljunkie - check if we are viewing a directory. We can direct play certain items ( play all sort of thing )
    ' currently works for photos/albums. Not sure how it woud work for others yet
    ' I.E. if video(movie/clip/episode) then we need to add more logic how to play the next item.. 
    'sec_metadata = getSectionType() -- todo later - we can play appClips if they are in the photosection, but other adverse effects happen
    if item.nodename <> invalid and item.nodename = "Directory" then
        if item.ContentType = "photo" then 
            Debug("vcCreatePlayerForItem:: trying to play photo from a directory")

            obj = {}:dummyItem = {}
            dummyItem.server = item.server
            dummyItem.sourceUrl = item.key
            dummyItem.showWait = true
            PhotoMetadataLazy(obj, dummyItem, true)
            if obj.context <> invalid and obj.context.count() > 0 then 
                for each item in obj.context
                    if item.nodename = "Photo" then 
                        Debug("vcCreatePlayerForItem:: CreateICPhotoPlayer with " + tostr(obj.context.count()) + " total items")
                        return m.CreateICPhotoPlayer(obj, 0, true, false, true)
                    end if
                end for
            end if
        else if item.ContentType = "album" then
            Debug("vcCreatePlayerForItem:: trying to play album from a directory")
            container = createPlexContainerForUrl(item.server, item.server.serverurl, item.key)
            context = container.getmetadata()
            AudioPlayer().Stop()
            return m.CreateScreenForItem(context, 0, invalid)
         end if
    else if item.ContentType = "photo" then '  and (item.nodename = invalid or item.nodename <> "Directory") then 
        Debug("vcCreatePlayerForItem:: creating photo player")
        obj = {}
        obj.context = context
        obj.sourceReloadUrl = sourceReloadUrl
        return m.CreateICphotoPlayer(obj, contextIndex, true, false, true)
    else if item.ContentType = "audio" then
        Debug("vcCreatePlayerForItem:: creating audio player")
        AudioPlayer().Stop()
        return m.CreateScreenForItem(context, contextIndex, invalid, true)
    else if item.ContentType = "movie" OR item.ContentType = "episode" OR item.ContentType = "clip" then
        Debug("vcCreatePlayerForItem:: creating player for ContentType: " + tostr(item.ContentType))
        ' create a preplay screen before we start to play - but only for the following (any of them):
        ' 1) continuous play/shuffle play is enabled
        ' 2) is episode and advanceToNextItem is enabled
        preplay = invalid
        continuousORshuffle = ( RegRead("continuous_play", "preferences") = "1" or RegRead("shuffle_play", "preferences") = "1" )
        episodeAdvance = ( item.ContentType = "episode" and RegRead("advanceToNextItem", "preferences", "enabled") = "enabled" ) 
        if episodeAdvance or continuousORshuffle then
            preplay = m.CreateScreenForItem(context, contextIndex, invalid, false)
            facade = CreateObject("roGridScreen")
            facade.Show()
            preplay.facade = facade
        end if

        directplay = RegRead("directplay", "preferences", "0").toint()
        return m.CreateVideoPlayer(item, seekValue, directplay, true, preplay)
    end if

    ' if we can't play - then create an screen item for the context
    Debug("Not sure how to play item of type " + tostr(item.ContentType) + " " + tostr(item.type) + " " + tostr(item.nodename))

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
End Function

Function vcIsVideoPlaying() As Boolean
    return type(m.screens.Peek().Screen) = "roVideoScreen"
End Function

Function vcIsSlideShowPlaying() As Boolean
    ' to be clear -- this returns true if on is in a PhotoPlayer (single photo/multi photo/paused/stopped/etc -- naming sucks, sorry )
    return (type(m.screens.Peek().Screen) = "roImageCanvas" and tostr(m.screens.Peek().imagecanvasname) = "slideshow")
End Function

Sub vcShowFirstRun()
    ' TODO(schuyler): Are these different?
    m.ShowHelpScreen()
End Sub

Sub vcShowReleaseNotes(options = invalid)
    if options <> invalid then 
        header = GetGlobal("appName") + " v" + GetGlobal("appVersionStr")
	where = "About"
    else 
        header = GetGlobal("appName") + " updated to v" + GetGlobal("appVersionStr")
	where = "Release Notes"
    end if
    paragraphs = []
    breadcrumbs = invalid

    textScreen = supportsTextScreen()

    spacer = chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)+chr(32)

    if NOT textScreen then 
            paragraphs.Push("Donate @ rarflix.com")
            paragraphs.Push(" * Plex Companion (remote/navigation control)")
            paragraphs.Push(" * Dynamic Watched Status Overlay")
            paragraphs.Push(spacer+"- check mark for watched items")
            paragraphs.Push(spacer+"- percentage for partially watched items")
            paragraphs.Push(" * Mark TV Shows as Watched/Unwatched (remote * key)")
            paragraphs.Push(spacer+"- Mark an Entire Season or Show")
            paragraphs.Push(" * bugfixes")
            paragraphs.Push("+ Profiles, Pin Codes, Trailers, and much more! http://www.rarflix.com")
    else 
        ' We have a scrollable text screen now - we can include all the updates - yay
        us = "_______________"
        paragraphs.Push("                 Donations accepted at http://www.rarflix.com")
        paragraphs.Push("  ")
        paragraphs.Push(us+"v3.1.36-DEV (2014-02-24)"+us)
        paragraphs.Push("  ")
        paragraphs.Push(" * If you are using this, then you know what has changed.")
        paragraphs.Push("   For more info, view the RARflix thread on the Forums.")
        paragraphs.Push("  ")

        paragraphs.Push("  ")
        paragraphs.Push(us+"v3.1.1 (2014-01-11)"+us)
        paragraphs.Push("  ")
        paragraphs.Push(" * focus on last used section when starting RARflix (regression)")
        paragraphs.Push(" * include the ROLE of the cast member to the Cast & Crew screen")
        paragraphs.Push(" * screen saver image updates (initial fix)")
        paragraphs.Push("     - images seem to only be saved on a springBoard (preplay screens)")
        paragraphs.Push("     - now we save whenever we focus on an image (gridscreen or postersreen)")
        paragraphs.Push(" * add a Description button to the Dialog Pop up to show the non truncated description")
        paragraphs.Push("  ")
        paragraphs.Push("  ")
        paragraphs.Push("    Here are the major changes since v3.0.0.")
        paragraphs.Push("  ")
        paragraphs.Push("     * Plex Companion support (remote/navigation control)")
        paragraphs.Push("      ")
        paragraphs.Push("     * Dynamic Watched Status Overlay")
        paragraphs.Push("         - check mark on watched items")
        paragraphs.Push("         - percentage on partially watched items")
        paragraphs.Push("      ")
        paragraphs.Push("     * Mark TV Shows as Watched/Unwatched (remote * key)")
        paragraphs.Push("         - Mark an Entire Season or Show and not just an episode")
        paragraphs.Push("      ")
        paragraphs.Push("     * bugfixes")
        paragraphs.Push("      ")

        'paragraphs.Push("Click down to see all changes since v3.0.0 or click BACK to start using " + GetGlobal("appName") + "!" )
        'paragraphs.Push("  ")
        'paragraphs.Push("  ")
        'paragraphs.Push("  ")
    end if

    if NOT textScreen then 
        screen = createParagraphScreen(header, paragraphs, m)
        screen.SetTitle = where
        breadcrumbs =  ["",where + " v"+GetGlobal("appVersionStr")]
    else 
        screen = createTextScreen(header + " - www.rarflix.com", invalid , paragraphs, m, true)
        screen.screen.AddButton(1, "Press OK or Back to Continue")
        breadcrumbs =  [where,"v"+GetGlobal("appVersionStr")]
    end if

    screen.screenName = "Release Notes"
    m.InitializeOtherScreen(screen, breadcrumbs)

    ' As a one time fix, if the user is just updating and previously specifically
    ' set the H.264 level preference to 4.0, update it to 4.1.

    '    if RegRead("level", "preferences", "41") = "40" then
    '        RegWrite("level", "41", "preferences")
    '    end if

    screen.Show()
End Sub

Sub vcShowHelpScreen(opt = invalid)
    header = "Welcome to Plex!"
    paragraphs = []
    if opt <> invalid and opt = 2 then
        ' GDM disabled, myPlex not connected and no manual servers?
        paragraphs.Push("There are no servers configured. Please enable one or more of the following:")
        paragraphs.Push(" * Connect your myPlex account: Prefs")
        paragraphs.Push(" * Enable Server Discovery: Prefs / Plex Media Servers")
        paragraphs.Push(" * Add a server manually: Prefs / Plex Media Servers")
    end if
    paragraphs.Push("With Plex you can easily stream your videos, music, photos and home movies to your Roku using your Plex Media Server.")
    paragraphs.Push("To download and install your free Plex Media Server on your computer, visit http://plexapp.com/getplex")
'    paragraphs.Push("Enjoy Plex free for 30 days, then unlock with a PlexPass subscription or a small one-time purchase.")

    screen = createParagraphScreen(header, paragraphs, m)
    m.InitializeOtherScreen(screen, invalid)

    screen.Show()
End Sub

Sub vcShowLimitedWelcome()
    header = "Your Plex trial has ended"
    paragraphs = []
    paragraphs.Push("Your Plex trial period has ended. You can continue to browse content in your library, but playback has been disabled.")
    addPurchaseButton = false

    if AppManager().IsAvailableForPurchase then
        paragraphs.Push("To continue using Plex, you can either buy the channel or connect a PlexPass-enabled myPlex account.")
        addPurchaseButton = true
    else
        paragraphs.Push("To continue using Plex, you must connect a PlexPass-enabled myPlex account.")
    end if

    screen = createParagraphScreen(header, paragraphs, m)
    m.InitializeOtherScreen(screen, invalid)

    if addPurchaseButton then
        screen.SetButton("purchase", "Purchase channel")
    end if

    screen.HandleButton = channelStatusHandleButton

    screen.SetButton("close", "Close")

    screen.Show()
End Sub

Sub vcShowPlaybackNotAllowed()
    ' TODO(schuyler): Are these different?
    m.ShowLimitedWelcome()
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
    AnalyticsTracker().TrackScreen(screenName)
    Debug("Pushing screen " + tostr(screen.ScreenID) + " onto view controller stack - " + screenName)
    m.screens.Push(screen)
End Sub

sub vcExitToUserSelection()
    Debug("vcExitToUserSelection called -- popping ALL screens, cleaning up")
    GetGlobalAA().AddReplace("ProfileExit", true)
    while m.screens.Count() > 0
        m.PopScreen(m.screens.Peek())
    end while
end sub

Sub vcPopScreen(screen)
    if screen = invalid then return

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
        closePrevious = screen.closeprevious
        m.screens.Pop()
        for i = 0 to screen.NumBreadcrumbs - 1
            m.breadcrumbs.Pop()
        next
        if closePrevious <> invalid then
           Debug("-------------- popping next screen too -- we called for this!")
           m.screens.Pop()
        end if
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
    if m.Home <> invalid AND screen.screenID = m.Home.ScreenID then
        Debug("Popping home screen")
        ' m.PopScreen(invalid) ' invalid will close all screens
        m.ExitToUserSelection()
    else if m.screens.Count() = 0 then
        if m.ShowSecurityScreen = true then
            m.CreateUserSelectionScreen()
        else
            m.Home = m.CreateHomeScreen()
        end if

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
            Debug("---- Top screen is a Dialog -- that can't happen! clearing it")
            m.popscreen(newScreen)
            newScreen = m.screens.Peek()
            'print newScreen
            'print type(newScreen.Screen)
        end if

        ' ljunkie - hack to allow hiding the row text on grid screens ( mainly for the Full Grid )
        ' sadly the counterText when changed on the fly affects all screen - but not the counter seperator
        ' another small bug ( or odd feature ) in the Roku firmware. So we will have to reset it for previous screens
        newScreen = m.screens.peek()
        if newScreen <> invalid and tostr(newScreen.screen) = "roGridScreen" then 
            if newScreen.isFullGrid <> invalid and newScreen.isFullGrid = true then 
                hideRowText(true)
            else 
                hideRowText(false)
            end if
        end if

        'ljunkie - another hack to set the current GridStyle ( only used if we refresh custom icons, for now )
        SetGlobalGridStyle(newScreen.gridstyle) 

        screenName = firstOf(newScreen.ScreenName, type(newScreen.Screen))
        Debug("Top of stack is once again: " + screenName)
        AnalyticsTracker().TrackScreen(screenName)
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

Sub vcCloseScreen(simulateRemote)
    ' Unless the visible screen is the home screen.
    if m.Home <> invalid AND NOT m.IsActiveScreen(m.Home) then
        ' Our one complication is the screensaver, which we can't know anything
        ' about. So if we're simulating the remote control and haven't been
        ' called in a while, send an ECP back. Otherwise, directly close our
        ' top screen.
        if m.backButtonTimer.IsExpired() then
            SendEcpCommand("Back")
        else
            m.screens.Peek().Screen.Close()
        end if
    end if
End Sub

Sub vcShow()
    AppManager().ClearInitializer("viewcontroller")

    m.Control()

    ' Clean up some references on the way out
    AnalyticsTracker().Cleanup()
    GDMAdvertiser().Cleanup()
    AudioPlayer().Cleanup()
    ' ljunkie - TODO - change to singleton
    '  will be required for channel exit confirmation
    'restoreAudio = m.AudioPlayer ' save for later (maybe)
    'AudioPlayer().Stop()         ' stop any audio for now. This might change with exit confirmation

    m.Home = invalid
    m.WebServer = invalid
    m.Timers.Clear()
    m.PendingRequests.Clear()
    m.SocketListeners.Clear()

    ' on exit clear any initializers -- required for multiProfiles
    Appmanager().Initializers = {}
    GetGlobalAA().Delete("ProfileExit")


     'Exit Confirmation TODO - for not we will show the user selection screen if enabled
    if m.RFisMultiUser then 
        Debug("Exit channel - show user selection")
        m = invalid
        ' ljunkie - extra cleanup for the user switching    
        GetGlobalAA().clear()
        'GetGlobalAA().AddReplace("restoreAudio", restoreAudio)
        Main(invalid)   'TODO: This needs to be changed as it's recursive and starts building up the stack.
        return
    else
        Debug("Finished global message loop")
    end if

    return
End Sub

Sub vcOnInitialized()
    ' As good a place as any, note that we've started
    AnalyticsTracker().OnStartup(MyPlexManager().IsSignedIn)

    if m.screens.Count() = 0 then
        if RegRead("last_run_version", "misc") = invalid then
            m.ShowFirstRun()
            RegWrite("last_run_version", GetGlobal("appVersionStr"), "misc")
        else if RegRead("last_run_version", "misc", "") <> GetGlobal("appVersionStr") then
            m.ShowReleaseNotes()
            RegWrite("last_run_version", GetGlobal("appVersionStr"), "misc")
        else if AppManager().State = "Limited" then
            m.ShowLimitedWelcome()
        else if m.ShowSecurityScreen = true then
            m.CreateUserSelectionScreen()
        else
            m.Home = m.CreateHomeScreen()
        end if
    end if
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

    if m.breadcrumbs = invalid then m.breadrumbs = "roArray"
    if (breadcrumbs.Count() = 0 AND m.breadcrumbs.Count() > 0) or (m.screens.peek() <> invalid and m.screens.peek().isfullgrid <> invalid and breadcrumbs.Count() < 2 AND m.breadcrumbs.Count() > 0) then
        count = m.breadcrumbs.Count()
        if count >= 2 then
            breadcrumbs = [m.breadcrumbs[count-2], m.breadcrumbs[count-1]]
        else
            breadcrumbs = [m.breadcrumbs[0]]
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
    else if screenType = "roTextScreen" then
        if enableBreadcrumbs then
            screen.Screen.SetBreadcrumbText(bread1, bread2)
        end if
    else if screenType = "roListScreen" OR screenType = "roKeyboardScreen" OR screenType = "roParagraphScreen" then
        if enableBreadcrumbs then
            screen.Screen.SetTitle(bread2)
        end if
    else if screenType = "roImageCanvas" then
        'roImageCanvas does not currently support breadcrumbs but allow for custom function to draw them
        if enableBreadcrumbs then
            if screen.SetBreadcrumbText <> invalid then screen.SetBreadcrumbText(bread2) 
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

Function vcStartRequest(request, listener, context, body=invalid, toFile=invalid) As Boolean
    ' ljunkie - added extra option to save request to a file
    request.SetPort(m.GlobalMessagePort)
    context.Listener = listener
    context.Request = request

    if toFile <> invalid then
        started = request.AsyncGetToFile(toFile)
    else if body = invalid then
        started = request.AsyncGetToString()
    else
        started = request.AsyncPostFromString(body)
    end if

    if started then
        id = request.GetIdentity().tostr()
        m.PendingRequests[id] = context

        if listener <> invalid then
            screenID = listener.ScreenID.tostr()
            if NOT m.RequestsByScreen.DoesExist(screenID) then
                m.RequestsByScreen[screenID] = []
            end if
            ' Screen ID's less than 0 are fake screens that won't be popped until
            ' the app is cleaned up, so no need to waste the bytes tracking them
            ' here.
            if listener.ScreenID >= 0 then m.RequestsByScreen[screenID].Push(id)
        end if

        return true
    else
        return false
    end if
End Function

Sub vcStartRequestIgnoringResponse(url, body=invalid, contentType="xml")
    request = CreateURLTransferObject(url)
    request.SetCertificatesFile("common:/certs/ca-bundle.crt")

    if body <> invalid then
        request.AddHeader("Content-Type", MimeType(contentType))
    end if

    context = CreateObject("roAssociativeArray")
    context.requestType = "ignored"

    m.StartRequest(request, invalid, context, body)
End Sub

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

Sub vcResetIdleTimer(fcnName="" as string)
    if m.timerIdleTime <> invalid then
        m.timerIdleTime.Mark()
    end if

    ' piggy back idle reset ( general idle time )
    m.resetGenIdleTimer()
End Sub

sub vcResetGenIdleTimer()
    if m.genIdleTime <> invalid then
        ' try to resend WOL packets if the roku idle
        homescreen = GetViewController().home
        if homescreen <> invalid and homescreen.WOLtimer <> invalid then 
            if homescreen.WOLtimer <> invalid and m.genIdleTime.RemainingSeconds() = 0 then 
                Debug("roku was idle -- need to set WOL packets and refresh")
                homescreen.WOLtimer.Name = "WOLsent"
                homescreen.WOLtimer.count = invalid
                homescreen.WOLtimer.keepAlive = false
                homescreen.WOLtimer.SetDuration(3*1000, false) ' 3 second time ( we will try 3 times )
            end if
        end if

        ' default action
        m.genIdleTime.Mark()
    end if
end sub

Sub vcCreateIdleTimer()
    m.timerIdleTime = invalid
    if RegRead("securityPincode","preferences",invalid) <> invalid then         
        lockTime = RegRead("locktime", "preferences","10800")
        if (lockTime <> invalid) and (strtoi(lockTime) > 0) then
            m.timerIdleTime = createTimer()
            m.timerIdleTime.SetDuration(int(strtoi(lockTime)*1000),false)
            m.ResetIdleTimer()
        end if 
    end if

    ' could use useful for some thing ( curretly used for WOL keepalives )
    ' 15 minutes is when we consider the channel idle
    m.genIdleTime = createTimer()
    m.genIdleTime.SetDuration(15*60*1000,true)
    m.ResetGenIdleTimer()
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
    globals.pkgname = "Plex"
    globals.maxRequestLength = 4000
    globals.idletime = 60
    globals.wwwroot = "tmp:/"
    globals.index_name = "index.html"
    globals.serverName = "Plex"
    AddGlobals(globals)
    MimeType()
    HttpTitle()
    ClassReply().AddHandler("/logs", ProcessLogsRequest)
    InitRemoteControlHandlers()

    vc.WebServer = InitServer({msgPort: vc.GlobalMessagePort, port: 8324})
End Sub

Sub createScreenForItemCallback()
    if m.breadcrumbs = invalid then 
        breadcrumbs = [firstOf(m.Heading, "")]
    else 
        breadcrumbs = m.breadcrumbs
    end if
    GetViewController().CreateScreenForItem(m.Item, invalid, breadcrumbs)
End Sub


sub vcControl() 
    timeout = 0

    while ( m.screens.Count() > 0 OR NOT AppManager().IsInitialized() ) and GetGlobalAA().ProfileExit = invalid

        m.WebServer.prewait()
        msg = wait(timeout, m.GlobalMessagePort)

        if msg <> invalid then
            ' Printing debug information about every message may be overkill
            ' regardless, but note that URL events don't play by the same rules,
            ' and there's no ifEvent interface to check for. Sigh.
            'if GetInterface(msg, "ifUrlEvent") = invalid AND GetInterface(msg, "ifSocketEvent") = invalid then
                'Debug("Processing " + type(msg) + " (top of stack " + type(m.screens.Peek().Screen) + "): " + tostr(msg.GetType()) + ", " + tostr(msg.GetIndex()) + ", " + tostr(msg.GetMessage()))
            'end if
            'if type(msg) <> "roUrlEvent" AND type(msg) <> "roSocketEvent" then
            '    Debug("Processing " + type(msg) + " (top of stack " + type(m.screens.Peek().Screen) + "): ")
            'end if
            for i = m.screens.Count() - 1 to 0 step -1
                if m.screens[i].HandleMessage(msg) = true then
                    m.ResetIdleTimer()
                    exit for
                end if                    
            end for

            ' Process URL events. Look up the request context and call a
            ' function on the listener.
            if type(msg) = "roUrlEvent" AND msg.GetInt() = 1 then
                id = msg.GetSourceIdentity().tostr()
                requestContext = m.PendingRequests[id]
                if requestContext <> invalid then
                    m.PendingRequests.Delete(id)
                    if requestContext.Listener <> invalid then
                        requestContext.Listener.OnUrlEvent(msg, requestContext)
                    end if
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
                if AudioPlayer().HandleMessage(msg) = true and RegRead("locktime_music", "preferences","enabled") <> "enabled" then
                    m.ResetIdleTimer() ' reset timer if music lock is disabled. I.E. when song changes timer will be reset
                end if
            else if type(msg) = "roSystemLogEvent" then
                msgInfo = msg.GetInfo()
                if msgInfo.LogType = "bandwidth.minute" then
                    GetGlobalAA().AddReplace("bandwidth", msgInfo.Bandwidth)
                end if
            else if type(msg) = "roChannelStoreEvent" then
                AppManager().HandleChannelStoreEvent(msg)
            else if msg.isRemoteKeyPressed() and msg.GetIndex() = 10 then
                ' do not allow global option key while screen is locked
                if m.IsLocked <> invalid or NOT m.IsLocked then m.CreateContextMenu()
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
        
        'check for idle timeout
        if m.timerIdleTime <> invalid then 'and (msg.isRemoteKeyPressed() or msg.isButtonInfo()) then 
            ' if for some reason one wants to disable timer during music, we'll handle it - we can handle paused if needed later [AudioPlayer().ispaused]
            if RegRead("locktime_music", "preferences","enabled") <> "enabled" and (AudioPlayer().isplaying) then 
                m.ResetIdleTimer()                
            else 
	        ' print "IDLE TIME Check: "; int(m.timerIdleTime.RemainingMillis()/int(1000))
                if m.timerIdleTime.IsExpired()=true then  'timer expired will only return true once
                    m.createLockScreen()    
                end if 
            end if
        end if
                 
    end while

    ' Exit confirmation?
    Debug("user has been requested to exit the channel")
    if RegRead("exit_confirmation", "preferences","enabled") <> "enabled" then 
        Debug("confirmation disabled")
        return
    end if
    Debug("confirmation enabled - creating a confirmation dialog")

    port = CreateObject("roMessagePort")
    dialog = CreateObject("roMessageDialog")
    dialog.SetMessagePort(port) 
    dialog.SetTitle("Are you sure you want to exit RARflix?")

    dialog.AddButton(1, "Yes")
    dialog.AddButton(2, "No")
    dialog.EnableBackButton(false)
    dialog.Show()

    closeChannel = false

    ' for now this will be a blocking request. The control has been stopped, so the 
    ' channel is not listening anymore more onHandle events. 
    ' pretty basic while loop - button index 2 will cancel the close/exit
    while True
        dlgMsg = wait(0, dialog.GetMessagePort())
        if type(dlgMsg) = "roMessageDialogEvent"
            if dlgMsg.isButtonPressed()
                if dlgMsg.GetIndex() = 1
                    closeChannel = true
                end if
                exit while
            else if dlgMsg.isScreenClosed()
                exit while
            end if
        end if
    end while 
    dialog.Close()


    ' user chose not to exit, we need to set the profileExit invalid, recreate the 
    ' homescreen, refresh the homescreen and start control again
    if NOT closeChannel then 
       Debug("user canceled exiting the channel - re-creating the homescreen now")
       GetGlobalAA().ProfileExit = invalid
       m.Home = m.CreateHomeScreen()
       m.Home.loader.refreshdata()
       m.Control()
    end if

    Debug("user confirmed exiting the channel - re-creating the homescreen now")

end sub

