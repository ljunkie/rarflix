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
	pms.GetLibrarySections = librarySections
	pms.GetLibrarySectionContent = librarySectionContent
	pms.VideoScreen = constructVideoScreen
	pms.StopVideo = stopTranscode
	return pms
End Function

Function librarySections(displayName) As Object
    queryUrl = m.serverUrl + "/library/sections"
    httpRequest = NewHttp(queryUrl)
    response = httpRequest.GetToStringWithRetry()
    xml=CreateObject("roXMLElement")
    if not xml.Parse(response) then
         print "Can't parse feed"
        return invalid
    endif
    'PrintXML(xml, 2)
    
    sections = CreateObject("roArray", 10, true)
    for each directory in xml.Directory
    
    	section = CreateObject("roAssociativeArray")
    	section.Server = m
    	section.SectionType = directory@type
    	section.Key = directory@key
    	if displayName
    		section.Title = directory@title + " ("+m.name+")"
    		section.ShortDescriptionLine1 = directory@title + " ("+m.name+")"
    	else
    		section.Title = directory@title
    		section.ShortDescriptionLine1 = directory@title
    	endif
    	
    	sectionType = directory@type
        if sectionType = "movie" then
    		section.SDPosterURL = "pkg:/images/clapperboard-icon.png"
    		section.HDPosterURL = "pkg:/images/clapperboard-icon.png"
    		sections.Push(section)
    	elseif sectionType = "show" then
    		section.SDPosterURL = "pkg:/images/leco.jpg"
    		section.HDPosterURL = "pkg:/images/leco.jpg"
    		sections.Push(section)
    	    
        endIf
    next
    return sections
End Function

Function librarySectionContent(key) As Object

    queryUrl = m.serverUrl + "/library/sections/"+key+"/all"
    httpRequest = NewHttp(queryUrl)
    response = httpRequest.GetToStringWithRetry()
    xml=CreateObject("roXMLElement")
    if not xml.Parse(response) then
         print "Can't parse feed"
        return invalid
    endif
	videos = CreateObject("roArray", 100, true)
    for each videoItem in xml.Video
    	video = CreateObject("roAssociativeArray")
    	video.Server = m
    	video.Title = videoItem@title
    	video.ShortDescriptionLine1 = videoItem@title
    	video.ShortDescriptionLine2 = videoItem@tagline
    	video.SDPosterURL = TranscodedImage(m.serverUrl, videoItem@thumb, "158", "204")
    	video.HDPosterURL = TranscodedImage(m.serverUrl, videoItem@thumb, "214", "306")
    	video.Key = videoItem@key
    	
    	'* TODO: deal with alternate media and multiple parts. 
    	'* We either let the user choose or come up with an algorithm to pick the best alternate
    	'* media, direct streaming, transcoding (with or without direct copy) and quality (network)
    	video.videoKey = videoItem.Media.Part@key
    	videos.Push(video)
    next
	return videos
End Function

'* Currently assumes transcoding but could encapsulate finding a direct stream
Function constructVideoScreen(videoKey as String, title as String) As Object
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

