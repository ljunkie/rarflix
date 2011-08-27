
Function playVideo(server, metadata, mediaData, seekValue) 
	print "Displaying video: ";metadata.title
	seconds = int(seekValue/1000)
	
	video = server.VideoScreen(metadata, mediaData, seconds)
	video.SetPositionNotificationPeriod(5)
	video.show()
    scrobbleThreshold = 0.90
    lastPosition = 0
    while true
        msg = wait(0, video.GetMessagePort())
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then
                print "Video Stop at -> "; lastPosition
            	server.SetProgress(metadata.ratingKey, metadata.mediaContainerIdentifier, 1000*lastPosition)
                server.StopVideo()
                exit while
            else if msg.isPlaybackPosition() then
                lastPosition = msg.GetIndex()
                print "Video Progress at -> "; lastPosition
                print "Compared to -> "; metadata.Length
                playedFraction = lastPosition/metadata.Length
                print "Played fraction -> "; playedFraction
            	
            	if playedFraction > scrobbleThreshold then
            		server.Scrobble(metadata.ratingKey, metadata.mediaContainerIdentifier)
            	else
            		server.SetProgress(metadata.ratingKey, metadata.mediaContainerIdentifier, 1000*lastPosition)
            	end if
            	server.PingTranscode()
            else if msg.isRequestFailed()
                print "play failed: "; msg.GetMessage()
            else if msg.isPaused()
                print "Video paused at -> "; lastPosition
            	server.PingTranscode()
            else if msg.isPartialResult()
                print "Video interrupted at -> "; lastPosition
                playedFraction = lastPosition/metadata.Length
                print "Played fraction -> "; playedFraction
            	if playedFraction > scrobbleThreshold then
            		server.Scrobble(metadata.ratingKey, metadata.mediaContainerIdentifier)
            	else
            		server.SetProgress(metadata.ratingKey, metadata.mediaContainerIdentifier, 1000*lastPosition)
            	end if
                server.StopVideo()
            else if msg.isFullResult()
                print "Video finished at -> "; lastPosition
    			server.Scrobble(metadata.ratingKey, metadata.mediaContainerIdentifier)
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        end if
    end while
End Function

Function playPluginVideo(server, metadata) 
	print "Displaying plugin video: ";metadata.title
	video = server.PluginVideoScreen(metadata)
	video.show()
    
    while true
        msg = wait(0, video.GetMessagePort())
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
