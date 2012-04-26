
Sub RunScreenSaver()
    mode = RegRead("screensaver", "preferences", "random")

    if mode <> "disabled" then
        DisplayScreenSaver(mode)
    else
        Debug("Deferring to system screensaver")
    end if
End Sub

Sub DisplayScreenSaver(mode)
    if IsHD() then
        m.default_screensaver = {url:"pkg:/images/screensaver-hd.png", SourceRect:{w:336,h:210}, TargetRect:{x:0,y:0}}
    else
        m.default_screensaver = {url:"pkg:/images/screensaver-sd.png", SourceRect:{w:248,h:140}, TargetRect:{x:0,y:0}}
    end if

    canvas = CreateScreenSaverCanvas("#FF141414")
    canvas.SetImageFunc(GetScreenSaverImage)
    canvas.SetUpdatePeriodInMS(6000)
    canvas.SetUnderscan(.05)

    if mode = "animated" then
        canvas.SetLocFunc(screensaverLib_SmoothAnimation)
        canvas.SetLocUpdatePeriodInMS(40)
    else if mode = "random" then
        canvas.SetLocFunc(screensaverLib_RandomLocation)
        canvas.SetLocUpdatePeriodInMS(0)
    else
        Debug("Unrecognized screensaver preference: " + tostr(mode))
        return
    end if

    canvas.Go()
End Sub

Function GetScreenSaverImage()
    savedImage = ReadAsciiFile("tmp:/plex_screensaver")
    if savedImage <> "" then
        tokens = savedImage.Tokenize("\")
        width = tokens[0].toint()
        height = tokens[1].toint()
        image = {url:tokens[2], SourceRect:{w:width, h:height}, TargetRect:{x:0,y:0}}
    else
        image = m.default_screensaver
    end if

    o = CreateObject("roAssociativeArray")
    o.art = image
    o.content_list = [image]

    o.GetHeight = function() :return m.art.SourceRect.h :end function
    o.GetWidth  = function() :return m.art.SourceRect.w :end function
    o.Update = function(x, y)
        m.art.TargetRect.x = x
        m.art.TargetRect.y = y
        return m.content_list
    end function

    return o
End Function

Sub SaveImagesForScreenSaver(url_SD43, url_HD, sizes)
    if IsHD() then
        WriteFileHelper("tmp:/plex_screensaver", url_HD, sizes.hdWidth, sizes.hdHeight)
    else
        WriteFileHelper("tmp:/plex_screensaver", url_SD43, sizes.sdWidth, sizes.sdHeight)
    end if
End Sub

Sub WriteFileHelper(fname, url, width, height)
    Debug("Saving image for screensaver: " + tostr(url))
    if url <> invalid then
        content = width + "\" + height + "\" + url
        if (not WriteAsciiFile(fname + "~", content)) then Debug("WriteAsciiFile() Failed")
        if (not MoveFile(fname + "~",fname)) then Debug("MoveFile() failed")
    else
        DeleteFile(fname)
    end if
End Sub

Function IsHD()
    di = CreateObject("roDeviceInfo")
    return di.GetDisplayType() = "HDTV"
End Function

