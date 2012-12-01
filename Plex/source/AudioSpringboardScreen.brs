

Function createAudioSpringboardScreen(context, index, viewController) As Dynamic
    obj = createBaseSpringboardScreen(context, index, viewController)

    obj.SetupButtons = audioSetupButtons
    obj.GetMediaDetails = audioGetMediaDetails
    obj.superHandleMessage = obj.HandleMessage
    obj.HandleMessage = audioHandleMessage
    obj.OnTimerExpired = audioOnTimerExpired

    obj.Screen.SetDescriptionStyle("audio")
    obj.Screen.SetStaticRatingEnabled(false)
    obj.Screen.AllowNavRewind(true)
    obj.Screen.AllowNavFastForward(true)

    ' Grid screens get corrupted when audio players are created, so we
    ' (used to) tell the view controller to destroy and recreate them.
    ' This doesn't appear to be an issue if we create a single audio player
    ' at startup and always use that.
    ' viewController.DestroyGlitchyScreens()

    ' If there isn't a single playable item in the list then the Roku has
    ' been observed to die a horrible death.
    obj.IsPlayable = false
    for i = obj.CurIndex to obj.Context.Count() - 1
        url = obj.Context[i].Url
        if url <> invalid AND url <> "" then
            obj.IsPlayable = true
            obj.CurIndex = i
            obj.Item = obj.Context[i]
            exit for
        end if
    next

    if NOT obj.IsPlayable then
        dialog = createBaseDialog()
        dialog.Title = "Unsupported Format"
        dialog.Text = "None of the audio tracks in this list are in a supported format. Use MP3s for best results."
        dialog.Show()
        return invalid
    end if

    obj.progressTimer = createTimer()
    obj.callbackTimer = createTimer()
    obj.callbackTimer.Active = false
    obj.callbackTimer.SetDuration(1000, true)
    viewController.AddTimer(obj.callbackTimer, obj)
    obj.progressOffset = 0
    obj.Playstate = 2

    viewController.AudioPlayer.SetContext(obj.Context, obj.CurIndex, obj)
    ' Start playback when screen is opened
    viewController.AudioPlayer.Play()

    return obj
End Function

Sub audioSetupButtons()
    m.ClearButtons()

    if NOT m.IsPlayable then return

    if m.Playstate = 2 then
        m.AddButton("pause playing", "pause")
        m.AddButton("stop playing", "stop")
    else if m.Playstate = 1 then
        m.AddButton("resume playing", "resume")
        m.AddButton("stop playing", "stop")
    else
        m.AddButton("start playing", "play")
    end if

    if m.Context.Count() > 1 then
        m.AddButton("next song", "next")
        m.AddButton("previous song", "prev")
    end if

    if m.metadata.UserRating = invalid then
        m.metadata.UserRating = 0
    endif
    if m.metadata.StarRating = invalid then
        m.metadata.StarRating = 0
    endif

    m.AddButton("more...", "more")
End Sub

Sub audioGetMediaDetails(content)
    m.metadata = content
    m.media = invalid
End Sub

Function audioHandleMessage(msg) As Boolean
    handled = false

    server = m.Item.server
    audioPlayer = m.ViewController.AudioPlayer

    if type(msg) = "roSpringboardScreenEvent" then
        if msg.isButtonPressed() then
            handled = true
            buttonCommand = m.buttonCommands[str(msg.getIndex())]
            Debug("Button command: " + tostr(buttonCommand))
            if buttonCommand = "play" then
                audioPlayer.Play()
            else if buttonCommand = "resume" then
                audioPlayer.Resume()
            else if buttonCommand = "pause" then
                audioPlayer.Pause()
            else if buttonCommand = "stop" then
                audioPlayer.Stop()

                ' There's no audio player event for stop, so we need to do some
                ' extra work here.
                m.Playstate = 0
                m.callbackTimer.Active = false
                m.SetupButtons()
            else if buttonCommand = "next" then
                if m.GotoNextItem() then
                    audioPlayer.Next()
                end if
            else if buttonCommand = "prev" then
                if m.GotoPrevItem() then
                    audioPlayer.Prev()
                end if
            else if buttonCommand = "more" then
                m.dialog = createBaseDialog()
                m.dialog.Title = ""
                m.dialog.Text = ""
                m.dialog.Item = m.metadata
                if m.IsShuffled then
                    m.dialog.SetButton("shuffle", "Shuffle: On")
                else
                    m.dialog.SetButton("shuffle", "Shuffle: Off")
                end if
                m.dialog.SetButton("rate", "_rate_")
                m.dialog.SetButton("close", "Back")
                m.dialog.HandleButton = audioDialogHandleButton
                m.dialog.ParentScreen = m
                m.dialog.Show()
                m.dialog.ParentScreen = invalid
                m.dialog = invalid
            else
                handled = false
            end if
            m.SetupButtons()
        else if msg.isRemoteKeyPressed() then
            handled = true
            button = msg.GetIndex()
            Debug("Remote Key button = " + tostr(button))

            if button = 5 or button = 9 ' next
                if m.GotoNextItem() then
                    audioPlayer.Next()
                end if
            else if button = 4 or button = 8 ' prev
                if m.GotoPrevItem() then
                    audioPlayer.Prev()
                end if
            end if
            m.SetupButtons()
        end if
    else if type(msg) = "roAudioPlayerEvent" then
        if msg.isRequestSucceeded() then
            m.GotoNextItem()
        else if msg.isRequestFailed() then
            m.GotoNextItem()
        else if msg.isListItemSelected() then
            m.Refresh(true)
            m.progressOffset = 0
            m.callbackTimer.Active = true
            m.progressTimer.Mark()
            m.Playstate = 2

            m.SetupButtons()
            if m.metadata.Duration <> invalid then
                m.Screen.SetProgressIndicator(0, m.metadata.Duration)
                m.Screen.SetProgressIndicatorEnabled(true)
            else
                m.Screen.SetProgressIndicatorEnabled(false)
            end if
        else if msg.isStatusMessage() then
            'Debug("Audio player status: " + tostr(msg.getMessage()))
        else if msg.isFullResult() then
            Debug("Playback of entire list finished")
            m.Playstate = 0
            m.Refresh(false)
        else if msg.isPartialResult() then
            Debug("isPartialResult")
        else if msg.isPaused() then
            m.Playstate = 1
            m.callbackTimer.Active = false
            m.progressOffset = m.progressOffset + m.progressTimer.GetElapsedSeconds()
            m.SetupButtons()
        else if msg.isResumed() then
            m.Playstate = 2
            m.callbackTimer.Active = true
            m.progressTimer.Mark()
            m.SetupButtons()
        end if
    end if

    return handled OR m.superHandleMessage(msg)
End Function

Sub audioOnTimerExpired(timer)
    if m.Playstate = 2 AND m.metadata.Duration <> invalid then
        m.Screen.SetProgressIndicator(m.progressOffset + m.progressTimer.GetElapsedSeconds(), m.metadata.Duration)
    end if
End Sub

Function audioDialogHandleButton(command, data) As Boolean
    ' We're evaluated in the context of the dialog, but we want to be in
    ' the context of the original screen.
    obj = m.ParentScreen

    if command = "shuffle" then
        if obj.IsShuffled then
            obj.Unshuffle(obj.Context)
            obj.IsShuffled = false
            m.SetButton(command, "Shuffle: Off")
        else
            obj.Shuffle(obj.Context)
            obj.IsShuffled = true
            m.SetButton(command, "Shuffle: On")
        end if
        m.Refresh()
    else if command = "rate" then
        Debug("audioHandleMessage:: Rate audio for key " + tostr(obj.metadata.ratingKey))
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
