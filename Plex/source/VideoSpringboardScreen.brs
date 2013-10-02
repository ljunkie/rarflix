Function createVideoSpringboardScreen(context, index, viewController) As Object
    obj = createBaseSpringboardScreen(context, index, viewController)

    'obj.screen.UseStableFocus(true) ' ljunkie - set this globally instead BaseSpringboardScreen.brs:createBaseSpringboardScreen

    ' Our item's content-type affects the poster dimensions here, so treat
    ' clips as episodes.
    if obj.Item.ContentType = "clip" then
        obj.Item.ContentType = "episode"
    end if

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

    return obj
End Function

Sub videoSetupButtons()
    m.ClearButtons()

   if m.metadata.starrating = invalid then 'ljunkie - don't show starts if invalid
        m.Screen.SetStaticRatingEnabled(false)
   end if


    m.AddButton(m.PlayButtonStates[m.PlayButtonState].label, "play")
    Debug("Media = " + tostr(m.media))
    Debug("Can direct play = " + tostr(videoCanDirectPlay(m.media)))

    ' Trailers! (TODO) enable this for TV shows ( youtube is still useful )
    ' if m.metadata.ContentType = "show" or m.metadata.ContentType = "episode"  then
    if m.metadata.ContentType = "movie" AND  RegRead("rf_trailers", "preferences", "disabled") <> "disabled" then 
         m.AddButton("Trailer", "getTrailers")
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
    
    ' Delete button for myplex vidoes (queue/recommended)
    if m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.myplex" AND m.metadata.id <> invalid then
        m.AddButton("Delete from queue", "delete")
    end if


    ' Playback options only if a tvshow or episode -- movies use a line for trailers (moved this to more...)
    if m.metadata.ContentType = "show" or m.metadata.ContentType = "episode"  then
      m.AddButton("Playback options", "options")
    end if


        ' Rotten Tomatoes ratings, if enabled
        if m.metadata.ContentType = "movie" AND RegRead("rf_rottentomatoes", "preferences", "enabled") = "enabled" then 
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




    if supportedIdentifier then ' this is for delete and rating button 
        if m.metadata.UserRating = invalid then
            m.metadata.UserRating = 0
        endif
        if m.metadata.StarRating = invalid then
            m.metadata.StarRating = 0
        endif
        if m.metadata.origStarRating = invalid then
            m.metadata.origStarRating = 0
        endif

          if m.metadata.server.AllowsMediaDeletion AND m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" then
              if m.metadata.ContentType = "show" or m.metadata.ContentType = "episode"  then
                  m.AddButton("Delete permanently","delete")
              end if
          end if

        ' Show rating bar if the content is a show or an episode - we might want this to be the delete button. We will see
          if m.metadata.ContentType = "show" or m.metadata.ContentType = "episode" or RegRead("rf_rottentomatoes", "preferences", "enabled") = "disabled" then
               m.AddRatingButton(m.metadata.UserRating, m.metadata.origStarRating, "rateVideo")
	  end if

    end if

	' more buttong if TV SHOW ( only if grandparent key is available,stops loops) OR if this is Movie
	  if m.metadata.grandparentKey <> invalid  then
              m.AddButton("More...", "more")
	  else if m.metadata.ContentType = "movie" then
              m.AddButton("Cast, Rate & More...", "more")
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
	'stop

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

        if where = "Now Playing" then  ' set the now Playing bread crumbs to the - where/user and update metadata
           m.Screen.SetBreadcrumbEnabled(true)
           m.Screen.SetBreadcrumbText(where, UcaseFirst(m.metadata.nowplaying_user,true))
           if m.metadata.viewOffset <> invalid then
               m.metadata.description = "Progress: " + GetDurationString(int(m.metadata.viewOffset.toint()/1000),0,1,1) ' update progress - if we exit player
               m.metadata.description = m.metadata.description + " on " + firstof(m.metadata.nowplaying_platform_title, m.metadata.nowplaying_platform, "")
               m.metadata.description = m.metadata.description + chr(10) + m.metadata.nowPlaying_orig_description ' append the original description
           end if
           if m.metadata.episodestr <> invalid then 
               m.metadata.titleseason = m.metadata.cleantitle + " - " + m.metadata.episodestr
           else
               m.metadata.title = m.metadata.cleantitle
           end if
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
        m.metadata.tomatoData = getRottenTomatoesData(m.metadata.RFSearchTitle) 
    end if
    m.media = m.metadata.preferredMediaItem
End Sub

Function videoHandleMessage(msg) As Boolean
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
                directPlayOptions = m.PlayButtonStates[m.PlayButtonState]
                Debug("Playing video with Direct Play options set to: " + directPlayOptions.label)
                m.ViewController.CreateVideoPlayer(m.metadata, invalid, directPlayOptions.value)

                ' Refresh play data after playing.
                m.refreshOnActivate = true
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
                screen = createVideoOptionsScreen(m.metadata, m.ViewController, m.ContinuousPlay)
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
                youtube_search(tostr(m.metadata.RFSearchTitle),tostr(year))
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
        youtube_search(tostr(obj.metadata.RFSearchTitle),tostr(year))
        closeDialog = true
    else if command = "RFCastAndCrewList" then
        m.ViewController.PopScreen(m) ' close dialog before we show the Cast&Crew screen
        dialog = ShowPleaseWait("Please wait","Gathering the Cast and Crew for '" + firstof(obj.metadata.umtitle,obj.metadata.title) + "'")
        screen = RFcreateCastAndCrewScreen(obj)
        if screen <> invalid then  screen.Show()
        dialog.Close()
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
        screen = createVideoOptionsScreen(obj.metadata, obj.ViewController, obj.ContinuousPlay)
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

        if priorScreen.Changes.DoesExist("continuous_play") then
            m.ContinuousPlay = (priorScreen.Changes["continuous_play"] = "1")
            priorScreen.Changes.Delete("continuous_play")
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
        if m.ContinuousPlay AND (priorScreen.isPlayed = true OR priorScreen.playbackError = true) then
            m.GotoNextItem()
            directPlayOptions = m.PlayButtonStates[m.PlayButtonState]
            Debug("Playing video with Direct Play options set to: " + directPlayOptions.label)
            m.ViewController.CreateVideoPlayer(m.metadata, 0, directPlayOptions.value)
        else
            m.Refresh(true)
        end if
    end if
End Sub
