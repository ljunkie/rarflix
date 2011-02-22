' ********************************************************************
' **  Entry point for the Plex client. Configurable themes etc. haven't been yet.
' **
' ********************************************************************

Sub Main()

    'initialize theme attributes like titles, logos and overhang color
    initTheme()

    'prepare the screen for display and get ready to begin
    screen=preShowHomeScreen("", "")
    if screen=invalid then
        print "unexpected error in preShowHomeScreen"
        return
    end if
	retrieving = CreateObject("roOneLineDialog")
	retrieving.SetTitle("Finding Plex Media Servers ...")
	retrieving.ShowBusyAnimation()
	retrieving.Show()
    servers = DiscoverPlexMediaServers()
	retrieving.Close()
    if servers.count() > 0 then
    	showHomeScreen(screen, servers)
    else
        '* TODO: user friendly can't find PMS message
    	
    endif

End Sub


'*************************************************************
'** Set the configurable theme attributes for the application
'** 
'** Configure the custom overhang and Logo attributes
'** Theme attributes affect the branding of the application
'** and are artwork, colors and offsets specific to the app
'*************************************************************

Sub initTheme()

    app = CreateObject("roAppManager")
    theme = CreateObject("roAssociativeArray")

   ' theme.OverhangOffsetSD_X = "72"
   ' theme.OverhangOffsetSD_Y = "31"
   ' theme.OverhangSliceSD = "pkg:/images/Overhang_Background_SD.png"
   ' theme.OverhangLogoSD  = "pkg:/images/Overhang_Logo_SD.png"

   ' theme.OverhangOffsetHD_X = "125"
   ' theme.OverhangOffsetHD_Y = "35"
   ' theme.OverhangSliceHD = "pkg:/images/Overhang_Background_HD.png"
   ' theme.OverhangLogoHD  = "pkg:/images/Overhang_Logo_HD.png"

    app.SetTheme(theme)

End Sub

