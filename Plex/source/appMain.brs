' ********************************************************************
' **  Entry point for the Plex client. Configurable themes etc. haven't been yet.
' **
' ********************************************************************
Sub Main(args)
    m.RegistryCache = CreateObject("roAssociativeArray")
    m.userNum = 0    'First use of the userNumber. 
    RegSetUserPrefsToCurrentUser()     

    ' Process any launch args (set registry values)
    for each arg in args
        if Left(arg, 5) = "pref!" then
            pref = Mid(arg, 6)
            value = args[arg]
            Debug("Setting preference from launch param: " + pref + " = " + value)
            if value <> "" then
                RegWrite(pref, value, "preferences")
            else
                RegDelete(pref, "preferences")
            end if
        end if
    next

    ' If necessary, restore the direct play preference. It's possible for a
    ' temporary value to persist if the video player crashes.
    directPlay = RegRead("directplay_restore", "preferences")
    if directPlay <> invalid then
        Debug("Restoring direct play options to: " + tostr(directPlay))
        RegWrite("directplay", directPlay, "preferences")
        RegDelete("directplay_restore", "preferences")
    end if

    RegDelete("quality_override", "preferences")

    ' ljunkie - remove prefs on start - testing
    'RegDelete("rf_bcdynamic", "preferences")
    'RegDelete("rf_rottentomatoes", "preferences")
    'RegDelete("rf_trailers", "preferences")
    'RegDelete("rf_tvwatch", "preferences")


    ' Convert the old theme music preference to the new one
    oldThemeMusic = RegRead("play_theme_music", "preferences", "")
    if oldThemeMusic <> "" then
        if oldThemeMusic = "0" then
            RegWrite("theme_music", "preferences", "disabled")
        end if
        RegDelete("play_theme_music", "preferences")
    end if

    'initialize theme attributes like titles, logos and overhang color
    initTheme()

    initGlobals()
 
    'load rarflix prefs
    rarflix = InitRARFlix() 

    'prepare the screen for display and get ready to begin
    controller = createViewController()

    ' restore the Audio if we set the global - and delete it. This is probably due to the exit confirmation
    ' this may need some more work. TODO once we have channel exit confirmation
    if GetGlobalAA().Lookup("restoreAudio") <> invalid then 
        resetPort = controller.audioPlayer.port
        resetVC = controller.audioPlayer.viewcontroller
        controller.audioPlayer = invalid
        controller.audioPlayer = GetGlobalAA().Lookup("restoreAudio")
        controller.audioPlayer.viewcontroller = resetVC
        controller.audioPlayer.port =  resetPort
        GetGlobalAA().Delete("restoreAudio")
    end if

    controller.Show()
End Sub

Sub initGlobals()
    device = CreateObject("roDeviceInfo")

    version = device.GetVersion()
    major = Mid(version, 3, 1).toInt()
    minor = Mid(version, 5, 2).toInt()
    build = Mid(version, 8, 5).toInt()
    versionStr = major.toStr() + "." + minor.toStr() + " build " + build.toStr()

    GetGlobalAA().AddReplace("rokuVersionStr", versionStr)
    GetGlobalAA().AddReplace("rokuVersionArr", [major, minor, build])

    Debug("UTC time: " + CurrentTimeAsString(false))
    Debug("Roku version: " + versionStr + " (" + version + ")")

    manifest = ReadAsciiFile("pkg:/manifest")
    lines = manifest.Tokenize(chr(10))
    aa = {}
    for each line in lines
        entry = line.Tokenize("=")
        aa.AddReplace(entry[0], entry[1])
    next

    appVersion = firstOf(aa["version"], "Unknown")
    GetGlobalAA().AddReplace("appVersionStr", appVersion)
    GetGlobalAA().AddReplace("appName", firstOf(aa["title"], "Unknown"))

    Debug("App version: " + appVersion)

    knownModels = {}
    knownModels["N1050"] = "Roku SD"
    knownModels["N1000"] = "Roku HD"
    knownModels["N1100"] = "Roku HD"
    knownModels["2000C"] = "Roku HD"
    knownModels["2050N"] = "Roku XD"
    knownModels["2050X"] = "Roku XD"
    knownModels["N1101"] = "Roku XD|S"
    knownModels["2100X"] = "Roku XD|S"
    knownModels["2400X"] = "Roku LT"
    knownModels["2450X"] = "Roku LT"
    knownModels["2400SK"] = "Now TV"
    ' 2500X is also Roku HD, but the newer meaning of it... not sure how best to distinguish
    knownModels["2500X"] = "Roku HD (New)"
    knownModels["3000X"] = "Roku 2 HD"
    knownModels["3050X"] = "Roku 2 XD"
    knownModels["3100X"] = "Roku 2 XS"
    knownModels["3400X"] = "Roku Streaming Stick"
    knownModels["3420X"] = "Roku Streaming Stick"
    knownModels["4200R"] = "Roku 3"
    knownModels["4200X"] = "Roku 3"

    model = firstOf(knownModels[device.GetModel()], "Roku " + device.GetModel())
    GetGlobalAA().AddReplace("rokuModel", model)

    Debug("Roku model: " + model)

    GetGlobalAA().AddReplace("rokuUniqueID", device.GetDeviceUniqueId())

    ' The Roku 1 doesn't seem to like anamorphic videos. It stretches them
    ' vertically and squishes them horizontally. We should try not to Direct
    ' Play these videos, and tell the transcoder that we don't support them.
    ' It doesn't appear to matter how the Roku is configured, even if the
    ' display type is set to 16:9 Anamorphic the videos are distorted.
    ' On the Roku 2, support was somewhat murkier, but 4.8 is intended to
    ' fix things.

    Debug("Display type: " + tostr(device.GetDisplayType()))

    playsAnamorphic = major > 4 OR (major = 4 AND (minor >= 8 OR device.GetDisplayType() = "HDTV"))
    Debug("Anamorphic support: " + tostr(playsAnamorphic))
    GetGlobalAA().AddReplace("playsAnamorphic", playsAnamorphic)

    ' Support for ReFrames seems mixed. These numbers could be wrong, but
    ' there are reports that the Roku 1 can't handle more than 5 ReFrames,
    ' and testing has shown that the video is black beyond that point. The
    ' Roku 2 has been observed to play all the way up to 16 ReFrames, but
    ' on at least one test video there were noticeable artifacts as the
    ' number increased, starting with 8.
    if major >= 4 then
        ' upping this to 9 for now -- RR look into this later and set as a preference 
        GetGlobalAA().AddReplace("maxRefFrames", 9)
    else
        GetGlobalAA().AddReplace("maxRefFrames", 5)
    end if

    GetGlobalAA().AddReplace("IsHD", device.GetDisplayType() = "HDTV")

    ' Set up mappings from old-style quality to the new transcoder params.
    GetGlobalAA().AddReplace("TranscodeVideoQualities",   ["10",      "20",     "30",     "30",     "40",     "60",     "60",      "75",      "100",     "60",       "75",       "90",        "100"])
    GetGlobalAA().AddReplace("TranscodeVideoResolutions", ["220x180", "220x128","284x160","420x240","576x320","720x480","1024x768","1280x720","1280x720","1920x1080","1920x1080","1920x1080", "1920x1080"])
    GetGlobalAA().AddReplace("TranscodeVideoBitrates",    ["64",      "96",     "208",    "320",    "720",    "1500",   "2000",    "3000",    "4000",    "8000",     "10000",    "12000",     "20000"])

    ' Stash some more info from roDeviceInfo into globals. Fetching the device
    ' info can be slow, especially for anything related to metadata creation
    ' that may happen inside a loop.

    GetGlobalAA().AddReplace("DisplaySize", device.GetDisplaySize())
    GetGlobalAA().AddReplace("DisplayMode", device.GetDisplayMode())
    GetGlobalAA().AddReplace("DisplayType", device.GetDisplayType())

    GetGlobalAA().AddReplace("legacy1080p", (device.HasFeature("1080p_hardware") AND major < 4))
    SupportsSurroundSound()
End Sub

Function GetGlobal(var, default=invalid)
    return firstOf(GetGlobalAA().Lookup(var), default)
End Function

'Returns array that contains information for duplicating the background on an roImageCanvas screen
function getImageCanvasTheme() 
    'break these up into a bunch of layers to ensure proper layering on screen
    colors = { colors : {  
                background : "#" + GetGlobalAA().Lookup("rfBGcolor")
                titleText : "#BFBFBF"
                normalText : "#999999"
                detailText : "#74777A"
                subtleText : "#525252"
                }}
    if GetGlobal("IsHD") = true then
        obj = {
            background : [{Color:"#363636", CompositionMode:"Source"}]    'Set opaque background to keep from flashing    '#363636
            backgroundItems : [ {url:GetGlobalAA().Lookup("rf_theme_dir")+ "Background_HD.jpg"}]
            logoItems : [ {url:"pkg:/images/logo_final_HD.png", TargetRect:{ x:125,y:10 }} ]
            breadCrumbs : [ {  Text:"", TargetRect:{x:640,y:10,w:520,h:89}  '16 pixel border on bottom of breadcrumb
                               TextAttrs:{Color:colors.colors.titleText, Font:"Medium",HAlign:"Right", VAlign:"Center",Direction:"LeftToRight"} } ]
        }
    else
        obj = {
            background : [{Color:"#363636", CompositionMode:"Source"}]    'Set opaque background to keep from flashing    '#363636
            backgroundItems : [ {url:GetGlobalAA().Lookup("rf_theme_dir")+ "Background_SD.jpg"}]
            logoItems : [ {url:"pkg:/images/logo_final_SD.png", TargetRect:{ x:72,y:10 }} ]
            breadCrumbs : [ {  Text:"", TargetRect:{x:360,y:10,w:260,h:56}  '16 pixel border on bottom of breadcrumb
                              TextAttrs:{Color:colors.colors.titleText, Font:"Medium",HAlign:"Right", VAlign:"Center",Direction:"LeftToRight"} } ]
        }
    endif
    obj["background"][0]["Color"] = colors.colors.background    'set background color 
    obj.Append(colors)
    return obj
end function

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

    rfTheme = RegRead("rf_theme", "preferences", "black")
    if rfTheme = "black" then 
        GetGlobalAA().AddReplace("rf_theme_dir", "file://pkg:/images/black/")
        GetGlobalAA().AddReplace("rfBGcolor", "000000")
    else 
        GetGlobalAA().AddReplace("rf_theme_dir", "file://pkg:/images/")
        GetGlobalAA().AddReplace("rfBGcolor", "363636")
    end if
    imageDir = GetGlobalAA().Lookup("rf_theme_dir")

    theme.OverhangOffsetSD_X = "72"
    theme.OverhangOffsetSD_Y = "10"
    theme.OverhangSliceSD = imageDir + "Background_SD.jpg"
    theme.OverhangLogoSD  = "pkg:/images/logo_final_SD.png" ' logo is transparent

    theme.OverhangOffsetHD_X = "125"    'these settings are duplicated in getImageCanvasTheme() so keep them in sync with this
    theme.OverhangOffsetHD_Y = "10"
    theme.OverhangSliceHD = imageDir + "Background_HD.jpg"
    theme.OverhangLogoHD  = "pkg:/images/logo_final_HD.png" ' logo is transparent

    theme.GridScreenLogoOffsetHD_X = "125"
    theme.GridScreenLogoOffsetHD_Y = "10"
    theme.GridScreenOverhangSliceHD = imageDir + "Background_HD.jpg"
    theme.GridScreenLogoHD  = "pkg:/images/logo_final_HD.png" ' logo is transparent
    theme.GridScreenOverhangHeightHD = "99"

    theme.GridScreenLogoOffsetSD_X = "72"
    theme.GridScreenLogoOffsetSD_Y = "10"
    theme.GridScreenOverhangSliceSD = imageDir + "Background_SD.jpg"
    theme.GridScreenLogoSD  = "pkg:/images/logo_final_SD.png" ' logo is transparent
    theme.GridScreenOverhangHeightSD = "66"

    'these settings are duplicated in getImageCanvasTheme() so keep them in sync with this
    background = "#" + GetGlobalAA().Lookup("rfBGcolor")
    titleText = "#BFBFBF" ' text in search screen. not sure where else yet
    normalText = "#999999" ' shared with dialog and summary text in video screen ( if we can make the dialog black, then we can lighten this up)
    detailText = "#74777A"
    subtleText = "#525252"
    plexOrange = "#FFA500"


    theme.BackgroundColor = background

    theme.GridScreenBackgroundColor = background
    theme.GridScreenRetrievingColor = subtleText
    theme.GridScreenListNameColor = titleText
    theme.CounterTextLeft = titleText
    theme.CounterSeparator = normalText
    theme.CounterTextRight = normalText
    ' Defaults for all GridScreenDescriptionXXX

    ' The actual focus border is set by the grid based on the style
    theme.GridScreenBorderOffsetHD = "(-9,-9)"
    theme.GridScreenBorderOffsetSD = "(-9,-9)"

    theme.ListScreenHeaderText = titleText
    theme.ListItemText = normalText
    theme.ListItemHighlightText = titleText
    theme.ListScreenDescriptionText = normalText

    theme.ParagraphHeaderText = titleText
    theme.ParagraphBodyText = normalText

    ' ljunkei this theme actually looks better even with the original.. no need to toggle
    if rfTheme = "black" then 
        theme.ThemeType = "generic-dark"
        theme.DialogTitleText="#000000" ' header should be bold and black
        theme.DialogBodyText="#222222"  ' test should now be too light or to dark
    else
        theme.DialogTitleText="#BFBFBF"
        theme.DialogBodyText="#BFBFBF"
    end if
    theme.ButtonNormalColor = "#333333" 'normalText
    theme.ButtonHighlightColor = plexOrange
    ' Default for ButtonHighlightColor seems OK...

    theme.RegistrationCodeColor = plexOrange
    theme.RegistrationFocalColor = normalText

    theme.SearchHeaderText = titleText
    theme.ButtonMenuHighlightText = plexOrange 'titleText
'    theme.ButtonMenuHighlightColor = "#FFA500" ' plex orange
    theme.ButtonMenuNormalText = titleText

    theme.PosterScreenLine1Text = titleText
    theme.PosterScreenLine2Text = normalText

    theme.SpringboardTitleText = titleText
    theme.SpringboardArtistColor = titleText
    theme.SpringboardArtistLabelColor = detailText
    theme.SpringboardAlbumColor = titleText
    theme.SpringboardAlbumLabelColor = detailText
    theme.SpringboardRuntimeColor = normalText
    theme.SpringboardActorColor = titleText
    theme.SpringboardDirectorColor = titleText
    theme.SpringboardDirectorLabel = detailText
    theme.SpringboardGenreColor = normalText
    theme.SpringboardSynopsisColor = normalText
    theme.SpringboardAllow6Buttons = "true"
    ' Not sure these are actually used, but they should probably be normal
    theme.SpringboardSynopsisText = normalText
    theme.EpisodeSynopsisText = normalText

    subtitleColor = RegRead("subtitle_color", "preferences", "")
    if subtitleColor <> "" then theme.SubtitleColor = subtitleColor

    app.SetTheme(theme)

End Sub

Function SupportsSurroundSound(transcoding=false, refresh=false) As Boolean
    ' Before the Roku 3, there's no need to ever refresh.
    major = GetGlobal("rokuVersionArr", [0])[0]

    if m.SurroundSoundTimer = invalid then
        refresh = true
        m.SurroundSoundTimer = CreateTimer()
    else if major <= 4 then
        refresh = false
    else if m.SurroundSoundTimer.GetElapsedSeconds() > 10 then
        refresh = true
    end if

    if refresh then
        device = CreateObject("roDeviceInfo")
        result = device.HasFeature("5.1_surround_sound")
        GetGlobalAA().AddReplace("surroundSound", result)
        m.SurroundSoundTimer.Mark()
    else
        result = GetGlobal("surroundSound")
    end if

    if transcoding then
        return (result AND major >= 4)
    else
        return result
    end if
End Function
