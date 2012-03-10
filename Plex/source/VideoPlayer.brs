Function videoAddButtons(obj) As Object
    screen = obj.Screen
    metadata = obj.metadata
    media = obj.media

    buttonCommands = CreateObject("roAssociativeArray")
    screen.ClearButtons()
    buttonCount = 0
    if metadata.viewOffset <> invalid then
        intervalInSeconds = fix(val(metadata.viewOffset)/(1000))
        resumeTitle = "Resume from "+TimeDisplay(intervalInSeconds)
        screen.AddButton(buttonCount, resumeTitle)
        buttonCommands[str(buttonCount)] = "resume"
        buttonCount = buttonCount + 1
    endif
    screen.AddButton(buttonCount, "Play")
    buttonCommands[str(buttonCount)] = "play"
    buttonCount = buttonCount + 1

    print "Media = ";media
    print "Can direct play = ";videoCanDirectPlay(media)

    if metadata.viewCount <> invalid AND val(metadata.viewCount) > 0 then
        screen.AddButton(buttonCount, "Mark as unwatched")
        buttonCommands[str(buttonCount)] = "unscrobble"
        buttonCount = buttonCount + 1
    else
        if metadata.viewOffset <> invalid AND val(metadata.viewOffset) > 0 then
            screen.AddButton(buttonCount, "Mark as unwatched")
            buttonCommands[str(buttonCount)] = "unscrobble"
            buttonCount = buttonCount + 1
        end if
        screen.AddButton(buttonCount, "Mark as watched")
        buttonCommands[str(buttonCount)] = "scrobble"
        buttonCount = buttonCount + 1
    end if

    mediaPart = media.preferredPart
    subtitleStreams = []
    audioStreams = []
    for each Stream in mediaPart.streams
        if Stream.streamType = "2" then
            audioStreams.Push(Stream)
        else if Stream.streamType = "3" then
            subtitleStreams.Push(Stream)
        endif
    next
    print "Found audio streams:";audioStreams.Count()
    print "Found subtitle streams:";subtitleStreams.Count()
    if audioStreams.Count() > 1 then
        screen.AddButton(buttonCount, "Select audio stream")
        buttonCommands[str(buttonCount)] = "audioStreamSelection"
        buttonCount = buttonCount + 1
    endif
    if subtitleStreams.Count() > 0 then
        screen.AddButton(buttonCount, "Select subtitles")
        buttonCommands[str(buttonCount)] = "subtitleStreamSelection"
        buttonCount = buttonCount + 1
    endif

    if metadata.UserRating = invalid then
        metadata.UserRating = 0
    endif
    if metadata.StarRating = invalid then
        metadata.StarRating = 0
    endif
    screen.AddRatingButton(buttonCount, metadata.UserRating, metadata.StarRating)
    buttonCommands[str(buttonCount)] = "rateVideo"
    buttonCount = buttonCount + 1
    return buttonCommands
End Function

Function videoHandleMessage(msg) As Boolean
    server = m.Item.server

    if msg = invalid then
        m.msgTimeout = 0
        m.Refresh(true)
        return true
    else if msg.isButtonPressed() then
        buttonCommand = m.buttonCommands[str(msg.getIndex())]
        print "Button command: ";buttonCommand
        if buttonCommand = "play" OR buttonCommand = "resume" then
            startTime = 0
            if buttonCommand = "resume" then
                startTime = int(val(m.metadata.viewOffset))
            endif
            playVideo(server, m.metadata, startTime, true)
            '* Refresh play data after playing, but only after a timeout,
            '* otherwise we may leak objects if the play ended because the
            '* springboard was closed.
            m.msgTimeout = 1
        else if buttonCommand = "audioStreamSelection" then
            SelectAudioStream(server, m.media)
            m.Refresh(true)
        else if buttonCommand = "subtitleStreamSelection" then
            SelectSubtitleStream(server, m.media)
            m.Refresh(true)
        else if buttonCommand = "scrobble" then
            'scrobble key here
            server.Scrobble(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier)
            '* Refresh play data after scrobbling
            m.Refresh(true)
        else if buttonCommand = "unscrobble" then
            'unscrobble key here
            server.Unscrobble(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier)
            '* Refresh play data after unscrobbling
            m.Refresh(true)
	    else if buttonCommand = "rateVideo" then                
		    rateValue% = msg.getData() /10
		    m.metadata.UserRating = msg.getdata()
		    server.Rate(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier,rateValue%.ToStr())
        else
            return false
        endif

        return true
    end if

    return false
End Function

Sub playVideo(server, metadata, seekValue=0, allowDirectPlay=true)
	print "MediaPlayer::playVideo: Displaying video: ";metadata.title
	seconds = int(seekValue/1000)

    videoItem = server.ConstructVideoItem(metadata, seconds, allowDirectPlay)
    if videoItem = invalid then
        print "Can't play video, server was unable to construct video item"
        return
    end if

    port = CreateObject("roMessagePort")
    videoPlayer = CreateObject("roVideoScreen")
    videoPlayer.SetMessagePort(port)
    videoPlayer.SetContent(videoItem)

    if videoItem.IsTranscoded then
        cookie = server.StartTranscode(videoItem.StreamUrls[0])
        if cookie <> invalid then
            videoPlayer.AddHeader("Cookie", cookie)
        end if
    end if

    videoPlayer.SetPositionNotificationPeriod(5)
    videoPlayer.Show()

    success = videoMessageLoop(server, metadata, port, videoItem.IsTranscoded)

    if NOT success then
        if videoItem.IsTranscoded then
            ' Nothing left to fall back to, tell the user
            dialog = createBaseDialog()
            dialog.Title = "Video Unavailable"
            dialog.Text = "We're unable to play this video, make sure the server is running and has access to this video."
            dialog.Show()
        else
            playVideo(server, metadata, seekValue, false)
        end if
    end if
End Sub

Function videoCanDirectPlay(mediaItem As Object) As Boolean
    print "Media item optimized for streaming: "; mediaItem.optimized

    if (mediaItem.optimized <> "true" AND mediaItem.optimized <> "1")
        print "videoCanDirectPlay: media is not optimized"
        return false
    end if

    print "Media item container: "; mediaItem.container
    print "Media item video codec: "; mediaItem.videoCodec
    print "Media item audio codec: "; mediaItem.audioCodec

    if (mediaItem.container <> "mp4" AND mediaItem.container <> "mov" AND mediaItem.container <> "mkv") then
        print "videoCanDirectPlay: container not mp4/mov/mkv"
        return false
    end if

    if mediaItem.videoCodec <> "h264" then
        print "videoCanDirectPlay: vc not h264"
        return false
    end if

    if (mediaItem.audioCodec <> "aac" AND mediaItem.audioCodec <> "ac3" AND mediaItem.audioCodec <> "mp3") then
        print "videoCanDirectPlay: ac not aac/ac3/mp3"
        return false
    end if

    return true
End Function

Function videoMessageLoop(server, metadata, messagePort, transcoded) As Boolean
    scrobbleThreshold = 0.90
    lastPosition = 0
    played = false
    success = true

    while true
    	' Time out after 60 seconds causing invalid event allowing ping to be sent during 
    	' long running periods with no video events (e.g. user pause). Note that this timeout
    	' has to be bigger than the SetPositionNotificationPeriod above to allow actual
    	' video screen isPlaybackPosition events to be generated and reacted to
        msg = wait(60005, messagePort)
        print "MediaPlayer::playVideo: Reacting to video screen event message -> ";msg
        if transcoded then server.PingTranscode()
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then
                print "MediaPlayer::playVideo::VideoScreenEvent::isScreenClosed: position -> "; lastPosition
                if metadata.ratingKey <> invalid then
                    if played then
                        print "MediaPlayer::playVideo::VideoScreenEvent::isScreenClosed: scrobbling media -> ";metadata.ratingKey
                        server.Scrobble(metadata.ratingKey, metadata.mediaContainerIdentifier)
                    else
                        server.SetProgress(metadata.ratingKey, metadata.mediaContainerIdentifier, 1000*lastPosition)
                    end if
                end if
                if transcoded then server.StopVideo()
                exit while
            else if msg.isPlaybackPosition() then
                lastPosition = msg.GetIndex()
                if metadata.ratingKey <> invalid then
                    if metadata.Length <> invalid AND metadata.Length > 0 then
                        playedFraction = lastPosition/metadata.Length
                        print "MediaPlayer::playVideo::VideoScreenEvent::isPlaybackPosition: position -> "; lastPosition;" playedFraction -> "; playedFraction
                        if playedFraction > scrobbleThreshold then
                            played = true
                        end if
                    end if
                    print "MediaPlayer::playVideo::VideoScreenEvent::isPlaybackPosition: set progress -> ";1000*lastPosition
                    server.SetProgress(metadata.ratingKey, metadata.mediaContainerIdentifier, 1000*lastPosition)
                end if
            else if msg.isRequestFailed() then
                print "MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - message = "; msg.GetMessage()
                print "MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - data = "; msg.GetData()
                print "MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - index = "; msg.GetIndex()
                success = false
            else if msg.isPaused() then
                print "MediaPlayer::playVideo::VideoScreenEvent::isPaused: position -> "; lastPosition
            else if msg.isPartialResult() then
                if metadata.Length <> invalid AND metadata.Length > 0 then
                	playedFraction = lastPosition/metadata.Length
                	print "MediaPlayer::playVideo::VideoScreenEvent::isPartialResult: position -> "; lastPosition;" playedFraction -> "; playedFraction
            		if playedFraction > scrobbleThreshold then
            			played = true
            		end if
            	end if
                if transcoded then server.StopVideo()
            else if msg.isFullResult() then
            	print "MediaPlayer::playVideo::VideoScreenEvent::isFullResult: position -> ";lastPosition
    			played = true
                if transcoded then server.StopVideo()
                success = true
            else if msg.isStreamStarted() then
            	print "MediaPlayer::playVideo::VideoScreenEvent::isStreamStarted: position -> ";lastPosition
            	print "Message data -> ";msg.GetInfo()
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        end if
    end while

    return success
End Function

