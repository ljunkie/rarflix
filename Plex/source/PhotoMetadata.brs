'itei*
'* Metadata objects for photo data
'*

Function createBasePhotoMetadata(container, item) As Object
    metadata = createBaseMetadata(container, item)

    metadata.ratingKey = item@ratingKey

    ' photos don't have a default - so only userrating for now
    userRating = item@userRating
    if userRating <> invalid then
	metadata.UserRating =  int(val(userRating)*10)
        ' if prefer user rating OR we ONLY show user ratings, then override the starRating if it exists (isn't need for photos yet)
        ' refer to VideoMetadata if these defaults ever change
            metadata.StarRating =  int(val(userRating)*10)
    else
	metadata.UserRating =  0
    end if


    ' We never need to fetch and parse additional details for audio metadata
    metadata.HasDetails = True

    return metadata
End Function

Function newPhotoMetadata(container, item, detailed=true) As Object
    photo = createBasePhotoMetadata(container, item)

    photo.Title = item@title
    photo.mediaContainerIdentifier = container.xml@identifier
    photo.ContentType = "photo"
    if photo.Type = invalid then photo.Type = "photo"
    photo.media = ParsePhotoMedia(item)

    if photo.media.Count() > 0 AND photo.media[0].preferredPart <> invalid then
        photo.Url = FullUrl(photo.server.serverUrl, photo.sourceUrl, photo.media[0].preferredPart.key)
    else
        photo.Url = FullUrl(photo.server.serverUrl, photo.sourceUrl, photo.key)
    end if

    photo.TextOverlayUL = photo.Title
    photo.TextOverlayBody = item@summary

    ' If there's no thumb, make a thumb out of the full URL.
    if photo.SDPosterURL = invalid OR Left(photo.SDPosterURL, 4) = "file" then
        sizes = ImageSizes("photos", "photo")
        photo.SDPosterURL = photo.server.TranscodedImage("", photo.Url, sizes.sdWidth, sizes.sdHeight)
        photo.HDPosterURL = photo.server.TranscodedImage("", photo.Url, sizes.hdWidth, sizes.hdHeight)
    end if

    ' Transcode if necessary
    if photo.media.Count() > 0 then
        format = UCase(firstOf(photo.media[0].container, "JPEG"))
        transcode = false
        size = GetGlobal("DisplaySize")

        ' JPEG and PNG are documented, GIF appears to work fine
        ' ljunkie - TODO - but it's also document the roku will cover the image back to a JPG ( is it faster to complete on the server )
        if format <> "JPEG" AND format <> "JPG" AND format <> "PNG" AND format <> "GIF" then
            Debug("Transcoding photo to JPEG from " + format)
            transcode = true
        else if photo.media[0].width > size.w OR photo.media[0].height > size.h then
            ' this will almost always happen.. i'm going to disable logging this. who is going to have images already in thumbnail format?
            ' Debug("Transcoding photo because it's unnecessarily large: " + tostr(photo.media[0].width) + "x" + tostr(photo.media[0].height))
            transcode = true
        else if photo.media[0].width <= 0 then
            Debug("Transcoding photo for fear that it requires EXIF rotation")
            transcode = true
        end if

        if transcode then
            photo.Url = photo.server.TranscodedImage("", photo.Url, size.w.toStr(), size.h.toStr())
        end if
    end if

    return photo
End Function

Function ParsePhotoMedia(photoItem) As Object
    mediaArray = CreateObject("roArray", 5, true)
    for each MediaItem in photoItem.Media
        media = CreateObject("roAssociativeArray")

        media.identifier = MediaItem@id
        media.container = MediaItem@container
        media.width = firstOf(MediaItem@width, "0").toint()
        media.height = firstOf(MediaItem@height, "0").toint()
        media.aspectratio = MediaItem@aspectRatio

        ' these will be invalid unless we directly query for the photo library key
        ' so don't expect this to be available all the time

        media.originallyAvailableAt = photoitem@originallyAvailableAt
        media.aperture = MediaItem@aperture
        media.exposure = MediaItem@exposure
        media.iso = MediaItem@iso
        media.lens = MediaItem@lens
        media.make = MediaItem@make
        media.model = MediaItem@model
        media.id = MediaItem@id

        media.parts = CreateObject("roArray", 2, true)
        for each MediaPart in MediaItem.Part
            part = CreateObject("roAssociativeArray")
            part.id = MediaPart@id
            part.key = MediaPart@key

            media.parts.Push(part)
        next

        media.preferredPart = media.parts[0]
        mediaArray.Push(media)
    next

    return mediaArray
End Function

function getExifData(metadata,compact = false) as dynamic
    container = createPlexContainerForUrl(metadata.server, metadata.server.serverUrl, metadata.key)
    if container <> invalid then
        container.getmetadata()
        ' only create dialog if metadata is available
        if type(container.metadata) = "roArray" and type(container.metadata[0].media) = "roArray" then 
            MediaInfo = container.metadata[0].media[0]
            desc = ""
            if compact then 
                if mediainfo.make <> invalid then desc = mediainfo.make + ": "
                if mediainfo.model <> invalid then desc = desc + mediainfo.model + "   "
                if mediainfo.lens <> invalid then desc = desc + "lens:" + mediainfo.lens + "   "
                if mediainfo.aperture <> invalid then desc = desc + "aperture:" + mediainfo.aperture + "   "
                if mediainfo.exposure <> invalid then desc = desc + "exposure:" + mediainfo.exposure + "   "
                if mediainfo.aspectratio <> invalid then desc = desc + "aspect:" + mediainfo.aspectratio + "   "
                if mediainfo.iso <> invalid then desc = desc + "iso:" + mediainfo.iso + "   "
                if mediainfo.width <> invalid and mediainfo.height <> invalid then desc = desc + "size:" + tostr(mediainfo.width) + " x " + tostr(mediainfo.height) + "   "
                'if mediainfo.container <> invalid then desc = desc + "format:" + mediainfo.container + "   "
                if mediainfo.originallyAvailableAt <> invalid then desc = desc + "date:" + tostr(mediainfo.originallyAvailableAt)
            else 
                if mediainfo.make <> invalid then desc = mediainfo.make + ": "
                if mediainfo.model <> invalid then desc = desc + mediainfo.model + "    "
                if mediainfo.lens <> invalid then desc = desc + "lens: " + mediainfo.lens
                if len(desc) < 50 then desc = desc + string(20," ") + "." ' hack to not make the line strech.. wtf roku
                desc = desc + chr(10)
                if mediainfo.aperture <> invalid then desc = desc + "aperture: " + mediainfo.aperture + "    "
                if mediainfo.exposure <> invalid then desc = desc + "exposure: " + mediainfo.exposure + "    "
                if mediainfo.aspectratio <> invalid then desc = desc + "aspect: " + mediainfo.aspectratio + "    "
                if mediainfo.iso <> invalid then desc = desc + "iso: " + mediainfo.iso
                desc = desc + chr(10)
                if mediainfo.width <> invalid and mediainfo.height <> invalid then desc = desc + "size: " + tostr(mediainfo.width) + " x " + tostr(mediainfo.height) + "    "
                if mediainfo.container <> invalid then desc = desc + "format: " + mediainfo.container + "    "
                if mediainfo.originallyAvailableAt <> invalid then desc = desc + "date: " + tostr(mediainfo.originallyAvailableAt)
            end if

            if desc <> "" then return desc
        end if
    end if
    return invalid
end function