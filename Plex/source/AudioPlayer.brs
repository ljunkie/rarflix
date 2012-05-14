'**********************************************************
'**  Audio Player Example Application - Audio Playback
'**  November 2009
'**  Copyright (c) 2009 Roku Inc. All Rights Reserved.
'**********************************************************

' playstate
' 0 = stopped
' 1 = paused
' 2 = playing

REM ******************************************************
REM
REM Update buttons based on state
REM
REM ******************************************************
Sub audioPlayer_setbuttons(obj)
    screen = obj.Screen
    metadata = obj.metadata
    media = obj.media
    playstate = obj.isPlayState

    screen.ClearButtons()

    if NOT m.IsPlayable then return

    if (playstate = 2)  then ' playing
        screen.AddButton(0, "pause playing")
        if m.Context.Count() > 1 then
            screen.AddButton(3, "next song")
            screen.AddButton(4, "previous song")
        end if
        screen.AddButton(2, "stop playing")
    else if (playstate = 1) then ' paused
        screen.AddButton(1, "resume playing")
        if m.Context.Count() > 1 then
            screen.AddButton(3, "next song")
            screen.AddButton(4, "previous song")
        end if
        screen.AddButton(2, "stop playing")
    else ' stopped
        screen.AddButton(1, "start playing")
        if m.Context.Count() > 1 then
            screen.AddButton(3, "next song")
            screen.AddButton(4, "previous song")
        end if
    endif

    if metadata.UserRating = invalid then
        metadata.UserRating = 0
    endif
    if metadata.StarRating = invalid then
        metadata.StarRating = 0
    endif
    screen.AddButton(6, "more...")
End Sub

REM ******************************************************
REM
REM Play audio
REM
REM ******************************************************
Sub audioPlayer_newstate(newstate as integer)
    if newstate = m.isplaystate return    ' already there

    if newstate = 0 then            ' STOPPED
        m.Screen.SetProgressIndicatorEnabled(false)
        m.audioPlayer.Stop()
        m.isPlayState = 0
        m.MsgTimeout = 0
    else if newstate = 1 then        ' PAUSED
        m.audioPlayer.Pause()
        m.isPlayState = 1
        m.MsgTimeout = 0
    else if newstate = 2 then        ' PLAYING
        if m.isplaystate = 0
            m.audioPlayer.play()    ' STOP->START
        else
            m.audioPlayer.Resume()    ' PAUSE->START
        endif
        m.isPlayState = 2
        m.MsgTimeout = 1000
    endif
End Sub

Function audioHandleMessage(msg) As Boolean
    server = m.Item.server

    if type(msg) = "roAudioPlayerEvent" then
        if msg.isRequestSucceeded() then
            Debug("Playback of single song completed")

            if m.metadata.ratingKey <> invalid then
                Debug("Scrobbling audio track -> " + tostr(m.metadata.ratingKey))
                server.Scrobble(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier)
            end if

            m.GotoNextItem()
        else if msg.isRequestFailed() then
            Debug("Playback failed")
            m.GotoNextItem()
        else if msg.isListItemSelected() then
            Debug("Starting to play item: " + tostr(m.metadata.Url))
            m.Refresh(true)
            m.progressOffset = 0
            m.progressTimer.Mark()

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
            m.setPlayState(0)
            m.Refresh(false)

            if m.metadata.Url = "" then
                ' TODO(schuyler): Show something more useful, especially once
                ' there's a server version that transcodes audio.
                dialog = createBaseDialog()
                dialog.Title = "Content Unavailable"
                dialog.Text = "We're unable to play this audio format."
                dialog.Show()
                dialog = invalid
            end if
        else if msg.isPartialResult() then
            Debug("isPartialResult")
        else if msg.isPaused() then
            Debug("Stream paused by user")
            m.progressOffset = m.progressOffset + m.progressTimer.TotalSeconds()
        else if msg.isResumed() then
            Debug("Stream resumed by user")
            m.progressTimer.Mark()
        end if
        return true
    else if msg = invalid then
        if m.isPlayState = 2 AND m.metadata.Duration <> invalid then
            m.Screen.SetProgressIndicator(m.progressOffset + m.progressTimer.TotalSeconds(), m.metadata.Duration)
        else
            m.MsgTimeout = 0
        end if
        return true
    else if msg.isRemoteKeyPressed() then
        Debug("audioHandleMessage: current index = " + tostr(m.curindex))

        button = msg.GetIndex()
        Debug("Remote Key button = " + tostr(button))
        newstate = m.isPlayState
        if button = 5 or button = 9 ' next
            if m.GotoNextItem() then
                m.setPlayState(0) ' stop
                m.audioPlayer.SetNext(m.CurIndex)
                m.setPlayState(2)
            end if
        else if button = 4 or button = 8 ' prev
            if m.GotoPrevItem() then
                m.setPlayState(0) ' stop
                m.audioPlayer.SetNext(m.CurIndex)
                m.setPlayState(2)
            end if
        end if
        m.AddButtons(m)
        return true
    else if msg.isButtonPressed() then
        button = msg.GetIndex()
        Debug("button index: " + tostr(button))
        newstate = m.isPlayState
        if button = 0 then
            newstate = 1
        else if button = 1 'play or resume
            newstate = 2
        else if button = 2 ' stop
            newstate = 0 ' now stopped
            m.audioPlayer.SetNext(m.CurIndex)
        else if button = 3 ' next
            if m.GotoNextItem() then
                m.setPlayState(0) ' stop
                newstate = 2
            end if
        else if button = 4 ' previous
            if m.GotoPrevItem() then
                m.setPlayState(0) ' stop
                newstate = 2
            end if
        else if button = 6 ' more
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
        end if
        m.setPlayState(newstate)
        m.AddButtons(m)
        return true
    end if

    return false
End Function

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

