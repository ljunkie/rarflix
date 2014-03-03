'RunScreenSaver() is called by Roku when idle is detected.  Note that this runs as a seperate thread and 
'is debugged on a different port.
'Note that this thread does NOT share global scope with the main thread.  All variables need to be recreated
'or shared via registry or files.
Sub RunScreenSaver()
    m.RegistryCache = CreateObject("roAssociativeArray")
    mode = RegRead("screensaver", "preferences", "random")

    if mode <> "disabled" then
        initGlobals()
        if GetGlobal("IsHD") then
            m.default_screensaver = {url:"pkg:/images/screensaver-hd.png", SourceRect:{w:336,h:210}, TargetRect:{x:0,y:0}}
        else
            m.default_screensaver = {url:"pkg:/images/screensaver-sd.png", SourceRect:{w:248,h:140}, TargetRect:{x:0,y:0}}
        end if
    
        m.ss_timer = CreateObject("roTimespan")
        m.ss_last_url = invalid
    
        canvas = CreateScreenSaverCanvas("#FF000000")
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
        canvas.Go() 'Doesn't return until screensaver is cancelled'
    else
        Debug("Deferring to system screensaver")
    end if
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

    ' If we've been on the same screensaver image for a long time, give the
    ' PMS a break and switch to the default image from the package.

    if m.ss_last_url <> image.url then
        m.ss_timer.Mark()
        m.ss_last_url = image.url
    end if

    if left(image.url, 4) <> "pkg:" AND m.ss_timer.TotalSeconds() > 7200 then
        SaveImagesForScreenSaver(invalid, {})
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

Sub SaveImagesForScreenSaver(item, sizes)
    ' Passing a token to the screensaver through the tmp file and then
    ' adding it to roImageCanvas requests as a header is (oddly) tricky,
    ' so just add it to the URL.

    token = ""
    if item <> invalid AND item.server <> invalid AND item.server.AccessToken <> invalid then
        if item.HDPosterURL <> invalid and Left(item.HDPosterURL, 4) = "http" then token = "&X-Plex-Token=" + item.server.AccessToken
    end if

    thumbUrlHD = invalid:thumbUrlSD = invalid

    ' ljunkie - override the item size for the screen saver. We don't want too large or too small
    if item <> invalid then 
        regW = CreateObject("roRegex", "width=\d+", "i"):regH = CreateObject("roRegex", "height=\d+", "i")
        hasToken = CreateObject("roRegex", "X-Plex-Token=\w+", "i")

        thumbUrlHD = item.HDPosterURL:thumbUrlSD = item.SDPosterURL
                
        if thumbUrlHD <> invalid then 
            thumbUrlHD = regW.Replace(thumbUrlHD, "width=300"):thumbUrlHD = regH.Replace(thumbUrlHD, "height=300")
            ' RARflix normally includes the PlexToken on any posterUrl - so appending the token shouldn't be required
            if NOT hasToken.IsMatch(thumbUrlHD) then thumbUrlHD = thumbUrlHD + token
        end if

        if thumbUrlSD <> invalid then 
            thumbUrlSD = regH.Replace(thumbUrlSD, "height=300"):thumbUrlSD = regW.Replace(thumbUrlSD, "width=300")
            ' RARflix normally includes the PlexToken on any posterUrl - so appending the token shouldn't be required
            if NOT hasToken.IsMatch(thumbUrlSD) then thumbUrlSD = thumbUrlSD + token
        end if

    end if

    isLocal = CreateObject("roRegex", "file://", "i") ' exclue local images 
    isCustom = CreateObject("roRegex", "d1gah69i16tuow", "i")

    if item = invalid or item.server = invalid or tostr(item.contenttype) = "section" then
        Debug("item invalid[1] -- removing screen saver image")
        WriteFileHelper("tmp:/plex_screensaver", invalid, invalid, invalid)
    else if thumbUrlHD <> invalid and isLocal.isMatch(thumbUrlHD) then
        Debug("item is local image -- removing screen saver image")
        WriteFileHelper("tmp:/plex_screensaver", invalid, invalid, invalid)
    else if thumbUrlHD <> invalid and isCustom.isMatch(thumbUrlHD) then
        Debug("item is custom icon -- removing screen saver image")
        WriteFileHelper("tmp:/plex_screensaver", invalid, invalid, invalid)
    else if GetGlobal("IsHD") and thumbUrlHD <> invalid then
        WriteFileHelper("tmp:/plex_screensaver", thumbUrlHD, "300", "300")
    else if thumbUrlSD <> invalid then 
        WriteFileHelper("tmp:/plex_screensaver", thumbUrlSD, "300", "300")
    else 
        Debug("item invalid[2] -- removing screen saver image")
        WriteFileHelper("tmp:/plex_screensaver", invalid, invalid, invalid)
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
