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
    print "metadata.optimizedForStreaming = ";metadata.optimizedForStreaming

    if media.container <> invalid AND media.videocodec <> invalid AND media.audiocodec <> invalid AND metadata.optimizedforstreaming <> invalid then
        dsp = 0
        ' MP4 files
        if media.container = "mov" then
            if media.videocodec = "h264" AND (media.audiocodec = "aac" OR media.audicodec = "ac3") then
                dsp = 1
            end if
        end if
        ' MKV files
        if media.container = "mkv" then
            if media.videocodec = "h264" AND (media.audiocodec = "aac" OR media.audicodec = "ac3") then
                dsp = 1
            end if
        end if

        if metadata.optimizedForStreaming = "0" AND dsp = 1 then
            print "Container = "+media.container+", ac = "+media.audiocodec+", vc = "+media.videocodec+", but not optimized for streaming"
            dsp = 0
        else if dsp = 1 then
            print "Container = "+media.container+", ac = "+media.audiocodec+", vc = "+media.videocodec+", OPTIMIZED FOR STREAMING"
        end if
    end if

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
        m.Refresh()
        return true
    else if msg.isButtonPressed() then
        buttonCommand = m.buttonCommands[str(msg.getIndex())]
        print "Button command: ";buttonCommand
        if buttonCommand = "play" OR buttonCommand = "resume" then
            startTime = 0
            if buttonCommand = "resume" then
                startTime = int(val(m.metadata.viewOffset))
            endif
            playVideo(server, m.metadata, m.media, startTime)
            '* Refresh play data after playing, but only after a timeout,
            '* otherwise we may leak objects if the play ended because the
            '* springboard was closed.
            m.msgTimeout = 1
        else if buttonCommand = "audioStreamSelection" then
            SelectAudioStream(server, m.media)
            m.Refresh()
        else if buttonCommand = "subtitleStreamSelection" then
            SelectSubtitleStream(server, m.media)
            m.Refresh()
        else if buttonCommand = "scrobble" then
            'scrobble key here
            server.Scrobble(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier)
            '* Refresh play data after scrobbling
            m.Refresh()
        else if buttonCommand = "unscrobble" then
            'unscrobble key here
            server.Unscrobble(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier)
            '* Refresh play data after unscrobbling
            m.Refresh()
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

Function playVideo(server, metadata, mediaData, seekValue) 
	print "MediaPlayer::playVideo: Displaying video: ";metadata.title
	seconds = int(seekValue/1000)
	
	video = server.VideoScreen(metadata, mediaData, seconds)
	video.SetPositionNotificationPeriod(5)
	video.show()
    scrobbleThreshold = 0.90
    lastPosition = 0
    played = false
    while true
    	' Time out after 60 seconds causing invalid event allowing ping to be sent during 
    	' long running periods with no video events (e.g. user pause). Note that this timeout
    	' has to be bigger than the SetPositionNotificationPeriod above to allow actual
    	' video screen isPlaybackPosition events to be generated and reacted to
        msg = wait(60005, video.GetMessagePort())
        print "MediaPlayer::playVideo: Reacting to video screen event message -> ";msg
        server.PingTranscode()
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then
                print "MediaPlayer::playVideo::VideoScreenEvent::isScreenClosed: position -> "; lastPosition
                if played then
            		print "MediaPlayer::playVideo::VideoScreenEvent::isScreenClosed: scrobbling media -> ";metadata.ratingKey
                	server.Scrobble(metadata.ratingKey, metadata.mediaContainerIdentifier)
                else
            		server.SetProgress(metadata.ratingKey, metadata.mediaContainerIdentifier, 1000*lastPosition)
            	end if
                server.StopVideo()
                exit while
            else if msg.isPlaybackPosition() then
                lastPosition = msg.GetIndex()
                if metadata.Length <> invalid AND metadata.Length > 0 then
                    playedFraction = lastPosition/metadata.Length
                    print "MediaPlayer::playVideo::VideoScreenEvent::isPlaybackPosition: position -> "; lastPosition;" playedFraction -> "; playedFraction
            	    if playedFraction > scrobbleThreshold then
            		    played = true
            	    end if
            	end if
            	print "MediaPlayer::playVideo::VideoScreenEvent::isPlaybackPosition: set progress -> ";1000*lastPosition
            	server.SetProgress(metadata.ratingKey, metadata.mediaContainerIdentifier, 1000*lastPosition)
            	server.PingTranscode()
            else if msg.isRequestFailed() then
                print "MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - message = "; msg.GetMessage()
                print "MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - data = "; msg.GetData()
                print "MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - index = "; msg.GetIndex()
            else if msg.isPaused() then
                print "MediaPlayer::playVideo::VideoScreenEvent::isPaused: position -> "; lastPosition
            	server.PingTranscode()
            else if msg.isPartialResult() then
                if metadata.Length <> invalid AND metadata.Length > 0 then
                	playedFraction = lastPosition/metadata.Length
                	print "MediaPlayer::playVideo::VideoScreenEvent::isPartialResult: position -> "; lastPosition;" playedFraction -> "; playedFraction
            		if playedFraction > scrobbleThreshold then
            			played = true
            		end if
            	end if
                server.StopVideo()
            else if msg.isFullResult() then
            	print "MediaPlayer::playVideo::VideoScreenEvent::isFullResult: position -> ";lastPosition
    			played = true
                server.StopVideo()
            else if msg.isStreamStarted() then
            	print "MediaPlayer::playVideo::VideoScreenEvent::isStreamStarted: position -> ";lastPosition
            	print "Message data -> ";msg.GetInfo()
            else
                print "MediaPlayer::playVideo::VideoScreenEvent::Uncaptured event: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        end if
    end while
End Function

'* TODO: should we scrobble and set played amount on plugin videos?
Function playPluginVideo(server, metadata) 
	print "MediaPlayer::playPluginVideo: Displaying plugin video: ";metadata.title
	video = server.PluginVideoScreen(metadata)
	video.show()
    
    while true
        msg = wait(60005, video.GetMessagePort())
        print "MediaPlayer::playPluginVideo: Reacting to video screen event message -> ";msg
        server.PingTranscode()
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then
                server.StopVideo()
                exit while
            else if msg.isPlaybackPosition() then
            	server.PingTranscode()
            else if msg.isRequestFailed()
                print "playPluginVideo::isRequestFailed: message = "; msg.GetMessage()
                print "playPluginVideo::isRequestFailed: data = "; msg.GetData()
                print "playPluginVideo::isRequestFailed: index = "; msg.GetIndex()
            else if msg.isPaused()
                print "Video paused at -> "; lastPosition
            	server.PingTranscode()
            else if msg.isPartialResult()
                print "Video interrupted at -> "; lastPosition
                server.StopVideo()
            else if msg.isFullResult()
                server.StopVideo()
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        end if
    end while
End Function
