'**********************************************************
'**  Modified beyond recognition but originally based on:
'**  Audio Player Example Application - Audio Playback
'**  November 2009
'**  Copyright (c) 2009 Roku Inc. All Rights Reserved.
'**********************************************************

Function createAudioPlayer(viewController)
    ' Unlike just about everything else, the audio player isn't a Screen.
    ' So we'll wrap the Roku audio player similarly, but not quite in the
    ' same way.

    obj = CreateObject("roAssociativeArray")

    obj.Port = viewController.GlobalMessagePort
    obj.ViewController = viewController

    obj.HandleMessage = audioPlayerHandleMessage

    obj.Play = audioPlayerPlay
    obj.Pause = audioPlayerPause
    obj.Resume = audioPlayerResume
    obj.Stop = audioPlayerStop
    obj.Next = audioPlayerNext
    obj.Prev = audioPlayerPrev

    obj.audioPlayer = CreateObject("roAudioPlayer")
    obj.audioPlayer.SetMessagePort(obj.Port)

    obj.Context = invalid
    obj.CurIndex = invalid ' this now what is currenlty displayed on the screen
    obj.PlayIndex = invalid ' this is whats playing
    obj.ContextScreenID = invalid
    obj.SetContext = audioPlayerSetContext

    obj.ShowContextMenu = audioPlayerShowContextMenu

    obj.PlayThemeMusic = audioPlayerPlayThemeMusic

    obj.ShufflePlay = false
    obj.IsPlaying = false
    obj.IsPaused = false

    obj.playbackTimer = createTimer()
    obj.playbackOffset = 0
    obj.GetPlaybackProgress = audioPlayerGetPlaybackProgress

    return obj
End Function

Function audioPlayerHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roAudioPlayerEvent" then
        handled = true
        ' item = m.Context[m.CurIndex] -- ljunkie
        item = m.Context[m.PlayIndex] ' curIndex is used for switching screens ( not always the music in the backgroud)

        if msg.isRequestSucceeded() then
            Debug("Playback of single song completed")

            if item.ratingKey <> invalid then
                Debug("Scrobbling audio track -> " + tostr(item.ratingKey))
                Debug("Scrobbling audio track -> " + tostr(item.artist) + " - " + tostr(item.album) + " - " + tostr(item.title))
                item.Server.Scrobble(item.ratingKey, item.mediaContainerIdentifier)
            end if

            ' Send an analytics event, but not for theme music
            if m.ContextScreenID <> invalid then
                amountPlayed = m.GetPlaybackProgress()
                Debug("Sending analytics event, appear to have listened to audio for " + tostr(amountPlayed) + " seconds")
                m.ViewController.Analytics.TrackEvent("Playback", firstOf(item.ContentType, "track"), item.mediaContainerIdentifier, amountPlayed)
            end if

            maxIndex = m.Context.Count() - 1
            'newIndex = m.CurIndex + 1
            newIndex = m.PlayIndex + 1
            if newIndex > maxIndex then newIndex = 0
            'm.CurIndex = newIndex 
            m.PlayIndex = newIndex
        else if msg.isRequestFailed() then
            Debug("Audio playback failed")
            maxIndex = m.Context.Count() - 1
            ' newIndex = m.CurIndex + 1
            newIndex = m.PlayIndex + 1
            if newIndex > maxIndex then newIndex = 0
            ' m.CurIndex = newIndex
            m.PlayIndex = newIndex
        else if msg.isListItemSelected() then
            Debug("Starting to play track: " + tostr(item.Url))
            m.IsPlaying = true
            m.IsPaused = false
            m.playbackOffset = 0
            m.playbackTimer.Mark()
            m.ViewController.DestroyGlitchyScreens()
        else if msg.isStatusMessage() then
            'Debug("Audio player status: " + tostr(msg.getMessage()))
            Debug("Audio player status (duplicates ok): " + tostr(msg.getMessage()))
            if tostr(msg.getMessage()) = "playback stopped" then 
                m.IsPlaying = false
                m.IsPaused = false
            else if tostr(msg.getMessage()) = "start of play" then 
                m.IsPlaying = true
                m.IsPaused = false
            end if
        else if msg.isFullResult() then
            Debug("Playback of entire audio list finished")
            m.Stop()

            if item.Url = "" then
                ' TODO(schuyler): Show something more useful, especially once
                ' there's a server version that transcodes audio.
                dialog = createBaseDialog()
                dialog.Title = "Content Unavailable"
                dialog.Text = "We're unable to play this audio format."
                dialog.Show()
            end if
        else if msg.isPartialResult() then
            Debug("isPartialResult")
        else if msg.isPaused() then
            Debug("Stream paused by user")
            m.IsPlaying = false
            m.IsPaused = true
            m.playbackOffset = m.playbackOffset + m.playbackTimer.GetElapsedSeconds()
            m.playbackTimer.Mark()
        else if msg.isResumed() then
            Debug("Stream resumed by user")
            m.IsPlaying = true
            m.IsPaused = false
            m.playbackTimer.Mark()
        end if
    end if

    return handled
End Function

Sub audioPlayerPlay()
    if m.Context <> invalid then
        m.audioPlayer.Play()
    end if
End Sub

Sub audioPlayerPause()
    if m.Context <> invalid then
        m.audioPlayer.Pause()
    end if
End Sub

Sub audioPlayerResume()
    if m.Context <> invalid then
        m.audioPlayer.Resume()
    end if
End Sub

Sub audioPlayerStop()
    if m.Context <> invalid then
        m.audioPlayer.Stop()
'        m.audioPlayer.SetNext(m.CurIndex)
        m.audioPlayer.SetNext(m.PlayIndex)
        m.IsPlaying = false
        m.IsPaused = false
    end if
End Sub

Sub audioPlayerNext(play=true)
    ' this used to display and backgroup ( if play is true) set playIndex/curIndex
    if m.Context = invalid then return

    maxIndex = m.Context.Count() - 1
    newIndex = m.CurIndex + 1

    if newIndex > maxIndex then newIndex = 0
    ' Allow right/left in springboard when item selected is NOT the on playing
    m.CurIndex = newIndex
    if play then 
        m.PlayIndex = newIndex ' only update if playing
        m.Stop()
        m.audioPlayer.SetNext(newIndex)
        m.Play()
    end if
End Sub

Sub audioPlayerPrev(play=true)
    ' this used to display and backgroup ( if play is true) set playIndex/curIndex
    if m.Context = invalid then return

    newIndex = m.CurIndex - 1
    if newIndex < 0 then newIndex = m.Context.Count() - 1

    ' Allow right/left in springboard when item selected is NOT the on playing
    m.CurIndex = newIndex

    if play then 
        m.PlayIndex = newIndex ' only update if playing
        m.Stop()
        m.audioPlayer.SetNext(newIndex)
        m.Play()
    end if
End Sub

Sub audioPlayerSetContext(context, contextIndex, screen, startPlayer)
    if startPlayer then m.Stop()

    item = context[contextIndex]

    m.Context = context
    m.CurIndex = contextIndex
    m.PlayIndex = contextIndex
    if screen <> invalid then
        m.ContextScreenID = screen.ScreenID
    else
        m.ContextScreenID = invalid
    end if

    if item.server <> invalid then
        AddAccountHeaders(m.audioPlayer, item.server.AccessToken)
    end if

    if screen = invalid then
        m.Loop = (RegRead("theme_music", "preferences", "disabled") = "loop")
    else
        pref = RegRead("loopalbums", "preferences", "sometimes")
        if pref = "sometimes" then
            m.Loop = (context.Count() > 1)
        else
            m.Loop = (pref = "always")
        end if
    end if

    m.audioPlayer.SetLoop(m.Loop)
    m.audioPlayer.SetContentList(context)

    if startPlayer then
        m.audioPlayer.SetNext(contextIndex)
        m.IsPlaying = false
        m.IsPaused = false
    else
        maxIndex = context.Count() - 1
        newIndex = contextIndex + 1
        if newIndex > maxIndex then newIndex = 0
        m.audioPlayer.SetNext(newIndex)
    end if
End Sub

Sub audioPlayerShowContextMenu()
    ' this is the dialog for Now Playing - use the playIndex
    dialog = createBaseDialog()
    dialog.Title = "Now Playing" 

    dialog.Text =               "  Artist: " + firstOf(m.Context[m.PlayIndex].Artist, "") + chr(10)
    dialog.Text = dialog.Text + "Album: " + firstOf(m.Context[m.PlayIndex].Album, "")
    if m.Context[m.PlayIndex].releasedate <> invalid then dialog.Text = dialog.Text + " (" + m.Context[m.PlayIndex].releasedate + ")"

    

    ' ljunkie - append current status in audio in the dialog title
    if m.ispaused then 
        dialog.Title = "Now Paused" 
    else if m.isplaying  then
        'append = "(playing)"
    else 
        dialog.Title = "Now Stopped" 
    end if
    dialog.Title = dialog.Title + " - " + firstOf(m.Context[m.PlayIndex].Title, "")

    ' ljunkie - slideshow fun - show current image if slideshow is the current screen
    if type(m.viewcontroller.screens.peek().screen) = "roSlideShow" then 
        m.slideshow = m.viewcontroller.screens.peek()
        print m.slideshow
        if type(m.slideshow.CurIndex) = "roInteger" and type(m.slideshow.items) = "roArray" then  ' ljunkie - show the photo title a slide show is in progress
            dialog.Text = dialog.Text + chr(10) + " Photo: " + tostr(m.slideshow.items[m.slideshow.CurIndex].title)
            if m.slideshow.isPaused = invalid then m.slideshow.isPaused = false
        end if 
    end if 

    if m.focusedbutton = invalid then m.focusedbutton = 0 
    focusbutton = m.focusedbutton
    append = ""

    ' slide shows get more buttons
    if m.slideshow <> invalid
        append = " Audio"
        variable = 0 ' variable buttongs.. we might have to +1 our focusedButton - logic will break if we add more buttons, so keep note of that
        if m.slideshow.isPaused or m.isPaused then
            dialog.SetButton("resumeAll", "Resume All")
            variable = variable +1
        end if
        if NOT m.slideshow.isPaused or m.isPlaying then 
            dialog.SetButton("pauseAll", "Pause All")
            variable = variable +1
        end if
        if variable = 2 then focusbutton = focusbutton + 1
    end if

    if m.IsPlaying then
        dialog.SetButton("pause", "Pause" + append)
    else if m.IsPaused then
        dialog.SetButton("resume", "Resume" + append)
    else
        dialog.SetButton("play", "Play" + append)
    end if


    if m.IsPlaying or m.IsPaused then ' only show if paused of playing
        dialog.SetButton("stop", "Stop" + append)
    end if 

    if m.Context.Count() > 1 then
        dialog.SetButton("next_track", "Next Track")
        dialog.SetButton("prev_track", "Previous Track")
    end if

    dialog.SetButton("show", "Go to Now Playing")
    dialog.SetButton("close", "Close")

    ' ljunkie - focus to last set button ( logic needs clean up now that set set the dialog.FocusedButton after)
    if m.IsPlaying or m.IsPaused then ' set focus only it playing or paused - otherwsie it should just be play
        'dialog.FocusedButton = focusbutton
    else if NOT m.IsPlaying and NOT m.IsPaused then
        if m.slideshow <> invalid then ' if slideshow ( audio not playing or paused ) set to resume audio
            focusbutton = 1 
            Debug("not playing/paused - with slideshow: setting focused button to 1")
        else 
            focusbutton = 0 ' Play Audio 
            Debug("not playing/paused: setting focused button to 0")
        end if
    else 
        Debug("NO match - setting focus to 0")
        focusbutton = 0 ' Play Audio
    end if

    dialog.FocusedButton = focusbutton
    dialog.HandleButton = audioPlayerMenuHandleButton
    dialog.SetFocusButton = dialogSetFocusButton
    dialog.ParentScreen = m
    dialog.Show()
End Sub

Function audioPlayerMenuHandleButton(command, data) As Boolean
    ' We're evaluated in the context of the dialog, but we want to be in the
    ' context of the audio player.
    obj = m.ParentScreen

    if command = "play" then
        obj.focusedbutton = 0 
        obj.Play()
    else if command = "pause" then
        obj.Pause()
    else if command = "pauseAll" then
        obj.focusedbutton = 0 
        ' we only get here if we know we are playing a slideshow too
        obj.slideshow.screen.Pause()
        obj.slideshow.isPaused = true
        obj.slideshow.forceResume = false
        obj.Pause()
    else if command = "resume" then
        obj.focusedbutton = 0 
        obj.Resume()
    else if command = "resumeAll" then
        obj.focusedbutton = 0
        ' we only get here if we know we are playing a slideshow too
        obj.slideshow.screen.Resume()
        obj.slideshow.isPaused = false
        obj.slideshow.forceResume = false
        if obj.ispaused then 
            obj.Resume()
        else if NOT obj.isplaying then 
            obj.Play()
        end if 
    else if command = "stop" then
        obj.Stop()
    else if command = "next_track" then
        obj.Next()
    else if command = "prev_track" then
        obj.Prev()
    else if command = "show" then
        obj.focusedbutton = 0
        dummyItem = CreateObject("roAssociativeArray")
        dummyItem.ContentType = "audio"
        dummyItem.Key = "nowplaying"
        obj.ViewController.CreateScreenForItem(dummyItem, invalid, ["","Now Playing"])
    else if command = "close" then
        obj.focusedbutton = 0 
        return true
    end if

    ' For now, close the dialog after any button press instead of trying to
    ' refresh the buttons based on the new state.
    return true
End Function

Sub audioPlayerPlayThemeMusic(item)
    themeItem = CreateObject("roAssociativeArray")
    themeItem.Url = item.server.serverUrl + item.theme
    themeItem.Title = item.Title + " Theme"
    themeItem.HasDetails = true
    themeItem.Type = "track"
    themeItem.ContentType = "audio"
    themeItem.StreamFormat = "mp3"
    themeItem.server = item.server

    m.SetContext([themeItem], 0, invalid, true)
    m.Play()
End Sub

Function audioPlayerGetPlaybackProgress() As Integer
    return m.playbackOffset + m.playbackTimer.GetElapsedSeconds()
End Function
