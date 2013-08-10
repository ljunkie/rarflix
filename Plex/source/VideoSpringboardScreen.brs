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

    supportedIdentifier = (m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" OR m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.myplex")
    if supportedIdentifier then
        if m.metadata.viewCount <> invalid AND val(m.metadata.viewCount) > 0 then
            m.AddButton("Mark as unwatched", "unscrobble")
        else
            if m.metadata.viewOffset <> invalid AND val(m.metadata.viewOffset) > 0 then
                m.AddButton("Mark as unwatched", "unscrobble")
            end if
            m.AddButton("Mark as watched", "scrobble")
        end if
    end if

    if m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.myplex" AND m.metadata.id <> invalid then
        m.AddButton("Delete from queue", "delete")
    end if

    m.AddButton("Playback options", "options")

    if supportedIdentifier then
        if m.metadata.UserRating = invalid then
            m.metadata.UserRating = 0
        endif
        if m.metadata.StarRating = invalid then
            m.metadata.StarRating = 0
        endif

        ' When delete is present we don't have enough room so we stuff delete
        ' and rate in a separate dialog.
        ' RR - when grandparentKey is present - we don't have enough room
        ' either. We present 'Show All Seasons' and 'Show Season #'
        if m.metadata.server.AllowsMediaDeletion OR m.metadata.grandparentKey <> invalid then
            m.AddButton("More...", "more")
        else
            m.AddRatingButton(m.metadata.UserRating, m.metadata.StarRating, "rateVideo")
        end if
    end if
End Sub

Sub videoGetMediaDetails(content)
    server = content.server
    Debug("About to fetch meta-data for Content Type: " + tostr(content.contentType))

    m.metadata = content.ParseDetails()
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
                m.Item.server.Delete(m.metadata.id)
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
                dialog.SetButton("rate", "_rate_")

                ' display View All Seasons if we have grandparentKey -- entered from a episode
                if m.metadata.grandparentKey <> invalid then
                   dialog.SetButton("showFromEpisode", "View All Seasons")
                end if
                ' display View specific season if we have parentKey/parentIndex -- entered from a episode
                if m.metadata.parentKey <> invalid AND m.metadata.parentIndex <> invalid then
                   dialog.SetButton("seasonFromEpisode", "View Season " + m.metadata.parentIndex)
                end if

                if m.metadata.server.AllowsMediaDeletion AND m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" then
                    dialog.SetButton("delete", "Delete permanently")
                end if
                dialog.SetButton("close", "Back")
                dialog.HandleButton = videoDialogHandleButton
                dialog.ParentScreen = m
                dialog.Show()
            else if buttonCommand = "rateVideo" then
                rateValue% = msg.getData() /10
                m.metadata.UserRating = msg.getdata()
                m.Item.server.Rate(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier,rateValue%.ToStr())
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
