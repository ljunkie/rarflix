Function SlideShowSetup(port as object, underscan, border, interval)
    slideshow = CreateObject("roSlideShow")
    slideshow.SetMessagePort(port)
    slideshow.SetUnderscan(underscan)      ' shrink pictures by 5% to show a little bit of border (no overscan)
    slideshow.SetBorderColor(border)
    slideshow.SetMaxUpscale(8.0)
    slideshow.SetDisplayMode("best-fit")
    slideshow.SetPeriod(interval)
    slideshow.Show()

    return slideshow
End Function

Function GetPhotoList(server, sourceUrl) As Object
    pl = CreateObject("roList")

    responseXml = DirectMediaXml(server, sourceUrl)
    nodes = responseXml.GetChildElements()
    for each n in nodes
        if n.GetName() = "Photo" then
            key = n.Media.Part@key
            if (key <> invalid) then
                url = FullUrl(server.serverUrl, sourceUrl, key)
                pl.Push(url)

                'Print "Found URL: ";url
            end if
        end if
    next

    return pl
End Function

Sub DisplaySlideShow(port, slideshow, photolist)
    'print "in DisplaySlideShow"

    'this is an alternate technique for adding content using AddContent():
    aa = CreateObject("roAssociativeArray")
    for each photo in photolist
       aa.Url = photo
       slideshow.AddContent(aa)
    next

waitformsg:
    msg = wait(0, port)
    if msg <> invalid then                          'invalid is timed-out
        'print "DisplaySlideShow: class of msg: ";type(msg); " type:";msg.gettype()
        if type(msg) = "roSlideShowEvent" then
            if msg.isScreenClosed() then
                return
            else if msg.isButtonPressed() then
                print "Menu button pressed: " + Stri(msg.GetIndex())
            else if msg.isPlaybackPosition() then
                onscreenphoto = msg.GetIndex()
                'print "slideshow display: " + Stri(msg.GetIndex())
            else if msg.isRemoteKeyPressed() then
                print "Button pressed: " + Stri(msg.GetIndex())
            else if msg.isRequestSucceeded() then
                'print "preload succeeded: " + Stri(msg.GetIndex())
            elseif msg.isRequestFailed() then
                print "preload failed: " + Stri(msg.GetIndex())
            elseif msg.isRequestInterrupted() then
                print "preload interrupted" + Stri(msg.GetIndex())
            elseif msg.isPaused() then
                print "paused"
            elseif msg.isResumed() then
                print "resumed"
            end if
        end if
    end if
    goto waitformsg
End Sub
