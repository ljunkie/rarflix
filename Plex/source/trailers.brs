Function LoadYouTube() As Object
    return m.youtube
End Function

Function InitYouTube() As Object
    this = CreateObject("roAssociativeArray")
    this.protocol = "http"
    this.scope = this.protocol + "://gdata.youtube.com"
    this.prefix = this.scope + "/feeds/api"

    this.tmdb_scope = this.protocol + "://api.themoviedb.org"
    this.tmdb_prefix = this.tmdb_scope + "/3"
    this.tmdb_apikey = "cc34d5f77b86f8c21377b86d4420439a"

    ' this.FieldsToInclude = "&fields=entry(title,author,link,gd:rating,media:group(media:category,media:description,media:thumbnail,yt:videoid))"
    
    this.CurrentPageTitle = ""
    this.screen=invalid
    this.video=invalid

    'API Calls
    this.ExecServerAPI = youtube_exec_api
    this.ExecTmdbAPI = tmdb_exec_api
    
    'Search
    this.SearchYouTube = youtube_search ' changed to a forced search

    'Videos
    this.DisplayVideoList = youtube_display_video_list
    this.FetchVideoList = youtube_fetch_video_list
    this.VideoDetails = youtube_display_video_springboard
    this.newVideoListFromXML = youtube_new_video_list
    this.newVideoFromXML = youtube_new_video


    print "YouTube: init complete"
    return this
End Function

Function youtube_exec_api(request As Dynamic) As Object

    method = "GET"
    url_stub = request
    postdata = invalid
    headers = { }

    if type(request) = "roAssociativeArray" then
        if request.url_stub<>invalid then url_stub = request.url_stub
        if request.postdata<>invalid then : postdata = request.postdata : method="POST" : end if
        if request.headers<>invalid then headers = request.headers
        if request.method<>invalid then method = request.method
    end if
        
    if Instr(0, url_stub, "http://") OR Instr(0, url_stub, "https://") then
        http = NewHttp(url_stub)
    else
        http = NewHttp(m.prefix + "/" + url_stub)
    end if
'    http = NewHttp("http://www.rarforge.com")
    Debug("url: " + tostr(m.prefix + "/" + url_stub))
    if not headers.DoesExist("GData-Version") then headers.AddReplace("GData-Version", "2") 

    http.method = method
    'print "----------------------------------"
    if postdata<>invalid then
        rsp=http.PostFromStringWithTimeout(postdata, 10, headers)
        'print "postdata:",postdata
    else
        rsp=http.getToStringWithTimeout(10, headers)
    end if

    xml=ParseXML(rsp)
    returnObj = CreateObject("roAssociativeArray")
    returnObj.xml = xml
    returnObj.status = 200
    'returnObj.status = http.status -- plex http functions only return data/string - we will just set this to 200 for now
    returnObj.error = handleYoutubeError(returnObj) ' kind of redundant, but maybe useful later
    return returnObj
End Function

Function handleYoutubeError(rsp) As Dynamic
    ' Is there a status code? If not, return a connection error.
    if rsp.status=invalid then return ShowConnectionFailed()
    ' Don't check for errors if the response code was a 2xx or 3xx number
    if int(rsp.status/100)=2 or int(rsp.status/100)=3 return ""
    if not isxmlelement(rsp.xml) return ShowErrorDialog("API return invalid. Try again later", "Bad response")
    error=rsp.xml.GetNamedElements("error")[0]
    if error=invalid then
        ' we got an unformatted HTML response with the error in the title
        error=rsp.xml.GetChildElements()[0].GetChildElements()[0].GetText()
    else
        error=error.GetNamedElements("internalReason")[0].GetText()
    end if
    ShowDialog1Button("Error", error, "OK", true)
    return error
End Function

Sub youtube_search(keyword as string, year = "invalid" as string )
    dialog = createBaseDialog()
    dialog.Title = ""
    dialog.Text = ""
    dialog=ShowPleaseWait("Please wait","Searching TMDB & YouTube for " + Quote()+keyword+Quote())
    origSearch_trailer = keyword + " trailer"
    searchString_trailer = URLEncode(origSearch_trailer)
    searchString = URLEncode(keyword)
    ' xml=m.youtube.ExecServerAPI("videos?q=HJEsNjH3JT8")["xml"]
    ' try the TMDB first.. then try youtube
    ' we could speed this up if we know the TMDB ( does PMS know this? )

    Videos=CreateObject("roList")

    if year <> "invalid" then
       re = CreateObject("roRegex", "-", "") ' only grab the year
       year = re.split(year)[0]
       s_tmdb = m.youtube.ExecTmdbAPI("search/movie?query="+searchString+"&page=1&include_adult=false&year=" + tostr(year))["json"]
       if s_tmdb.results.count() = 0 then
         Debug("---------------- no match found with year.. try again")
         year = "invalid" ' invalidate year to try again without it
       end if
    end if
    
    ' try TMDB lookup without year
    if year = "invalid" then
       s_tmdb = m.youtube.ExecTmdbAPI("search/movie?query="+searchString+"&page=1&include_adult=false")["json"]
    end if

    ' locate trailers for video
    if s_tmdb.results.count() > 0 and tostr(s_tmdb.results[0].id) <> "invalid"  then
       s_tmdb = m.youtube.ExecTmdbAPI("movie/"+tostr(s_tmdb.results[0].id)+"/trailers?page=1")["json"]
    end if


    if type(s_tmdb.youtube) = "roArray"  then 
       for each trailer in s_tmdb.youtube
            Debug("Found YouTube Trailer from TMDB")
            PrintAA(trailer)
            re = CreateObject("roRegex", "&", "") ' seems some urls have &hd=1 .. maybe more to come
	    source = re.split(trailer.Source)[0]

            ' verify it's playable first
            if video_check_embed(source) <> "invalid" then
              xml=m.youtube.ExecServerAPI("videos/" + source)["xml"]
              if isxmlelement(xml) then 
                  ' single video will be retured.. call newVideoFromXML
                  video=m.youtube.newVideoFromXML(xml, searchString, "TMDb", "themoviedb.org")
                  Videos.Push(video)      
               else 
                   Debug("---------------------- Failed to get TMDB YouTube Trailer ")
              end if
             end if
        end for
    end if


    ' join raw youtube videos - maybe make this a toggle? some may ONLY want TMDB
    ' or include them if nothing is found from TMDB? to many options... I am sure someone will complain - never enough.. too much
    xml=m.youtube.ExecServerAPI("videos?q="+searchString_trailer+"&prettyprint=true&max-results=6&alt=atom&paid-content=false&v=2")["xml"]
    if isxmlelement(xml) then
        Videos =m.youtube.newVideoListFromXML(xml.entry,Videos,origSearch_trailer)
    else 
        xml = CreateObject("roXMLElement") ' just backwards compatibility
    end if

    if videos.Count() > 0 then
        dialog.Close()
        m.youtube.DisplayVideoList(videos, "Search Results for "+Chr(39)+keyword+Chr(39), xml.link, invalid)
    else
        dialog.Close():ShowErrorDialog("No videos match your search","Search results")
    end if
End Sub

Sub DisplayVideo(content As Object)
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)
    video.SetPositionNotificationPeriod(5)
    content.releaseDate = "Played: " + GetDurationString(0,0,1,1) ' just to keep the format the same on initial start
    'PrintAA(content)
    video.SetContent(content)
    video.show()
    
    while true
        msg = wait(0, video.GetMessagePort())
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then 
                video.Close()
                exit while
            else if msg.isStreamStarted() then
		'print "Video status: "; msg.GetIndex(); " " msg.GetInfo() 
            else if msg.isPlaybackPosition() then
                'print "Video GetIndex: "; msg.GetIndex()
                if msg.GetIndex() > 0
		    content.releaseDate = "Played: " + GetDurationString(msg.GetIndex(),0,1,1)
                    video.SetContent(content)
                end if
	    else if msg.isStatusMessage()
                'print "Video status: "; msg.GetIndex(); " " msg.GetData() 
            else if msg.isRequestFailed()
                print "play failed: "; msg.GetMessage()
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            end if
        end if
    end while
End Sub

Function parseVideoFormatsMap(videoInfo As String) As Object

    ' print "-----------------------------------------------"
    ' print videoInfo
    ' print "-----------------------------------------------"

    r = CreateObject("roRegex", "(?:|&"+CHR(34)+")url_encoded_fmt_stream_map=([^(&|\$)]+)", "")
    videoFormatsMatches = r.Match(videoInfo)

    if videoFormatsMatches[0]<>invalid then
        videoFormats = videoFormatsMatches[1]
    else
        print "parseVideoFormatsMap: didn't find any video formats"
        print "---------------------------------------------------"
        print videoInfo
        print "---------------------------------------------------"
        return invalid
    end if

    sep1 = CreateObject("roRegex", "%2C", "")
    sep2 = CreateObject("roRegex", "%26", "")
    sep3 = CreateObject("roRegex", "%3D", "")

    videoURL = CreateObject("roAssociativeArray")
    videoFormatsGroup = sep1.Split(videoFormats)

    for each videoFormat in videoFormatsGroup
        videoFormatsElem = sep2.Split(videoFormat)
        videoFormatsPair = CreateObject("roAssociativeArray")
        for each elem in videoFormatsElem
            pair = sep3.Split(elem)
            if pair.Count() = 2 then
                videoFormatsPair[pair[0]] = pair[1]
            end if
        end for

        if videoFormatsPair["url"]<>invalid then 
            r1=CreateObject("roRegex", "\\\/", ""):r2=CreateObject("roRegex", "\\u0026", "")
            url=URLDecode(URLDecode(videoFormatsPair["url"]))
            r1.ReplaceAll(url, "/"):r2.ReplaceAll(url, "&")
        end if
        if videoFormatsPair["itag"]<>invalid then
            itag = videoFormatsPair["itag"]
        end if
        if videoFormatsPair["sig"]<>invalid then 
            sig = videoFormatsPair["sig"]
            url = url + "&signature=" + sig
        end if

        if Instr(0, LCase(url), "http") = 1 then 
            videoURL[itag] = url
        end if
    end for

    qualityOrder = ["18","22","37"]
    bitrates = [768,2250,3750]
    isHD = [false,true,true]
    streamQualities = []

    for i=0 to qualityOrder.Count()-1
        qn = qualityOrder[i]
        if videoURL[qn]<>invalid then
            streamQualities.Push({url: videoURL[qn], bitrate: bitrates[i], quality: isHD[i], contentid: qn})
        end if
    end for

    return streamQualities

End Function

Sub youtube_display_video_list(videos As Object, title As String, links=invalid, screen=invalid)
    if screen=invalid then
        screen=uitkPreShowPosterMenu("flat-episodic-16x9", title)
        screen.showMessage("Loading...")
    end if
    m.CurrentPageTitle = title

    if videos.Count() > 0 then
        metadata=GetVideoMetaData(videos)

        for each link in links
            if link@rel = "next" then
                metadata.Push({shortDescriptionLine1: "More Results", action: "next", pageURL: link@href, HDPosterUrl:"pkg:/images/icon_next_episode.jpg", SDPosterUrl:"pkg:/images/icon_next_episode.jpg"})
            else if link@rel = "previous" then
                metadata.Unshift({shortDescriptionLine1: "Back", action: "prev", pageURL: link@href, HDPosterUrl:"pkg:/images/icon_prev_episode.jpg", SDPosterUrl:"pkg:/images/icon_prev_episode.jpg"})
            end if
        end for

        onselect = [1, metadata, m,
            function(video, youtube, set_idx)
                if video[set_idx]["action"]<>invalid then
                    youtube.FetchVideoList(video[set_idx]["pageURL"], youtube.CurrentPageTitle)
                else
                    youtube.VideoDetails(video[set_idx], youtube.CurrentPageTitle)
                end if
            end function]
        uitkDoPosterMenu(metadata, screen, onselect)
    else
        uitkDoMessage("No videos found.", screen)
    end if
End Sub

Sub youtube_display_video_springboard(video As Object, breadcrumb As String)
    p = CreateObject("roMessagePort")
    screen = CreateObject("roSpringboardScreen")
    screen.SetMessagePort(p)

    m.screen=screen
    m.video=video

    screen.SetDescriptionStyle("movie")
    screen.AllowNavLeft(true)
    screen.AllowNavRight(true)
    screen.SetPosterStyle("rounded-rect-16x9-generic")
    screen.SetDisplayMode("zoom-to-fill")
    screen.SetBreadcrumbText(breadcrumb, "Video")

    buttons = CreateObject("roAssociativeArray")

    streamQualities = video_get_qualities(video.id)
    if streamQualities<>invalid
        video.Streams = streamQualities
        
        if streamQualities.Peek()["contentid"].toInt() > 18
	    Debug("is HD")
            video.HDBranded = true
            video.FullHD = false
        else if streamQualities.Peek()["contentid"].toInt() = 37
            video.HDBranded = true
            video.FullHD = true
	    Debug("is FULL HD")
        end if

        buttons["play"] = screen.AddButton(0, "Play")
    end if

    'video.ReleaseDate = video.shortdescriptionline1

    screen.SetContent(video)
    screen.Show()

    while true
        msg = wait(0, screen.GetMessagePort())
        if type(msg) = "roSpringboardScreenEvent" then
            if msg.isScreenClosed()
                'print "Closing springboard screen"
                exit while
            else if msg.isButtonPressed()
                print "Button pressed: "; msg.GetIndex(); " " msg.GetData()
                if msg.GetIndex() = 0 then
                    DisplayVideo(video)
                endif
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        end If
    end while
End Sub

Function video_get_qualities(videoID as String) As Object
    http = NewHttp("http://www.youtube.com/get_video_info?video_id="+videoID)
    Debug("SteamQualities: http://www.youtube.com/get_video_info?video_id="+videoID)
    rsp = http.getToStringWithTimeout(10)
    if rsp<>invalid then

        videoFormats = parseVideoFormatsMap(rsp)
        if videoFormats<>invalid then
            if videoFormats.Count()>0 then
                return videoFormats
            end if
        else
            'try again with full youtube page
            dialog=ShowPleaseWait("Looking for compatible videos...", invalid)
            http = NewHttp("http://www.youtube.com/watch?v="+videoID)
            rsp = http.getToStringWithTimeout(30)
            if rsp<>invalid then
                videoFormats = parseVideoFormatsMap(rsp)
                if videoFormats<>invalid then
                    if videoFormats.Count()>0 then
                        dialog.Close()
                        return videoFormats
                    end if
                else
                    dialog.Close()
                    ShowErrorDialog("Could not find any playable formats. Please try another video...")
                end if
            end if
            dialog.Close()
        end if

    else
        ShowErrorDialog("HTTP Request for get_video_info failed!")
    end if
    
    return invalid
End Function


Function video_check_embed(videoID as String) As string
    http = NewHttp("http://www.youtube.com/get_video_info?video_id="+videoID)
    Debug("Checking Embed options: http://www.youtube.com/get_video_info?video_id="+videoID)
    rsp = http.getToStringWithTimeout(10)
    r = CreateObject("roRegex", "status=fail", "i")
    if r.IsMatch(rsp) then
          r = CreateObject("roRegex", "reason=([^(&|\$)]+)", "i")
          if r.IsMatch(rsp) then
            reason = r.Match(rsp)
            Debug("-------" + videoID +"------------- this YouTube Video is not playable:" + URLDecode(tostr(reason[0])))
          else 
             r = CreateObject("roRegex", "Embedding\+disabled", "i")
             if r.IsMatch(rsp) then
               Debug("-------" + videoID +"------------- this YouTube Video is not playable -- embedding disabled")
             end if
           end if
    else 
        ' no failure - we can embed this
        return "playable"
    end if
    
    ' invalid for any result of status=fail
    return "invalid"
End Function

Function URLEncode(str As String) As String
    if not m.DoesExist("encodeProxyUrl") then m.encodeProxyUrl = CreateObject("roUrlTransfer")
    return m.encodeProxyUrl.urlEncode(str)
End Function

Function URLDecode(str As String) As String
    strReplace(str,"+"," ") ' backward compatibility
    if not m.DoesExist("encodeProxyUrl") then m.encodeProxyUrl = CreateObject("roUrlTransfer")
    return m.encodeProxyUrl.Unescape(str)
End Function

Function Quote()
    q$ = Chr(34)
    return q$
End Function

Function ShowPleaseWait(title As dynamic, text As dynamic) As Object
    if not isstr(title) title = ""
    if not isstr(text) text = ""

    port = CreateObject("roMessagePort")
    dialog = invalid

    'the OneLineDialog renders a single line of text better
    'than the MessageDialog.

    if text = ""
        dialog = CreateObject("roOneLineDialog")
    else
        dialog = CreateObject("roMessageDialog")
        dialog.SetText(text)
    endif

    dialog.SetMessagePort(port)

    dialog.SetTitle(title)
    dialog.ShowBusyAnimation()
    dialog.Show()
    return dialog
End Function

Sub youtube_fetch_video_list(APIRequest As Dynamic, title As String)
    
    ' fields = m.FieldsToInclude
    ' if Instr(0, APIRequest, "?") = 0 then
    '     fields = "?"+Mid(fields, 2)
    ' end if

    screen=uitkPreShowPosterMenu("flat-episodic-16x9", title)
    screen.showMessage("Loading...")

    xml=m.ExecServerAPI(APIRequest)["xml"]
    if not isxmlelement(xml) then ShowConnectionFailed():return
    
    videos=m.newVideoListFromXML(xml.entry)
    m.DisplayVideoList(videos, title, xml.link, screen)

End Sub

Function youtube_new_video_list(xmllist As Object, videolist = invalid as Object, searchString = "invalid" as String) As Object
    print "youtube_new_video_list init"

    if videolist = invalid then
        videolist=CreateObject("roList")
    end if

    for each record in xmllist
           'ljunkie - might be slower -- but at least all the videos will play instead of having random videos that fail
            source = record.GetNamedElements("media:group")[0].GetNamedElements("yt:videoid")[0].GetText()
            if video_check_embed(source) <> "invalid" then
             video=m.newVideoFromXML(record, SearchString)
             videolist.Push(video)
            end if
    next
    return videolist
End Function

Function youtube_new_video(xml As Object, searchString = "invalid" as String, provider = "YouTube" as String, providerLong = "YouTube" as String) As Object
    video = CreateObject("roAssociativeArray")



    video.youtube=m
    video.xml=xml
    video.GetID=function():return m.xml.GetNamedElements("media:group")[0].GetNamedElements("yt:videoid")[0].GetText():end function
    video.GetAuthor=get_xml_author
    video.GetUserID=function():return m.xml.GetNamedElements("media:group")[0].GetNamedElements("yt:uploaderId")[0].GetText():end function
    video.GetTitle=function():return m.xml.title[0].GetText():end function
    video.GetCategory=function():return m.xml.GetNamedElements("media:group")[0].GetNamedElements("media:category")[0].GetText():end function
    video.GetDesc=function():return Left(m.xml.GetNamedElements("media:group")[0].GetNamedElements("media:description")[0].GetText(), 300):end function
    video.GetRating=get_xml_rating
    video.GetThumb=get_xml_thumb
    video.GetEditLink=get_xml_edit_link
    video.GetEditLink=get_xml_edit_link
    'video.GetLinks=function():return m.xml.GetNamedElements("link"):end function
    'video.GetURL=video_get_url
    video.Provider=provider
    video.ProviderLong=providerLong
    video.SearchString=searchString
    return video
End Function

Function GetVideoMetaData(videos As Object)
    metadata=[]
        
    for each video in videos
        meta=CreateObject("roAssociativeArray")
        meta.ContentType="movie"
        
        meta.ID=video.GetID()
        meta.provider=video.Provider
        meta.providerLong=video.ProviderLong
        meta.Author=video.GetAuthor()
        meta.Title=video.GetTitle()
        meta.Actors=meta.Author
        meta.Description=video.GetDesc()
        meta.Categories=video.GetCategory()
        meta.StarRating=video.GetRating()
        meta.ShortDescriptionLine1=meta.Title
        meta.SDPosterUrl=video.GetThumb()
        meta.HDPosterUrl=video.GetThumb()


        ' cleanup Description
        output = meta.Description
        re = CreateObject("roRegex", "\s+", "i")
        output = re.ReplaceAll(output, ". ")
	if tostr(meta.provider) <> "YouTube" then
           meta.Description = "Provided by: " + meta.providerLong + chr(10) + output
	else 
           meta.Description = "Provided by: YouTube search for '" + tostr(video.SearchString) +"'" + chr(10) + output
        end if
        meta.ShortDescriptionLine1 = meta.ShortDescriptionLine1 + " [" + meta.provider + "]"

        meta.xml=video.xml
        meta.UserID=video.GetUserID()
        meta.EditLink=video.GetEditLink(video.xml)

        meta.StreamFormat="mp4"
        meta.Streams=[]
        'meta.StreamBitrates=[]
        'meta.StreamQualities=[]
        'meta.StreamUrls=[]
        
        metadata.Push(meta)
    end for
    
    return metadata
End Function

Function get_xml_author() As Dynamic
    credits=m.xml.GetNamedElements("media:group")[0].GetNamedElements("media:credit")
    if credits.Count()>0 then
        for each author in credits
            if author.GetAttributes()["role"] = "uploader" then return author.GetAttributes()["yt:display"]
        end for
    end if
End Function

Function get_xml_rating() As Dynamic
    if m.xml.GetNamedElements("gd:rating").Count()>0 then
        return m.xml.GetNamedElements("gd:rating").GetAttributes()["average"].toInt()*20
    end if
    return invalid
End Function

Function get_xml_edit_link(xml) As Dynamic
    links=xml.GetNamedElements("link")
    if links.Count()>0 then
        for each link in links
            'print link.GetAttributes()["rel"]
            if link.GetAttributes()["rel"] = "edit" then return link.GetAttributes()["href"]
        end for
    end if
    return invalid
End Function

Function get_xml_thumb() As Dynamic
    thumbs=m.xml.GetNamedElements("media:group")[0].GetNamedElements("media:thumbnail")
    if thumbs.Count()>0 then
        for each thumb in thumbs
            if thumb.GetAttributes()["yt:name"] = "mqdefault" then return thumb.GetAttributes()["url"]
        end for
        return m.xml.GetNamedElements("media:group")[0].GetNamedElements("media:thumbnail")[0].GetAttributes()["url"]
    end if
    return "pkg:/images/icon_s.jpg"
End Function

Function ParseXML(str As String) As dynamic
    if str = invalid return invalid
    xml=CreateObject("roXMLElement")
    if not xml.Parse(str) return invalid
    return xml
End Function

Sub ShowConnectionFailed()
    Dbg("Connection Failed")
    title = "Can't connect to service"
    text  = GetConnectionFailedText()
    ShowErrorDialog(text, title)
End Sub

Sub Dbg(pre As Dynamic, o=invalid As Dynamic)
    p = AnyToString(pre)
    if p = invalid p = ""
    if o = invalid o = ""
    s = AnyToString(o)
    if s = invalid s = "???: " + type(o)
    if Len(s) > 4000
        s = Left(s, 4000)
    endif
    print p + s
End Sub

Function GetConnectionFailedText() as String
    return "We were unable to connect to the service.  Please try again in a few minutes."
End Function

Function ShowConnectionFailedRetry() as dynamic
    Dbg("Connection Failed Retry")
    title = "Can't connect to service"
    text  = GetConnectionFailedText()
    return ShowDialog2Buttons(title, text, "Try Again", "Back")
End Function

Sub ShowErrorDialog(text As dynamic, title=invalid as dynamic)
    if not isstr(text) text = "Unspecified error"
    if not isstr(title) title = "Error"
    ShowDialog1Button(title, text, "Done")
End Sub

Sub ShowDialog1Button(title As dynamic, text As dynamic, but1 As String, quickReturn=false As Boolean)
    if not isstr(title) title = ""
    if not isstr(text) text = ""

    Dbg("DIALOG1: ", title + " - " + text)

    port = CreateObject("roMessagePort")
    dialog = CreateObject("roMessageDialog")
    dialog.SetMessagePort(port)

    dialog.SetTitle(title)
    dialog.SetText(text)
    dialog.AddButton(0, but1)
    dialog.Show()

    if quickReturn=true then return

    while true
        dlgMsg = wait(0, dialog.GetMessagePort())

        if type(dlgMsg) = "roMessageDialogEvent"
            if dlgMsg.isScreenClosed()
                'print "Screen closed"
                return
            else if dlgMsg.isButtonPressed()
                print "Button pressed: "; dlgMsg.GetIndex(); " " dlgMsg.GetData()
                return
            endif
        endif
    end while
End Sub


Function ShowDialog2Buttons(title As dynamic, text As dynamic, but1 As String, but2 As String) As Integer
    if not isstr(title) title = ""
    if not isstr(text) text = ""

    Dbg("DIALOG2: ", title + " - " + text)

    port = CreateObject("roMessagePort")
    dialog = CreateObject("roMessageDialog")
    dialog.SetMessagePort(port)

    dialog.SetTitle(title)
    dialog.SetText(text)
    dialog.AddButton(0, but1)
    dialog.AddButton(1, but2)
    dialog.Show()

    while true
        dlgMsg = wait(0, dialog.GetMessagePort())

        if type(dlgMsg) = "roMessageDialogEvent"
            if dlgMsg.isScreenClosed()
                'print "Screen closed"
                dialog = invalid
                return 0
            else if dlgMsg.isButtonPressed()
                print "Button pressed: "; dlgMsg.GetIndex(); " " dlgMsg.GetData()
                dialog = invalid
                return dlgMsg.GetIndex()
            endif
        endif
    end while
End Function

Function isxmlelement(obj as dynamic) As Boolean
    if obj = invalid return false
    if GetInterface(obj, "ifXMLElement") = invalid return false
    return true
End Function

' uitk Poster/Grids -- remove these and use Plex functions (TODO)
Function uitkPreShowPosterMenu(ListStyle="flat-category" as String, breadA=invalid, breadB=invalid) As Object
	port=CreateObject("roMessagePort")
	screen = CreateObject("roPosterScreen")
	screen.SetMessagePort(port)

	if breadA<>invalid and breadB<>invalid then
		screen.SetBreadcrumbText(breadA, breadB)
        else if breadA<>invalid and breadB = invalid then
        screen.SetTitle(breadA)
	end if

    if ListStyle = "" OR ListStyle = invalid then
        ListStyle = "flat-category"
    end if

	screen.SetListStyle(ListStyle)
	screen.SetListDisplayMode("scale-to-fit")
	 screen.SetListDisplayMode("zoom-to-fill")
	screen.Show()

	return screen
end function

Function uitkDoPosterMenu(posterdata, screen, onselect_callback=invalid) As Integer

	if type(screen)<>"roPosterScreen" then
		print "illegal type/value for screen passed to uitkDoPosterMenu()" 
		return -1
	end if
	
	screen.SetContentList(posterdata)

    while true
        msg = wait(0, screen.GetMessagePort())
		
		'print "uitkDoPosterMenu | msg type = ";type(msg)
		
		if type(msg) = "roPosterScreenEvent" then
			print "event.GetType()=";msg.GetType(); " event.GetMessage()= "; msg.GetMessage()
			if msg.isListItemSelected() then
				if onselect_callback<>invalid then
					selecttype = onselect_callback[0]
					if selecttype=0 then
						this = onselect_callback[1]
                        selected_callback=onselect_callback[msg.GetIndex()+2]
                        if islist(selected_callback) then
                            f=selected_callback[0]
                            userdata1=selected_callback[1]
                            userdata2=selected_callback[2]
                            userdata3=selected_callback[3]
                            
                            if userdata1=invalid then
                                this[f]()
                            else if userdata2=invalid then
                                this[f](userdata1)
                            else if userdata3=invalid then
                                this[f](userdata1, userdata2)
                            else
                                this[f](userdata1, userdata2, userdata3)
                            end if
                        else
                            if selected_callback="return" then
                                return msg.GetIndex()
                            else
                                this[selected_callback]()
                            end if
                        end if
					else if selecttype=1 then
						userdata1=onselect_callback[1]
						userdata2=onselect_callback[2]
						f=onselect_callback[3]
						f(userdata1, userdata2, msg.GetIndex())
					end if
				else
					return msg.GetIndex()
				end if
			else if msg.isScreenClosed() then
				return -1
			end if
        end if
	end while
End Function

Function uitkPreShowListMenu(breadA=invalid, breadB=invalid) As Object
    port=CreateObject("roMessagePort")
    screen = CreateObject("roListScreen")
    screen.SetMessagePort(port)
    if breadA<>invalid and breadB<>invalid then
        screen.SetBreadcrumbText(breadA, breadB)
    end if
    'screen.SetListStyle("flat-category")
    'screen.SetListDisplayMode("best-fit")
    'screen.SetListDisplayMode("zoom-to-fill")
    screen.Show()

    return screen
end function

Function uitkDoListMenu(posterdata, screen, onselect_callback=invalid) As Integer

    if type(screen)<>"roListScreen" then
        print "illegal type/value for screen passed to uitkDoListMenu()" 
        return -1
    end if
    
    screen.SetContent(posterdata)

    while true
        msg = wait(0, screen.GetMessagePort())
        
        'print "uitkDoPosterMenu | msg type = ";type(msg)
        
        if type(msg) = "roListScreenEvent" then
            print "event.GetType()=";msg.GetType(); " Event.GetMessage()= "; msg.GetMessage()
            if msg.isListItemSelected() then
                if onselect_callback<>invalid then
                    selecttype = onselect_callback[0]
                    if selecttype=0 then
                        this = onselect_callback[1]
                        selected_callback=onselect_callback[msg.GetIndex()+2]
                        if islist(selected_callback) then
                            f=selected_callback[0]
                            userdata1=selected_callback[1]
                            userdata2=selected_callback[2]
                            userdata3=selected_callback[3]
                            
                            if userdata1=invalid then
                                this[f]()
                            else if userdata2=invalid then
                                this[f](userdata1)
                            else if userdata3=invalid then
                                this[f](userdata1, userdata2)
                            else
                                this[f](userdata1, userdata2, userdata3)
                            end if
                        else
                            if selected_callback="return" then
                                return msg.GetIndex()
                            else
                                this[selected_callback]()
                            end if
                        end if
                    else if selecttype=1 then
                        userdata1=onselect_callback[1]
                        userdata2=onselect_callback[2]
                        f=onselect_callback[3]
                        f(userdata1, userdata2, msg.GetIndex())
                    end if
                else
                    return msg.GetIndex()
                end if
            else if msg.isScreenClosed() then
                return -1
            end if
        end if
    end while
End Function

Function uitkDoCategoryMenu(categoryList, screen, content_callback, onclick_callback) As Integer  
    'Set current category to first in list
    category_idx=0
    
    screen.SetListNames(categoryList)
    contentdata1=content_callback[0]
    contentdata2=content_callback[1]
    content_f=content_callback[2]
    
    contentlist=content_f(contentdata1, contentdata2, 0)
    
    if contentlist.Count()=0 then
        screen.SetContentList([])
        screen.SetMessage("No viewable content in this section")
    else
        screen.SetContentList(contentlist)
    end if
    screen.Show()
    
    while true
        msg = wait(0, screen.GetMessagePort())
        if type(msg) = "roPosterScreenEvent" then
            if msg.isListFocused() then
                category_idx=msg.GetIndex()
                contentdata1=content_callback[0]
                contentdata2=content_callback[1]
                content_f=content_callback[2]
                
                contentlist=content_f(contentdata1, contentdata2, category_idx)
    
                if contentlist.Count()=0 then
                    screen.SetContentList([])
                    screen.ShowMessage("No viewable content in this section")
                else
                    screen.SetContentList(contentlist)
                    screen.SetFocusedListItem(0)
                end if
            else if msg.isListItemSelected() then
                userdata1=onclick_callback[0]
                userdata2=onclick_callback[1]
                content_f=onclick_callback[2]
                
                content_f(userdata1, userdata2, category_idx, msg.GetIndex())
            else if msg.isScreenClosed() then
                return -1
            end if
        end If
    end while
End Function

Sub uitkDoMessage(message, screen)
    screen.showMessage(message)
    while true
        msg = wait(0, screen.GetMessagePort())
        if msg.isScreenClosed() then
            return
        end if
    end while
End Sub
' end uitk





Function tmdb_exec_api(request As Dynamic) As Object

    method = "GET"
    url_stub = request
    postdata = invalid
    headers = { }

    if type(request) = "roAssociativeArray" then
        if request.url_stub<>invalid then url_stub = request.url_stub
        if request.postdata<>invalid then : postdata = request.postdata : method="POST" : end if
        if request.headers<>invalid then headers = request.headers
        if request.method<>invalid then method = request.method
    end if
        
    url_stub = url_stub + "&api_key=" + m.tmdb_apikey
    if Instr(0, url_stub, "http://") OR Instr(0, url_stub, "https://") then
        Debug("url: " + url_stub)
        http = NewHttp(url_stub)
    else
        Debug("url: " + tostr(m.tmdb_prefix + "/" + url_stub))
        http = NewHttp(m.tmdb_prefix + "/" + url_stub)

    end if


    if not headers.DoesExist("Accept") then headers.AddReplace("Accept", "application/json") 
    'xhr.setRequestHeader("Accept", "application/json");
    http.method = method
    'print "----------------------------------"
    if postdata<>invalid then
        rsp=http.PostFromStringWithTimeout(postdata, 10, headers)
        'print "postdata:",postdata
    else
        rsp=http.getToStringWithTimeout(10, headers)
    end if

    json=ParseJSON(rsp)
    returnObj = CreateObject("roAssociativeArray")
    returnObj.json = json
    returnObj.status = 200
    'returnObj.status = http.status -- plex http functions only return data/string - we will just set this to 200 for now
    'returnObj.error = handleYoutubeError(returnObj) ' kind of redundant, but maybe useful later
    return returnObj
End Function

