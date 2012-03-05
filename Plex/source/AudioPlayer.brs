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
        screen.AddButton(1, "pause playing")
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
REM Setup song
REM
REM ******************************************************
Sub audioPlayer_setup(song As string, format as string)
    m.setPlayState(0)
    item = CreateObject("roAssociativeArray")
    item.Url = song
    item.StreamFormat = format
    m.audioPlayer.AddContent(item)
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
    else if newstate = 1 then        ' PAUSED
        m.audioPlayer.Pause()
        m.isPlayState = 1
    else if newstate = 2 then        ' PLAYING
        if m.isplaystate = 0
            m.audioPlayer.play()    ' STOP->START
        else
            m.audioPlayer.Resume()    ' PAUSE->START
        endif
        m.isPlayState = 2
    endif
End Sub

REM ******************************************************
REM
REM Clear content
REM
REM ******************************************************
Sub audioPlayer_clear_content()
    m.audioPlayer.ClearContent()
End Sub

REM ******************************************************
REM
REM Set content list
REM
REM ******************************************************
Sub audioPlayer_set_content_list(contentList As Object) 
    m.audioPlayer.SetContentList(contentList)
End Sub


REM ******************************************************
REM
REM Get Message events
REM Return with audioplayer events or events for the 'escape' active screen
REM
REM ******************************************************
Function audioPlayer_getmsg(timeout as Integer, escape as String) As Object
    'print "In audioPlayer get selection - Waiting for msg escape=" ; escape
    while true
        msg = wait(timeout, m.port)
        'print "Got msg = "; type(msg)
        if type(msg) = "roAudioPlayerEvent" return msg
        if type(msg) = escape return msg
        if type(msg) = "Invalid" return msg
        ' eat all other messages
    end while
End Function

REM ******************************************************
REM
REM TODO: Need to check and see if this is actually used anywhere...
REM
REM ******************************************************
Function playAlbum(server, metadata)
    print "Playing album: ";metadata.title
    audioplayer = server.AudioPlayer(metadata)
    audioplayer.play()
    
    while true
        msg = wait(0, audioplayer.GetMessagePort())
        print "Message:";type(msg)
        if type(msg) = "roAudioPlayerEvent"
            print "roAudioPlayerEvent: "; msg.getmessage() 
            if msg.isRequestSucceeded() then 
                exit while
            else if msg.isPaused() then
                audioplayer.pause()
            else if msg.isResumed() then
                audioplayer.resume()
            else if msg.isRequestFailed()
                print "playAlbum::isRequestFailed: message = "; msg.GetMessage()
                print "playAlbum::isRequestFailed: data = "; msg.GetData()
                print "playAlbum::isRequestFailed: index = "; msg.GetIndex()
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        end if
    end while
End Function

Function audioHandleMessage(msg) As Boolean
    server = m.Item.server
    nextOffset = m.curindex
    prevOffset = m.curindex - 2
    if (prevOffset < 0) then
        prevOffset = 0
    end if

    if type(msg) = "roAudioPlayerEvent" then
        if msg.isRequestSucceeded() then
            Print "Playback of single song completed"
        else if msg.isRequestFailed() then
            Print "Playback failed"
        else if msg.isListItemSelected() then
            Print "Starting to play item"
            m.Refresh(true)
        else if msg.isStatusMessage() then
            'Print "Audio player status: "; msg.getMessage()
        else if msg.isFullResult() then
            Print "Playback of entire list finished"
        else if msg.isPartialResult() then
            Print "isPartialResult"
        else if msg.isPaused() then
            Print "Stream paused by user"
        else if msg.isResumed() then
            Print "Stream resumed by user"
        end if
        return true
    else if msg.isRemoteKeyPressed() then
        print "audioHandleMessage: current index = ";m.curindex
        print "audioHandleMessage: next = ";nextOffset
        print "audioHandleMessage: prev = ";prevOffset

        button = msg.GetIndex()
        print "Remote Key button = "; button
        newstate = m.isPlayState
        if button = 5 or button = 9 ' next
            m.setPlayState(0) ' stop
            m.audioPlayer.Stop()
            m.GotoNextItem()
            m.audioPlayer.SetNext(nextOffset)
            m.audioPlayer.Play()
            newstate = 2
        else if button = 4 or button = 8 ' prev
            m.setPlayState(0) ' stop
            m.audioPlayer.Stop()
            m.GotoPrevItem()
            m.audioPlayer.SetNext(prevOffset)
            m.audioPlayer.Play()
            newstate = 2
        end if
        m.setPlayState(newstate)
        m.AddButtons(m)
        return true
    else if msg.isButtonPressed() then
        button = msg.GetIndex()
        print "button index="; button
        newstate = m.isPlayState
        if button = 1 'pause or resume
            if m.isPlayState < 2    ' stopped or paused?
                if (m.isPlayState = 0)
                      m.audioplayer.setNext(0)
                end if
                newstate = 2  ' now playing
            else 'started
                newstate = 1 ' now paused
            end if
        else if button = 2 ' stop
            newstate = 0 ' now stopped
        else if button = 3 ' next
            m.setPlayState(0) ' stop
            m.audioPlayer.Stop()
            m.GotoNextItem()
            m.audioPlayer.SetNext(nextOffset)
            m.audioPlayer.Play()
            newstate = 2 
        else if button = 4 ' previous
            m.setPlayState(0) ' stop
            m.audioPlayer.Stop()
            m.GotoPrevItem()
            m.audioPlayer.SetNext(prevOffset)
            m.audioPlayer.Play()
            newstate = 2 
        else if button = 5 ' rating
            Print "audioHandleMessage:: Rate audio for key ";m.metadata.ratingKey
            rateValue% = (msg.getData() /10)
            m.metadata.UserRating = msg.getdata()
            if m.metadata.ratingKey = invalid then
                m.metadata.ratingKey = 0
            end if
            server.Rate(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier, rateValue%.ToStr())
        end if
        m.setPlayState(newstate)
        m.AddButtons(m)
        return true
    end if

    return false
End Function

