

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
    player = AudioPlayer()
    if NOT player.IsPlaying then
        obj.Playstate = 2
        player.SetContext(obj.Context, obj.CurIndex, obj, true)
        player.Play()
    else if isItemPlaying(obj) then ' this will allow us to update Now Playing and Details screen
        obj.Playstate = 2
        obj.callbackTimer.Active = true
        obj.Screen.SetProgressIndicatorEnabled(true)
    else
        obj.Playstate = 0
    end if

    if player.ContextScreenID = obj.ScreenID then
        NowPlayingManager().location = "fullScreenMusic"
    end if

    return obj
End Function

Sub audioSetupButtons()
    m.ClearButtons()

    player = AudioPlayer()

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

'    if player.ShufflePlay then
'        if m.Playstate = 2 then 'only show unshuffle if current item is playing
'            m.addButton( "un-shuffle", "shufflePlay")
'        end if
'    else
'         m.addButton( "shuffle", "shufflePlay")
'    end if

'    if m.Context.Count() > 1 then
    if m.Playstate = 2 and m.Context.Count() > 1 then
        m.AddButton("next song", "next")
        m.AddButton("previous song", "prev")
    end if

    if m.metadata.UserRating = invalid then
        m.metadata.UserRating = 0
    endif

'    if player.Repeat = 2 then
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

    if tostr(m.screenname) <> "Now Playing" then 
        m.AddButton("go to now playing", "showNowPlaying")
    end if
End Sub

Sub audioGetMediaDetails(content)
    m.metadata = content
    m.media = invalid
End Sub

Function audioHandleMessage(msg) As Boolean
    handled = false

    server = m.Item.server
    player = AudioPlayer()
    UpdateButtons = false
    DisableUpdateButtons = false
    if type(msg) = "roSpringboardScreenEvent" then
        if msg.isButtonPressed() then
            handled = true
            buttonCommand = m.buttonCommands[str(msg.getIndex())]
            Debug("Button command: " + tostr(buttonCommand))
            if buttonCommand = "play" then
                player.SetContext(m.Context, m.CurIndex, m, true)
                player.Play()
                print "--------------- play pressed"
                'm.PlayIndex = m.CurIndex
                m.Playstate = 2
                UpdateButtons = true
            else if buttonCommand = "resume" then
                player.Resume()
                UpdateButtons = true
            else if buttonCommand = "pause" then
                player.Pause()
                UpdateButtons = true
            else if buttonCommand = "stop" then
                player.Stop()

                ' There's no audio player event for stop, so we need to do some
                ' extra work here.
                m.Playstate = 0
                m.callbackTimer.Active = false
                UpdateButtons = true
            else if buttonCommand = "next" then
                if m.GotoNextItem() then
                    player.Next()
                    DisableUpdateButtons = true
                end if
            else if buttonCommand = "prev" then
                if m.GotoPrevItem() then
                    player.Prev()
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
                    m.Unshuffle() 'm.Unshuffle(m.Context)
                    m.IsShuffled = false
               else
                    m.Shuffle() ' m.Shuffle(m.Context)
                    m.IsShuffled = true
                end if
                player.ShufflePlay = Not player.ShufflePlay
                player.SetContext(m.Context, m.CurIndex, m, true)
                player.Play()
                UpdateButtons = true
            else if buttonCommand = "loop" then
                if player.Repeat = 2 then
                    player.SetRepeat(0)
                else
                    player.SetRepeat(2)
                end if
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

            if button = 8 and player.IsPlaying then ' rewind
                 curOffset = player.GetPlaybackProgress()
                 newOffset = (curOffset*1000)-10000
                 if newOffset < 0 then newOffset = 0
                 Debug(tostr(newOffset))
                 player.player.Seek(newOffset)
                 player.playbackOffset = newOffset/1000
                 player.playbackTimer.Mark()
                 DisableUpdateButtons = true
            else if button = 9 and player.IsPlaying then ' forward
                 curOffset = player.GetPlaybackProgress()
                 newOffset = (curOffset*1000)+10000
                 if player.context[player.curindex].duration <> invalid then 
                     duration = player.context[player.curindex].duration*1000
                     if newOffset < int(duration) then 
                         Debug(tostr(newOffset))
                         player.player.Seek(newOffset)
                         player.playbackOffset = newOffset/1000
                         player.playbackTimer.Mark()
                     end if
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
                     player.Next(play)
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
                     player.Prev(play)
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
    else if type(msg) = "roAudioPlayerEvent" AND player.ContextScreenID = m.ScreenID then
        UpdateButtons = false ' we will only update buttons on events (when things change)
        if msg.isRequestSucceeded() then
            m.GotoNextItem()
        else if msg.isRequestFailed() then
            m.GotoNextItem()
        else if msg.isListItemSelected() then
            m.CurIndex = player.CurIndex
            m.Item = m.Context[m.CurIndex]
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
        m.Screen.SetProgressIndicator(AudioPlayer().GetPlaybackProgress(), m.metadata.Duration)
    end if
End Sub

Function audioDialogHandleButton(command, data) As Boolean
    ' We're evaluated in the context of the dialog, but we want to be in
    ' the context of the original screen.
    obj = m.ParentScreen
    player = AudioPlayer()

    if command = "shuffle" then
        if obj.IsShuffled then
            obj.Unshuffle()
            obj.IsShuffled = false
            m.SetButton(command, "Shuffle: Off")
        else
            obj.Shuffle()
            obj.IsShuffled = true
            m.SetButton(command, "Shuffle: On")
        end if
        m.Refresh()

        if player.ContextScreenID = obj.ScreenID
            player.SetContext(obj.Context, obj.CurIndex, obj, false)
        end if
    else if command = "show" then
        dummyItem = CreateObject("roAssociativeArray")
        dummyItem.ContentType = "audio"
        dummyItem.Key = "nowplaying"
        obj.ViewController.CreateScreenForItem(dummyItem, invalid, ["","Now Playing"])
        return true
    else if command = "loop" then
        if player.Repeat = 2 then
            m.SetButton(command, "Loop: Off")
            player.SetRepeat(0)
        else
            m.SetButton(command, "Loop: On")
            player.SetRepeat(2)
        end if
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
    player = AudioPlayer()
    dialog = createBaseDialog()
    dialog.Title = ""
    dialog.Text = ""
    dialog.Item = m.metadata
    if m.IsShuffled then
        dialog.SetButton("shuffle", "Shuffle: On")
    else
        dialog.SetButton("shuffle", "Shuffle: Off")
    end if
    if player.ContextScreenID = m.ScreenID then
        if player.Repeat = 2 then
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
    player = AudioPlayer()
    playingIndex = player.playindex
    onScreenKey = obj.item.key
    playingKey = "Invalid"
    if playingIndex <> invalid and type(player.context) = "roArray" and player.context.count() > 0 then playingKey = player.context[playingIndex].key

    print "playingIndex" + tostr(playingIndex)
    print "Playing:" + tostr(playingKey)
    print "Viewing:" + tostr(onScreenKey)

    if playing = false then playing = player.isplaying
    if playing and playingKey = onScreenKey then return true
    if NOT playing print "--- audio is not playing ---"
    return false
end function
