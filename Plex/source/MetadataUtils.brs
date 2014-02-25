
'* This logic reflects that in the PosterScreen.SetListStyle
'* Not using the standard sizes appears to slow navigation down
Function ImageSizes(viewGroup, contentType) As Object
    ' ljunkie -- these still are not the correct sizes for all screens...
    ' ljunkie (2013-12-03) we now set the screen we are creating globally ( for roGridScree & roPosterScreen )
    ' let's use the sizes documented by Roku for these screens - it should speed up the display
    ' fall back to the default sizes the Official channel uses if neither are set
    sizes = CreateObject("roAssociativeArray")

    if tostr(GetGlobalAA().lookup("GlobalNewScreen")) = "poster" then
        sizes = PosterImageSizes()
    else if tostr(GetGlobalAA().lookup("GlobalNewScreen")) = "grid" then
        sizes = GridImageSizes()
    else
	sdWidth = "223"
	sdHeight = "200"
	hdWidth = "300"
	hdHeight = "300"
	if viewGroup = "movie" OR viewGroup = "show" OR viewGroup = "season" OR viewGroup = "episode" then
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
	elseif viewGroup = "Details" then
		'* arced-square sizes
		sdWidth = "223"
		sdHeight = "200"
		hdWidth = "300"
		hdHeight = "300"

	endif
	sizes.sdWidth = sdWidth
	sizes.sdHeight = sdHeight
	sizes.hdWidth = hdWidth
	sizes.hdHeight = hdHeight
    end if
 
    ' for now, the detail thumbs will be hard coded 
    ' we don't specify the Style (yet) when calling a SpringBoard
    ' ONLY if they are small.. (flat-square)
    if sizes.hdWidth.toInt() < 200 then 
        sizes.detailHDH = "300"
        sizes.detailHDW = "300"
        sizes.detailSDH = "300"
        sizes.detailSDW = "300"
    else
        sizes.detailHDH = sizes.hdHeight
        sizes.detailHDW = sizes.hdWidth
        sizes.detailSDH = sizes.sdHeight
        sizes.detailSDW = sizes.sdWidth
    end if

    return sizes
End Function

Function createBaseMetadata(container, item, thumb=invalid) As Object
    metadata = CreateObject("roAssociativeArray")
    imageDir = GetGlobalAA().Lookup("rf_theme_dir")

    server = container.server
    if item@machineIdentifier <> invalid then
        server = GetPlexMediaServer(item@machineIdentifier)
    end if

    setMetaBasics(metadata, container, item)

    sizes = ImageSizes(container.ViewGroup, item@type)
    if thumb = invalid then
        thumb = firstOf(item@thumb, item@parentThumb, item@grandparentThumb, container.xml@thumb)
    end if

    if thumb <> invalid AND thumb <> "" AND server <> invalid then
        metadata.SDPosterURL = server.TranscodedImage(container.sourceUrl, thumb, sizes.sdWidth, sizes.sdHeight)
        metadata.HDPosterURL = server.TranscodedImage(container.sourceUrl, thumb, sizes.hdWidth, sizes.hdHeight)
        ' use a larger thumb for the SpringBoard screen
        metadata.SDsbThumb = server.TranscodedImage(container.sourceUrl, thumb, sizes.detailSDW, sizes.detailSDH)
        metadata.HDsbThumb = server.TranscodedImage(container.sourceUrl, thumb, sizes.detailHDW, sizes.detailHDH)
    else
        metadata.SDPosterURL = imageDir + "BlankPoster.png"
        metadata.HDPosterURL = imageDir + "BlankPoster.png"
    end if

    metadata.sourceUrl = container.sourceUrl
    metadata.server = server

    metadata.HasDetails = false
    metadata.ParseDetails = baseParseDetails
    metadata.Refresh = baseMetadataRefresh

    PosterIndicators(metadata)

    return metadata
End Function

Function baseParseDetails()
    m.HasDetails = true
    return m
End Function

Sub baseMetadataRefresh(detailed=false)
    ' ljunkie - required to refresh watched status ( and indicators )
    if m.key <> invalid and m.server <> invalid and m.sourceUrl <> invalid then
        container = createPlexContainerForUrl(m.server, m.sourceUrl, "")
        if container <> invalid and container.xml <> invalid and type(container.xml.Directory) = "roXMLList" then 
            for each dirXml in container.xml.Directory
                if dirXml@key = m.key then 
                    setMetaBasics(m, container, dirXml)
                    exit for
                end if
            end for
        end if
    end if
End Sub


Sub setMetaBasics(meta, container, item)
    meta.Title = firstOf(item@title, item@name, "")

    ' There is a *massive* performance problem on grid views if the description
    ' isn't truncated.
    meta.Description = truncateString(item@summary, 250, invalid)
    meta.UMDescription = item@summary ' un-modified summary
    meta.ShortDescriptionLine1 = meta.Title
    meta.ShortDescriptionLine2 = truncateString(item@summary, 250, invalid)
    meta.Type = item@type
    meta.Key = item@key
    meta.Settings = item@settings
    meta.NodeName = item.GetName()

    meta.viewGroup = container.ViewGroup

    meta.sourceTitle = item@sourceTitle

    if (tostr(meta.viewgroup) <> "album" and tostr(meta.type) <> "album") and  RegRead("rf_tvwatch", "preferences", "enabled") = "enabled" then 
        if item@leafCount <> invalid then meta.leafCount = item@leafCount
        if item@viewedLeafCount <> invalid then meta.viewedLeafCount = item@viewedLeafCount

        meta.umTitle = meta.Title ' change from OrigTitle -- confusion with originalTitle and unmodified Title
    
        ' append title differently based on leaf/viewed
        ' I might what to check the type here - not sure how this looks for types other than shows (TODO)

        ' START: ljunkie - leafCount viewedLeafCount ( how many items, how many items watched)
        if item@viewedLeafCount <> invalid and item@leafCount <> invalid 
            extra = invalid
            if val(item@viewedLeafCount) = val(item@leafCount) then
                extra = " (watched)" ' all items watched
            else if val(item@viewedLeafCount) > 0 then
                extra = " (" + tostr(item@viewedLeafCount) + " of " + tostr(item@leafCount) + " watched)" ' partially watched - show count
            else if val(item@leafCount) > 0 then
                extra = " (" + tostr(item@leafCount) + ")"
            end if
            if extra <> invalid then
                meta.Title = meta.Title + extra
                meta.ShortDescriptionLine1 = meta.ShortDescriptionLine1 + extra
            end if
        end if
        ' END: ljunkie - leafCount viewedLeafCount ( how many items, how many items watched)
    end if

    if container.xml@mixedParents = "1" then
        parentTitle = firstOf(item@parentTitle, container.xml@parentTitle, "")
        if parentTitle <> "" then 
            meta.Title = parentTitle + ": " + meta.Title
            meta.parentTitle = parentTitle
        end if
    end if

    if item@userRating <> invalid then meta.UserRating =  int(val(item@userRating)*10)

    PosterIndicators(meta)
end sub

Function newSearchMetadata(container, item) As Object
    metadata = createBaseMetadata(container, item)
    imageDir = GetGlobalAA().Lookup("rf_theme_dir")

    metadata.type = "search"
    metadata.ContentType = "search"
    metadata.search = true
    metadata.prompt = item@prompt

    if metadata.SDPosterURL = invalid OR Left(metadata.SDPosterURL, 4) = "file" then
        metadata.SDPosterURL = imageDir + "search.png"
        metadata.HDPosterURL = imageDir + "search.png"
    end if

    ' Special handling for search items inside channels, which may actually be
    ' text input objects. There's no good way to tell. :[
    if metadata.key.Left(1) = "/" then
        ' If the item isn't for a search service and doesn't start with "Search",
        ' we'll try using a keyboard screen. Anything else sounds like an honest
        ' to goodness search and will get a search screen.
        if instr(1, metadata.key, "/serviceSearch") <= 0 AND metadata.prompt.Left(6) <> "Search" then
            metadata.ContentType = "keyboard"
        end if
    end if

    return metadata
End Function

Function newSettingMetadata(container, item) As Object
    metadata = CreateObject("roAssociativeArray")

    metadata.ContentType = "setting"
    metadata.setting = true

    metadata.type = firstOf(item@type, "text")
    metadata.default = firstOf(item@default, "")
    metadata.value = firstOf(item@value, "")
    metadata.label = firstOf(item@label, "")
    metadata.id = firstOf(item@id, "")
    metadata.hidden = (item@option = "hidden")
    metadata.secure = (item@secure = "true")

    if metadata.value = "" then
        metadata.value = metadata.default
    end if

    if metadata.type = "enum" then
        re = CreateObject("roRegex", "\|", "")
        metadata.values = re.Split(item@values)
    end if

    metadata.GetValueString = settingGetValueString

    return metadata
End Function

Function settingGetValueString() As String
    if m.type = "enum" then
        value = m.values[m.value.toint()]
    else
        value = m.value
    end if

    if m.hidden OR m.secure then
        re = CreateObject("roRegex", ".", "i")
        value = re.ReplaceAll(value, "\*")
    end if

    return value
End Function

