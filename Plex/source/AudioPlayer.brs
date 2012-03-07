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
    if (playstate = 2)  then ' playing
        screen.AddButton(0, "pause playing")
        screen.AddButton(3, "next song")
        screen.AddButton(4, "previous song")
        screen.AddButton(2, "stop playing")
    else if (playstate = 1) then ' paused
        screen.AddButton(1, "resume playing")
        screen.AddButton(3, "next song")
        screen.AddButton(4, "previous song")
        screen.AddButton(2, "stop playing")
    else ' stopped
        screen.AddButton(1, "start playing")
        screen.AddButton(3, "next song")
        screen.AddButton(4, "previous song")
    endif

    if metadata.UserRating = invalid then
        metadata.UserRating = 0
    endif
    if metadata.StarRating = invalid then
        metadata.StarRating = 0
    endif
    screen.AddRatingButton(5, metadata.UserRating, metadata.StarRating)
End Sub

REM ******************************************************
REM
REM Play audio
REM
REM ******************************************************
Sub audioPlayer_newstate(newstate as integer)
    if newstate = m.isplaystate return    ' already there

    if newstate = 0 then            ' STOPPED
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
            Print "Playback of single song completed"

            if m.metadata.ratingKey <> invalid then
                print "Scrobbling audio track -> "; m.metadata.ratingKey
                server.Scrobble(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier)
            end if

            m.GotoNextItem()
        else if msg.isRequestFailed() then
            Print "Playback failed"
        else if msg.isListItemSelected() then
            Print "Starting to play item"
            m.Refresh(true)
            m.progressOffset = 0
            m.progressTimer.Mark()
        else if msg.isStatusMessage() then
            'Print "Audio player status: "; msg.getMessage()
        else if msg.isFullResult() then
            Print "Playback of entire list finished"
        else if msg.isPartialResult() then
            Print "isPartialResult"
        else if msg.isPaused() then
            Print "Stream paused by user"
            m.progressOffset = m.progressOffset + m.progressTimer.TotalSeconds()
        else if msg.isResumed() then
            Print "Stream resumed by user"
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
        print "audioHandleMessage: current index = ";m.curindex

        button = msg.GetIndex()
        print "Remote Key button = "; button
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
        print "button index="; button
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
        else if button = 5 ' rating
            Print "audioHandleMessage:: Rate audio for key ";m.metadata.ratingKey
            rateValue% = (msg.getData() /10)
            m.metadata.UserRating = msg.getdata()
            if m.metadata.ratingKey <> invalid then
                server.Rate(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier, rateValue%.ToStr())
            end if
        end if
        m.setPlayState(newstate)
        m.AddButtons(m)
        return true
    end if

    return false
End Function

