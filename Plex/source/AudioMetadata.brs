'*
'* Metadata objects for audio data (albums, artists, tracks)
'*

Function createBaseAudioMetadata(container, item) As Object
    metadata = CreateObject("roAssociativeArray")

    metadata.Title = item@title
    ' Do we need to truncate this one?
    metadata.Description = item@summary
    metadata.ShortDescriptionLine1 = item@title
    metadata.ShortDescriptionLine2 = truncateString(item@summary, 180, invalid)
    metadata.Type = item@type
    metadata.Key = item@key

    metadata.ratingKey = item@ratingKey

    sizes = ImageSizes(container.ViewGroup, item@type)
    art = firstOf(item@thumb, item@parentThumb, item@art, container.xml@art)
    if art <> invalid then
        metadata.SDPosterURL = container.server.TranscodedImage(container.sourceUrl, art, sizes.sdWidth, sizes.sdHeight)
        metadata.HDPosterURL = container.server.TranscodedImage(container.sourceUrl, art, sizes.hdWidth, sizes.hdHeight)
    end if

    metadata.sourceUrl = container.sourceUrl
    metadata.server = container.server

    return metadata
End Function

Function newArtistMetadata(container, item, detailed=true) As Object
    artist = createBaseAudioMetadata(container, item)

    artist.Artist = item@title
    artist.ContentType = "artist"
    if artist.Type = invalid then artist.Type = "artist"

    if detailed then
        artist.Categories = CreateObject("roArray", 5, true)
        for each genre in item.Genre
            artist.Categories.Push(genre@tag)
        next
    end if

    return artist
End Function

Function newAlbumMetadata(container, item, detailed=true) As Object
    album = createBaseAudioMetadata(container, item)

    album.ContentType = "album"
    if album.Type = invalid then album.Type = "album"

    album.Artist = firstOf(item@parentTitle, container.xml@parentTitle)
    album.Album = item@title
    album.ReleaseDate = firstOf(item@originallyAvailableAt, item@year)

    return album
End Function
