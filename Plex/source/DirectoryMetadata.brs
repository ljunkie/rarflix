
Function newDirectoryMetadata(server, sourceUrl, xmlContainer, directoryItemXml) As Object
	rokuMetadata = ConstructDirectoryMetadata(server, sourceUrl, xmlContainer, directoryItemXml)
	
	rokuMetadata.server = server
	rokuMetadata.sourceUrl = sourceUrl
	rokuMetadata.viewGroup = xmlContainer@viewGroup
	return rokuMetadata
End Function


Function ConstructDirectoryMetadata(server, sourceUrl, xmlContainer, directoryItemXml) As Object	
	directory = CreateObject("roAssociativeArray")
	directory.type  = directoryItemXml@type
	directory.ContentType = directoryItemXml@type
	if directory.ContentType = "show" then
		directory.ContentType = "series"
	else if directory.ContentType = invalid then
		directory.ContentType = "appClip"
	endif
	directory.Key = directoryItemXml@key
	directory.Title = directoryItemXml@title
	directory.Description = directoryItemXml@summary
	if directory.Title = invalid then
		directory.Title = directoryItemXml@name
	endif
	directory.ShortDescriptionLine1 = directoryItemXml@title
	if directory.ShortDescriptionLine1 = invalid then
		directory.ShortDescriptionLine1 = directoryItemXml@name
	endif
	directory.ShortDescriptionLine2 = directoryItemXml@summary
	'if xmlResponse.xml@viewGroup = "Details" OR xmlResponse.xml@viewGroup = "InfoList" then
	'	video.ShortDescriptionLine2 = videoItem@summary
	'endif
	
	sizes = ImageSizes(xmlContainer@viewGroup, directory.ContentType)
	thumb = directoryItemXml@thumb
	if thumb <> invalid and thumb <> "" then
		directory.SDPosterURL = server.TranscodedImage(sourceUrl, thumb, sizes.sdWidth, sizes.sdHeight)
		directory.HDPosterURL = server.TranscodedImage(sourceUrl, thumb, sizes.hdWidth, sizes.hdHeight)
	else
		art = directoryItemXml@art
		if art = invalid then
			art = xmlContainer@art
		endif
		if art <> invalid then
			directory.SDPosterURL = server.TranscodedImage(sourceUrl, art, sizes.sdWidth, sizes.sdHeight)
			directory.HDPosterURL = server.TranscodedImage(sourceUrl, art, sizes.hdWidth, sizes.hdHeight)
		endif
	endif
	return directory
End Function
