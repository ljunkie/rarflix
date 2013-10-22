

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

    obj.callbackTimer = createTimer()
    obj.callbackTimer.Active = false
    obj.callbackTimer.SetDuration(1000, true)
    viewController.AddTimer(obj.callbackTimer, obj)

    ' Start playback when screen is opened if there's nothing playing
    if NOT viewController.AudioPlayer.IsPlaying then
        obj.Playstate = 2
        viewController.AudioPlayer.SetContext(obj.Context, obj.CurIndex, obj, true)
        viewController.AudioPlayer.Play()
    else if isItemPlaying(obj) then ' this will allow us to update Now Playing and Details screen
        obj.Playstate = 2
        obj.callbackTimer.Active = true
        obj.Screen.SetProgressIndicatorEnabled(true)
    else
        obj.Playstate = 0
    end if

    return obj
End Function

Sub audioSetupButtons()
    m.ClearButtons()

    audioPlayer = GetViewController().AudioPlayer

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

'    if audioPlayer.ShufflePlay then
'        if m.Playstate = 2 then 'only show unshuffle if current item is playing
'            m.addButton( "un-shuffle", "shufflePlay")
'        end if
'    else
'         m.addButton( "shuffle", "shufflePlay")
'    end if

    if m.Context.Count() > 1 then
        m.AddButton("next song", "next")
        m.AddButton("previous song", "prev")
    end if

    if m.metadata.UserRating = invalid then
        m.metadata.UserRating = 0
    endif

'    if audioPlayer.Loop then
'        m.AddButton( "loop: on", "loop")
'    else
'        m.AddButton( "loop: off", "loop")
'    end if

    if m.metadata.StarRating = invalid then
        m.metadata.StarRating = 0
    endif
    if m.metadata.origStarRating = invalid then
        m.metadata.origStarRating = 0
    endif

    ' m.AddButton("more...", "more")
    ' more button will be handled by * -- it's pretty much redundant now
    m.AddButton("go to now playing", "showNowPlaying")
End Sub

Sub audioGetMediaDetails(content)
    m.metadata = content
    m.media = invalid
End Sub

Function audioHandleMessage(msg) As Boolean
    handled = false

    server = m.Item.server
    audioPlayer = m.ViewController.AudioPlayer
    UpdateButtons = false
    DisableUpdateButtons = false
    if type(msg) = "roSpringboardScreenEvent" then
        if msg.isButtonPressed() then
            handled = true
            buttonCommand = m.buttonCommands[str(msg.getIndex())]
            Debug("Button command: " + tostr(buttonCommand))
            if buttonCommand = "play" then
                print "--------------- play pressed"
                audioPlayer.SetContext(m.Context, m.CurIndex, m, true)
                audioPlayer.Play()
                'm.PlayIndex = m.CurIndex
                m.Playstate = 2
                UpdateButtons = true
            else if buttonCommand = "resume" then
                audioPlayer.Resume()
                UpdateButtons = true
            else if buttonCommand = "pause" then
                audioPlayer.Pause()
                UpdateButtons = true
            else if buttonCommand = "stop" then
                audioPlayer.Stop()

                ' There's no audio player event for stop, so we need to do some
                ' extra work here.
                m.Playstate = 0
                m.callbackTimer.Active = false
                UpdateButtons = true
            else if buttonCommand = "next" then
                if m.GotoNextItem() then
                    audioPlayer.Next()
                    DisableUpdateButtons = true
                end if
            else if buttonCommand = "prev" then
                if m.GotoPrevItem() then
                    audioPlayer.Prev()
                    DisableUpdateButtons = true
                end if
            else if buttonCommand = "more" then
                rfCreateAudioSBdialog(m)
            else if buttonCommand = "showNowPlaying" then
                dummyItem = CreateObject("roAssociativeArray")
                dummyItem.ContentType = "audio"
                dummyItem.Key = "nowplaying"
                m.ViewController.CreateScreenForItem(dummyItem, invalid, ["","Now Playing"])
        return true
            else if buttonCommand = "shufflePlay" then
                if m.IsShuffled then
                    m.Unshuffle(m.Context)
                    m.IsShuffled = false
               else
                    m.Shuffle(m.Context)
                    m.IsShuffled = true
                end if
                audioPlayer.ShufflePlay = Not audioPlayer.ShufflePlay
                audioPlayer.SetContext(m.Context, m.CurIndex, m, true)
                audioPlayer.Play()
                UpdateButtons = true
            else if buttonCommand = "loop" then
                audioPlayer.Loop = Not audioPlayer.Loop
                audioPlayer.audioPlayer.SetLoop(audioPlayer.Loop)
                UpdateButtons = true
            else
                handled = false
            end if
        else if ((msg.isRemoteKeyPressed() AND msg.GetIndex() = 10) OR msg.isButtonInfo()) then ' ljunkie - use * for more options on focused item
                rfCreateAudioSBdialog(m)
        else if msg.isRemoteKeyPressed() then
            handled = true
            button = msg.GetIndex()
            Debug("Remote Key button = " + tostr(button))

            if button = 8 and audioplayer.IsPlaying then ' rewind
                 curOffset = audioplayer.GetPlaybackProgress()
                 newOffset = (curOffset*1000)-10000
                 if newOffset < 0 then newOffset = 0
                 Debug(tostr(newOffset))
                 audioPlayer.audioPlayer.Seek(newOffset)
                 audioPlayer.playbackOffset = newOffset/1000
                 audioPlayer.playbackTimer.Mark()
                 DisableUpdateButtons = true
            else if button = 9 and audioplayer.IsPlaying then ' forward
                 curOffset = audioplayer.GetPlaybackProgress()
                 newOffset = (curOffset*1000)+10000
                 duration = audioplayer.context[audioplayer.curindex].duration*1000
                 if newOffset < int(duration) then 
                     Debug(tostr(newOffset))
                     audioPlayer.audioPlayer.Seek(newOffset)
                     audioPlayer.playbackOffset = newOffset/1000
                     audioPlayer.playbackTimer.Mark()
                 end if
                 DisableUpdateButtons = true
            else if button = 5 then ' next             'if button = 5 or button = 9 ' next
                 'DisableUpdateButtons = true
                 UpdateButtons = true
                 ' ljunkie - actually we are going to disable left/right play NOW that sticky next track/previous track work
                 ' it's a little more consistent
                 'play = (m.Playstate = 2) ' Allow right/left in springboard when item selected is NOT the on playing
                 play = false
                 if m.GotoNextItem() then 
                     audioPlayer.Next(play)
                     if isItemPlaying(m) then 
                         m.Playstate = 2
                         m.callbackTimer.Active = true
                         m.Screen.SetProgressIndicatorEnabled(true)
                     else 
                         m.Playstate = 0
                     end if
                 end if
            else if button = 4 then ' prev'            else if button = 4 or button = 8 ' prev
                 'DisableUpdateButtons = true
                  UpdateButtons = true
                 ' ljunkie - actually we are going to disable left/right play NOW that sticky next track/previous track work
                 ' it's a little more consistent
                 'play = (m.Playstate = 2) ' Allow right/left in springboard when item selected is NOT the on playing
                 play = false
                 if m.GotoPrevItem() then 
                     audioPlayer.Prev(play)
                     if isItemPlaying(m) then 
                         m.Playstate = 2
                         m.callbackTimer.Active = true
                         m.Screen.SetProgressIndicatorEnabled(true)
                     else 
                         m.Playstate = 0
                     end if
                 end if
            end if
            'm.SetupButtons() ' no need for this.. keep the buttons stable
        end if
    else if type(msg) = "roAudioPlayerEvent" AND m.ViewController.AudioPlayer.ContextScreenID = m.ScreenID then
        UpdateButtons = false ' we will only update buttons on events (when things change)
        if msg.isRequestSucceeded() then
            m.GotoNextItem()
        else if msg.isRequestFailed() then
            m.GotoNextItem()
        else if msg.isListItemSelected() then
            m.Refresh(true)
            m.callbackTimer.Active = true
            m.Playstate = 2

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
            UpdateButtons = true
        else if msg.isResumed() then
            m.Playstate = 2
            m.callbackTimer.Active = true
            UpdateButtons = true
        end if

    end if

    if UpdateButtons and NOT DisableUpdateButtons then m.SetupButtons()
    if DisableUpdateButtons then print "--- disabled button refresh "
    return handled OR m.superHandleMessage(msg)
End Function

Sub audioOnTimerExpired(timer)
    if m.Playstate = 2 AND m.metadata.Duration <> invalid then
        m.Screen.SetProgressIndicator(m.ViewController.AudioPlayer.GetPlaybackProgress(), m.metadata.Duration)
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

        audioPlayer = GetViewController().AudioPlayer
        if audioPlayer.ContextScreenID = obj.ScreenID
            audioPlayer.SetContext(obj.Context, obj.CurIndex, obj, false)
        end if
    else if command = "show" then
        dummyItem = CreateObject("roAssociativeArray")
        dummyItem.ContentType = "audio"
        dummyItem.Key = "nowplaying"
        obj.ViewController.CreateScreenForItem(dummyItem, invalid, ["","Now Playing"])
        return true
    else if command = "loop" then
        audioPlayer = GetViewController().AudioPlayer
        if audioPlayer.Loop then
            m.SetButton(command, "Loop: Off")
        else
            m.SetButton(command, "Loop: On")
        end if
        audioPlayer.Loop = Not audioPlayer.Loop
        audioPlayer.audioPlayer.SetLoop(audioPlayer.Loop)
        m.Refresh()
    else if command = "delete" then
        obj.metadata.server.delete(obj.metadata.key)
        obj.closeOnActivate = true
        return true
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

sub rfCreateAudioSBdialog(m)
    audioPlayer = GetViewController().AudioPlayer
    dialog = createBaseDialog()
    dialog.Title = ""
    dialog.Text = ""
    dialog.Item = m.metadata
    if m.IsShuffled then
        dialog.SetButton("shuffle", "Shuffle: On")
    else
        dialog.SetButton("shuffle", "Shuffle: Off")
    end if
    if audioPlayer.ContextScreenID = m.ScreenID then
        if audioPlayer.Loop then
            dialog.SetButton("loop", "Loop: On")
        else
            dialog.SetButton("loop", "Loop: Off")
        end if
    else
        dialog.SetButton("show", "Go to Now Playing")
    end if
     dialog.SetButton("rate", "_rate_")
    if m.metadata.server.AllowsMediaDeletion AND m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" then
        dialog.SetButton("delete", "Delete permanently")
    end if
    dialog.SetButton("close", "Back")
    dialog.HandleButton = audioDialogHandleButton
    dialog.ParentScreen = m
    dialog.Show()
end sub

function isItemPlaying(obj,playing = false) as boolean
    print obj
    audioPlayer = GetViewController().AudioPlayer
    playingIndex = audioPlayer.playindex
    onScreenKey = obj.item.key
    playingKey = "Invalid"
    if playingIndex <> invalid and type(audioPlayer.context) = "roArray" and audioPlayer.context.count() > 0 then playingKey = audioPlayer.context[playingIndex].key

    print "playingIndex" + tostr(playingIndex)
    print "Playing:" + tostr(playingKey)
    print "Viewing:" + tostr(onScreenKey)

    if playing = false then playing = audioPlayer.isplaying
    if playing and playingKey = onScreenKey then return true
    if NOT playing print "--- audio is not playing ---"
    return false
end function