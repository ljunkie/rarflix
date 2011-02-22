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
	pms.GetHomePageContent = homePageContent
	pms.GetListNames = listNames
	pms.GetListKeys = listKeys
	pms.VideoScreen = constructVideoScreen
	pms.StopVideo = stopTranscode
	pms.GetQueryResponse = xmlContent
	pms.ConstructDirectoryMetadata = ConstructDirectoryMetadata
	pms.ConstructVideoMetadata = ConstructVideoMetadata
	pms.ConstructTrackMetadata = ConstructTrackMetadata
	return pms
End Function

Function homePageContent() As Object
	xml = m.GetQueryResponse("", "/library/sections")
	librarySections = m.GetContent(xml)
	content = CreateObject("roArray", librarySections.Count() + 1, true)
	for each section in librarySections
		content.Push(section)
	next
	'* TODO: only add this if we actually have any valid apps?
	appsSection = CreateObject("roAssociativeArray")
	appsSection.server = m
    appsSection.sourceUrl = ""
	appsSection.ContentType = "series"
	appsSection.Key = "apps"
	appsSection.Title = "Apps"
	appsSection.ShortDescriptionLine1 = "Apps"
	appsSection.SDPosterURL = "file://pkg:/images/plex.png"
	appsSection.HDPosterURL = "file://pkg:/images/plex.png"
	content.Push(appsSection)
	return content
End Function

Function xmlContent(sourceUrl, key) As Object

	xmlResult = CreateObject("roAssociativeArray")
	xmlResult.server = m
	if key = "apps" then
		'* Fake a minimal server response with a new viewgroup
		xml=CreateObject("roXMLElement")
		xml.Parse("<MediaContainer viewgroup='apps'/>")
		xmlResult.xml = xml
		xmlResult.sourceUrl = invalid
	else
		queryUrl = FullUrl(m.serverUrl, sourceUrl, key)
		
		print "Fetching content from server at query URL:";queryUrl
		httpRequest = NewHttp(queryUrl)
		response = httpRequest.GetToStringWithRetry()
		xml=CreateObject("roXMLElement")
		if not xml.Parse(response) then
			print "Can't parse feed:";response
		endif
			
		xmlResult.xml = xml
		xmlResult.sourceUrl = queryUrl
	endif
	return xmlResult
End Function

Function listNames(parsedXml) As Object
	content = CreateObject("roArray", 10, true)
	if parsedXml.xml@viewGroup = "apps" then
		content.Push("Video Apps")
		content.Push("Audio Apps")
		content.Push("Photo Apps")
	else
		sectionViewGroup = parsedXml.xml@viewGroup
		if sectionViewGroup = "secondary" then
			sections = m.GetContent(parsedXml)
			for each section in sections
				content.Push(section.title)
			next
		endif
	endif
	return content
End Function

Function listKeys(parsedXml) As Object
	content = CreateObject("roArray", 10, true)
	if parsedXml.xml@viewGroup = "apps" then
		content.Push("/video")
		content.Push("/music")
		content.Push("/photos")
	else
		sectionViewGroup = parsedXml.xml@viewGroup
		if sectionViewGroup = "secondary" then
			sections = m.GetContent(parsedXml)
			for each section in sections
				content.Push(section.key)
			next
		endif
	endif
	return content
End Function
		
Function directoryContent(parsedXml) As Object
	content = CreateObject("roArray", 10, true)
	for each directoryItem in parsedXml.xml.Directory
		if directoryItem@search = invalid then
			directory = m.ConstructDirectoryMetadata(parsedXml.xml, directoryItem, parsedXml.sourceUrl)
			content.Push(directory)
		endif
	next
	for each videoItem in parsedXml.xml.Video
		video = m.ConstructVideoMetadata(parsedXml.xml, videoItem, parsedXml.sourceUrl)
		content.Push(video)
	next
	for each trackItem in parsedXml.xml.Track
		track = m.ConstructTrackMetadata(parsedXml.xml, trackItem, parsedXml.sourceUrl)
		content.Push(track)
	next
	print "Found a content list with elements";content.count()
	return content
End Function

Function ConstructDirectoryMetadata(xml, directoryItem, sourceUrl) As Object	
	directory = CreateObject("roAssociativeArray")
	directory.server = m
	directory.sourceUrl = sourceUrl
	directory.ContentType = directoryItem@type
	if directory.ContentType = "show" then
		directory.ContentType = "series"
	endif
	directory.Key = directoryItem@key
	directory.Title = directoryItem@title
	directory.Description = directoryItem@summary
	if directory.Title = invalid then
		directory.Title = directoryItem@name
	endif
	directory.ShortDescriptionLine1 = directoryItem@title
	if directory.ShortDescriptionLine1 = invalid then
		directory.ShortDescriptionLine1 = directoryItem@name
	endif
	
	sizes = ImageSizes(xml@viewGroup, directory.ContentType)
	thumb = directoryItem@thumb
	if thumb <> invalid then
		directory.SDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, thumb, sizes.sdWidth, sizes.sdHeight)
		directory.HDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, thumb, sizes.hdWidth, sizes.hdHeight)
	else
		art = directoryItem@art
		if art = invalid then
			art = xml@art
		endif
		if art <> invalid then
			directory.SDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, art, sizes.sdWidth, sizes.sdHeight)
			directory.HDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, art, sizes.hdWidth, sizes.hdHeight)
		endif
	endif
	return directory
End Function
		
Function ConstructVideoMetadata(xml, videoItem, sourceUrl) As Object
	video = CreateObject("roAssociativeArray")
	video.server = m
	video.sourceUrl = sourceUrl
	video.ContentType = videoItem@type
	video.Title = videoItem@title
	video.Key = videoItem@key
	video.ShortDescriptionLine1 = videoItem@title
	video.ShortDescriptionLine2 = videoItem@tagline
	if xml@viewGroup = "episode" then
		video.ShortDescriptionLine2 = videoItem@grandparentTitle
		if video.ShortDescriptionLine2 = invalid then
			video.ShortDescriptionLine2 = "Episode "+videoItem@index
		endif
	endif
	video.Description = videoItem@summary
	
	sizes = ImageSizes(xml@viewGroup, video.ContentType)
	thumb = videoItem@thumb
	if thumb <> invalid then
		video.SDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, thumb, sizes.sdWidth, sizes.sdHeight)
		video.HDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, thumb, sizes.hdWidth, sizes.hdHeight)
	else
		art = videoItem@art
		if art = invalid then
			art = xml@art
		endif
		if art <> invalid then
			video.SDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, art, sizes.sdWidth, sizes.sdHeight)
			video.HDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, art, sizes.hdWidth, sizes.hdHeight)	
		endif
	endif
	
	'* TODO: need a way to choose between media options and concat parts
	video.mediaKey = videoItem.Media.Part@Key
	if video.mediaKey = invalid then
		video.mediaKey = videoItem@key
	endif
	return video
End Function
		
'* This logic reflects that in the PosterScreen.SetListStyle
'* Not using the standard sizes appears to slow navigation down
Function ImageSizes(viewGroup, contentType) As Object
	'* arced-square size	
	sdWidth = "223"
	sdHeight = "200"
	hdWidth = "300"
	hdHeight = "300"
	
	if viewGroup = "movie" OR viewGroup = "show" OR viewGroup = "season" OR viewGroup = "episode" or contentType="clip" then
	'* arced-portrait sizes
		sdWidth = "158"
		sdHeight = "204"
		hdWidth = "214"
		hdHeight = "306"
	elseif contentType = "episode" AND viewGroup = "episode" then
		'* flat-episodic sizes
		sdWidth = "166"
		sdHeight = "112"
		hdWidth = "224"
		hdHeight = "168"
	endif
	sizes = CreateObject("roAssociativeArray")
	sizes.sdWidth = sdWidth
	sizes.sdHeight = sdHeight
	sizes.hdWidth = hdWidth
	sizes.hdHeight = hdHeight
	return sizes
End Function
		
Function ConstructTrackMetadata(xml, trackItem, sourceUrl) As Object
	track = CreateObject("roAssociativeArray")
	track.server = m
	track.sourceUrl = sourceUrl
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
	return track
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
    'print "ServerURL:";serverUrl
    'print "SourceURL:";sourceUrl
    'print "Key:";key
	finalUrl = ""
	if left(key, 4) = "http" then
	    finalUrl = key
	else if key = "" AND sourceUrl = "" then
	    finalUrl = serverUrl
    else if key = "" AND serverUrl = "" then
        finalUrl = sourceUrl
	else if left(key, 1) = "/" then
		finalUrl = serverUrl+key
	else
		finalUrl = sourceUrl+"/"+key
	endif
    'print "FinalURL:";finalUrl
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
	'myurl = "/video/:/transcode/segmented/start.m3u8?identifier=com.plexapp.plugins.library&ratingKey=97007888&offset=0&minQuality=1&maxQuality=7&url="+HttpEncode(location)+"&3g=0&httpCookies=&userAgent="
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


REM ******************************************************
REM Constucts a URL Transfer object
REM ******************************************************

Function CreateURLTransferObject(url As String) as Object
    obj = CreateObject("roUrlTransfer")
    obj.SetPort(CreateObject("roMessagePort"))
    obj.SetUrl(url)
    obj.AddHeader("Content-Type", "application/x-www-form-urlencoded")
	obj.AddHeader("X-Plex-Version", "0.9") '* Correct ?
	obj.AddHeader("X-Plex-Language", "en") '* Anyway to get this from the platform ?
	obj.AddHeader("X-Plex-Client-Platform", "Roku")
    obj.EnableEncodings(true)
    return obj
End Function

REM ******************************************************
REM Url Query builder
REM so this is a quick and dirty name/value encoder/accumulator
REM ******************************************************

Function NewHttp(url As String) as Object
    obj = CreateObject("roAssociativeArray")
    obj.Http                        = CreateURLTransferObject(url)
    obj.FirstParam                  = true
    obj.AddParam                    = http_add_param
    obj.AddRawQuery                 = http_add_raw_query
    obj.GetToStringWithRetry        = http_get_to_string_with_retry
    obj.PrepareUrlForQuery          = http_prepare_url_for_query
    obj.GetToStringWithTimeout      = http_get_to_string_with_timeout
    obj.PostFromStringWithTimeout   = http_post_from_string_with_timeout

    if Instr(1, url, "?") > 0 then obj.FirstParam = false

    return obj
End Function


