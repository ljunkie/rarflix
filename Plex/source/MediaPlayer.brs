
Function playVideo(server, metadata, mediaData, seekValue) 
	print "Displaying video: ";metadata.title
	seconds = int(seekValue/1000)
	
	video = server.VideoScreen(metadata, mediaData, seconds)
	video.SetPositionNotificationPeriod(5)
	' Scrobble shouldn't happen here. Figure out where.
    'server.Scrobble(metadata.ratingKey, metadata.mediaContainerIdentifier)
	video.show()
    
    lastPosition = 0
    while true
        msg = wait(0, video.GetMessagePort())
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then
            	server.SetProgress(metadata.ratingKey, metadata.mediaContainerIdentifier, 1000*lastPosition)
                server.StopVideo()
                exit while
            else if msg.isPlaybackPosition() then
                lastPosition = msg.GetIndex()
                print "Progress"; lastPosition
            	server.SetProgress(metadata.ratingKey, metadata.mediaContainerIdentifier, 1000*lastPosition)
            else if msg.isRequestFailed()
                print "play failed: "; msg.GetMessage()
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
            else if msg.isRequestFailed()
                print "play failed: "; msg.GetMessage()
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
