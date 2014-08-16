'
'
' Movie Trailers - TMDB and YouTube
'  - removed more videos button from posterScreen ( will only show max 10 videos )
'
'

' Generic HTTP transfer object (not plex related)
Function NewGenHttp(url As String) as Object
    Debug("Creating new generic http transfer object for " + url)
    obj = CreateObject("roAssociativeArray")
    obj.Http                        = CreateGenURLTransferObject(url)
    obj.FirstParam                  = true
    obj.AddParam                    = http_add_param
    obj.AddRawQuery                 = http_add_raw_query
    obj.PrepareUrlForQuery          = http_prepare_url_for_query
    obj.GetToStringWithTimeout      = http_get_to_string_with_timeout

    if Instr(1, url, "?") > 0 then obj.FirstParam = false

    return obj
End Function

Function CreateGenURLTransferObject(url As String) as Object
    Debug("Creating Generic URL transfer object for " + url)
    obj = CreateObject("roUrlTransfer")
    obj.SetPort(CreateObject("roMessagePort"))
    obj.SetUrl(url)
    obj.AddHeader("Content-Type", "application/x-www-form-urlencoded")
    obj.EnableEncodings(true)
    if instr(1, url, "https://") > 0 then
        print "adding cert!"
        obj.SetCertificatesFile("common:/certs/ca-bundle.crt")
    end if
    return obj
End Function

Function vcInitYouTube() As Object
    obj = CreateObject("roAssociativeArray")
    obj.protocol = "http"

    obj.yt_url = obj.protocol + "://gdata.youtube.com"
    obj.yt_prefix = obj.yt_url + "/feeds/api"

    obj.tmdb_url = obj.protocol + "://api.themoviedb.org"
    obj.tmdb_prefix = obj.tmdb_url + "/3"
    obj.tmdb_apikey = "cc34d5f77b86f8c21377b86d4420439a"
    obj.viewcontroller = m.viewcontroller

    'API Calls
    obj.ExecServerAPI = youtube_exec_api
    obj.ExecTmdbAPI = tmdb_exec_api

    'Search
    obj.maxResults = 5
    obj.SearchTrailer = youtube_search_trailer ' changed to a forced search
    obj.newVideoListFromXML = youtube_new_video_list
    obj.newVideoFromXML = youtube_new_video

    Debug(" Trailers (m.YouTube): init complete")
    return obj
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
        http = NewGenHttp(url_stub)
    else
        http = NewGenHttp(m.yt_prefix + "/" + url_stub)
    end if

    Debug("url: " + tostr(m.yt_prefix + "/" + url_stub))
    if not headers.DoesExist("GData-Version") then headers.AddReplace("GData-Version", "2")

    http.method = method
    if postdata<>invalid then
        rsp=http.PostFromStringWithTimeout(postdata, 10, headers)
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
    if rsp.status=invalid then return ShowConnectionFailed("youtube")
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
    ShowErrorDialog(error, "Error")
    return error
End Function

Function parseVideoFormatsMap(videoInfo As String) As Object
    r = CreateObject("roRegex", "(?:|&"+CHR(34)+")url_encoded_fmt_stream_map=([^(&|\$)]+)", "")
    videoFormatsMatches = r.Match(videoInfo)

    if videoFormatsMatches[0]<>invalid then
        videoFormats = videoFormatsMatches[1]
    else
        Debug("parseVideoFormatsMap: didn't find any video formats")
        Debug("---------------------------------------------------")
        Debug(videoInfo)
        Debug("---------------------------------------------------")
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

Function video_get_qualities(videoID as String) As Object
    http = NewGenHttp("https://www.youtube.com/get_video_info?video_id="+videoID)
    Debug("SteamQualities: https://www.youtube.com/get_video_info?video_id="+videoID)
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
            http = NewGenHttp("http://www.youtube.com/watch?v="+videoID)
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
    http = NewGenHttp("http://www.youtube.com/get_video_info?video_id="+videoID)
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


Function youtube_new_video_list(xmllist As Object, videolist = invalid as Object, searchString = invalid) As Object
    if videolist = invalid then videolist=CreateObject("roList")
    for each record in xmllist
        'ljunkie - might be slower -- but at least all the videos will play instead of having random videos that fail
        if videolist.count() < m.maxresults then
            source = record.GetNamedElements("media:group")[0].GetNamedElements("yt:videoid")[0].GetText()
            exclude = false
            if video_check_embed(source) <> "invalid" then
                video=m.newVideoFromXML(record, tostr(SearchString))
                ' check if video already exists
                for each vi in videolist
                    if vi.getid() = video.getid()
                        exclude = true
                        exit for
                    end if
                end for
                if NOT exclude then videolist.Push(video)
            end if
        end if
    next
    return videolist
End Function

Function youtube_new_video(xml As Object, searchString = invalid, provider = "YouTube" as String, providerLong = "YouTube" as String) As Object
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
    video.GetLength=get_length
    video.Provider=provider
    video.ProviderLong=providerLong
    video.SearchString=tostr(searchString)
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

        if tostr(meta.provider) <> "YouTube" then
            meta.ShortDescriptionLine2 = "Provided by: " + meta.providerLong
        else
            meta.ShortDescriptionLine2 = "Provided by: YouTube search for '" + tostr(video.SearchString) +"'"
        end if
        meta.ShortDescriptionLine2  = GetDurationString(video.GetLength()) + " - " + meta.ShortDescriptionLine2

        meta.SDPosterUrl=video.GetThumb()
        meta.HDPosterUrl=video.GetThumb()
        meta.Length=video.GetLength()

        ' cleanup Description
        output = meta.Description
        re = CreateObject("roRegex", "\s+", "i")
        output = re.ReplaceAll(output, " ")
        meta.Description = output

        meta.ShortDescriptionLine1 = meta.ShortDescriptionLine1 + " [" + meta.provider + "]"

        meta.xml=video.xml
        meta.UserID=video.GetUserID()
        meta.EditLink=video.GetEditLink(video.xml)

        meta.StreamFormat="mp4"
        meta.Streams=[]
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

Sub ShowConnectionFailed(string = "")
    Debug(tostr(string) + " Connection Failed")
    title = "Can't connect to service"
    text  = "We were unable to connect to the service.  Please try again in a few minutes."
    ShowErrorDialog(text, title)
End Sub

Sub ShowErrorDialog(text As dynamic, title=invalid as dynamic)
    if not isstr(text) text = "Unspecified error"
    if not isstr(title) title = "Error"
    dialog = createBaseDialog()
    dialog.Title = title
    dialog.DisableBackButton = false
    dialog.Text = text
    dialog.Show(true) ' blocking
End Sub

Function isxmlelement(obj as dynamic) As Boolean
    if obj = invalid return false
    if GetInterface(obj, "ifXMLElement") = invalid return false
    return true
End Function

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
        http = NewGenHttp(url_stub)
    else
        Debug("url: " + tostr(m.tmdb_prefix + "/" + url_stub))
        http = NewGenHttp(m.tmdb_prefix + "/" + url_stub)

    end if


    if not headers.DoesExist("Accept") then headers.AddReplace("Accept", "application/json")
    http.method = method
    if postdata<>invalid then
        rsp=http.PostFromStringWithTimeout(postdata, 10, headers)
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


Function get_length() As Dynamic
    durations = m.xml.GetNamedElements("media:group")[0].GetNamedElements("yt:duration")
    if (durations.Count() > 0) then
        return durations.GetAttributes()["seconds"]
    end if
End Function

Function build_buttons() as Object
    m.screen.ClearButtons()
    buttons = CreateObject("roAssociativeArray")
    buttons["play"] = m.screen.AddButton(0, "Play")
    buttons["play_all"] = m.screen.AddButton(1, "Play All") ' might add this option
    return buttons
End Function

function youtube_search_trailer(keyword as string, year = invalid) as object
    'dialog=ShowPleaseWait("Please wait","Searching TMDB & YouTube for " + Quote()+keyword+Quote())
    origSearch_trailer = keyword + " trailer"
    searchString_trailer = URLEncode(origSearch_trailer)
    searchString = URLEncode(keyword)
    ' xml=m.viewcontroller.youtube.ExecServerAPI("videos?q=HJEsNjH3JT8")["xml"]
    ' try the TMDB first.. then try youtube
    ' we could speed this up if we know the TMDB ( does PMS know this? )

    Videos=CreateObject("roList")

    if year <> invalid then
        re = CreateObject("roRegex", "-", "") ' only grab the year
        year = re.split(year)[0]
        s_tmdb = m.viewcontroller.youtube.ExecTmdbAPI("search/movie?query="+searchString+"&page=1&include_adult=false&year=" + tostr(year))["json"]
        if s_tmdb.results.count() = 0 then
            Debug("---------------- no match found with year.. try again")
            year = "invalid" ' invalidate year to try again without it
        end if
    else
        ' try TMDB lookup without year
        s_tmdb = m.viewcontroller.youtube.ExecTmdbAPI("search/movie?query="+searchString+"&page=1&include_adult=false")["json"]
    end if

    ' locate trailers for video
    if s_tmdb.results.count() > 0 and tostr(s_tmdb.results[0].id) <> "invalid"  then
        s_tmdb = m.viewcontroller.youtube.ExecTmdbAPI("movie/"+tostr(s_tmdb.results[0].id)+"/trailers?page=1")["json"]
    end if

    if type (s_tmdb) = "roAssociativeArray" and type(s_tmdb.youtube) = "roArray"  then
        for each trailer in s_tmdb.youtube
            Debug("Found YouTube Trailer from TMDB")
            'PrintAA(trailer)
            re = CreateObject("roRegex", "&", "") ' seems some urls have &hd=1 .. maybe more to come
            source = re.split(trailer.Source)[0]

            ' verify it's playable first
            if video_check_embed(source) <> "invalid" then
                xml=m.viewcontroller.youtube.ExecServerAPI("videos/" + source)["xml"]
                if isxmlelement(xml) then
                    ' single video will be retured.. call newVideoFromXML
                    video=m.viewcontroller.youtube.newVideoFromXML(xml, searchString, "TMDb", "themoviedb.org")
                    Videos.Push(video)
                else
                    Debug("---------------------- Failed to get TMDB YouTube Trailer ")
                end if
            end if
        end for
    end if

    ' join raw youtube videos - maybe make this a toggle? some may ONLY want TMDB
    trailerTypes = RegRead("rf_trailers", "preferences")
    includeYouTubeRaw = 0

    if trailerTypes = "enabled"  then
        Debug("------------ Included raw youtube trailer search (trailers: enabled) ------------------ trailer:" + trailerTypes)
        includeYouTubeRaw = 1 ' include youtube trailers when 'enabled' is set -- grab everything
    else if videos.Count() = 0 and trailerTypes = "enabled_tmdb_ytfb"  then
        Debug("------------ Included raw youtube trailer search (trailers: enabled_tmdb_ytfb and 0 TMDB found) ------------------ trailer:" + trailerTypes)
        includeYouTubeRaw = 1 ' include youtube trailers when youtube fallback is enabled and we didn't find any trailers on tmdb
    else
        Debug("------------ skipping raw youtube trailer search (found trailers on TMDB) ------------------ trailer:" + trailerTypes)
    end if

    ' so - should we include the raw yourube search?
    if includeYouTubeRaw = 1 then
        xml=m.viewcontroller.youtube.ExecServerAPI("videos?q="+searchString_trailer+"&prettyprint=true&max-results=20&alt=atom&paid-content=false&v=2")["xml"]
        if isxmlelement(xml) then
            videos = m.viewcontroller.youtube.newVideoListFromXML(xml.entry,Videos,origSearch_trailer)
        else
            xml = CreateObject("roXMLElement") ' just backwards compatibility
        end if
    end if

    return videos
End function


' Play Video
function DisplayYouTubeVideo(video As Object, waitDialog = invalid)
    videoHDflag(video)
    ret = DisplayVideo(video,waitDialog)
    return ret
end function

sub videoHDflag(video)
    streamQualities = video_get_qualities(video.id)
    if streamQualities <> invalid then
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
     end if
end sub

Function  trailerSBhandleMessage(msg) as boolean
    handled = false
    if type(msg) = "roSpringboardScreenEvent" then
        handled = true

        if msg.isScreenClosed()
            m.ViewController.PopScreen(m)
        else if msg.isButtonPressed()
            ' Play Button
            if msg.GetIndex() = 0 then
                DisplayYouTubeVideo(m.item)
            ' Play All
            else if (msg.GetIndex() = 1) then
                for i = m.focusedIndex to m.contentarray.Count() - 1 Step +1 ' last video is button
                    selectedVideo = m.contentarray[i]
                    if selectedVideo.id <> invalid then
                        ret = DisplayYouTubeVideo(selectedVideo)
                        if (ret > 0) then
                            Exit For
                        end if
                    end if
                end for
            end if
        else if (msg.isRemoteKeyPressed()) then
            if (msg.GetIndex() = 4) then  ' left
                if (m.contentarray.Count() > 1) then
                    m.focusedIndex = m.focusedIndex - 1
                    if m.focusedIndex < 0 then  m.focusedIndex = m.contentarray.Count() - 1
                    videoHDflag(m.contentarray[m.focusedIndex])
                    m.item = m.contentarray[m.focusedIndex]
                    m.BuildButtons()
                    m.screen.SetContent( m.item )
                end if
            else if (msg.GetIndex() = 5) then ' right
                if (m.contentarray.Count() > 1) then
                    m.focusedIndex = m.focusedIndex + 1
                    if m.focusedIndex > m.contentarray.Count() - 1 then m.focusedIndex = 0
                    videoHDflag(m.contentarray[m.focusedIndex])
                    m.item = m.contentarray[m.focusedIndex]
                    m.BuildButtons()
                    m.screen.SetContent( m.item )
                end if
            end if
        end if
    end if

    return handled
end function

Function trailerHandleMessage(msg) As Boolean
    handled = false
    if type(msg) = "roPosterScreenEvent" then
        handled = true
        if msg.isListItemSelected() then
            ' show a details springBoard for all videos
            screen = createSpringBoardScreenExt(m.contentArray, msg.GetIndex(), m.viewcontroller)
            screen.HandleMessage = trailerSBhandlemessage
            m.viewcontroller.AddBreadcrumbs(screen, [""])
            m.viewcontroller.UpdateScreenProperties(screen)
            m.viewcontroller.PushScreen(screen)
            screen.screen.Show()
            ' play the video
            ' video = m.contentarray[msg.GetIndex()]
            ' DisplayYouTubeVideo(video)
        else if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
        else if msg.isListItemFocused() then
            m.focusedIndex = msg.GetIndex()
        else if ((msg.isRemoteKeyPressed() AND msg.GetIndex() = 10) OR msg.isButtonInfo()) then ' ljunkie - use * for more options on focused item
            'print "event.GetType()=";msg.GetType(); " event.GetMessage()= "; msg.GetMessage()
            Debug("(*) remote key not handled for trailers")
        else if msg.isRemoteKeyPressed() then
            if msg.GetIndex() = 13 then
                Debug("Handling direct play of trailer from poster")
                video = m.contentArray[m.focusedIndex]
                DisplayYouTubeVideo(video)
            end if
        end if
    end if

    return handled
End Function
