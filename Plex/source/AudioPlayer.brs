'**********************************************************
'**  Modified beyond recognition but originally based on:
'**  Audio Player Example Application - Audio Playback
'**  November 2009
'**  Copyright (c) 2009 Roku Inc. All Rights Reserved.
'**********************************************************

Function AudioPlayer()
    ' Unlike just about everything else, the audio player isn't a Screen.
    ' So we'll wrap the Roku audio player similarly, but not quite in the
    ' same way.

    if m.AudioPlayer = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.Port = GetViewController().GlobalMessagePort

        ' We need a ScreenID property in order to use the view controller for timers
        obj.ScreenID = -1

        obj.HandleMessage = audioPlayerHandleMessage
        obj.Cleanup = audioPlayerCleanup

        obj.StopKeepState = audioPlayerStopKeepState

        obj.Play = audioPlayerPlay
        obj.Pause = audioPlayerPause
        obj.Resume = audioPlayerResume
        obj.Stop = audioPlayerStop
        obj.Seek = audioPlayerSeek
        obj.Next = audioPlayerNext
        obj.Prev = audioPlayerPrev

        obj.player = CreateObject("roAudioPlayer")
        obj.player.SetMessagePort(obj.Port)

    obj.Context = invalid
    obj.CurIndex = invalid  ' var for index of displayed object ( can be different than object playing )
    obj.PlayIndex = invalid ' var for index of playing object
    obj.ContextScreenID = invalid
    obj.SetContext = audioPlayerSetContext

        obj.ShowContextMenu = audioPlayerShowContextMenu

        obj.PlayThemeMusic = audioPlayerPlayThemeMusic

    obj.ShufflePlay = false
    obj.IsPlaying = false
    obj.IsPaused = false

        obj.Repeat = 0
        obj.SetRepeat = audioPlayerSetRepeat
        NowPlayingManager().timelines["music"].attrs["repeat"] = "0"

        obj.IsShuffled = false
        obj.SetShuffle = audioPlayerSetShuffle
        NowPlayingManager().timelines["music"].attrs["shuffle"] = "0"

        obj.playbackTimer = createTimer()
        obj.playbackOffset = 0
        obj.GetPlaybackProgress = audioPlayerGetPlaybackProgress

        obj.UpdateNowPlaying = audioPlayerUpdateNowPlaying
        obj.OnTimerExpired = audioPlayerOnTimerExpired

        obj.IgnoreTimelines = false
        obj.timelineTimer = createTimer()
        obj.timelineTimer.Name = "timeline"
        obj.timelineTimer.SetDuration(1000, true)
        obj.timelineTimer.Active = false
        GetViewController().AddTimer(obj.timelineTimer, obj)

        ' Singleton
        m.AudioPlayer = obj
    end if

    return m.AudioPlayer
End Function

Function audioPlayerHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roAudioPlayerEvent" then
        handled = true
        item = m.Context[m.PlayIndex] ' curIndex is used for switching screens ( not always the music in the backgroud )

        UpdateButtons = invalid
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
                AnalyticsTracker().TrackEvent("Playback", firstOf(item.ContentType, "track"), item.mediaContainerIdentifier, amountPlayed)
            end if
            ' is m.Repeat set to 1 for normal music? seems related to theme loop
            if m.Repeat <> 1 then ' ljunkie - TODO verify - seems wrong
                maxIndex = m.Context.Count() - 1
                newIndex = m.PlayIndex + 1
                if newIndex > maxIndex then newIndex = 0
                m.CurIndex = newIndex 
                m.PlayIndex = newIndex
            end if
        else if msg.isRequestFailed() then
            Debug("Audio playback failed")
            m.IgnoreTimelines = false
            maxIndex = m.Context.Count() - 1
            newIndex = m.PlayIndex + 1
            if newIndex > maxIndex then newIndex = 0
            m.CurIndex = newIndex
            m.PlayIndex = newIndex
        else if msg.isListItemSelected() then
            Debug("Starting to play track: " + tostr(item.Url))
            m.IgnoreTimelines = false
            m.IsPlaying = true
            m.IsPaused = false
            ' ljunkie -- set AudioPlayer().ResumeOffset = intMS 
            '  before calling AudioPlayer().Play() to start at an offset
            if m.ResumeOffset <> invalid then 
                m.playbackOffset = int(m.ResumeOffset/1000)
                m.player.Seek(m.ResumeOffset)
                m.ResumeOffset = invalid
            else 
                m.playbackOffset = 0
            end if

            m.playbackTimer.Mark()
            GetViewController().DestroyGlitchyScreens()

            if m.Repeat = 1 then
                m.player.SetNext(m.CurIndex)
            end if

            if m.Context.Count() > 1 then
                NowPlayingManager().SetControllable("music", "skipPrevious", (m.CurIndex > 0 OR m.Repeat = 2))
                NowPlayingManager().SetControllable("music", "skipNext", (m.CurIndex < m.Context.Count() - 1 OR m.Repeat = 2))
            end if
        else if msg.isStatusMessage() then
            'Debug("Audio player status: " + tostr(msg.getMessage()))
            Debug("Audio player status (duplicates ok): " + tostr(msg.getMessage()))
            if tostr(msg.getMessage()) = "playback stopped" then 
                m.IsPlaying = false
                m.IsPaused = false
                UpdateButtons = true
            else if tostr(msg.getMessage()) = "start of play" then 
                m.IsPlaying = true
                m.IsPaused = false
                UpdateButtons = true
                ' refresh the slideshow overlay on music changes ( if applicable)
                if GetViewController().IsSlideShowPlaying() and PhotoPlayer() <> invalid and PhotoPlayer().overlay_audio then PhotoPlayer().OverlayToggle("forceShow")
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
            UpdateButtons = true
        else if msg.isResumed() then
            Debug("Stream resumed by user")
            m.IsPlaying = true
            m.IsPaused = false
            m.playbackTimer.Mark()
            UpdateButtons = true
        end if

        if UpdateButtons <> invalid then 
            screen = GetViewController().screens.peek()
            if screen <> invalid and screen.PlayState <> invalid and type(screen.SetupButtons) = "roFunction" then 
                if m.IsPlaying then 
                    screen.PlayState = 2
                else if m.IsPaused then 
                    screen.PlayState = 1
                else 
                    screen.PlayState = 0
                end if
                screen.SetupButtons()
            end if
        end if

        m.UpdateNowPlaying()
    end if

    return handled
End Function

Sub audioPlayerCleanup()
    m.Stop()
    m.timelineTimer = invalid
    fn = function() :m.AudioPlayer = invalid :end function
    fn()
End Sub

Sub audioPlayerPlay()
    if m.Context <> invalid then
        m.player.Play()
    end if
End Sub

Sub audioPlayerPause()
    if m.Context <> invalid then
        m.player.Pause()
    end if
End Sub

Sub audioPlayerResume()
    if m.Context <> invalid then
        m.player.Resume()
    end if
End Sub

Sub audioPlayerStop()
    if m.Context <> invalid then
        m.player.Stop()
        m.player.SetNext(m.PlayIndex)
        m.IsPlaying = false
        m.IsPaused = false
    end if
End Sub

Sub audioPlayerSeek(offset, relative=false)
    if relative then
        if m.IsPlaying then
            offset = offset + (1000 * m.GetPlaybackProgress())
        else if m.IsPaused then
            offset = offset + (1000 * m.playbackOffset)
        end if

        if offset < 0 then offset = 0
    end if

    if m.IsPlaying then
        m.playbackOffset = int(offset / 1000)
        m.playbackTimer.Mark()
        m.player.Seek(offset)
    else if m.IsPaused then
        ' If we just call Seek while paused, we don't get a resumed event. This
        ' way the UI is always correct, but it's possible for a blip of audio.
        m.playbackOffset = int(offset / 1000)
        m.playbackTimer.Mark()
        m.player.Resume()
        m.player.Seek(offset)
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
        m.IgnoreTimelines = true

        m.PlayIndex = newIndex ' only update if playing
        m.Stop()
        m.player.SetNext(newIndex)
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
        m.IgnoreTimelines = true

        m.PlayIndex = newIndex ' only update if playing
        m.Stop()
        m.player.SetNext(newIndex)
        m.Play()
    end if
End Sub

Sub audioPlayerSetContext(context, contextIndex, screen, startPlayer)
    if NOT AppManager().IsPlaybackAllowed() then
        GetViewController().ShowPlaybackNotAllowed()
        return
    end if

    if startPlayer then
        m.IgnoreTimelines = true
        m.Stop()
    end if

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
        AddAccountHeaders(m.player, item.server.AccessToken)
    end if

    if screen = invalid then
        if RegRead("theme_music", "preferences", "disabled") = "loop" then
            m.Repeat = 1
        else
            m.Repeat = 0
        end if
    else
        pref = RegRead("loopalbums", "preferences", "sometimes")
        if pref = "sometimes" then
            loop = (context.Count() > 1)
        else
            loop = (pref = "always")
        end if
        if loop then
            m.SetRepeat(2)
        else
            m.SetRepeat(0)
        end if
    end if

    m.player.SetLoop(m.Repeat = 2)
    m.player.SetContentList(context)

    m.IsShuffled = (screen <> invalid AND screen.IsShuffled)
    if m.IsShuffled then
        NowPlayingManager().timelines["music"].attrs["shuffle"] = "1"
    else
        NowPlayingManager().timelines["music"].attrs["shuffle"] = "0"
    end if

    NowPlayingManager().SetControllable("music", "skipPrevious", context.Count() > 1)
    NowPlayingManager().SetControllable("music", "skipNext", context.Count() > 1)

    if startPlayer then
        m.player.SetNext(contextIndex)
        m.IsPlaying = false
        m.IsPaused = false
    else
        maxIndex = context.Count() - 1
        newIndex = contextIndex + 1
        if newIndex > maxIndex then newIndex = 0
        m.player.SetNext(newIndex)
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
    screen = GetViewController().screens.Peek()
    if type(screen.screen) = "roSlideShow" then 
        m.slideshow = screen
        print m.slideshow
        if type(m.slideshow.CurIndex) = "roInteger" and type(m.slideshow.items) = "roArray" then  ' ljunkie - show the photo title a slide show is in progress
            dialog.Text = dialog.Text + chr(10) + " Photo: " + tostr(m.slideshow.items[m.slideshow.CurIndex].title)
            if m.slideshow.isPaused = invalid then m.slideshow.isPaused = false
        end if 
    else if type(screen.screen) = "roImageCanvas" and tostr(screen.imagecanvasname) = "slideshow" then 
        dialog.EnableOverlay = true
        m.slideshow = screen
        if type(m.slideshow.CurIndex) = "roInteger" and type(m.slideshow.context) = "roArray" then  ' ljunkie - show the photo title a slide show is in progress
            dialog.Text = dialog.Text + chr(10) + " Photo: " + tostr(m.slideshow.context[m.slideshow.CurIndex].title)
            if m.slideshow.isPaused = invalid then m.slideshow.isPaused = false
        end if 
    else 
        m.slideshow = invalid
    end if

    if m.focusedbutton = invalid then m.focusedbutton = 0 
    focusbutton = m.focusedbutton
    append = ""

    ' slide shows get more buttons
    if m.slideshow <> invalid
        append = " Audio"
        ' variable buttons.. we might have to +1 our focusedButton 
        ' - logic will break if we add more buttons, so keep note of that
        variable = 0 
        if (m.slideshow.isPaused and NOT m.slideshow.forceresume = true) or m.isPaused then
            dialog.SetButton("resumeAll", "Resume All")
            variable = variable +1
        end if
        if NOT m.slideshow.isPaused or m.isPlaying then 
            dialog.SetButton("pauseAll", "Pause All")
            variable = variable +1
        end if

        ' shuffle for slideshow needs to be unique ( music will have a shuffle button too )
        if m.slideshow.isShuffled then 
            dialog.SetButton("shufflePhoto", "Photo Shuffle: On")
            variable = variable +1
        else 
            dialog.SetButton("shufflePhoto", "Photo Shuffle: Off")
            variable = variable +1
        end if

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

    screen = GetViewController().screens.peek()
    dialogSetSortingButton(dialog,screen) 

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
    ' ljunkie - sometimes we need to use the actually parent screen and not the audioPlayer singleton
    dialog.RealParentScreen = GetViewController().screens.peek()
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
        if type(obj.slideshow.screen) = "roImageCanvas" then 
            obj.slideshow.Pause()
            obj.slideshow.forceResume = false
        else 
            obj.slideshow.screen.Pause()
            obj.slideshow.isPaused = true
            obj.slideshow.forceResume = false
        end if
        obj.Pause()
    else if command = "resume" then
        obj.focusedbutton = 0 
        obj.Resume()
    else if command = "resumeAll" then
        obj.focusedbutton = 0
        ' we only get here if we know we are playing a slideshow too
        if type(obj.slideshow.screen) = "roImageCanvas" then 
            obj.slideshow.Resume()
        else 
            obj.slideshow.screen.Resume()
            obj.slideshow.isPaused = false
            obj.slideshow.forceResume = false
        end if

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
        GetViewController().CreateScreenForItem(dummyItem, invalid, ["Now Playing"])
    else if command = "close" then
        obj.focusedbutton = 0 
        return true
    else if command = "shufflePhoto" then
        if obj.slideshow.IsShuffled then 
            obj.slideshow.SetShuffle(0)
            m.SetButton(command, "Photo Shuffle: Off")
        else 
            obj.slideshow.SetShuffle(1)
            m.SetButton(command, "Photo Shuffle: On")
        end if

        ' refresh buttons and slideshow overlay
        m.Refresh()
        obj.slideshow.Refresh()

        ' keep dialog open
        return false
    else if command = "SectionSorting" then
        dialog = createGridSortingDialog(m,m.RealParentScreen)
        if dialog <> invalid then dialog.Show(true)
        return false
    else if command = "gotoFilters" then
        ' audio dialog is special. Get the original item from the grid screen
        ' TODO(ljunkie) dedupe this block elsewhere
        parentScreen = m.RealParentScreen
        item = m.RealParentScreen.originalItem
        createFilterSortScreenFromItem(item, parentScreen)
        closeDialog = true
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

Sub audioPlayerOnTimerExpired(timer)
    if timer.Name = "timeline"
        m.UpdateNowPlaying()
    end if
End Sub

Sub audioPlayerUpdateNowPlaying()
    if m.IgnoreTimelines then return
    state = "stopped"
    item = invalid
    time = 0

    m.timelineTimer.Active = m.IsPlaying

    if m.IsPlaying then
        state = "playing"
        time = 1000 * m.GetPlaybackProgress()
        item = m.Context[m.PlayIndex]
    else if m.IsPaused then
        state = "paused"
        time = 1000 * m.playbackOffset
        item = m.Context[m.PlayIndex]
    else if m.Context <> invalid then
        item = m.Context[m.CurIndex]
    end if

    if m.ContextScreenID <> invalid then
        NowPlayingManager().UpdatePlaybackState("music", item, state, time)
    end if
End Sub

Sub audioPlayerSetRepeat(repeatVal)
    if m.Repeat = repeatVal then return

    m.Repeat = repeatVal
    m.player.SetLoop(repeatVal = 2)

    if repeatVal = 1 then
        m.player.SetNext(m.CurIndex)
    end if

    NowPlayingManager().timelines["music"].attrs["repeat"] = tostr(repeatVal)
End Sub

Sub audioPlayerSetShuffle(shuffleVal)
    newVal = (shuffleVal = 1)
    if newVal = m.IsShuffled then return

    m.IsShuffled = newVal
    if m.IsShuffled then
        m.CurIndex = ShuffleArray(m.Context, m.CurIndex)
    else
        m.CurIndex = UnshuffleArray(m.Context, m.CurIndex)
    end if

    m.player.SetContentList(m.Context)
    maxIndex = m.Context.Count() - 1
    newIndex = m.CurIndex + 1
    if newIndex > maxIndex then newIndex = 0
    m.player.SetNext(newIndex)

    NowPlayingManager().timelines["music"].attrs["shuffle"] = tostr(shuffleVal)
End Sub

' used when someone plays a Video on top of an Audio/Slideshow
' this way we can resume audio when the video is closed 
' ( PhotoPlayerImageCanvas.brs has the same routine )
Sub audioPlayerStopKeepState()
    if m.Context <> invalid then
        if m.IsPlaying and m.PlayIndex <> invalid then 
            m.ResumeOffset = int(1000*m.GetPlaybackProgress())
            m.ForceResume = true
            m.player.SetNext(m.PlayIndex)
        end if
        m.player.Stop()
        m.IsPlaying = false
        m.IsPaused = false
        NowPlayingManager().location = "navigation"
        NowPlayingManager().UpdatePlaybackState("music", invalid, "stopped", 0)
    end if
End Sub
