'*
'* Metadata objects for audio data (albums, artists, tracks)
'*

Function newArtistMetadata(container, item, detailed=true) As Object
    artist = CreateObject("roAssociativeArray")

    artist.ContentType = "artist"
    artist.Title = item@title
    ' Do we need to truncate this one?
    artist.Description = item@summary
    artist.ShortDescriptionLine1 = item@title
    artist.ShortDescriptionLine2 = truncateString(item@summary, 180, invalid)
    artist.Type = item@type
    artist.Key = item@key

    artist.ratingKey = item@ratingKey

    sizes = ImageSizes(container.ViewGroup, item@type)
    art = item@thumb
    if art = invalid then art = item@art
    if art = invalid then art = container.xml@art
    if art <> invalid then
        artist.SDPosterURL = container.server.TranscodedImage(container.sourceUrl, art, sizes.sdWidth, sizes.sdHeight)
        artist.HDPosterURL = container.server.TranscodedImage(container.sourceUrl, art, sizes.hdWidth, sizes.hdHeight)
    end if

    if detailed then
        artist.Categories = CreateObject("roArray", 5, true)
        for each genre in item.Genre
            artist.Categories.Push(genre@tag)
        next
    end if

    artist.sourceUrl = container.sourceUrl
    artist.server = container.server

    return artist
End Function
