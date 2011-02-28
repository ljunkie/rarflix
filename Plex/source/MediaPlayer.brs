
Function playVideo(server, metadata, mediaData, seekValue) 
	print "Displaying video: ";metadata.title
	seconds = int(seekValue/1000)
	
	video = server.VideoScreen(metadata, mediaData, seconds)
	video.SetPositionNotificationPeriod(5)
    server.Scrobble(metadata.ratingKey, metadata.mediaContainerIdentifier)
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
            else if msg.isRequestFailed()
                print "play failed: "; msg.GetMessage()
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        end if
    end while
End Function
