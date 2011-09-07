
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
                print "MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed "; msg.GetMessage()
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
                print "play failed: "; msg.GetMessage()
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
                print "play failed: "; msg.GetMessage()
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        end if
    end while
End Function
