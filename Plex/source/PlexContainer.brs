'*
'* An object representing a container fetched from a PMS. All of the fetching
'* and parsing of data is handled here. The XML is only parsed once, so
'* sequential calls to things like GetNames and GetKeys should be fast.
'*

Function createPlexContainerForXml(xmlResponse) As Object
    c = CreateObject("roAssociativeArray")

    c.server = xmlResponse.server
    c.sourceUrl = xmlResponse.sourceUrl
    c.xml = xmlResponse.xml

    c.ParseXml = containerParseXml
    c.GetNames = containerGetNames
    c.GetKeys = containerGetKeys
    c.GetMetadata = containerGetMetadata
    c.GetSearch = containerGetSearch
    c.GetSettings = containerGetSettings
    c.Count = containerCount

    c.ParseDetails = false
    c.SeparateSearchItems = false

    c.ViewGroup = c.xml@viewGroup

    c.names = []
    c.keys = []
    c.metadata = []
    c.search = []
    c.settings = []
    c.Parsed = false
    c.IsError = c.xml = invalid OR c.xml.GetName() = ""

    return c
End Function

Function createPlexContainerForUrl(server, baseUrl, key) As Object
    responseXml = server.GetQueryResponse(baseUrl, key)
    return createPlexContainerForXml(responseXml)
End Function

Function createFakePlexContainer(server, names, keys) As Object
    c = CreateObject("roAssociativeArray")

    c.server = server
    c.sourceUrl = ""
    c.names = names
    c.keys = keys
    c.search = []
    c.settings = []
    c.Parsed = true
    c.IsError = false

    c.GetNames = containerGetNames
    c.GetKeys = containerGetKeys
    c.GetSearch = containerGetSearch
    c.GetSettings = containerGetSettings

    return c
End Function

Sub containerParseXml()
    if m.Parsed then return
    imageDir = GetGlobalAA().Lookup("rf_theme_dir")

    ' If this container has an error message, show it now
    if isnonemptystr(m.xml@header) AND isnonemptystr(m.xml@message) then
        dlg = createBaseDialog()
        dlg.Title = m.xml@header
        dlg.Text = m.xml@message
        dlg.Show(true)
        dlg = invalid
        m.DialogShown = true
    end if

    nodes = m.xml.GetChildElements()
    for each n in nodes
        nodeType = firstOf(n@type, m.ViewGroup)

        if n@scanner <> invalid OR n@agent <> invalid then
            metadata = newDirectoryMetadata(m, n)
            metadata.contentType = "section"
            if n@thumb = invalid then
                if metadata.Type = "movie" then
                    thumb = imageDir + "section-movie.png"
                else if metadata.Type = "show" then
                    thumb = imageDir + "section-tv.png"
                else if metadata.Type = "artist" then
                    thumb = imageDir + "section-music.png"
                else if metadata.Type = "photo" then
                    thumb = imageDir + "section-photo.png"
                else
                    thumb = invalid
                end if

                if thumb <> invalid then
                    metadata.SDPosterURL = thumb
                    metadata.HDPosterURL = thumb
                    metadata.CompositionMode = "Source_Over"
                end if
            end if
        else if nodeType = "artist" OR n.GetName() = "Artist" then
            metadata = newArtistMetadata(m, n, m.ParseDetails)
        else if nodeType = "album" OR n.GetName() = "Album" then
            metadata = newAlbumMetadata(m, n, m.ParseDetails)
        else if nodeType = "season" then
            metadata = newSeasonMetadata(m, n)
        else if nodeType = "Store:Info" then
            metadata = newChannelMetadata(m, n)
        else if n@search = "1" then
            metadata = newSearchMetadata(m, n)
        else if n.GetName() = "Directory" then
            metadata = newDirectoryMetadata(m, n)       
        else if nodeType = "movie" OR nodeType = "episode" then
            metadata = newVideoMetadata(m, n, m.ParseDetails)
        else if nodeType = "clip" OR n.GetName() = "Video" then
            ' Video in a channel, use the regular video metadata
            metadata = newVideoMetadata(m, n, m.ParseDetails)
        else if nodeType = "track" OR n.GetName() = "Track" then
            metadata = newTrackMetadata(m, n, m.ParseDetails)
        else if nodeType = "photo" OR n.GetName() = "Photo" then
            metadata = newPhotoMetadata(m, n, m.ParseDetails)
        else if n.GetName() = "Setting" then
            metadata = newSettingMetadata(m, n)
        else
            metadata = newDirectoryMetadata(m, n)
        end if

        ' ljunkie - custom posters/thumbs for items the PMS does not give a thumb for
        ' I had some crazy logic if the thumb existing thumb was local or a /libary/metadata/etc.. 
        ' it seems though it's safe to assume if the PMS doesn't give a thumb then we can replace it
        ' if the PMS starts giving out generic thumbs, I'll have to repace with the crazy logic/regex

        if RegRead("rf_custom_thumbs", "preferences","enabled") = "enabled" then
            rfHasThumb = firstof(n@thumb, n@grandparentThumb, n@parentThumb)
           ' any other resources we want to override below
            re = CreateObject("roRegex", "/:/resources/actor-icon|resources/Book1.png", "") 
            ' this has mixed results - really the channel provider should be adding custom thumbs for every directory instead of the base channel thumb
            ' I.E. youtube, cbs.. ( for now it's disabled - Toggle is ready, but I am not ready for the outcome -- I.E. use it for "this" channel, and not "that" channel, etc..) 
            if RegRead("rf_channel_text", "preferences","disabled") <> "disabled" and nodetype = invalid then
                rfHasThumb = invalid
            end if

            ' for now, I am not going to override these
            remusic = CreateObject("roRegex", "resources%2Fartist.png", "") 
            if tostr(nodeType) =  "track" or tostr(nodeType) = "album" then
              rfHasThumb = "skip"
              if remusic.isMatch(tostr(metadata.HDPosterURL)) then rfHasThumb = invalid
            end if
                  
            PrintDebug = false
            if rfHasThumb = invalid or re.isMatch(rfHasThumb) then 
                thumb_text = firstof(metadata.umtitle, metadata.title)
                if thumb_text <> invalid AND metadata.server <> invalid then
                    if PrintDebug then 
                        Debug( "-------------------------------------------")
                        Debug("---- using custom thumb from rarflix cloudfrount service with title:" + firstof(metadata.umtitle, metadata.title))
                        Debug("---- viewGroup:" + tostr(metadata.ViewGroup) + " nodeType:" + tostr(nodeType))
                        Debug("---- Original:" + tostr(metadata.HDPosterURL))
                    end if
                    rfCDNthumb(metadata,thumb_text,nodetype,PrintDebug)
                else if PrintDebug then  
                    Debug( "-------------------------------------------")
                    Debug("---- NOT using custom thumb due to the below? we have skipped it due to the data below")
                    Debug("---- viewGroup:" + tostr(metadata.ViewGroup) + " nodeType:" + tostr(nodeType))
                    Debug("---- Original:" + tostr(metadata.HDPosterURL))
                    Debug( "-------------------------------------------")
                end if
            else if PrintDebug then 
                isLocal = CreateObject("roRegex", "127.0.0.1", "") ' TODO: any other than actor_con? these are default template.. ignore them
                if NOT isLocal.isMatch(rfHasThumb) then 
                    Debug( "-------------------------------------------")
                    Debug("---- NOT using custom thumb for valid image")
                    Debug("---- viewGroup:" + tostr(metadata.ViewGroup) + " nodeType:" + tostr(nodeType))
                    Debug("---- Original:" + tostr(metadata.HDPosterURL))
                    Debug( "-------------------------------------------")
                end if
            end if
        end if
        ' END custom poster/thumbs

        ' ROKU is not working with SSL ( some cloud sync thumbs ) -- 
        ' reset the thumb url from https://my.plexapp.com:443/sync/ to http://plex-cloudsync.s3.amazonaws.com/sync/
        remyplex = CreateObject("roRegex", "my.plexapp.com", "i")        
        if metadata.server <> invalid and metadata.server.serverurl <> invalid and remyplex.IsMatch(metadata.server.serverurl) then 
            re = CreateObject("roRegex", "https://my.plexapp.com:443/sync/", "")
            if metadata.hdposterurl <> invalid then metadata.hdposterurl = re.replace(metadata.hdposterurl,"http://plex-cloudsync.s3.amazonaws.com/sync/")
            if metadata.sdposterurl <> invalid then metadata.sdposterurl = re.replace(metadata.sdposterurl,"http://plex-cloudsync.s3.amazonaws.com/sync/")
            if metadata.sdgridthumb <> invalid then metadata.sdgridthumb = re.replace(metadata.sdgridthumb,"http://plex-cloudsync.s3.amazonaws.com/sync/")
            if metadata.hdgridthumb <> invalid then metadata.hdgridthumb = re.replace(metadata.hdgridthumb,"http://plex-cloudsync.s3.amazonaws.com/sync/")
            if metadata.hddetailthumb <> invalid then metadata.hddetailthumb = re.replace(metadata.hddetailthumb,"http://plex-cloudsync.s3.amazonaws.com/sync/")
            if metadata.sddetailthumb <> invalid then metadata.sddetailthumb = re.replace(metadata.sddetailthumb,"http://plex-cloudsync.s3.amazonaws.com/sync/")
        end if

        PosterIndicators(metadata)

        ' ljunkie - check if HomeVideo. This will be used to limit or change options since HomeVideos don't work with certain features.
        ' I.E. cast & crew, trailers. The thumbnail size will also be landscape instead of a poster
        if m.xml@librarySectionUUID <> invalid then 
            metadata.isHomeVideos = GetGlobalAA().lookup("lsHomeVideos_"+m.xml@librarySectionUUID)
        end if

        if metadata.search = true AND m.SeparateSearchItems then
            m.search.Push(metadata)
        else if metadata.setting = true then
            m.settings.Push(metadata)
        else
            m.metadata.Push(metadata)
            m.names.Push(metadata.Title)
            m.keys.Push(metadata.Key)
        end if
    next

    ' ljunkie - from ROKU -- this can be a memmory issue. So after we parse the XML, we invalidate it.
    m.xml = invalid ' cleanup XML -- it's parsed now
    ' RunGarbageCollector()

    m.Parsed = true
End Sub

Function containerGetNames()
    if NOT m.Parsed then m.ParseXml()

    return m.names
End Function

Function containerGetKeys()
    if NOT m.Parsed then m.ParseXml()

    return m.keys
End Function

Function containerGetMetadata()
    if NOT m.Parsed then m.ParseXml()

    return m.metadata
End Function

Function containerGetSearch()
    if NOT m.Parsed then m.ParseXml()

    return m.search
End Function

Function containerGetSettings()
    if NOT m.Parsed then m.ParseXml()

    return m.settings
End Function

Function containerCount()
    if NOT m.Parsed then m.ParseXml()

    return m.metadata.Count()
End Function
