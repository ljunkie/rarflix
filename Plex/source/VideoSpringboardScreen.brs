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

    obj.OrigQuality = RegRead("quality", "preferences", "7")

    return obj
End Function

Sub videoSetupButtons()
    m.ClearButtons()

    m.offerResume = m.metadata.viewOffset <> invalid

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
        if m.metadata.server.AllowsMediaDeletion then
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
            RegWrite("quality", m.OrigQuality, "preferences")
            ' Don't treat the message as handled though, the super class handles
            ' closing.
        else if msg.isButtonPressed() then
            handled = true
            buttonCommand = m.buttonCommands[str(msg.getIndex())]
            Debug("Button command: " + tostr(buttonCommand))

            if buttonCommand = "play" OR buttonCommand = "resume" then
                startTime = 0

                if m.offerResume then
                    intervalInSeconds = fix(val(m.metadata.viewOffset)/(1000))

                    dlg = createBaseDialog()
                    dlg.Title = "Play Video"
                    dlg.SetButton("play", "Play from beginning")
                    dlg.SetButton("resume", "Resume from " + TimeDisplay(intervalInSeconds))
                    dlg.Show(true)

                    if dlg.Result = "resume" then startTime = int(val(m.metadata.viewOffset))
                end if

                directPlayOptions = m.PlayButtonStates[m.PlayButtonState]
                Debug("Playing video with Direct Play options set to: " + directPlayOptions.label)
                m.ViewController.CreateVideoPlayer(m.metadata, startTime, directPlayOptions.value)

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
                screen = createVideoOptionsScreen(m.metadata, m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Video Playback Options"])
                screen.Show()
                m.checkChangesOnActivate = true
            else if buttonCommand = "more" then
                dialog = createBaseDialog()
                dialog.Title = ""
                dialog.Text = ""
                dialog.Item = m.metadata
                dialog.SetButton("rate", "_rate_")
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

    if command = "delete" then
        obj.metadata.server.delete(obj.metadata.key)
        obj.closeOnActivate = true
        return true
    else if command = "rate" then
        Debug("videoHandleMessage:: Rate audio for key " + tostr(obj.metadata.ratingKey))
        rateValue% = (data /10)
        obj.metadata.UserRating = data
        if obj.metadata.ratingKey <> invalid then
            obj.Item.server.Rate(obj.metadata.ratingKey, obj.metadata.mediaContainerIdentifier, rateValue%.ToStr())
        end if
    else if command = "close" then
        return true
    end if
    return false
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
            RegWrite("quality", priorScreen.Changes["quality"], "preferences")
            m.metadata.preferredMediaItem = PickMediaItem(m.metadata.media, m.metadata.HasDetails)
        end if

        if priorScreen.Changes.DoesExist("audio") then
            m.media.canDirectPlay = invalid
            m.Item.server.UpdateAudioStreamSelection(m.media.preferredPart.id, priorScreen.Changes["audio"])
        end if

        if priorScreen.Changes.DoesExist("subtitles") then
            m.media.canDirectPlay = invalid
            m.Item.server.UpdateSubtitleStreamSelection(m.media.preferredPart.id, priorScreen.Changes["subtitles"])
        end if

        if NOT priorScreen.Changes.IsEmpty() then
            m.Refresh(true)
        end if
    end if

    if m.refreshOnActivate then
        m.Refresh(true)
    end if
End Sub
