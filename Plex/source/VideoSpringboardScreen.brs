Function createVideoSpringboardScreen(context, index, viewController) As Object
    obj = createBaseSpringboardScreen(context, index, viewController)

    'obj.screen.UseStableFocus(true) ' ljunkie - set this globally instead BaseSpringboardScreen.brs:createBaseSpringboardScreen

    obj.SetupButtons = videoSetupButtons
    obj.GetMediaDetails = videoGetMediaDetails
    obj.superHandleMessage = obj.HandleMessage
    obj.HandleMessage = videoHandleMessage

    obj.checkChangesOnActivate = false
    obj.refreshOnActivate = false
    obj.closeOnActivate = false
    obj.Activate = videoActivate

    obj.PlayButtonStates = [
        {label: "Play", value: 0},
        {label: "Direct Play", value: 1},
        {label: "Direct Play w/ Fallback", value: 2},
        {label: "Direct Stream/Transcode", value: 3},
        {label: "Play Transcoded", value: 4}
    ]
    obj.PlayButtonState = RegRead("directplay", "preferences", "0").toint()

    obj.ContinuousPlay = (RegRead("continuous_play", "preferences") = "1")
    obj.ShufflePlay = (RegRead("shuffle_play", "preferences") = "1")
    obj.continuousContextPlay = (RegRead("continuous_context_play", "preferences") = "1") 'not a global option (yet)

    return obj
End Function

Sub videoSetupButtons()
    m.ClearButtons()
    versionArr = GetGlobal("rokuVersionArr", [0])

    isMovieShowEpisode = (m.metadata.ContentType = "movie" or m.metadata.ContentType = "show" or m.metadata.ContentType = "episode")
    isHomeVideos = (m.metadata.isHomeVideos = true)

   'ljunkie - don't show stars if invalid
    if m.metadata.starrating = invalid then m.Screen.SetStaticRatingEnabled(false)

    playLabel = m.PlayButtonStates[m.PlayButtonState].label
    if m.ShufflePlay then
        playLabel = "Shuffle+Continuous " + playLabel
    else if m.continuousContextPlay then
        playLabel = "Continuous [context] " + playLabel
    else if m.ContinuousPlay then
         playLabel = "Continuous " + playLabel
    end if
    m.AddButton(playLabel, "play")
    Debug("Media = " + tostr(m.media))
    Debug("Can direct play = " + tostr(videoCanDirectPlay(m.media)))

    ' Trailers! (TODO) enable this for TV shows ( youtube is still useful? )
    if NOT isHomeVideos and m.metadata.ContentType = "movie" AND  RegRead("rf_trailers", "preferences", "disabled") <> "disabled" then 
         m.AddButton("Trailer", "getTrailers")
    end if

    ' hide cast and crew to show ratings instead ( firmware 3.x and less only allow for 5 buttons )
    if versionArr[0] >= 4 then 
        if NOT isHomeVideos and isMovieShowEpisode and m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" then m.AddButton("Cast & Crew","RFCastAndCrewList")
    end if

    supportedIdentifier = (m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" OR m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.myplex")
    if supportedIdentifier then
         ' Partial Watch ( can be watched/unwatched - but in progess) allow scrobbleMore dialog - to show both options mark as watched or unwatched
        if m.metadata.viewOffset <> invalid AND val(m.metadata.viewOffset) > 0 then
            m.AddButton("Mark as watched/unwatched", "scrobbleMore")
        ' content is watched - show unscrobble button
        else if m.metadata.viewCount <> invalid AND val(m.metadata.viewCount) > 0 then
            m.AddButton("Mark as unwatched", "unscrobble")
        ' content is NOT watched - show unscrobble button
        else
            m.AddButton("Mark as watched", "scrobble")
        end if

    end if

    ' we have ONE more button to work with -- if tv, lets add the seasons option
    ' display View All Seasons if we have grandparentKey -- entered from a episode
    ' we might want to add some more checks in here to limit the display.
    ' Does someone really need to 'View Season 1' when they are already in Season 1
    ' Does someone really need to 'View Season All season'  when previous screen might already be that?
    if m.metadata.grandparentKey <> invalid then ' global on deck does not work with this
         m.AddButton( "View All Seasons", "showFromEpisode")
    end if
    ' display View specific season if we have parentKey/parentIndex -- entered from a episode
    if m.metadata.parentKey <> invalid AND m.metadata.parentIndex <> invalid then
        m.AddButton( "View Season " + m.metadata.parentIndex, "seasonFromEpisode")
    end if

    ' show more button now for firmware 3.x and less -- only allow for 5 buttons
    if versionArr[0] < 4 then 
        if isMovieShowEpisode then
            m.AddButton("Playback Options & More...", "more")
        else 
            m.AddButton("More...", "more")
        end if
    end if

    ' Delete button for myplex vidoes (queue/recommended) - we should have room for this
    if m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.myplex" AND m.metadata.id <> invalid then
        m.AddButton("Delete from queue", "delete")
    end if

    ' Rotten Tomatoes ratings, if enabled
    if NOT isHomeVideos and m.metadata.ContentType = "movie" AND RegRead("rf_rottentomatoes", "preferences", "enabled") = "enabled" then 
        tomatoData = m.metadata.tomatoData
        rating_string = "Not Found"
        append_string = "on Rotten Tomatoes"
        if tomatoData <> invalid AND tomatoData.ratings <> invalid AND tomatoData.ratings.critics_score <> invalid then
            if RegRead("rf_rottentomatoes_score", "preferences", "audience") = "critic" then 
                rating = tomatoData.ratings.critics_score
            else 
                rating = tomatoData.ratings.audience_score
            end if

            if rating = invalid or rating < 0 then 
                Debug("RT rating is invalid/-1 -- trying to find a valid rating")
                if tomatoData.ratings.audience_score > 0
                    rating = tomatoData.ratings.audience_score
                    append_string = append_string + " *"
                else if NOT tomatoData.ratings.critics_score = -1 then
                    rating = tomatoData.ratings.critics_score
                    append_string = append_string + " *"
                else 
                    rating = -1
                end if
            end if

            if rating = -1 then
                rating_string = "Not Found"
            else 
                rating_string = tostr(rating) + "%"
            end if
        end if
        m.AddButton(rating_string + " " + append_string, "tomatoes")
    end if

    if supportedIdentifier then
        ' not enough room for this.. only in the more dialog
        'if m.metadata.server.AllowsMediaDeletion AND m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" then
        '    if m.metadata.ContentType = "show" or m.metadata.ContentType = "episode"  then
        '        m.AddButton("Delete permanently","delete")
        '    end if
        'end if

        ' only show rating bar for movies if rotten tomoatoes is disabled. (this option is available in the more dialog)
        if RegRead("rf_rottentomatoes", "preferences", "enabled") = "disabled" then
            if m.metadata.UserRating = invalid then
                m.metadata.UserRating = 0
            end if
            if m.metadata.StarRating = invalid then
                m.metadata.StarRating = 0
            end if
            if m.metadata.origStarRating = invalid then
                m.metadata.origStarRating = 0
            end if
            m.AddRatingButton(m.metadata.UserRating, m.metadata.origStarRating, "rateVideo")
        end if

    end if

    if versionArr[0] >= 4 then 
        if isMovieShowEpisode then
            m.AddButton("Playback Options & More...", "more")
        else 
            m.AddButton("More...", "more")
        end if
    end if

End Sub

Sub videoGetMediaDetails(content)
    server = content.server
    Debug("About to fetch meta-data for Content Type: " + tostr(content.contentType))

    m.metadata = content.ParseDetails()

    'ljunkie - dynamically update breadbcrumbs -- 
    ' Useful for Ondeck/Recently Added -- when someone enters an episode directly
    ' .. also useful when someone enters an episode from All Seasons in the gridview for TV shows
    ' * should probably be done in sbRefresh - (well maybe not anymore)

    if RegRead("rf_bcdynamic", "preferences", "enabled") = "enabled" then 
        ' todo - figure out what screen we are in.. kinda done the lame way
        ra = CreateObject("roRegex", "/recentlyAdded", "")
        od = CreateObject("roRegex", "/onDeck", "")
        rv = CreateObject("roRegex", "/recentlyViewed", "")
        rair = CreateObject("roRegex", "/newest", "")
        rallLeaves = CreateObject("roRegex", "/allLeaves", "")
        rnp = CreateObject("roRegex", "/status/sessions", "")

        where = "invalid"
        if ra.Match(m.metadata.sourceurl)[0] <> invalid then
           where = "Recently Added"
        else if od.Match(m.metadata.sourceurl)[0] <> invalid then
           where = "On Deck"
        else if rv.Match(m.metadata.sourceurl)[0] <> invalid then
           where = "Recently Viewed"
        else if rair.Match(m.metadata.sourceurl)[0] <> invalid then
	   where = "Recently Aired"
        else if rallLeaves.Match(m.metadata.sourceurl)[0] <> invalid then
	   where = "All Episodes"
        else if rnp.Match(m.metadata.sourceurl)[0] <> invalid then
	   where = "Now Playing"
        end if

        if where = "Now Playing" then  ' set the now Playing bread crumbs to the - where/user and set the title
           m.Screen.SetBreadcrumbEnabled(true)
           m.Screen.SetBreadcrumbText(where, UcaseFirst(m.metadata.nowplaying_user,true))
           rf_updateNowPlayingSB(m)
           Debug("Dynamically set Episode breadcrumbs; " + where + ": " + UcaseFirst(m.metadata.nowplaying_user,true))
        else if m.metadata.ContentType = "episode" and tostr(m.metadata.ShowTitle) <> "invalid" and where <> "invalid" then 
           m.Screen.SetBreadcrumbEnabled(true)
           m.Screen.SetBreadcrumbText(where, truncateString(m.metadata.ShowTitle,26))
           Debug("Dynamically set Episode breadcrumbs; " + where + ": " + truncateString(m.metadata.ShowTitle,26))
        else if m.metadata.ContentType = "movie" and where <> "invalid" and od.Match(m.metadata.sourceurl)[0] <> invalid then 
           ' this has been added for the global on deck view. Normally we already have this breadcrumb displayed, 
           ' but due to global on deck (possibly recently added) , we need to account for switching between differnt contentTypes
           m.Screen.SetBreadcrumbEnabled(true)
           m.Screen.SetBreadcrumbText("Movies", where) 
           Debug("Dynamically set MOVIES breadcrumbs; Movies: " + where)
        else if tostr(m.metadata.ContentType) = "invalid" then
           m.Screen.SetBreadcrumbEnabled(true)
           'ljunkie BUGFIX TODO ( this is bug existing in official plex ) 
           '  left/right buttons when viewing global recently added dies when switching from movie to other contentType
	   ' Note: left and right have been denied now in BaseSpringboardScreen.brs - sbRefresh 
           m.Screen.SetBreadcrumbText("invalid", "bug in official channel too")
        end if
    end if

    if m.metadata.ContentType = "movie" AND RegRead("rf_rottentomatoes", "preferences", "enabled") = "enabled" then 
        if m.metadata.tomatoData = invalid then m.metadata.tomatoData = getRottenTomatoesData(m.metadata.RFSearchTitle) 
    end if

    m.media = m.metadata.preferredMediaItem

    ' posterStyle: set episodes/clips to 16x9 -- the rest are still default ( auto size )
    '  this is mainly for the mixed content springBoards ( global onDeck/recentlyAdded )
    '  also useful for TV Episodes: they use screenshots - so thumbs are mixed 4x3 vs 16x9
    '   we can utilize the m.media.aspectratio to determine if it's 4x3 or 16x9
    posterStyle = "default" 
    if tostr(m.metadata.contentType) = "episode" OR tostr(m.metadata.contentType) = "clip" or m.metadata.isHomeVideos = true then
        posterStyle = "rounded-rect-16x9-generic"
        ' we cannot assume the thumbnail is 4x3 even is the content seems to be ( I have run into 16x9 thumbs with 4x3 content -- how is the possible? )
        ' ' only override back to default if we know it's 4x3
        'if m.media <> invalid and type(m.media.aspectratio) = "roFloat" and m.media.aspectratio > 0 and m.media.aspectratio < 1.5 then
        '    posterStyle = "default"
        'end if            
    end if
    Debug("set posterstyle " + tostr(posterStyle))
    m.Screen.SetPosterStyle(posterStyle)
End Sub

Function videoHandleMessage(msg) As Boolean
    ' this is in the context of a the videos detail screen
    handled = false

    if type(msg) = "roSpringboardScreenEvent" then
        if msg.isScreenClosed() then
            RegDelete("quality_override", "preferences")
            ' Don't treat the message as handled though, the super class handles
            ' closing.
        else if ((msg.isRemoteKeyPressed() AND msg.GetIndex() = 10) OR msg.isButtonInfo()) then
                rfVideoMoreButton(m)
        else if msg.isButtonPressed() then
            handled = true
            buttonCommand = m.buttonCommands[str(msg.getIndex())]
            Debug("Button command: " + tostr(buttonCommand))

            if buttonCommand = "play" OR buttonCommand = "resume" then
                ' ljunkie - continuous/shuffle play - load the content required now

                ' special: get all context if we came from a FullGrid and ContinuousPlay/ShufflePlay are enabled
                if (m.ContinuousPlay or m.shuffleplay or m.continuousContextPlay) and m.FullContext = invalid and fromFullGrid(true) then GetContextFromFullGrid(m)

                ' shuffle the context if shufflePlay enable - as of now the selected video will always play
                if m.shuffleplay then 
                    m.Shuffle() 'm.Shuffle(m.context)
                    m.metadata = m.context[0]
                end if
                
                directPlayOptions = m.PlayButtonStates[m.PlayButtonState]
                Debug("Playing video with Direct Play options set to: " + directPlayOptions.label)
                m.ViewController.CreateVideoPlayer(m.metadata, invalid, directPlayOptions.value)

                ' Refresh play data after playing.
                m.refreshOnActivate = true
            else if buttonCommand = "putOnDeck" then
                if m.item <> invalid and m.item.server <> invalid then 
                    m.item.server.putOnDeck(m.item)
                end if
                m.Refresh(true)
            else if buttonCommand = "scrobble" then
                m.Item.server.Scrobble(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier)
                ' Refresh play data after scrobbling
                m.Refresh(true)
            else if buttonCommand = "unscrobble" then
                m.Item.server.Unscrobble(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier)
                ' Refresh play data after unscrobbling
                m.Refresh(true)
            else if buttonCommand = "delete" then
    	        key = m.metadata.id
	        	if tostr(key) = "invalid"
                  key = m.metadata.key
                end if
                m.Item.server.Delete(key)
                m.Screen.Close()
            else if buttonCommand = "options" then
                screen = createVideoOptionsScreen(m.metadata, m.ViewController, m.ContinuousPlay, m.ShufflePlay, m.continuousContextPlay)
                m.ViewController.InitializeOtherScreen(screen, ["Video Playback Options"])
                screen.Show()
                m.checkChangesOnActivate = true
            else if buttonCommand = "more" then
                rfVideoMoreButton(m)
            else if buttonCommand = "scrobbleMore" then
                dialog = createBaseDialog()
                dialog.Title = ""
                dialog.Text = ""
                dialog.Item = m.metadata

                supportedIdentifier = (m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" OR m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.myplex")
                if supportedIdentifier then
                    if m.metadata.viewCount <> invalid AND val(m.metadata.viewCount) > 0 then
                        dialog.SetButton("unscrobble", "Mark as unwatched")
                    else
                        if m.metadata.viewOffset <> invalid AND val(m.metadata.viewOffset) > 0 then
                            dialog.SetButton("unscrobble", "Mark as unwatched")
                        end if
                    end if
                    dialog.SetButton("scrobble", "Mark as watched")
                end if

                dialog.SetButton("close", "Back")
                dialog.HandleButton = videoDialogHandleButton
                dialog.ParentScreen = m
                dialog.Show()
            else if buttonCommand = "rateVideo" then
                rateValue% = msg.getData() /10
                m.metadata.UserRating = msg.getdata()
                m.Item.server.Rate(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier,rateValue%.ToStr())
            else if buttonCommand = "getTrailers" then
                if m.metaData.OrigReleaseDate <> invalid then
                     year = m.metaData.OrigReleaseDate
                else 
                     year = m.metaData.ReleaseDate
                end if
                breadcrumbs = ["Trailers",tostr(m.metadata.RFSearchTitle)]
                dummyItem = CreateObject("roAssociativeArray")
                dummyItem.ContentType = invalid
                dummyItem.server = invalid
                dummyItem.key = "movietrailer"
                dummyItem.year = year
                dummyItem.searchTitle = tostr(m.metadata.RFSearchTitle)
                m.ViewController.CreateScreenForItem(dummyItem, invalid, breadcrumbs)
                handled = true
            else if buttonCommand = "tomatoes" then
                dialog = createBaseDialog()
                dialog.Title = "Rotten Tomatoes Review"
                review_text = "'" + m.metadata.RFSearchTitle + "' could not be located on Rotten Tomatoes... sorry."
                if m.metadata.tomatoData <> invalid  then 
                    if m.metadata.tomatoData.ratings.critics_score = -1 then
                        review_text = "Not Rated by Critics" + chr(10)
                    else
                        review_text = tostr(m.metadata.tomatoData.ratings.critics_score) + "%  Critic's score" + chr(10)
                    end if
                    review_text = review_text + tostr(m.metadata.tomatoData.ratings.audience_score) + "% Audience's score" + chr(10)
                    if m.metadata.tomatoData.critics_consensus <> invalid then
                        review_text = review_text + chr(10) + tostr(m.metadata.tomatoData.critics_consensus) + chr(10)
                    end if
                end if
                dialog.Text = review_text
                dialog.SetButton("getTrailers", "Trailer")
                dialog.SetButton("close", "Back")
                dialog.HandleButton = videoDialogHandleButton
                dialog.ParentScreen = m
                dialog.Show()
            ' rob to fix
            else if buttonCommand = "RFCastAndCrewList" then
                'm.ViewController.PopScreen(m) ' close dialog before we show the Cast&Crew screen
                ' for now lets not use the show with episode
                dialog = ShowPleaseWait("Please wait","Gathering the Cast and Crew for '" + firstof(m.metadata.showtitle,m.metadata.cleantitle,m.metadata.umtitle,m.metadata.title) + "'")
                screen = RFcreateCastAndCrewScreen(m)
                if screen <> invalid then  screen.Show()
                dialog.Close()
                handled = true
            else if buttonCommand = "showFromEpisode" then
                breadcrumbs = ["All Seasons",m.metadata.showtitle]
                dummyItem = CreateObject("roAssociativeArray")
                dummyItem.ContentType = "series"
                dummyItem.key = m.metadata.grandparentKey + "/children"
                dummyItem.server = m.metadata.server
                m.ViewController.CreateScreenForItem(dummyItem, invalid, breadcrumbs)
                handled = true
            else if buttonCommand = "seasonFromEpisode" then
                breadcrumbs = [m.metadata.showtitle, "Season " + m.metadata.parentindex]
                dummyItem = CreateObject("roAssociativeArray")
                dummyItem.ContentType = "series"
                dummyItem.key = m.metadata.parentKey + "/children"
                dummyItem.server = m.metadata.server
                m.ViewController.CreateScreenForItem(dummyItem, invalid, breadcrumbs)
                handled = true
            else
                handled = false
            end if
        end if
    end if

    return handled OR m.superHandleMessage(msg)
End Function

Function videoDialogHandleButton(command, data) As Boolean
    ' We're evaluated in the context of the dialog, but we want to be in
    ' the context of the original screen.
    obj = m.ParentScreen

    closeDialog = false

    if command = "delete" then
        obj.metadata.server.delete(obj.metadata.key)
        obj.closeOnActivate = true
        closeDialog = true
    else if command = "fullGridScreen" then
        screen = m.viewcontroller.screens.peek().parentscreen
        if screen <> invalid then
            itype = invalid
            dummyItem = CreateObject("roAssociativeArray")
           
            ' home screen is special...
            vc = GetViewController()
            if vc.Home <> invalid AND m.parentscreen.screenid = vc.Home.ScreenID then
                for each key in screen.loader.rowindexes
                    if screen.loader.rowindexes[key] = screen.selectedrow then
                        dummyItem  = m.parentscreen.contentarray[m.parentscreen.selectedrow][m.parentscreen.focusedindex]
                        dummyItem.key = key
                        itype = "All Sections" 'breadcrumb
                        exit for
                    end if
                end for  
            else
                ' get the section type name we are in for breadcrumb
                sec_metadata = getSectionType()
                if sec_metadata.title <> invalid then itype = sec_metadata.title

                dummyItem.server = screen.loader.server
                dummyItem.sourceurl = screen.loader.sourceurl
                dummyItem.key = screen.loader.contentarray[screen.selectedrow].key
            end if

            screenName = "Section: Full Grid"
            breadcrumbs = [itype,screen.loader.Getnames()[screen.selectedrow]]

            displaymode_grid = RegRead("rf_grid_displaymode", "preferences", "scale-to-fit")
            screen = createFULLGridScreen(dummyItem, m.viewcontroller, "Invalid", displaymode_grid) 
            if screen <> invalid then 
                screen.ScreenName = screenName
                m.viewcontroller.AddBreadcrumbs(screen, breadcrumbs)
                m.viewcontroller.UpdateScreenProperties(screen)
                m.viewcontroller.PushScreen(screen)
                screen.Show()
            end if
            closeDialog = true
        end if
    else if command = "showFromEpisode" then
        breadcrumbs = ["All Seasons",obj.metadata.showtitle]
        dummyItem = CreateObject("roAssociativeArray")
        dummyItem.ContentType = "series"
        dummyItem.key = obj.metadata.grandparentKey + "/children"
        dummyItem.server = obj.metadata.server
        obj.ViewController.CreateScreenForItem(dummyItem, invalid, breadcrumbs)
        closeDialog = true
    else if command = "getTrailers" then
        if obj.metaData.OrigReleaseDate <> invalid then
            year = obj.metaData.OrigReleaseDate
        else 
            year = obj.metaData.ReleaseDate
        end if
        breadcrumbs = ["Trailers",tostr(obj.metadata.RFSearchTitle)]
        dummyItem = CreateObject("roAssociativeArray")
        dummyItem.server = invalid
        dummyItem.key = "movietrailer"
        dummyItem.year = year
        dummyItem.searchTitle = tostr(obj.metadata.RFSearchTitle)
        m.ViewController.CreateScreenForItem(dummyItem, invalid, breadcrumbs)
        closeDialog = true
    else if command = "RFCastAndCrewList" then
        'm.ViewController.PopScreen(m) ' close dialog before we show the Cast&Crew screen ' not needed and wrong
        ' for now lets not use the show with episode
        dialog = ShowPleaseWait("Please wait","Gathering the Cast and Crew for '" + firstof(obj.metadata.showtitle,obj.metadata.cleantitle,obj.metadata.umtitle,obj.metadata.title) + "'")
        screen = RFcreateCastAndCrewScreen(obj)
        if screen <> invalid then  screen.Show()
        dialog.Close()
        closeDialog = true
    else if command = "GoToHomeScreen" then
        ' Close all screens except for HomeScreen
        '  thanks Schuyler -- logic already existed!
        context = CreateObject("roAssociativeArray")
        context.OnAfterClose = CloseScreenUntilHomeVisible
        context.OnAfterClose()
        closeDialog = true
    else if command = "gotoFilters" then
        parentScreen = m.parentscreen
        item = parentscreen.originalItem
        createFilterSortScreenFromItem(item, parentScreen)
        closeDialog = true
    else if command = "SectionSorting" then
        dialog = createGridSortingDialog(m,obj)
        if dialog <> invalid then dialog.Show(true)
    else if command = "RFVideoDescription" then

        ' A TextScreen seems a little too much for this.. a description (should) fit it a dialog all by iteself 
        ' maybe show the text screen if the len(obj.metadata.UMdescription) > ??
        paragraphs = []
        paragraphs.Push(obj.metadata.UMdescription)
        screen = createTextScreen("Description", invalid , paragraphs, m.ViewController, true)
        screen.screen.AddButton(1, "Done")
        breadcrumbs =  [obj.metadata.title,"Description"]
        screen.screenName = "Video Description"
        m.ViewController.InitializeOtherScreen(screen, breadcrumbs)
        screen.Show()

        'dialog = createBaseDialog()
        'dialog.Title = obj.metadata.title
        'dialog.Text = obj.metadata.UMdescription
        'dialog.Item = m.metadata
        'dialog.SetButton("close", "Close") ' back seems odd because we came from a dialog ( one might get confused )
        'dialog.HandleButton = videoDialogHandleButton
        'dialog.ParentScreen = m
        'dialog.Show(true)

        closeDialog = true
    else if command = "putOnDeck" then
        if obj.item <> invalid and obj.item.server <> invalid then 
            obj.item.server.putOnDeck(m.item)
        end if
        obj.Refresh(true)
        closeDialog = true
    else if command = "scrobble" then
        obj.metadata.server.Scrobble(obj.metadata.ratingKey, obj.metadata.mediaContainerIdentifier)
        obj.Refresh(true)
        closeDialog = true
    else if command = "unscrobble" then
        obj.metadata.server.Unscrobble(obj.metadata.ratingKey, obj.metadata.mediaContainerIdentifier)
        obj.Refresh(true)
        closeDialog = true
    else if Command = "options" then
        screen = createVideoOptionsScreen(obj.metadata, obj.ViewController, obj.ContinuousPlay, obj.ShufflePlay, obj.continuousContextPlay)
        obj.ViewController.InitializeOtherScreen(screen, ["Video Playback Options"])
        screen.Show()
        obj.checkChangesOnActivate = true
        closeDialog = true
    else if command = "seasonFromEpisode" then
        breadcrumbs = [obj.metadata.showtitle, "Season " + obj.metadata.parentindex]
        dummyItem = CreateObject("roAssociativeArray")
        dummyItem.ContentType = "series"
        dummyItem.key = obj.metadata.parentKey + "/children"
        dummyItem.server = obj.metadata.server
        obj.ViewController.CreateScreenForItem(dummyItem, invalid, breadcrumbs)
        closeDialog = true
    else if command = "rate" then
        Debug("videoHandleMessage:: Rate audio for key " + tostr(obj.metadata.ratingKey))
        rateValue% = (data /10)
        obj.metadata.UserRating = data
        if obj.metadata.ratingKey <> invalid then
            obj.Item.server.Rate(obj.metadata.ratingKey, obj.metadata.mediaContainerIdentifier, rateValue%.ToStr())
        end if
    else if command = "gotoMusicNowPlaying" then
        obj.focusedbutton = 0
        dummyItem = CreateObject("roAssociativeArray")
        dummyItem.ContentType = "audio"
        dummyItem.Key = "nowplaying"
        obj.ViewController.CreateScreenForItem(dummyItem, invalid, ["","Now Playing"])
        closeDialog = true
    else if command = "close" then
        closeDialog = true
    end if

    return closeDialog
End Function

Sub videoActivate(priorScreen)
    if m.closeOnActivate then
        m.Screen.Close()
        return
    end if

    if m.checkChangesOnActivate AND priorScreen.Changes <> invalid then
        m.checkChangesOnActivate = false
        if priorScreen.Changes.DoesExist("playback") then
            m.PlayButtonState = priorScreen.Changes["playback"].toint()
        end if

        if priorScreen.Changes.DoesExist("quality") then
            RegWrite("quality_override", priorScreen.Changes["quality"], "preferences")
            m.metadata.PickMediaItem(m.metadata.HasDetails)
        end if

        if priorScreen.Changes.DoesExist("audio") then
            m.media.canDirectPlay = invalid
            m.Item.server.UpdateStreamSelection("audio", m.media.preferredPart.id, priorScreen.Changes["audio"])
        end if

        if priorScreen.Changes.DoesExist("subtitles") then
            m.media.canDirectPlay = invalid
            m.Item.server.UpdateStreamSelection("subtitle", m.media.preferredPart.id, priorScreen.Changes["subtitles"])
        end if

        if priorScreen.Changes.DoesExist("playBack_type") then
            m.ShufflePlay = (priorScreen.Changes["playBack_type"] = "shuffle_play")
            m.ContinuousPlay = (priorScreen.Changes["playBack_type"] = "continuous_play")
            m.continuousContextPlay = (priorScreen.Changes["playBack_type"] = "continuous_context_play")
            priorScreen.Changes["playback"] = tostr(m.PlayButtonState)
        end if

        if priorScreen.Changes.DoesExist("media") then
            index = strtoi(priorScreen.Changes["media"])
            media = m.metadata.media[index]
            if media <> invalid then
                m.media = media
                m.metadata.preferredMediaItem = media
                m.metadata.preferredMediaIndex = index
                m.metadata.isManuallySelectedMediaItem = true
            end if
        end if

        if NOT priorScreen.Changes.IsEmpty() then
            m.Refresh(true)
        end if
    end if

    if m.refreshOnActivate then
        ' only consider advancedToNext value if we have the next Episode info
        advancedToNext = RegRead("advanceToNextItem", "preferences", "enabled") = "enabled" and (m.NextEpisodes <> invalid or priorScreen.NextEpisodes <> invalid)

        ' shuffleplay/continuousContextPlay overrides advanceToNext ( these DO NOT try and use the next available episode )
        if m.ShufflePlay or m.continuousContextPlay then advancedToNext = false

        ' ContinuousPlay/ShufflePlay - go to next and play ( excluding advancedToNext content )
        if NOT advancedToNext and (m.ContinuousPlay or m.ShufflePlay or m.continuousContextPlay) AND (priorScreen.isPlayed = true OR priorScreen.playbackError = true) then
            m.Refresh(true) ' refresh the watched item (watched status/overlay) before moving on
            m.GotoNextItem()
            directPlayOptions = m.PlayButtonStates[m.PlayButtonState]
            Debug("Playing video with Direct Play options set to: " + directPlayOptions.label)
            m.ViewController.CreateVideoPlayer(m.metadata, 0, directPlayOptions.value)
        else if advancedToNext AND (priorScreen.isPlayed = true) then
            m.skipFullContext = true ' never load full context ( deprecated due to fullcontext load true )
            m.fullcontext = true     ' fullcontext is loaded
            m.Refresh(true)

            ' advanceToNext ( tv episode only ) -- this will replace any springboard context with the shows context
            if m.nextEpisodes = invalid then 
                Debug("[AutoEpisodeAdvance] nextEpisodes is specified - using the shows context now: " + tostr(priorScreen.NextEpisodes.item.title))
                ' setting for videoPlayer to know nextEpisodes has already been determined
                m.nextEpisodes = priorScreen.NextEpisodes

                ' refresh the current item before resetting the new context
                refreshedItem = m.context[m.curindex]

                ' reset the context with the shows (all seasons episodes context)
                m.context = priorScreen.NextEpisodes.context
                m.CurIndex = priorScreen.NextEpisodes.curindex

                ' replace the refreshed item in the new context            
                m.context[m.CurIndex] = refreshedItem
            else 
                Debug("[AutoEpisodeAdvance] nextEpisodes context is already known")
            end if

            ' standard - go to next item
            m.GotoNextItem()

            ' start play if m.ContinuousPlay
            if m.ContinuousPlay then 
                directPlayOptions = m.PlayButtonStates[m.PlayButtonState]
                Debug("[ContinuousPlay] Playing video with Direct Play options set to: " + directPlayOptions.label)
                m.ViewController.CreateVideoPlayer(m.metadata, 0, directPlayOptions.value)
            end if
        else
            m.Refresh(true)
        end if
    end if
End Sub
