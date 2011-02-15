' ********************************************************************
' **  Modification of the Sample PlayVideo App to test playback, 
' **  transcoding, etc of PMS fed content
' ********************************************************************

Sub Main()
    'initialize theme attributes like titles, logos and overhang color
    initTheme()

    'display a fake screen while the real one initializes. this screen
    'has to live for the duration of the whole app to prevent flashing
    'back to the roku home screen.
    screenFacade = CreateObject("roPosterScreen")
    screenFacade.show()

    item = {   ContentType:"episode"
               SDPosterUrl:"file://pkg:/images/Cash.jpg"
               HDPosterUrl:"file://pkg:/images/Cash.jpg"
               IsHD:true
               HDBranded:true
               ShortDescriptionLine1:"Plex Media Server"
               ShortDescriptionLine2:""
               Description:"Play content from the Plex Media Server"
               Rating:"NR"
               StarRating:"80"
               Length:600
               Categories:["Technology"]
               Title:"Plex"
            }

    showSpringboardScreen(item)  
    
    'exit the app gently so that the screen doesn't flash to black
    screenFacade.showMessage("")
    sleep(25)
End Sub

'*************************************************************
'** Set the configurable theme attributes for the application
'** 
'** Configure the custom overhang and Logo attributes
'*************************************************************

Sub initTheme()

    app = CreateObject("roAppManager")
    theme = CreateObject("roAssociativeArray")

    theme.OverhangPrimaryLogoOffsetSD_X = "72"
    theme.OverhangPrimaryLogoOffsetSD_Y = "15"
    theme.OverhangSliceSD = "pkg:/images/Overhang_BackgroundSlice_SD43.png"
    theme.OverhangPrimaryLogoSD  = "pkg:/images/Logo_Overhang_SD43.png"

    theme.OverhangPrimaryLogoOffsetHD_X = "123"
    theme.OverhangPrimaryLogoOffsetHD_Y = "20"
    theme.OverhangSliceHD = "pkg:/images/Overhang_BackgroundSlice_HD.png"
    theme.OverhangPrimaryLogoHD  = "pkg:/images/Logo_Overhang_HD.png"
    
    app.SetTheme(theme)

End Sub


'*************************************************************
'** showSpringboardScreen()
'*************************************************************

Function showSpringboardScreen(item as object) As Boolean
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSpringboardScreen")

    print "showSpringboardScreen"
    
    screen.SetMessagePort(port)
    screen.AllowUpdates(false)
    if item <> invalid and type(item) = "roAssociativeArray"
        screen.SetContent(item)
    endif

    screen.SetDescriptionStyle("generic") 'audio, movie, video, generic
                                        ' generic+episode=4x3,
    screen.ClearButtons()
    screen.AddButton(1,"Play")
    screen.AddButton(2,"Go Back")
    screen.SetStaticRatingEnabled(false)
    screen.AllowUpdates(true)
    screen.Show()

    downKey=3
    selectKey=6
    while true
        msg = wait(0, screen.GetMessagePort())
        if type(msg) = "roSpringboardScreenEvent"
            if msg.isScreenClosed()
                print "Screen closed"
                exit while                
            else if msg.isButtonPressed()
                    print "Button pressed: "; msg.GetIndex(); " " msg.GetData()
                    if msg.GetIndex() = 1
                         displayVideo()
                    else if msg.GetIndex() = 2
                         return true
                    endif
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        else 
            print "wrong type.... type=";msg.GetType(); " msg: "; msg.GetMessage()
        endif
    end while


    return true
End Function


Function displayVideo()
    print "Displaying video: "
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)

	'* Some hardcoded test URLs
	'* 1080p
	'videoUrl = "/library/parts/3/Apocalypto%20(1080p).mkv"
	
	'* 720p with level = 3.1
	videoUrl = "/library/parts/9/The%20Dark%20Knight.mkv"
	
	'* 720p with level = 4.1
	'videoUrl = "/library/parts/7/Cemetery%2EJunction%2E2010%2E720p%2EBluRay%2Ex264-EbP.mkv"
	
    videoclip = ConstructVideo(videoUrl)
    video.SetContent(videoclip)
	cookiesRequest = CreateObject("roUrlTransfer")
	cookiesRequest.SetUrl(videoclip.StreamUrls[0])
	capabilities = "protocols=http-streaming-video;http-streaming-video-720p;http-streaming-video-1080p;videoDecoders=h264{profile:high&resolution:1080&level:40};audioDecoders=aac"
	cookiesRequest.AddHeader("X-Plex-Client-Capabilities", capabilities)
	cookiesHead = cookiesRequest.Head()
	cookieHeader = cookiesHead.GetResponseHeaders()["set-cookie"]
	'print "Cookies:";cookieHeader
	
	video.AddHeader("Cookie", cookieHeader)
    video.show()
    
    lastSavedPos   = 0
    statusInterval = 10 'position must change by more than this number of seconds before saving

    while true
        msg = wait(0, video.GetMessagePort())
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then 'ScreenClosed event
                stopTransfer = CreateObject("roUrlTransfer")
                stopTransfer.SetUrl("http://192.168.1.3:32400/video/:/transcode/segmented/stop")
                stopTransfer.AddHeader("Cookie", cookieHeader) 
                content = stopTransfer.GetToString()
                exit while
            else if msg.isPlaybackPosition() then
                nowpos = msg.GetIndex()
                if nowpos > 10000
                    
                end if
                if nowpos > 0
                    if abs(nowpos - lastSavedPos) > statusInterval
                        lastSavedPos = nowpos
                    end if
                end if
            else if msg.isRequestFailed()
                print "play failed: "; msg.GetMessage()
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        end if
    end while
End Function

'*
'* Constructs the actual video clip object using a PMS provided videoUrl
'*
'* TODO: check the video URL coming from PMS is HTTP encoded
'*
Function ConstructVideo(videoUrl as String) As Object
	videoclip = CreateObject("roAssociativeArray")
    videoclip.StreamBitrates = [0]
    videoclip.StreamUrls = [TranscodingVideoUrl(videoUrl)]
    videoclip.StreamQualities = ["HD"]
    videoclip.StreamFormat = "hls"
    videoclip.Title = "Plex Test Stream"
    videoclip.minBandwidth = 20
    return videoclip
End Function


'*
'* Construct the Plex transcoding URL. 
'*
Function TranscodingVideoUrl(base As String) As String
    location = "http://localhost:32400"+base
	myurl = "/video/:/transcode/segmented/start.m3u8?identifier=com.plexapp.plugins.library&ratingKey=97007888&offset=0&quality=8&url="+HttpEncode(location)+"&3g=0&httpCookies=&userAgent="
	publicKey = "KQMIY6GATPC63AIMC4R2"
	time = LinuxTime().tostr()
	msg = myurl+"@"+time
	finalMsg = HMACHash(msg)
	finalUrl = "http://192.168.1.3:32400"+myurl+"&X-Plex-Access-Key=" + publicKey + "&X-Plex-Access-Time=" + time + "&X-Plex-Access-Code=" + HttpEncode(finalMsg)
	'print "Final URL";finalUrl
    return finalUrl
End Function

'*
'* HMAC encode the message
'* 
Function HMACHash(msg As String) As String
	hmac = CreateObject("roHMAC") 
	privateKey = CreateObject("roByteArray") 
	privateKey.fromBase64String("k3U6GLkZOoNIoSgjDshPErvqMIFdE0xMTx8kgsrhnC0=")
	result = hmac.setup("sha256", privateKey)
	if result = 0
		message = CreateObject("roByteArray") 
		message.fromAsciiString(msg) 
		result = hmac.process(message)
		return result.toBase64String()
	end if
End Function

'*
'* Time since the start (of UNIX time)
'*
Function LinuxTime() As Integer
	time = CreateObject("roDateTime")
	return time.asSeconds()
End Function

'* 
'* Encode a string for URL parameter
'* 
Function HttpEncode(str As String) As String
    o = CreateObject("roUrlTransfer")
    return o.Escape(str)
End Function


