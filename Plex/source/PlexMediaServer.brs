'*
'* Facade to a PMS server responsible for fetching PMS meta-data and
'* formatting into Roku format as well providing the interface to the
'* streaming media
'* 

'* Constructor for a specific PMS instance identified via the URL and 
'* human readable name, which can be used in section names
Function newPlexMediaServer(pmsUrl, pmsName) As Object
	pms = CreateObject("roAssociativeArray")
	pms.serverUrl = pmsUrl
	pms.name = pmsName
	pms.GetContent = directoryContent
	pms.VideoScreen = constructVideoScreen
	pms.StopVideo = stopTranscode
	return pms
End Function

Function directoryContent(sourceUrl, key) As Object
	queryUrl = FullUrl(m.serverUrl, sourceUrl, key)
	print "Server Query URL:";queryUrl
	httpRequest = NewHttp(queryUrl)
    response = httpRequest.GetToStringWithRetry()
    xml=CreateObject("roXMLElement")
    if not xml.Parse(response) then
         print "Can't parse feed"
        return invalid
    endif
    content = CreateObject("roArray", 10, true)
    for each directoryItem in xml.Directory
    	directoryType = directoryItem@type
    	directory = CreateObject("roAssociativeArray")
    	'* We need to know which server items come from so carry a reference to their home around
    	directory.server = m
    	directory.sourceUrl = queryUrl
		directory.ContentType = "Directory"
		directory.Key = directoryItem@key
		directory.Title = directoryItem@title
		directory.ShortDescriptionLine1 = directoryItem@title
		thumb = directoryItem@thumb
		if thumb <> invalid then
			directory.SDPosterURL = TranscodedImage(m.serverUrl, queryUrl, thumb, "256", "256")
			directory.HDPosterURL = TranscodedImage(m.serverUrl, queryUrl, thumb, "512", "512")
		else
			art = directoryItem@art
			if art <> invalid then
				directory.SDPosterURL = TranscodedImage(m.serverUrl, queryUrl, art, "256", "256")
				directory.HDPosterURL = TranscodedImage(m.serverUrl, queryUrl, art, "512", "512")
			endif
		endif
		
		if directoryItem@search = invalid then
			content.Push(directory)
		endif
    next
    for each videoItem in xml.Video
    	video = CreateObject("roAssociativeArray")
    	video.server = m
    	video.sourceUrl = queryUrl
    	video.ContentType = videoItem@type
    	video.Title = videoItem@title
		video.Key = videoItem@key
    	video.ShortDescriptionLine1 = videoItem@title
    	video.ShortDescriptionLine2 = videoItem@tagline
		thumb = videoItem@thumb
		'* these dimensions appear to slow down navigation. Maybe need to make it type specific
		'* and agree with the Roku dimensions
		if thumb <> invalid then
			video.SDPosterURL = TranscodedImage(m.serverUrl, queryUrl, thumb, "158", "204")
			video.HDPosterURL = TranscodedImage(m.serverUrl, queryUrl, thumb, "214", "306")
		else
			art = directoryItem@art
			if art <> invalid then
				video.SDPosterURL = TranscodedImage(m.serverUrl, queryUrl, art, "158", "204")
				video.HDPosterURL = TranscodedImage(m.serverUrl, queryUrl, art, "214", "306")
			endif
		endif
    	
    	'* TODO: need a way to choose between media options and concat parts
    	video.mediaKey = videoItem.Media.Part@Key
		content.Push(video)
    next
    for each trackItem in xml.Track
    	track = CreateObject("roAssociativeArray")
    	track.server = m
    	track.sourceUrl = queryUrl
    	track.ContentType = trackItem@type
    	track.Title = trackItem@title
		track.Key = trackItem@key
    	track.ShortDescriptionLine1 = trackItem@title
    	'* TODO: need a way to choose between media options and concat parts
    	track.mediaKey = trackItem.Media.Part@Key
    	
    	'* Use parent
    	'track.ShortDescriptionLine2 = trackItem@tagline
		'thumb = videoItem@thumb
    	'video.SDPosterURL = TranscodedImage(m.serverUrl, queryUrl, thumb, "158", "204")
    	'video.HDPosterURL = TranscodedImage(m.serverUrl, queryUrl, thumb, "214", "306")
		content.Push(track)
    next
    print "Found a content list with elements";content.count()
    return content
End Function

'* Currently assumes transcoding but could encapsulate finding a direct stream
Function constructVideoScreen(videoKey as String, title as String) As Object
    print "Constructing video screen for ";videoKey
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)
    videoclip = ConstructVideoClip(m.serverUrl, videoKey, title)
    video.SetContent(videoclip)
    m.Cookie = StartTranscodingSession(videoclip.StreamUrls[0])
	video.AddHeader("Cookie", m.Cookie)
	return video
End Function

Function stopTranscode()
	stopTransfer = CreateObject("roUrlTransfer")
    stopTransfer.SetUrl(m.serverUrl + "/video/:/transcode/segmented/stop")
    stopTransfer.AddHeader("Cookie", m.Cookie) 
    content = stopTransfer.GetToString()
End Function


'* Constructs a Full URL taking into account relative/absolute. Relative to the 
'* source URL, and absolute URLs, so
'* relative to the server URL
Function FullUrl(serverUrl, sourceUrl, key) As String
    print "ServerURL:";serverUrl
    print "SourceURL:";sourceUrl
    print "Key:";key
	finalUrl = ""
	if left(key, 1) = "/" then
		finalUrl = serverUrl+key
	else
		finalUrl = sourceUrl+"/"+key
	endif
	return finalUrl
End Function

'* Constructs an image based on a PMS url with the specific width and height. 
Function TranscodedImage(serverUrl, queryUrl, imagePath, width, height) As String
	imageUrl = FullUrl(serverUrl, queryUrl, imagePath)
	encodedUrl = HttpEncode(imageUrl)
	image = serverUrl + "/photo/:/transcode?url="+encodedUrl+"&width="+width+"&height="+height
	'print "Final Image URL:";image
	return image
End Function


'* Starts a transcoding session by issuing a HEAD request and captures
'* the resultant session ID from the cookie that can then be used to
'* access and stop the transcoding
Function StartTranscodingSession(videoUrl) As String
	cookiesRequest = CreateObject("roUrlTransfer")
	cookiesRequest.SetUrl(videoUrl)
	capabilities = "protocols=http-streaming-video;http-streaming-video-720p;http-streaming-video-1080p;videoDecoders=h264{profile:high&resolution:1080&level:40};audioDecoders=aac"
	cookiesRequest.AddHeader("X-Plex-Client-Capabilities", capabilities)
	cookiesHead = cookiesRequest.Head()
	cookieHeader = cookiesHead.GetResponseHeaders()["set-cookie"]
	return cookieHeader
End Function

'* Roku video clip definition as an array
Function ConstructVideoClip(serverUrl as String, videoUrl as String, title as String) As Object
	videoclip = CreateObject("roAssociativeArray")
    videoclip.StreamBitrates = [0]
    videoclip.StreamUrls = [TranscodingVideoUrl(serverUrl, videoUrl)]
    videoclip.StreamQualities = ["HD"]
    videoclip.StreamFormat = "hls"
    videoclip.Title = title
    return videoclip
End Function

'*
'* Construct the Plex transcoding URL. 
'*
Function TranscodingVideoUrl(serverUrl As String, videoUrl As String) As String
    
    location = serverUrl + videoUrl
    print "Location:";location
    '* Question here about how the quality is handled by Roku for q>6
    '* 
    myurl = "/video/:/transcode/segmented/start.m3u8?identifier=com.plexapp.plugins.library&ratingKey=97007888&offset=0&quality=7&url="+HttpEncode(location)+"&3g=0&httpCookies=&userAgent="
	'myurl = "/video/:/transcode/segmented/start.m3u8?identifier=com.plexapp.plugins.library&ratingKey=97007888&offset=0&minQuality=5&maxQuality=10&url="+HttpEncode(location)+"&3g=0&httpCookies=&userAgent="
	publicKey = "KQMIY6GATPC63AIMC4R2"
	time = LinuxTime().tostr()
	msg = myurl+"@"+time
	finalMsg = HMACHash(msg)
	finalUrl = serverUrl + myurl+"&X-Plex-Access-Key=" + publicKey + "&X-Plex-Access-Time=" + time + "&X-Plex-Access-Code=" + HttpEncode(finalMsg)
	print "Final URL";finalUrl
    return finalUrl
End Function

'*
'* HMAC encode the message
'* 
Function HMACHash(msg As String) As String
	hmac = CreateObject("roHMAC") 
	privateKey = CreateObject("roByteArray") 
	privateKey.fromBase64String("k3U6GLkZOoNIoSgjDshPErvqMIFdE0xMTx8kgsrhnC0=")
	result = hmac.setup("sha256", privateKey)
	if result = 0
		message = CreateObject("roByteArray") 
		message.fromAsciiString(msg) 
		result = hmac.process(message)
		return result.toBase64String()
	end if
End Function

'*
'* Time since the start (of UNIX time)
'*
Function LinuxTime() As Integer
	time = CreateObject("roDateTime")
	return time.asSeconds()
End Function



