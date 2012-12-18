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
    obj.CurIndex = invalid
    obj.ContextScreenID = invalid
    obj.SetContext = audioPlayerSetContext

    obj.ShowContextMenu = audioPlayerShowContextMenu

    obj.PlayThemeMusic = audioPlayerPlayThemeMusic

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
        item = m.Context[m.CurIndex]

        if msg.isRequestSucceeded() then
            Debug("Playback of single song completed")

            if item.ratingKey <> invalid then
                Debug("Scrobbling audio track -> " + tostr(item.ratingKey))
                item.Server.Scrobble(item.ratingKey, item.mediaContainerIdentifier)
            end if

            ' Send an analytics event, but not for theme music
            if m.ContextScreenID <> invalid then
                amountPlayed = m.GetPlaybackProgress()
                Debug("Sending analytics event, appear to have listened to audio for " + tostr(amountPlayed) + " seconds")
                m.ViewController.Analytics.TrackEvent("Playback", firstOf(item.ContentType, "track"), item.mediaContainerIdentifier, amountPlayed, [])
            end if

            maxIndex = m.Context.Count() - 1
            newIndex = m.CurIndex + 1
            if newIndex > maxIndex then newIndex = 0
            m.CurIndex = newIndex
        else if msg.isRequestFailed() then
            Debug("Audio playback failed")
            maxIndex = m.Context.Count() - 1
            newIndex = m.CurIndex + 1
            if newIndex > maxIndex then newIndex = 0
            m.CurIndex = newIndex
        else if msg.isListItemSelected() then
            Debug("Starting to play track: " + tostr(item.Url))
            m.IsPlaying = true
            m.IsPaused = false
            m.playbackOffset = 0
            m.playbackTimer.Mark()
            m.ViewController.DestroyGlitchyScreens()
        else if msg.isStatusMessage() then
            'Debug("Audio player status: " + tostr(msg.getMessage()))
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
        m.audioPlayer.SetNext(m.CurIndex)
        m.IsPlaying = false
        m.IsPaused = false
    end if
End Sub

Sub audioPlayerNext()
    if m.Context = invalid then return

    maxIndex = m.Context.Count() - 1
    newIndex = m.CurIndex + 1

    if newIndex > maxIndex then newIndex = 0

    m.Stop()
    m.CurIndex = newIndex
    m.audioPlayer.SetNext(newIndex)
    m.Play()
End Sub

Sub audioPlayerPrev()
    if m.Context = invalid then return

    newIndex = m.CurIndex - 1
    if newIndex < 0 then newIndex = m.Context.Count() - 1

    m.Stop()
    m.CurIndex = newIndex
    m.audioPlayer.SetNext(newIndex)
    m.Play()
End Sub

Sub audioPlayerSetContext(context, contextIndex, screen)
    m.Stop()

    item = context[contextIndex]

    m.Context = context
    m.CurIndex = contextIndex

    if screen <> invalid then
        m.ContextScreenID = screen.ScreenID
    else
        m.ContextScreenID = invalid
    end if

    if item.server <> invalid AND item.server.AccessToken <> invalid then
        m.audioPlayer.AddHeader("X-Plex-Token", item.server.AccessToken)
    end if

    ' TODO: Do we want to loop? Always/Sometimes/Never/Preference?
    m.audioPlayer.SetLoop(context.Count() > 1 OR screen = invalid)

    m.audioPlayer.SetContentList(context)
    m.audioPlayer.SetNext(contextIndex)

    m.IsPlaying = false
    m.IsPaused = false
End Sub

Sub audioPlayerShowContextMenu()
    dialog = createBaseDialog()
    dialog.Title = "Now Playing"
    dialog.Text = firstOf(m.Context[m.CurIndex].Title, "")

    if m.IsPlaying then
        dialog.SetButton("pause", "Pause")
    else if m.IsPaused then
        dialog.SetButton("resume", "Play")
    else
        dialog.SetButton("play", "Play")
    end if
    dialog.SetButton("stop", "Stop")

    if m.Context.Count() > 1 then
        dialog.SetButton("next_track", "Next Track")
        dialog.SetButton("prev_track", "Previous Track")
    end if

    dialog.SetButton("show", "Go to Now Playing")
    dialog.SetButton("close", "Close")

    dialog.HandleButton = audioPlayerMenuHandleButton
    dialog.ParentScreen = m
    dialog.Show()
End Sub

Function audioPlayerMenuHandleButton(command, data) As Boolean
    ' We're evaluated in the context of the dialog, but we want to be in the
    ' context of the audio player.
    obj = m.ParentScreen

    if command = "play" then
        obj.Play()
    else if command = "pause" then
        obj.Pause()
    else if command = "resume" then
        obj.Resume()
    else if command = "stop" then
        obj.Stop()
    else if command = "next_track" then
        obj.Next()
    else if command = "prev_track" then
        obj.Prev()
    else if command = "show" then
        dummyItem = CreateObject("roAssociativeArray")
        dummyItem.ContentType = "audio"
        dummyItem.Key = "nowplaying"
        obj.ViewController.CreateScreenForItem(dummyItem, invalid, ["Now Playing"])
    else if command = "close" then
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

    m.SetContext([themeItem], 0, invalid)
    m.Play()
End Sub

Function audioPlayerGetPlaybackProgress() As Integer
    return m.playbackOffset + m.playbackTimer.GetElapsedSeconds()
End Function
