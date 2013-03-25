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
                    thumb = "file://pkg:/images/section-movie.png"
                else if metadata.Type = "show" then
                    thumb = "file://pkg:/images/section-tv.png"
                else if metadata.Type = "artist" then
                    thumb = "file://pkg:/images/section-music.png"
                else if metadata.Type = "photo" then
                    thumb = "file://pkg:/images/section-photo.png"
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
