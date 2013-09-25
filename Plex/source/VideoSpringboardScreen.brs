Function createVideoSpringboardScreen(context, index, viewController) As Object
    obj = createBaseSpringboardScreen(context, index, viewController)

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

    if supportedIdentifier then
        if m.metadata.UserRating = invalid then
            m.metadata.UserRating = 0
        endif
        if m.metadata.StarRating = invalid then
            m.metadata.StarRating = 0
        endif

        ' Rotten Tomatoes ratings, if enabled
        if m.metadata.ContentType = "movie" AND RegRead("rf_rottentomatoes", "preferences", "enabled") = "enabled" then 
            tomatoData = m.metadata.tomatoData
            rating_string = "Not Found"
            if tomatoData <> invalid AND tomatoData.ratings <> invalid AND tomatoData.ratings.critics_score <> invalid then
                if tomatoData.ratings.critics_score = -1 AND tomatoData.ratings.audience_score > 0
                    rating_string = tostr(tomatoData.ratings.audience_score) + "%"
                else if tomatoData.ratings.critics_score = -1 then
                    rating_string = "Not rated"
                else
		    ' I prefer the audience score vs the critics - RR - maybe we can make this a setting if needed
		    'rating_string = tostr(tomatoData.ratings.critics_score) + "%"
                    rating_string = tostr(tomatoData.ratings.audience_score) + "%"
                endif
            endif
            m.AddButton(rating_string + " on Rotten Tomatoes", "tomatoes")
        endif


          if m.metadata.server.AllowsMediaDeletion AND m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" then
              if m.metadata.ContentType = "show" or m.metadata.ContentType = "episode"  then
                  m.AddButton("Delete permanently","delete")
              end if
          end if

	' more buttong if TV SHOW ( only if grandparent key is available,stops loops) OR if this is Movie
	  if m.metadata.grandparentKey <> invalid  then
              m.AddButton("More...", "more")
	  else if m.metadata.ContentType = "movie" then
              m.AddButton("Cast, Rate & More...", "more")
	  end if

        ' Show rating bar if the content is a show or an episode - we might want this to be the delete button. We will see
          if m.metadata.ContentType = "show" or m.metadata.ContentType = "episode"  then
               m.AddRatingButton(m.metadata.UserRating, m.metadata.StarRating, "rateVideo")
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
        end if
        
        if m.metadata.ContentType = "episode" and tostr(m.metadata.ShowTitle) <> "invalid" and where <> "invalid" then 
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
                dialog = createBaseDialog()
                dialog.Title = ""
                dialog.Text = ""
                dialog.Item = m.metadata

                'if m.metadata.grandparentKey = invalid then
                if m.metadata.ContentType = "movie"  then
                    dialog.SetButton("options", "Playback options")
                end if

                ' display View All Seasons if we have grandparentKey -- entered from a episode
                if m.metadata.grandparentKey <> invalid then ' global on deck does not work with this
                'if m.metadata.ContentType = "show" or m.metadata.ContentType = "episode"  then
                    dialog.SetButton("showFromEpisode", "View All Seasons of " + m.metadata.ShowTitle )
                end if
                ' display View specific season if we have parentKey/parentIndex -- entered from a episode
                if m.metadata.parentKey <> invalid AND m.metadata.parentIndex <> invalid then  ' global on deck does not work with this
                'if m.metadata.ContentType = "show" or m.metadata.ContentType = "episode"  then
                   dialog.SetButton("seasonFromEpisode", "View Season " + m.metadata.parentIndex)
                end if

                ' if m.metadata.ContentType = "movie"  or m.metadata.ContentType = "show"  or m.metadata.ContentType = "episode"  then
                if m.metadata.ContentType = "movie" then ' TODO - try and make this work with TV shows ( seems it only works for episodes -- but not well ) 
                    dialog.SetButton("RFCastAndCrewList", "Cast & Crew")
                end if

                ' Trailers link - RR (last now that we include it on the main screen .. well before delete - people my be used to delete being second to last)
                'if m.metadata.grandparentKey = invalid then
                if m.metadata.ContentType = "movie" AND  RegRead("rf_trailers", "preferences", "disabled") <> "disabled" then 
                    dialog.SetButton("getTrailers", "Trailer")
                end if

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

                if m.metadata.server.AllowsMediaDeletion AND m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" then
                    dialog.SetButton("delete", "Delete permanently")
                end if

                ' set this to last -- unless someone complains
                if m.metadata.ContentType = "movie" or m.metadata.ContentType = "episode" or m.metadata.ContentType = "show"  then
                    dialog.SetButton("rate", "_rate_")
                end if

                dialog.SetButton("close", "Back")
                dialog.HandleButton = videoDialogHandleButton
                dialog.ParentScreen = m
                dialog.Show()
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
		     review_text = tostr(m.metadata.tomatoData.ratings.critics_score) + "%  Critic's score" + chr(10)
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
        dummyItem = CreateObject("roAssociativeArray")
        dummyItem.ContentType = "series"
        dummyItem.key = obj.metadata.grandparentKey + "/children"
        dummyItem.server = obj.metadata.server
        obj.ViewController.CreateScreenForItem(dummyItem, invalid, ["Series"])
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
        dialog = ShowPleaseWait("Please wait","Gathering the Cast and Crew for " + firstof(obj.metadata.umtitle,obj.metadata.title))
        screen = RFcreateCastAndCrewScreen(obj)
        screen.Show()
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
        dummyItem = CreateObject("roAssociativeArray")
        dummyItem.ContentType = "series"
        dummyItem.key = obj.metadata.parentKey + "/children"
        dummyItem.server = obj.metadata.server
        obj.ViewController.CreateScreenForItem(dummyItem, invalid, ["Series"])
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
