'* Rob Reed: Cast and Crew functions
'*  
'* misc rarflix function
'*

' other functions required for my mods

function isRFdev() as boolean
    ' dev only
    if GetGlobalAA().appName = "RARflixDev" then 
        return true
    end if
    return false
end function

function isRFtest() as boolean
    ' test and dev 
    if GetGlobalAA().appName = "RARflix" then 
        return false
    end if
    return true
end function

Sub InitRARflix() 

    GetGlobalAA()
    'RegDelete("userprofile_icon_color", "preferences")
    'RegDelete("rf_unwatched_limit", "preferences")
    'RegDelete("rf_grid_style", "preferences")
    'RegDelete("rf_photos_grid_style", "preferences")
    'RegDelete("rf_poster_grid_style", "preferences")
    'RegDelete("rf_theme", "preferences")
    'RegDelete("rf_img_overlay", "preferences")
    Debug("=======================RARFLIX SETTINGS ====================================")

    ' purge specific sections - works for unclean exists ( add new sections to purge to "purge_sections")
    Debug("---- purge registry settings for specific sections ---- ")
    purge_sections = ["rf_notified"]
    flush = false
    reg = CreateObject("roRegistry")
    reg_keys = reg.Getsectionlist()
    for each purge in purge_sections 
        for each sec in reg_keys
            if purge = sec then 
                Debug("    purging " + purge + " from registry")
                reg.Delete(sec)
                flush = true
            end if 
         next
    next
    if flush then 
        reg.Flush()
        Debug("    flushed changes to registry")
    end if

    '     this might be useful if we ever need to remove specific keys -- needs work since it was used for what I am doing above (above is better to flush all)
    '     flush = []
    '     for each sec_key in purge_sections 
    '         sec = CreateObject("roRegistrySection", sec_key)
    '         keys = sec.GetKeyList()
    '         delete  = invalid
    '         for each k in keys
    '             delete = sec_key
    '             Debug("    deleting " + tostr(k) + " from " + tostr(sec_key))
    '             sec.Delete(k)
    '         next
    '         if delete <> invalid then flush.Push(delete)
    '     next 
    '
    '     ' we only want to flush once per registry section     
    '     if flush.Count() > 0 then
    '         for each sec_key in flush
    '             sec = CreateObject("roRegistrySection", sec_key)
    '             sec.Flush()
    '             Debug("Flush called for " + tostr(sec_key))
    '         next
    '     end if

    Debug("---- end purge ----")

    ' Temporarily disable theme music due to bug - user can change it back if they really want it
    ' 2013-12-01 -- this has played it's role now... theme_music defaults to "disabled"
    'if RegRead("rf_temp_thememusic", "preferences","first") = "first" then
    '    prev_setting = RegRead("theme_music", "preferences","disabled")
    '    Debug("first run - disabling theme music due to bug")
    '    RegWrite("theme_music", "disabled", "preferences")
    '    RegWrite("rf_temp_thememusic", prev_setting, "preferences")
    'end if

    ' reset the grid style to flat-portrait/photo-fit - only once
    ' we can imcrement this to change settings on newer versions
    ' 2013-12-01
    ' 2013-12-04 (3) - forcing images instead of numbers for episodic view
    '                  this will also force Poster/Photo-fit for grid still ( but that's ok )
    forceVer = "3"
    if RegRead("rf_force_reg", "preferences","0") <> forceVer then
        RegWrite("rf_force_reg", forceVer, "preferences")
        Debug("---- first run - forcing grid mode/styule")
        if GetGlobal("IsHD") = true then RegWrite("rf_grid_style", "flat-portrait", "preferences")
        RegWrite("rf_poster_displaymode", "scale-to-fit", "preferences")
        RegWrite("rf_grid_displaymode", "photo-fit", "preferences")
        'RegWrite("rf_episode_episodic_thumbnail", "enabled", "preferences") - default as of v3.1.2
    end if

    ' set remote pref to legacy is device is legacy ( only on the first run -- users can override this )
    RegDelete("legacy_remote", "preferences")
    if RegRead("legacy_remote", "preferences") = invalid then 
        if GetGlobal("rokuLegacy") = true then 
            RegWrite("legacy_remote", "1", "preferences")
        else 
            RegWrite("legacy_remote", "0", "preferences")
        end if
    end if

    ' v3.1.2 - forces everyone to use images for the episodic view ( TV shows only )
    if RegRead("rf_episode_episodic_thumbnail", "preferences","enabled") <> "enabled" then RegWrite("rf_episode_episodic_thumbnail", "enabled", "preferences")

    ' cleaning up some options -- these *should* not need a toggle anymore
    '   I.E. we changed ways the Official channel works, but don't need to toggle to go back to the Official way
    '
    ' Force dynamic breadcrumbs
    RegWrite("rf_bcdynamic", "enabled", "preferences")
    ' end cleaning of options
 
    'RegRead("rf_theme", "preferences","black") done in appMain initTheme()
    RegRead("rf_img_overlay", "preferences","BFBFBF") ' plex white
    RegRead("rf_channel_text", "preferences","disabled") ' enabled channel icons to show text ( after the main row )
    RegRead("rf_poster_grid", "preferences","grid")
    RegRead("rf_grid_style", "preferences","flat-portrait")
    RegRead("rf_home_displaymode", "preferences","photo-fit")
    RegRead("rf_grid_displaymode", "preferences","photo-fit")
    RegRead("rf_poster_displaymode", "preferences","scale-to-fit")
    RegRead("rf_music_artist", "preferences","track")
    RegRead("rf_grid_dynamic", "preferences","full")
    RegRead("rf_rottentomatoes", "preferences","enabled")
    RegRead("rf_rottentomatoes_score", "preferences","audience")
    RegRead("rf_trailers", "preferences","enabled")
    RegRead("rf_tvwatch", "preferences","enabled")
    RegRead("rf_season_poster", "preferences","season") ' seasons poster instead of show ( show was Plex Official Channel default )
    RegRead("rf_episode_poster", "preferences","season") ' seasons poster instead of show ( show was Plex Official Channel default )
    RegRead("rf_searchtitle", "preferences","title")
    RegRead("rf_rowfilter_limit", "preferences","200") ' no toggle yet
    RegRead("rf_hs_clock", "preferences", "enabled")
    RegRead("rf_hs_date", "preferences", "enabled")
    RegRead("rf_focus_unwatched", "preferences", "enabled")
    RegRead("rf_user_rating_only", "preferences", "user_prefer") ' this will show the original star rating as the users if it exists. seems safe to set at first
    RegRead("rf_up_behavior", "preferences", "exit") ' default is exit screen ( except for home )
    RegRead("rf_notify", "preferences", "enabled") ' enabled:all, video:video only, nonvideo:non video, disabled:disabled (when to notify)
    RegRead("rf_notify_np_type", "preferences", "all") ' now playing notify types
    RegRead("securityPincode", "preferences", invalid)  'PIN code required for startup

    Debug("rf_theme: " + tostr(RegRead("rf_theme", "preferences")))
    Debug("rf_img_overlay: " + tostr(RegRead("rf_img_overlay", "preferences")))
    Debug("rf_channel_text: " + tostr(RegRead("rf_channel_text", "preferences")))
    Debug("rf_poster_grid: " + tostr(RegRead("rf_poster_grid", "preferences")))
    Debug("rf_grid_style: " + tostr(RegRead("rf_grid_style", "preferences")))
    Debug("rf_home_displaymode: " + tostr(RegRead("rf_home_displaymode", "preferences")))
    Debug("rf_grid_displaymode: " + tostr(RegRead("rf_grid_displaymode", "preferences")))
    Debug("rf_poster_displaymode: " + tostr(RegRead("rf_poster_displaymode", "preferences")))
    Debug("rf_bcdynamic: " + tostr(RegRead("rf_bcdynamic", "preferences")))
    Debug("rf_dynamic_grid: " + tostr(RegRead("rf_dynamic_grid", "preferences")))
    Debug("rf_hs_clock: " + tostr(RegRead("rf_hs_clock", "preferences")))
    Debug("rf_hs_date: " + tostr(RegRead("rf_hs_date", "preferences")))
    Debug("rf_rottentomatoes: " + tostr(RegRead("rf_rottentomatoes", "preferences")))
    Debug("rf_rottentomatoes_score: " + tostr(RegRead("rf_rottentomatoes_score", "preferences")))
    Debug("rf_trailers: " + tostr(RegRead("rf_trailers", "preferences")))
    Debug("rf_tvwatch: " + tostr(RegRead("rf_tvwatch", "preferences")))
    Debug("rf_season_poster: " + tostr(RegRead("rf_season_poster", "preferences")))
    Debug("rf_episode_poster: " + tostr(RegRead("rf_episode_poster", "preferences")))
    Debug("rf_searchtitle: " + tostr(RegRead("rf_searchtitle", "preferences")))
    Debug("rf_rowfilter_limit: " + tostr(RegRead("rf_rowfilter_limit", "preferences")))
    Debug("rf_focus_unwatched: " + tostr(RegRead("rf_focus_unwatched", "preferences")))
    Debug("rf_user_rating_only: " + tostr(RegRead("rf_user_rating_only", "preferences")))
    Debug("rf_up_behavior: " + tostr(RegRead("rf_up_behavior", "preferences")))
    Debug("rf_notify: " + tostr(RegRead("rf_notify", "preferences")))
    Debug("rf_notify_np_type: " + tostr(RegRead("rf_notify_np_type", "preferences")))
    Debug("rf_temp_thememusic: " + tostr(RegRead("rf_temp_thememusic", "preferences")))
    Debug("rf_music_artist: " + tostr(RegRead("rf_music_artist", "preferences")))
    Debug("securityPincode: " + tostr(RegRead("securityPincode", "preferences")))
    Debug("============================================================================")

end sub


Function GetDurationString( Seconds As Dynamic, emptyHr = 0 As Integer, emptyMin = 0 As Integer, emptySec = 0 As Integer  ) As String
   datetime = CreateObject( "roDateTime" )

   if (type(Seconds) = "roString") then
       TotalSeconds% = Seconds.toint()
   else if (type(Seconds) = "roInteger") or (type(Seconds) = "Integer") then
       TotalSeconds% = Seconds
   else
       return "Unknown"
   end if

   datetime.FromSeconds( TotalSeconds% )
      
   hours = datetime.GetHours().ToStr()
   minutes = datetime.GetMinutes().ToStr()
   seconds = datetime.GetSeconds().ToStr()
   
   duration = ""
   If hours <> "0" or emptyHr = 1 Then
      duration = duration + hours + "h "
   End If

   If minutes <> "0" or emptyMin = 1 Then
      duration = duration + minutes + "m "
   End If
   If seconds <> "0" or emptySec = 1 Then
      duration = duration + seconds + "s"
   End If
   
   Return duration
End Function

Function RRmktime( epoch As Integer, localize = 1 as Integer) As String
    ' we will use home screen clock type to make the time ( if disabled, we will just use 12 hour )
    ' -- another toggle could be useful if someone wants 24hour time and NO clock on the homescreen ( too many toggles though )
    timePref = RegRead("rf_hs_clock", "preferences")

    datetime = CreateObject("roDateTime")
    datetime.FromSeconds(epoch)
    if localize = 1 then datetime.ToLocalTime()

    hours = datetime.GetHours()
    minutes = datetime.GetMinutes()
    seconds = datetime.GetSeconds()
  

    ' this works for 12/24 hour formats
    minute = minutes.ToStr()
    if minutes < 10 then minute = "0" + minutes.ToStr()

    hour = hours
    if toStr(timePref) <> "24hour" then 
        ' 12 hour format
        if hours = 0 then
           hour = 12
        end If

        if hours > 12 then
            hour = hours-12
        end If

        if hours >= 0 and hours < 12 then
            AMPM = "am"
        else
            AMPM = "pm"
        end if

        result = hour.ToStr() + ":" + minute + AMPM
    else 
        ' 24 hour format
        if hours < 10 then hour = "0" + hours.ToStr()
        result = hour.ToStr() + ":" + minute
    end if

    return result
End Function

Function RRbitrate( bitrate As Float) As String
    speed = bitrate/1000/1000
    ' brightscript doesn't have sprintf ( only include on decimal place )
    speed = speed * 10
    speed = speed + 0.5
    speed = fix(speed)
    speed = speed / 10
    format = "mbps"
    if speed < 1 then
      speed = speed*1000
      format = "kbps"
    end if
    return tostr(speed) + format
End Function

sub RRHomeScreenBreadcrumbs(force=false)

    ' ONLY display the user if we have MULTI users
    UserName = invalid
    if NOT GetGlobalAA().ViewController.SkipUserSelection then
        UserName = RegRead("friendlyName", "preferences", invalid, GetGlobalAA().userNum)
        if UserName <> invalid and UserName = "" then Username = invalid
    end if 

    vc = GetViewController()
    if force or (vc.Home <> invalid AND vc.IsActiveScreen(vc.Home)) then

        myscreen = GetViewController().screens.peek()
        timePref = RegRead("rf_hs_clock", "preferences", "enabled")
        datePref = RegRead("rf_hs_date", "preferences", "enabled")
        time_date = (timePref <> "disabled" or datePref <> "disabled")
        showBreadCrumbs = true
        if time_date then 
            breadCrumb1="":breadCrumb2=""

            date = CreateObject("roDateTime")
            date.ToLocalTime() ' localizetime
            timeString = RRmktime(date.AsSeconds(),0)

            if datePref = "short-date" then 
                dateFormat = "short-date"
            else 
                dateFormat = "short-month-short-weekday"
            end if
            dateString = date.AsDateString(dateFormat)

            if datePref <> "disabled" then breadCrumb1 = dateString
            if timePref <> "disabled" then breadCrumb2 = timeString

            if UserName <> invalid then 
                breadCrumb1 = breadCrumb1 + " " + breadCrumb2
                breadCrumb2 = UserName
            end if
        else if UserName <> invalid then 
            breadCrumb1 = UserName:breadCrumb2 = ""
        else 
            showBreadCrumbs = false
        end if

        if showBreadCrumbs and breadCrumb1 <> invalid and breadCrumb2 <> invalid then 
            myscreen.Screen.SetBreadcrumbEnabled(true)
            myscreen.Screen.SetBreadcrumbText(breadCrumb1, breadCrumb2)
        else 
            myscreen.Screen.SetBreadcrumbEnabled(false)
        end if

    end if

End Sub

Function createRARflixPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)
    obj.HandleMessage = prefsRARFflixHandleMessage

    rf_theme = [
        { title: "Original", EnumValue: "original", },
        { title: "Black", EnumValue: "black", },
    ]
    obj.Prefs["rf_theme"] = {
        values: rf_theme,
        heading: "Theme for Channel (restart required)",
        default: "black"
    }

    ' Rotten Tomatoes
    rt_prefs = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "Display Ratings from RottenTomatoes" },
        { title: "Disabled", EnumValue: "disabled", ShortDescriptionLine2: "Display Ratings from RottenTomatoes" },
    ]
    obj.Prefs["rf_rottentomatoes"] = {
        values: rt_prefs,
        heading: "Movie Ratings from Critics and Users",
        default: "enabled"
    }

    ' Rotten Tomatoes
    rt_prefs_score = [
        { title: "Critic's", EnumValue: "critic", ShortDescriptionLine2: "Use Critic's Score" },
        { title: "Audience's", EnumValue: "audience", ShortDescriptionLine2: "Use Audience's Score" },
    ]
    obj.Prefs["rf_rottentomatoes_score"] = {
        values: rt_prefs_score,
        heading: "Score to display on the Movie Details Screen",
        default: "audience"
    }

    ' trailers - play first trailer automatically
    values = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "Play first trailer" },
        { title: "Disabled", EnumValue: "disabled", ShortDescriptionLine2: "Show trailer list before playing" },
    ]
    obj.Prefs["rf_trailerplayfirst"] = {
        values: values,
        heading: "Play the first Movie Trailer automatically",
        default: "enabled"
    }


    ' RT/Trailers - search title
    rt_prefs = [
        { title: "Title", EnumValue: "title", ShortDescriptionLine2: "Search by Movie Title" },
        { title: "Original Title", EnumValue: "originalTitle", ShortDescriptionLine2: "Search by Original Movie Title" },
    ]
    obj.Prefs["rf_searchtitle"] = {
        values: rt_prefs,
        heading: "Search by Title or 'Original' Title",
        default: "title"
    }

    ' Trailers
    trailer_prefs = [
        { title: "Enabled TMDB & Youtube", EnumValue: "enabled", ShortDescriptionLine2: "Display Movie Trailers" + chr(10) + "themoviedb.org and Youtube" },
        { title: "Enabled TMDB w/ Youtube Fallback", EnumValue: "enabled_tmdb_ytfb", ShortDescriptionLine2: "Display Movie Trailers" + chr(10) + "themoviedb.org or Fallback to Youtube" },
        { title: "Disabled", EnumValue: "disabled"}

    ]
    obj.Prefs["rf_trailers"] = {
        values: trailer_prefs,
        heading: "Show Movie Trailer button",
        default: "enabled_tmdb_yt"
    }

' Toggle removed - it's now a forced default
'    ' Breadcrumb fixes
'    bc_prefs = [
'        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "Update header when browsing " +chr(10)+ "On Deck, Recently Added, etc.."  },
'        { title: "Disabled", EnumValue: "disabled", ShortDescriptionLine2: "Update header when browsing " +chr(10)+ "On Deck, Recently Added, etc.."  },
'
'
'    ]
'    obj.Prefs["rf_bcdynamic"] = {
'        values: bc_prefs,
'        heading: "Update Header (top right)",
'        default: "enabled"
'    }
'
    ' partially update grid or full reload -- to fix any speed issues people experience 
    grid_dynamic = [
        { title: "Full", EnumValue: "full", ShortDescriptionLine2: "Try partial if the grid seems slow"  },
        { title: "Partial", EnumValue: "partial", ShortDescriptionLine2: "Increases Speed/Less dynamic"  },
    ]
    obj.Prefs["rf_grid_dynamic"] = {
        values: grid_dynamic,
        heading: "Grid Updates / Reloading of Rows",
        default: "full"
    }

    ' TV Seasons Poster ( prefer season over show )
    values = [
        { title: "Season", EnumValue: "season", },
        { title: "Show", EnumValue: "show" },

    ]
    obj.Prefs["rf_season_poster"] = {
        values: values,
        heading: "Poster to display when viewing a TV Show Season on the Grid",
        default: "season"
    }
    obj.Prefs["rf_episode_poster"] = {
        values: values,
        heading: "Poster to display when viewing a TV Show Episode on the Grid",
        default: "season"
    }

    ' TV Watched status next to ShowTITLE
    tv_watch_prefs = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "Dexter (watched)" + chr(10) + "Dexter (1 of 12 watched)" },
        { title: "Disabled", EnumValue: "disabled" },

    ]
    obj.Prefs["rf_tvwatch"] = {
        values: tv_watch_prefs,
        heading: "Append the watched status to TV Show Titles",
        default: "enabled"
    }

    ' focus to the unwatched item in a postescreen -  maybe others later
    focus_unwatched = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "",}
        { title: "Disabled", EnumValue: "disabled" },

    ]
    obj.Prefs["rf_focus_unwatched"] = {
        values: focus_unwatched,
        heading: "Focus on the first Unwatched item"
        default: "enabled"
    }

    ' focus to the unwatched item in a postescreen -  maybe others later
    music_artist = [
        { title: "Track", EnumValue: "track", ShortDescriptionLine2: "Track Artist",}
        { title: "Album", EnumValue: "album", ShortDescriptionLine2: "Album Artist",}
        { title: "Various", EnumValue: "various", ShortDescriptionLine2: "Track Artist when Various Artists",}
    ]
    obj.Prefs["rf_music_artist"] = {
        values: music_artist,
        heading: "Display Artist when Playing a Track"
        default: "enabled"
    }

    ' user ratings only
    user_ratings = [
        { title: "Only Your Ratings", EnumValue: "user_only", ShortDescriptionLine2: "Display your Star Ratings Only",}
        { title: "Prefer Your Ratings", EnumValue: "user_prefer", ShortDescriptionLine2: "Prefer your Ratings over the Default",}
        { title: "Default", EnumValue: "disabled" },

    ]
    obj.Prefs["rf_user_rating_only"] = {
        values: user_ratings,
        heading: "Only show or Prefer your Star Ratings"
        default: "disabled"
    }

    ' user ratings only
    up_behavior = [
        { title: "Previous Screen", EnumValue: "exit", ShortDescriptionLine2: "Go to the Previous Screen (go back)",}
        { title: "Do Nothing", EnumValue: "stop", ShortDescriptionLine2: "Stay on Screen (do nothing)",}

    ]
    obj.Prefs["rf_up_behavior"] = {
        values: up_behavior,
        heading: "Up Key action when Top Row is Selected",
        default: "exit"
    }

    ' text overlay color (customer posters)
    rf_overlay = [
        { title: "White  (Plex)", EnumValue: "BFBFBF", }
        { title: "Orange (Plex)", EnumValue: "FFA500", }
        { title: "White", EnumValue: "F5F5F5",}
        { title: "Light Gray", EnumValue: "A0A0A0",}
        { title: "Gray", EnumValue: "606060",}
        { title: "Tan", EnumValue: "bf8e60",}
        { title: "Green", EnumValue: "778554",}
        { title: "Sky", EnumValue: "bfcada",}
    ]
    obj.Prefs["rf_img_overlay"] = {
        values: rf_overlay,
        heading: "Text Color for Images in Sub Sections",
        default: "BFBFBF"
    }

    ' Breadcrumb fixes
    custom_thumbs = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "Use Custom"  },
        { title: "Disabled", EnumValue: "disabled", ShortDescriptionLine2: "Use Generic Icon"  },


    ]
    obj.Prefs["rf_custom_thumbs"] = {
        values: custom_thumbs,
        heading: "Replace Generic Icons with Text",
        default: "enabled"
    }

   ' enable notifications?  (if we add more events (currently now playing) we can add more toggles )
    notifications = [
        { title: "Enabled", EnumValue: "enabled",}
        { title: "in Video Screen", EnumValue: "video", ShortDescriptionLine2: "Only show on Video Screen",}
        { title: "in NON Video Screens", EnumValue: "nonvideo", ShortDescriptionLine2: "Only when not Playing a Video",}
        { title: "Disabled", EnumValue: "disabled",}

    ]
    obj.Prefs["rf_notify"] = {
        values: notifications,
        heading: "Show Now Playing Notifications",
        default: "exit"
    }

    ' start, stop, all:enabled
    np_notificationstypes = [
        { title: "All", EnumValue: "all", ShortDescriptionLine2: "Notify on Start and Stop",}
        { title: "Start", EnumValue: "start", ShortDescriptionLine2: "Notify on Start",}
        { title: "Stop", EnumValue: "stop", ShortDescriptionLine2: "Notify on Stop",}
    ]
    obj.Prefs["rf_notify_np_type"] = {
        values: np_notificationstypes,
        heading: "When to Notify?",
        default: "all"
    }


    filter_limit = [
        { title: "100", EnumValue: "100" },
        { title: "200", EnumValue: "200" },
        { title: "300", EnumValue: "300", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "400", EnumValue: "400", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "500", EnumValue: "500", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "600", EnumValue: "600", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "700", EnumValue: "700", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "800", EnumValue: "800", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "900", EnumValue: "900", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "1000", EnumValue: "1000", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "1500", EnumValue: "1500", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "All", EnumValue: "9999", ShortDescriptionLine2: "May cause Plex to be Sluggish.. really?"},
    ]
    obj.Prefs["rf_rowfilter_limit"] = {
        values: filter_limit,
        heading: "Item limit for Unwatched Recently Added & Released [movies]",
        default: "200"
    }


    obj.Screen.SetHeader("RARflix Preferences")
    obj.AddItem({title: "Theme"}, "rf_theme", obj.GetEnumValue("rf_theme"))
    obj.AddItem({title: "Custom Icons", ShortDescriptionLine2: "Replace generic icons with Text"}, "rf_custom_thumbs", obj.GetEnumValue("rf_custom_thumbs"))
    if RegRead("rf_custom_thumbs", "preferences","enabled") = "enabled" then
        obj.AddItem({title: "Custom Icons Text", ShortDescriptionLine2: "Color of text to use"}, "rf_img_overlay", obj.GetEnumValue("rf_img_overlay"))
    end if
    obj.AddItem({title: "Hide Rows",ShortDescriptionLine2: "Sorry for the confusion..."}, "hide_rows_prefs")
    obj.AddItem({title: "Section Display", ShortDescriptionLine2: "a plex original, for easy access"}, "sections")

    obj.AddItem({title: "Movie Trailers", ShortDescriptionLine2: "Got Trailers?"}, "rf_trailers", obj.GetEnumValue("rf_trailers"))
    obj.AddItem({title: "Play first Trailer", ShortDescriptionLine2: "Automatically play first trailer"}, "rf_trailerplayfirst", obj.GetEnumValue("rf_trailerplayfirst"))
    obj.AddItem({title: "Rotten Tomatoes", ShortDescriptionLine2: "Movie Ratings from Rotten Tomatoes"}, "rf_rottentomatoes", obj.GetEnumValue("rf_rottentomatoes"))
    if RegRead("rf_rottentomatoes", "preferences","enabled") = "enabled" then
        obj.AddItem({title: "Rotten Tomatoes Score", ShortDescriptionLine2: "Who do you trust more..." + chr(10) + "A Critic or an Audience?"}, "rf_rottentomatoes_score", obj.GetEnumValue("rf_rottentomatoes_score"))
    end if
    if RegRead("rf_rottentomatoes", "preferences","enabled") = "enabled" or RegRead("rf_trailers", "preferences") <> "disabled" then
        obj.AddItem({title: "Trailers/Tomatoes Search by", ShortDescriptionLine2: "You probably don't want to change this"}, "rf_searchtitle", obj.GetEnumValue("rf_searchtitle"))
    end if
'    Toggle removed - it's now a forced default
'    obj.AddItem({title: "Dynamic Headers", ShortDescriptionLine2: "Info on the top Right of the Screen"}, "rf_bcdynamic", obj.GetEnumValue("rf_bcdynamic"))
    obj.AddItem({title: "TV Show (Watched Status)", ShortDescriptionLine2: "feels good enabled"}, "rf_tvwatch", obj.GetEnumValue("rf_tvwatch"))
    obj.AddItem({title: "TV Season Poster (Grid)", ShortDescriptionLine2: "Season or Show's Poster on Grid"}, "rf_season_poster", obj.GetEnumValue("rf_season_poster"))
    obj.AddItem({title: "TV Episode Poster (Grid)", ShortDescriptionLine2: "Season or Show's Poster on Grid"}, "rf_episode_poster", obj.GetEnumValue("rf_episode_poster"))
    obj.AddItem({title: "Focus on Unwatched", ShortDescriptionLine2: "Default to the first unwatched " + chr(10) + "item (poster screen only)"}, "rf_focus_unwatched", obj.GetEnumValue("rf_focus_unwatched"))
    obj.AddItem({title: "Unwatched Added/Released", ShortDescriptionLine2: "Item limit for unwatched Recently Added &" + chr(10) +"Recently Released rows [movies]"}, "rf_rowfilter_limit", obj.GetEnumValue("rf_rowfilter_limit"))
    obj.AddItem({title: "Star Ratings Override", ShortDescriptionLine2: "Only show or Prefer"+chr(10)+"Star Ratings that you have set"}, "rf_user_rating_only", obj.GetEnumValue("rf_user_rating_only"))
    obj.AddItem({title: "Up Button (row screens)", ShortDescriptionLine2: "What to do when the UP button is " + chr(10) + "pressed on a screen with rows"}, "rf_up_behavior", obj.GetEnumValue("rf_up_behavior"))
    obj.AddItem({title: "Music Artists", ShortDescriptionLine2: "Artist to display for a track"}, "rf_music_artist", obj.GetEnumValue("rf_music_artist"))

    'if isRFtest() then 
    obj.AddItem({title: "Now Playing Notifications", ShortDescriptionLine2: "Want to be notified on Now Playing?"}, "rf_notify", obj.GetEnumValue("rf_notify"))
    if RegRead("rf_notify", "preferences","enabled") = "enabled" then 
        obj.AddItem({title: "Now Playing Notify Types", ShortDescriptionLine2: "When do you want to be notified?" + chr(10) + " On Start/Stop or Both"}, "rf_notify_np_type", obj.GetEnumValue("rf_notify_np_type"))
    end if

    obj.AddItem({title: "Grid Updates/Speed", ShortDescriptionLine2: "Change how the Grid Refreshes/Reloads content"}, "rf_grid_dynamic", obj.GetEnumValue("rf_grid_dynamic"))
    obj.AddItem({title: "About RARflix"}, "ShowReleaseNotes")
    obj.AddItem({title: "Close"}, "close")
    return obj
End Function

Function prefsRARFflixHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
            m.ViewController.Home.Refresh(m.Changes) ' include the Changes for homescreen refresh ( might be useful to add this to the main ALL *HandleMessages functions )
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "hide_rows_prefs" then
                screen = createHideRowsPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Hide Rows Preferences"])
                screen.Show()
            else if command = "sections" then
                screen = createSectionDisplayPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Section Display Preferences"])
                screen.Show()
            else if command = "ShowReleaseNotes" then
                m.ViewController.ShowReleaseNotes("about")
            else if command = "close" then
                m.Screen.Close()
            else
                m.HandleEnumPreference(command, msg.GetIndex())
            end if
        end if
    end if

    return handled
End Function

Function createHideRowsPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)
    obj.HandleMessage = prefsRARFflixHandleMessage

    'a little cleaner: if Plex adds/changes rows it will be in PreferenceScreen.brs:createSectionDisplayPrefsScreen()
    PlexRows = [
        { title: "All Items", key: "all" },
        { title: "On Deck", key: "onDeck" },
        { title: "Recently Added", key: "recentlyAdded" },
        { title: "Recently Released", key: "newest" },
        { title: "Unwatched", key: "unwatched" },
        { title: "[movie] Recently Added (uw)", key: "all?type=1&unwatched=1&sort=addedAt:desc" }, 'movie/film for now
        { title: "[movie] Recently Released (uw)", key: "all?type=1&unwatched=1&sort=originallyAvailableAt:desc" }, 
        { title: "[tv] Recently Added Season", key: "recentlyAdded?stack=1" }, 
        { title: "[tv] Recently Aired (uw)", key: "all?timelineState=1&type=4&unwatched=1&sort=originallyAvailableAt:desc" }, 
        { title: "[tv] Recently Added (uw)", key: "all?timelineState=1&type=4&unwatched=1&sort=addedAt:desc" }, 
        { title: "Recently Viewed", key: "recentlyViewed" },
        { title: "[tv] Recently Viewed Shows", key: "recentlyViewedShows" },
        { title: "By Album", key: "albums" },
        { title: "By Collection", key: "collection" },
        { title: "By Genre", key: "genre" },
        { title: "By Year", key: "year" },
        { title: "By Decade", key: "decade" },
        { title: "By Director", key: "director" },
        { title: "By Actor", key: "actor" },
        { title: "By Country", key: "country" },
        { title: "By Content Rating", key: "contentRating" },
        { title: "By Rating", key: "rating" },
        { title: "By Resolution", key: "resolution" },
        { title: "By First Letter", key: "firstCharacter" },
        { title: "By Folder", key: "folder" },
        { title: "Search", key: "_search_" }
    ]
    obj.Screen.SetHeader("Hide or Show Rows for Library Sections")

    ReorderItemsByKeyPriority(PlexRows, RegRead("section_row_order", "preferences", ""))

    for each item in PlexRows
        if item.key = "_search_" then item.key = "search" 'special case
        rf_hide_key = "rf_hide_"+item.key

        ' allow one to Hide Recently Released and Recently Added if Movie/Show/Music - would really be nice to reorder per section.. but that's another time (TODO)
        if item.key = "newest" or item.key = "recentlyAdded" then 
            itypes = [
                { type: "movie", short: "[movie]", },
                { type: "artist", short: "[music]", },
                { type: "show", short: "[tv]", newest: "Recently Aired" },
            ]

            for each it in itypes
                new_hide_key = rf_hide_key + "_" + it.type
                title = it.short + " " + item.title
                if it[item.key] <> invalid then title = it.short + " " + it[item.key]

                values = [
                    { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: title },
                    { title: "Show", EnumValue: "show", ShortDescriptionLine2: title },
                ]
                obj.Prefs[new_hide_key] = {
                    values: values,
                    heading: "Show or Hide Row",
                    default: "show"
                }
                if (it.type = "artist" and item.key <> "newest") or ( it.type <> "artist")   then
                    obj.AddItem({title: title}, new_hide_key, obj.GetEnumValue(new_hide_key))
                end if
            end for
        end if ' else  -- allow other sections to hide recentlyAdded/released normally

        if item.key = "recentlyAdded" then item.title = "[other] Recently Added"
        if item.key = "newest" then item.title = "[other] Recently Released"
        values = [
            { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: item.title },
            { title: "Show", EnumValue: "show", ShortDescriptionLine2: item.title },
        ]
        obj.Prefs[rf_hide_key] = {
            values: values,
            heading: "Show or Hide Row",
            default: "show"
        }
        if NOT item.key = "newest" then ' others don't have this yet
            obj.AddItem({title: item.title}, rf_hide_key, obj.GetEnumValue(rf_hide_key))
        end if
    next
   
    obj.AddItem({title: "Close"}, "close")
    return obj
End Function


function ShowPleaseWaitIC(title As dynamic, text As dynamic) As Object
    if not isstr(title) title = "Please Wait"
    if not isstr(text) text = ""

    vc = GetViewController()

    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, vc)

    screen = createobject("roimagecanvas")
    screen.SetRequireAllImagesToDraw(false)
    screen.SetMessagePort(obj.Port)

    obj.theme = getImageCanvasTheme()
    obj.canvasrect = screen.GetCanvasRect()

    w = obj.canvasrect.w/2
    h = obj.canvasrect.h/4
    ' center the image by the w/h
    x = int(obj.canvasrect.w/2)-(w/2)
    y = int(obj.canvasrect.h/2)-(h/2)

    display = [ { color: "#90000000", TargetRect:{x:int(x),y:int(y),w:int(w),h:int(h)} }]
    screen.setlayer(0,display)

    display = [{Text: title + chr(10) + text, TextAttrs:{Color:"#FFFFFFFF", Font:"Small", HAlign:"HCenter", VAlign:"VCenter",  Direction:"LeftToRight"}, TargetRect:{x:0,y:0,w:obj.canvasrect.w,h:0} },]
    screen.setlayer(1,display)

    obj.Screen = screen
    obj.ScreenName = "ImageCanvas::Please Wait"
    vc.AddBreadcrumbs(obj, invalid)
    vc.UpdateScreenProperties(obj)
    vc.PushScreen(obj)

    obj.screen.show()

    obj.close = function(): GetViewController().popscreen(m) : end function

    return obj

end function

Function ShowPleaseWait(title As dynamic, text As dynamic) As Object
    Debug("ShowPleaseWait:: created")
    if not isstr(title) title = ""
    if not isstr(text) text = ""

    port = CreateObject("roMessagePort")
    dialog = invalid

    'the OneLineDialog renders a single line of text better
    'than the MessageDialog.

    if text = ""
        dialog = CreateObject("roOneLineDialog")
    else
        dialog = CreateObject("roMessageDialog")
        dialog.SetText(text)
    end if

    dialog.SetMessagePort(port)
    dialog.SetTitle(title)
    dialog.ShowBusyAnimation()
    dialog.EnableOverlay(true) ' required for image canvas
    dialog.Show()
    return dialog
End Function



sub rfVideoMoreButton(obj as Object) as Dynamic
    dialog = createBaseDialog()
    dialog.Title = firstof(obj.metadata.showtitle, obj.metadata.umtitle, obj.metadata.title)
    'dialog.Text = truncateString(obj.metadata.shortdescriptionline2,80)
    dialog.Text = "" ' too many buttons for text now
    dialog.Item = obj.metadata

    supportedIdentifier = (obj.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" OR obj.metadata.mediaContainerIdentifier = "com.plexapp.plugins.myplex")
    isMovieShowEpisode = (obj.metadata.ContentType = "movie" or obj.metadata.ContentType = "show" or obj.metadata.ContentType = "episode")
    isHomeVideos = (obj.metadata.isHomeVideos = true)


    ' ljunkie - Home Screen shortcut ( if we are not already on the homescreen )
    ' always first button
    vc = GetViewController()
    screen = vc.screens.peek()
    if vc.Home <> invalid AND screen <> invalid and screen.screenid <> vc.Home.ScreenID then 
        'dialog.sepAfter.Push("GoToHomeScreen") ' don't have room anymore 
        dialog.SetButton("GoToHomeScreen", "Home Screen")
    end if

    dialogSetSortingButton(dialog,obj) 

    if isMovieShowEpisode then 
        dialog.SetButton("options", "Playback options")
    end if

    ' display View All Seasons if we have grandparentKey -- entered from a episode
    if obj.metadata.grandparentKey <> invalid then
         dialog.SetButton("showFromEpisode", "View All Seasons")
    end if

    ' display View specific season if we have parentKey/parentIndex -- entered from a episode
    if obj.metadata.parentKey <> invalid AND obj.metadata.parentIndex <> invalid then
       dialog.SetButton("seasonFromEpisode", "View Season " + obj.metadata.parentIndex)
    end if

    if supportedIdentifier then
        ' this might be a TV season/All Seasons
        print obj.metadata
        if tostr(obj.metadata.type) = "season" or tostr(obj.metadata.viewgroup) = "season" then
            print obj.metadata.type
    	    print obj.metadata.viewedLeafCount
    	    print obj.metadata.leafCount

            if val(obj.metadata.viewedLeafCount) = val(obj.metadata.leafCount) then
                dialog.SetButton("unscrobble", "Mark as unwatched")
            else if val(obj.metadata.viewedLeafCount) > 0 then
                dialog.SetButton("unscrobble", "Mark as unwatched")
                dialog.SetButton("scrobble", "Mark as watched")
            else if val(obj.metadata.leafCount) > 0 then
                dialog.SetButton("scrobble", "Mark as watched")
            end if
        else 

            if obj.metadata.sourceurl = invalid or instr(1, obj.metadata.sourceurl, "onDeck") = 0 then 
                dialog.SetButton("putOnDeck", "Put On Deck")
            end if

            if obj.metadata.viewOffset <> invalid AND val(obj.metadata.viewOffset) > 0 then ' partially watched
                dialog.SetButton("unscrobble", "Mark as unwatched")
                dialog.SetButton("scrobble", "Mark as watched")
            else if obj.metadata.viewCount <> invalid AND val(obj.metadata.viewCount) > 0 then ' watched
                dialog.SetButton("unscrobble", "Mark as unwatched")
                ' no need to show watched button (already watched)
            else if obj.metadata.viewCount = invalid then  ' not watched
                dialog.SetButton("scrobble", "Mark as watched")
                ' no need to show unwatched 
            end if
        end if
        if obj.metadata.server.AllowsMediaDeletion AND obj.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" then
            dialog.SetButton("delete", "Delete permanently")
        end if

        ' cast & crew is already on this screen
        ' cast & crew must be part of the supported identifier 

        'if isMovieShowEpisode or obj.metadata.type = "season" or obj.metadata.ContentType = "series" then
        '    dialog.SetButton("RFCastAndCrewList", "Cast & Crew")
        'else 
        '   Debug("---- Cast and Crew are not available for " + tostr(obj.metadata.ContentType))
        'end if

    end if

    ' these are on the main details screen -- show them last ( maybe not at all )
    if NOT isHomeVideos and obj.metadata.ContentType = "movie" AND  RegRead("rf_trailers", "preferences", "disabled") <> "disabled" then 
        dialog.SetButton("getTrailers", "Trailer")
    end if

    if supportsTextScreen() and obj.metadata.UMdescription <> invalid and len(obj.metadata.UMdescription) > 10 then dialog.SetButton("RFVideoDescription", "Description")

    ' set this to last -- unless someone complains
    if supportedIdentifier then
        if obj.metadata.ContentType = "movie" or obj.metadata.ContentType = "episode" or obj.metadata.ContentType = "show"  then
            dialog.SetButton("rate", "_rate_")
        end if
    end if

    dialog.SetButton("close", "Back")
    dialog.HandleButton = videoDialogHandleButton
    dialog.ParentScreen = obj
    dialog.Show()
end sub

sub dummyRefresh(force=false) 
end sub

sub posterRefresh(force=false) 
    Debug("posterRefresh called! do we have a valid item")
 
    if m.noRefresh <> invalid then 
        Debug("---- noRefresh set -- skipping item.refresh()")
        return
    end if

    if type(m.screen) = "roPosterScreen" then 
        if type(m.contentarray) = "roArray" and m.contentarray.count() > 0 and type(m.contentarray[0]) = "roAssociativeArray" then 
            focusedIndex = m.contentarray[0].focusedindex ' we have to refresh this for sure 
                                                          ' we also have to refresh the "All Episodes" item if it exists
            content = m.contentarray[0].content
            forceRefresh=false
            for each item in content 
                if type(item.refresh) = "roFunction" then  
                    doRefresh=true
                    if item.type = invalid and tostr(item.viewgroup) = "season" then 
                        if content[focusedIndex].key = item.key then forceRefresh = true
                    else if content[focusedIndex].key = item.key then 
                        'print "------------ focused item -- refresh it"
                    else if NOT forceRefresh then 
                        doRefresh = false
                    end if
                    
                    if doRefresh then 
                        item.refresh()
                        if item.titleseason <> invalid then item.shortdescriptionline1 = item.titleseason
                    end if
                end if
            end for
            m.screen.SetContentList(content)
            Debug("refresh content list!")
        end if
    end if


'        if m.item <> invalid and type(m.item.refresh) = "roFunction" then 
'            m.item.refresh()
'            Debug("item refreshed!")
'        end if

end sub 

' This is the context Dialog from the GRID - I should rename this TODO
sub rfVideoMoreButtonFromGrid(obj as Object) as Dynamic
    ' this should probably just be combined into rfVideoMoreButton  ( there are some caveats though and maybe more to come.. so until this has been finalized )
    dialog = createBaseDialog()
    buttonSep = invalid

    ' ljunkie - Home Screen shortcut ( if we are not already on the homescreen )
    ' always first button
    vc = GetViewController()
    screen = vc.screens.peek()
    if vc.Home <> invalid AND screen <> invalid and screen.screenid <> vc.Home.ScreenID then 
        buttonSep = "GoToHomeScreen"
        dialog.SetButton("GoToHomeScreen", "Home Screen")
    end if

    dialogSetSortingButton(dialog,obj) 

    ' TODO full grid screen yo
    if obj.isfullgrid = invalid and obj.disablefullgrid = invalid and type(obj.screen) = "roGridScreen" then 
        fromName = "invalid"
        if type(obj.loader.getnames) = "roFunction" and obj.selectedrow <> invalid then fromName = obj.loader.getnames()[obj.selectedrow]
        buttonSep = "fullGridScreen"
        dialog.SetButton("fullGridScreen", "Grid View: " + fromName)
    end if

    ' no room for this
    'if buttonSep <> invalid then dialog.sepAfter.Push(buttonSep)

    isMovieShowEpisode = (obj.metadata.ContentType = "movie" or obj.metadata.ContentType = "show" or obj.metadata.ContentType = "episode")
    isHomeVideos = (obj.metadata.isHomeVideos = true)

' this is not supported from the grid
'    if isMovieShowEpisode then 
'       dialog.SetButton("options", "Playback options")
'    end if

    if (obj.metadata.type = "season") then 
        dialog.Title = firstof(obj.metadata.title, obj.metadata.umtitle, obj.metadata.title)
        dialog.Text = ""
    else if (obj.metadata.type = "episode") then 
        dialog.Title = firstof(obj.metadata.showtitle, obj.metadata.title)
        dialog.Text = firstof(obj.metadata.shortdescriptionline2,  obj.metadata.shortdescriptionline1)
        dialog.Text = dialog.Text + chr(10) + chr(32) + chr(32) +chr(32) +firstof(obj.metadata.description, obj.metadata.umtitle)
    else 
        ' movies -- the description is too much
        dialog.Title = firstof(obj.metadata.showtitle, obj.metadata.umtitle, obj.metadata.title)
        dialog.Text = obj.metadata.shortdescriptionline2
     end if

    'dialog.Text = truncateString(dialog.Text,80)
    dialog.Text = "" ' too many buttons for text now

    dialog.Item = obj.metadata

    if type(obj.Refresh) <> "roFunction" then 
        ' obj.Refresh = posterRefresh ' this should no longer be needed ( or dupes happen ) - poster refresh is activated now
        obj.Refresh = dummyRefresh ' still need a dummy as some logic requires it
       'else
       'print "not calling posterRefresh since 'obj.Refresh' exists"
    end if

    ' hack for global recently added ( tv shows are displayed as seasons )
    if (obj.metadata.type = "season") and obj.metadata.grandparentKey = invalid then 
        ' available: obj.metadata.key = "/library/metadata/88482/childen'
        re = CreateObject("roRegex", "/children.*", "i")
        obj.metadata.parentKey = re.ReplaceAll(obj.metadata.key, "")
        container = createPlexContainerForUrl(obj.metadata.server, obj.metadata.server.serverUrl, obj.metadata.parentKey)
       ' we haven't Parsed anything yet.. the raw XML is available
       ' TODO: clean this up and stop using the xml ( parse it -- GetMetaData() )
        if container <> invalid and container.xml <> invalid then 
            obj.metadata.grandparentKey = container.xml.Directory[0]@parentKey
            obj.metadata.parentIndex = container.xml.Directory[0]@index
            obj.metadata.ShowTitle = container.xml.Directory[0]@parentTitle
            container = invalid
        end if
    else if (obj.metadata.type = "show") and obj.metadata.grandparentKey = invalid then 
        ' object type is a show -- we have all we need
        re = CreateObject("roRegex", "/children.*", "i")
        obj.metadata.grandparentKey = re.ReplaceAll(obj.metadata.key, "")
        obj.metadata.ShowTitle = firstof(obj.metadata.umtitle, obj.metadata.showtitle, obj.metadata.title)
        'end if
    else if obj.metadata.grandparentKey = invalid then 
         Debug("---- we should probably handle " + tostr(obj.metadata.type) + "? figure out the parentKey/grandparentkey for: " + tostr(obj.metadata.key))
    end if
    ' end hack

    ' display View All Seasons if we have grandparentKey -- entered from a episode
    if obj.metadata.grandparentKey <> invalid then
        if obj.metadata.type = "season" and type(obj.screen) = "roPosterScreen"  then
            ' this is a ALL seasons view on a posterscreen -- can we add mark as watched/unwatched to make them all??
        else 
            dialog.SetButton("showFromEpisode", "View All Seasons of " + tostr(obj.metadata.ShowTitle) )
        end if
    end if
    ' display View specific season if we have parentKey/parentIndex -- entered from a episode
    if obj.metadata.parentKey <> invalid AND obj.metadata.parentIndex <> invalid and type(obj.screen) <> "roPosterScreen" then 
       dialog.SetButton("seasonFromEpisode", "View Season " + obj.metadata.parentIndex)
    end if

    ' Trailers link - RR (last now that we include it on the main screen .. well before delete - people my be used to delete being second to last)
    if NOT isHomeVideos and obj.metadata.ContentType = "movie" AND  RegRead("rf_trailers", "preferences", "disabled") <> "disabled" then 
        dialog.SetButton("getTrailers", "Trailer")
    end if

    ' cast & crew - must be part of the supported identifier  ( v2.8.2 - changed: a season from global recently added on the homescreen is not a "supported identifier" but is still valid )
    isMovieShowEpisode = (obj.metadata.type = "season" or obj.metadata.ContentType = "movie" or obj.metadata.ContentType = "show" or obj.metadata.ContentType = "episode" or obj.metadata.ContentType = "series")
    if NOT isHomeVideos and isMovieShowEpisode then 
        dialog.SetButton("RFCastAndCrewList", "Cast & Crew")
    else
        Debug(" Cast and Crew are not available for " + tostr(obj.metadata.ContentType))
    end if

    supportedIdentifier = (obj.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" OR obj.metadata.mediaContainerIdentifier = "com.plexapp.plugins.myplex")

    if supportedIdentifier then
        print obj.metadata
        if tostr(obj.metadata.type) = "season" or tostr(obj.metadata.viewgroup) = "season" then
            print obj.metadata.type
    	    print obj.metadata.viewedLeafCount
	        print obj.metadata.leafCount

            if val(obj.metadata.viewedLeafCount) = val(obj.metadata.leafCount) then
                dialog.SetButton("unscrobble", "Mark as unwatched")
            else if val(obj.metadata.viewedLeafCount) > 0 then
                dialog.SetButton("unscrobble", "Mark as unwatched")
                dialog.SetButton("scrobble", "Mark as watched")
            else if val(obj.metadata.leafCount) > 0 then
                dialog.SetButton("scrobble", "Mark as watched")
            end if
        else 
            if obj.metadata.sourceurl = invalid or instr(1, obj.metadata.sourceurl, "onDeck") = 0 then 
                dialog.SetButton("putOnDeck", "Put On Deck")
            end if
            if obj.metadata.viewOffset <> invalid AND val(obj.metadata.viewOffset) > 0 then ' partially watched
                dialog.SetButton("unscrobble", "Mark as unwatched")
                dialog.SetButton("scrobble", "Mark as watched")
            else if obj.metadata.viewCount <> invalid AND val(obj.metadata.viewCount) > 0 then ' watched
                dialog.SetButton("unscrobble", "Mark as unwatched")
                ' no need to show watched button (already watched)
            else if obj.metadata.viewCount = invalid then  ' not watched
                dialog.SetButton("scrobble", "Mark as watched")
                ' no need to show unwatched 
            end if
        end if
    end if

    if supportsTextScreen() and obj.metadata.UMdescription <> invalid and len(obj.metadata.UMdescription) > 10 then dialog.SetButton("RFVideoDescription", "Description")

    ' set this to last -- unless someone complains
    ' hide this for now.. unless someone complains :)
    if supportedIdentifier then
        if obj.metadata.ContentType = "movie" or obj.metadata.ContentType = "episode" or obj.metadata.ContentType = "show"  then
            if obj.Item.StarRating = invalid then obj.Item.StarRating = 0
            if obj.Item.origStarRating = invalid then obj.Item.origStarRating = 0
            dialog.SetButton("rate", "_rate_")
        end if
    end if

    dialog.SetButton("close", "Back")
    dialog.HandleButton = videoDialogHandleButton
    dialog.ParentScreen = obj
    dialog.Show()
end sub

function UcaseFirst(var,strip = invalid) as dynamic
 'Debug("UcaseFirst start:" + var)
 if strip <> invalid then ' extra function to strip chars/replace them - I didn't want to create another function
     re = CreateObject("roRegex", "_", "i")
     var = re.ReplaceAll(var, "       ")
     re = CreateObject("roRegex", "rarforge", "i") ' just for me :)
     var = re.ReplaceAll(var, "")
     'Debug("UcaseFirst strip:" + var)
 end if

 re = CreateObject("roRegex", "  ", "i") ' remove double spaces
 var = re.ReplaceAll(var, " ")
 'Debug("UcaseFirst spaces:" + var)

 ' Capitalize first of every word
 parts = strTokenize(var, " ")
 result = invalid
 for each part in parts
     if result = invalid then 
         result = ucase(left(part,1))+right(part,len(part)-1)
     else
         result = result + " " + ucase(left(part,1))+right(part,len(part)-1)
     end if
 end for
 if result <> invalid then var = result
 'Debug("UcaseFirst result:" + var)

 return var ' return either modified or untouched var
end function



' Hack to show the HUD
Sub SendRemoteKey(key)
    'deprecated in favor of SendEcpCommand()
    url = "http://127.0.0.1:8060/keypress/" + key
    Debug("sending key " + tostr(key) + " " + tostr(url))
    xfer = CreateObject("roUrlTransfer")
    xfer.SetUrl(url)
    xfer.PostFromString("")
End Sub


' Hack to show a notification through the HUD
sub HUDnotify(screen,obj = invalid) 
    ' we must be in a roVideoScreen
    if type(screen.screen) = "roVideoScreen" and type(obj) = "roArray" then
        Debug("showing HUD notification")
        content = CreateObject("roAssociativeArray")
        content_orig = screen.VideoItem        ' set original content to reset
        content.title = "Now Playing" ' we use the title for HUD messages ( less text )
        content.releasedate = ""
        for each i in obj
            content.releasedate = content.releasedate + chr(10) + i.title + chr(10)  'chr(10) for spacing between notifications (works with 1 too)
        next
        screen.Screen.SetContent(content)      ' set new content for notification 
        SendEcpCommand("Down")
        screen.Screen.SetContent(content_orig) ' reset HUD to our original content
    end if
end sub

sub rfBasicDialog(obj) 
    ' ljunkie - Home Screen shortcut ( if we are not already on the homescreen )
    '  TODO: rethink using this for rfDefRemoteOptionButton() sub -- we could also add in a button for searching
    dialog = createBaseDialog()

    ' always first button
    dialog.SetButton("GoToHomeScreen", "Home Screen")

    dialogSetSortingButton(dialog,obj) 
    dialog.SetButton("close", "Back")
    dialog.HandleButton = videoDialogHandleButton
    dialog.ParentScreen = obj
    dialog.Show()
end sub

sub rfDefRemoteOptionButton(m) 
    'for now we will show the preferences screen :)
    player = AudioPlayer()
    if player.IsPlaying or player.IsPaused then return

    sec_metadata = getSectionType()
    notAllowed = CreateObject("roRegex", "artist|music|album", "") 
    if NOT notAllowed.isMatch(tostr(sec_metadata.type)) then 
        new = CreateObject("roAssociativeArray")
        new.sourceUrl = ""
        'new.ContentType = "prefs"
        'new.Key = "globalprefs"
        'new.Title = "Preferences"
        new.Key = "globalsearch"
        new.Title = "Search"
        new.ContentType = "search"
        breadcrumbs = ["Miscellaneous","Search"]
        m.ViewController.CreateScreenForItem(new, invalid, breadcrumbs)
        Debug("Showing default serach screen - remote option button pressed ")
    else if m.isfullgrid = true and type(m.screen) = "roGridScreen" then 
        dialog = createBaseDialog()
        dialog.Text = ""
        dialog.Title = "Options"

        'always first button
        dialog.SetButton("GoToHomeScreen", "Home Screen")

        dialogSetSortingButton(dialog,m) 
        if player.ContextScreenID <> invalid then dialog.setButton("gotoMusicNowPlaying","go to now playing [music]")
        dialog.SetButton("close", "Back")
        dialog.HandleButton = videoDialogHandleButton
        dialog.ParentScreen = m
        dialog.Show()
     else 
        Debug("Default dialog not allowed in this section")
     end if 
end sub


sub rfDialogGridScreen(obj as Object)
    player = AudioPlayer()
    if player.IsPlaying or player.IsPaused then return

    if type(obj.item) = "roAssociativeArray" and tostr(obj.item.contenttype) = "section" and NOT tostr(obj.item.nodename) = "Directory" or obj.selectedrow = 0 then ' row 0 is reserved for the fullGrid shortcuts
        print obj.item
        rfDefRemoteOptionButton(obj) 
    ' for now the only option is grid view so we will verify we are in a roGridScreen. It we add more buttons, the type check below is for fullGridScreen
    else if type(obj.screen) = "roGridScreen" then 
        dialog = createBaseDialog()
        dialog.Text = ""
        dialog.Title = "Options"
        fromName = "invalid"
        if type(obj.loader.getnames) = "roFunction" and obj.selectedrow <> invalid then fromName = obj.loader.getnames()[obj.selectedrow]

        ' always first button
        dialog.SetButton("GoToHomeScreen", "Home Screen")

        dialogSetSortingButton(dialog,obj) 

        if obj.isfullgrid = invalid and obj.disablefullgrid = invalid then
            dialog.sepAfter.Push("fullGridScreen")
            dialog.SetButton("fullGridScreen", "Grid View: " + fromName) 'and type(obj.screen) = "roGridScreen" 
        end if
        if player.ContextScreenID <> invalid then dialog.setButton("gotoMusicNowPlaying","go to now playing [music]")
        dialog.SetButton("close", "Back")
        dialog.HandleButton = videoDialogHandleButton
        dialog.ParentScreen = obj
        dialog.Show()
     end if

end sub

function getAllRowsContext(screen,context,index) as object
    obj = CreateObject("roAssociativeArray")
    obj.curindex = index

    if type(screen.screen) = "roGridScreen" then
        srow = screen.selectedrow
        sitem = screen.focusedindex+1
        rsize = screen.contentarray[0].count()
        obj.curindex = (srow*rsize)+sitem-1 ' index is zero based (minus 1)
        context = []
        for each c in screen.contentarray
            for each i in c
                context.push(i)
            end for
        end for
    end if

    obj.context = context

    return obj
end function

Function ShallowCopy(array As Dynamic, depth = 0 As Integer) As Dynamic
    If Type(array) = "roArray" Then
        copy = []
        For Each item In array
            childCopy = ShallowCopy(item, depth)
            If childCopy <> invalid Then
                copy.Push(childCopy)
            End If
        Next
        Return copy
    Else If Type(array) = "roAssociativeArray" Then
        copy = {}
        For Each key In array
            If depth > 0 Then
                copy[key] = ShallowCopy(array[key], depth - 1)
            Else
                copy[key] = array[key]
            End If
        Next
        Return copy
    Else
        Return array
    End If
    Return invalid
End Function

sub rfCDNthumb(metadata,thumb_text,nodetype = invalid, PrintDebug = false)
    if RegRead("rf_custom_thumbs", "preferences","enabled") = "enabled" then
        remyplex = CreateObject("roRegex", "my.plexapp.com|plex.tv", "i")        
        remyplexMD = CreateObject("roRegex", "library/metadata/\d+", "i")        
        if remyplex.IsMatch(metadata.server.serverurl) then 
	    if metadata.HDPosterURL <> invalid and remyplexMD.isMatch(metadata.HDPosterURL) then 
                if PrintDebug then Debug("Skipping custom thumb -- this is cloud sync")
                return
            end if
            if PrintDebug then Debug("overriding cloudsync thumb" + tostr(metadata.HDPosterURL))
        end if


        if tostr(GetGlobalAA().lookup("GlobalNewScreen")) = "poster" then
            sizes = PosterImageSizes()
        else if tostr(GetGlobalAA().lookup("GlobalNewScreen")) = "grid" then
            sizes = GridImageSizes()
        else
            sizes = ImageSizes(metadata.ViewGroup, nodeType)
        end if

        ' mod_rewrite/apache do not allow & or %26
        ' replace with :::: - the cdn will replace with &
        reand = CreateObject("roRegex", "&", "") 
        reslash = CreateObject("roRegex", "/", "")  ' seo urls, so replace these
        redots = CreateObject("roRegex", "\.", "")  ' freaks out the photo transcoder
        thumb_text = reand.ReplaceAll(thumb_text, "::::") 
        thumb_text = reslash.ReplaceAll(thumb_text, "::") 
        thumb_text = redots.ReplaceAll(thumb_text, " ") 
        ' append cloud to the text if not a secondary ( this should only be on library sections )
        ' if there are complaints, we can skip these so people see their default TV icon in the section
        if remyplex.IsMatch(metadata.server.serverurl) and tostr(nodeType) <> "secondary" and tostr(metadata.ViewGroup) <> "secondary" then thumb_text = thumb_text + " (cloud)"

	if GetGlobal("IsHD") = true then 
            Width = sizes.hdWidth
            Height = sizes.hdHeight
        else
            Width = sizes.sdWidth
            Height = sizes.sdHeight
        end if

        ' the Image Processor expects images to be 300px wide ( text is set to fit that )
        ' reset the height accordingly. The PMS transcoder will resize it after the image has been created
        ' this is also done in the image processor.. 2013-12-13
        Height = int((300/Width.toInt())*Height.toInt())
        Width = "300"

        rarflix_cdn = "http://d1gah69i16tuow.cloudfront.net"
        ' rarflix_cdn = "http://ec2-b.rarflix.com"
        ' new format -- no longer need to update apache 'CK\d\d\d\d\d\d\d\d'
        cachekey = "CK20140001" ' 2013-12-13 ( handle an image < 300px height after resizing -- centering text > 3 lines )
        NewThumb = rarflix_cdn + "/" + cachekey + "/key/" + URLEncode(thumb_text) ' this will be a autogenerate poster (transparent)
'        NewThumb = NewThumb + "/size/" + tostr(hdWidth) + "x" + tostr(hdHeight) ' things seem to play nice this way with the my image processor
        NewThumb = NewThumb + "/size/" + tostr(Width) + "x" + tostr(Height)
        NewThumb = NewThumb + "/fg/" + RegRead("rf_img_overlay", "preferences","999999")
        if PrintDebug then Debug("----   newraw:" + tostr(NewThumb))
        ' we still want to transcode the size to the specific roku standard
        ' however I am not sure the my.plexapp.com server will transcode properly yet
        if remyplex.IsMatch(metadata.server.serverurl) then 
            metadata.SDPosterURL = NewThumb
            metadata.HDPosterURL = NewThumb
        else 
            metadata.SDPosterURL = metadata.server.TranscodedImage(metadata.server.serverurl, NewThumb, sizes.sdWidth, sizes.sdHeight) 
            metadata.HDPosterURL = metadata.server.TranscodedImage(metadata.server.serverurl, NewThumb, sizes.hdWidth, sizes.hdHeight)
        end if

        if PrintDebug then 
            Debug("----      new:" + tostr(metadata.HDPosterURL))
            Debug( "-------------------------------------------")
        end if

    end if
end sub

' ljunkie - crazy sauce right? this is a way to figure out what section we are in 
' -- better way -- just use the vc.Home object !
function getSectionType() as object
    Debug("checking if we can figure out the section we are in")
    metadata = CreateObject("roAssociativeArray")

    screen = GetViewController().Home
    
    if screen <> invalid  and screen.selectedrow <> invalid and screen.focusedindex <> invalid  then 
        row = screen.selectedrow
        index = screen.focusedindex
        if type(screen.loader.contentarray[row].content) = "roArray" and screen.loader.contentarray[row].content.count() > 0 then 
                   metadata = screen.loader.contentarray[row].content[index]
                   Debug("type: " + tostr(metadata.type) +"; contenttype: " + tostr(metadata.contenttype) + "; viewgroup: " + tostr(metadata.viewgroup) + "; nodename: " + tostr(metadata.nodename))
        end if
    end if

    return metadata ' return empty assoc
end function

function getEpoch() as integer
        datetime = CreateObject( "roDateTime" )
        return datetime.AsSeconds()
end function 

function getLogDate(epoch=invalid) as string
        datetime = CreateObject( "roDateTime" )

        ' convert epoch if given - otherwise use the current time
        if epoch <> invalid then 
            datetime.FromSeconds(epoch)
        end if

        datetime.ToLocalTime()

        date = datetime.AsDateString("short-date")

        hours = datetime.GetHours()
    	if hours < 10 then 
            hours = "0" + tostr(hours)
        else 
            hours = tostr(hours)
        end if

        minutes = datetime.GetMinutes()
        if minutes < 10 then 
            minutes = "0" + tostr(minutes)
        else 
            minutes = tostr(minutes)
        end if

        seconds = datetime.GetSeconds()
        if seconds < 10 then 
            seconds = "0" + tostr(seconds)
        else 
            seconds = tostr(seconds)
        end if

	return date + " " + hours + ":" + minutes + ":" + seconds
end function

sub updateVideoHUD(m,curProgress,releaseDate = invalid)
    Debug("---- timeline sent :: HUD updated " + tostr(curProgress))
    if releaseDate <> invalid then m.VideoItem.OrigHUDreleaseDate = releaseDate

    endString = invalid
    watchedString = invalid

    date = CreateObject("roDateTime")
    if m.VideoItem.Duration <> invalid and m.VideoItem.Duration > 0 then
        duration = int(m.VideoItem.Duration/1000)
        timeLeft = int(Duration - curProgress)
        endString = "End Time: " + RRmktime(date.AsSeconds()+timeLeft) + "  (" + GetDurationString(timeLeft,0,1,1) + ")" + "  Watched: " + GetDurationString(int(curProgress),0,0,1)
    else
         ' include current time and watched time when video duration is unavailable (HLS & web videos)
         watchedString = "Time: " + RRmktime(date.AsSeconds()) + "     Watched: " + GetDurationString(int(curProgress),0,0,1)
    end if

    ' set the HUD
    content = CreateObject("roAssociativeArray")
    content = m.VideoItem ' assign Video item and reset other keys
    content.length = m.VideoItem.duration
    content.title = m.VideoItem.title

    ' set the Orig Release date before we start appending. We can then reuse the OrigHUDreleaseDate for future calls
    if m.VideoItem.OrigHUDreleaseDate = invalid then
        if content.releasedate <> invalid then
            m.VideoItem.OrigHUDreleaseDate = content.releasedate
        else
            m.VideoItem.OrigHUDreleaseDate = ""
        end if
    end if

     ' overwrite release date now
    content.releasedate = m.VideoItem.OrigHUDreleasedate

    if tostr(m.VideoItem.rokustreambitrate) <> "invalid" and validint(m.VideoItem.rokustreambitrate) > 0 then
        bitrate = RRbitrate(m.VideoItem.rokustreambitrate)
        content.releasedate = content.releasedate + " " + bitrate
    end if

    content.releasedate = content.releasedate + chr(10) + chr(10)  'two line breaks - easier to read
    if endString <> invalid then content.releasedate = content.releasedate +  endString
    if watchedString <> invalid then content.releasedate = content.releasedate + watchedString
 
   ' update HUD
    m.Screen.SetContent(content)
end sub

' hide Row Text (headers) for Rows on the Grid Screen
' refer to vcPopScreen in ViewController.brs - we have to call this on every Pop for any GridScreen
' due to Roku globally setting the counterText* for every open screen
sub hideRowText(hide = true)
    if RegRead("rf_fullgrid_hidetext", "preferences", "disabled") = "disabled" return ' nothing to do if we haven't set this pref

    app = CreateObject("roAppManager")
    if hide then 
        app.SetThemeAttribute("GridScreenListNameColor", "#" +  GetGlobalAA().Lookup("rfBGcolor"))
        app.SetThemeAttribute("CounterTextRight", "#" +  GetGlobalAA().Lookup("rfBGcolor"))
        app.SetThemeAttribute("CounterTextLeft", "#" +  GetGlobalAA().Lookup("rfBGcolor"))
        app.SetThemeAttribute("CounterSeparator", "#" +  GetGlobalAA().Lookup("rfBGcolor"))
    else 
        titleText = "#BFBFBF" 
        normalText = "#999999"
        subtleText = "#525252"
        app.SetThemeAttribute("GridScreenListNameColor", titleText)
        app.SetThemeAttribute("CounterTextRight", normalText)
        app.SetThemeAttribute("CounterTextLeft", titleText)
        app.SetThemeAttribute("CounterSeparator", normalText)
    end if
end sub


Function GridImageSizes(style = invalid) As Object
    ' will have to modify this if we use multi-aspect-ratio -- get the gridStyle for the focused index. TODO at a later date
    if style = invalid then style = GetGlobalAA().Lookup("GlobalGridStyle")

    if style = "flat-movie" then 
        sdWidth = "110"
        sdheight = "150"
        hdWidth = "210"
        hdheight = "270"
    else if style = "flat-portrait" then 
        sdWidth = "110"
        sdheight = "140"
        hdWidth = "210"
        hdheight = "300"
    else if style = "flat-landscape" then 
        sdWidth = "140"
        sdheight = "94"
        hdWidth = "210"
        hdheight = "158"
    else if style = "flat-square" then 
        sdWidth = "96"
        sdheight = "86"
        hdWidth = "132"
        hdheight = "132"
    else if style = "flat-16x9" then 
        sdWidth = "140"
        sdheight = "70"
        hdWidth = "210"
        hdheight = "118"
    else if style = "two-row-flat-landscape-custom" then
        sdwidth = "140"
        sdHeight = "94"
        hdWidth = "266"
        hdHeight = "150"
    else if style =  "four-column-flat-landscape" then 
        sdwidth = "140"
        sdHeight = "70"
        hdWidth = "210"
        hdHeight = "118"
    else 
        'default to something
        sdWidth = "223"
        sdHeight = "200"
        hdWidth = "300"
        hdHeight = "300"
    end if

    ' Mixed Aspect Ratio.... fun
    '"mixed-aspect-ratio"
    ' HD
    'landscape - 192 x 144
    'portrait - 192 x 274
    'square - 192 x 192
    ' SD 
    'landscape -  140 x 94
    'portrait - 140 x 180
    'square - 140 x 126

    sizes = CreateObject("roAssociativeArray")
    sizes.sdWidth = sdWidth
    sizes.sdHeight = sdHeight
    sizes.hdWidth = hdWidth
    sizes.hdHeight = hdHeight
    return sizes
End Function



Function PosterImageSizes(style = invalid) As Object
    if style = invalid then style = GetGlobalAA().Lookup("GlobalPosterStyle")

    if style = "arced-portrait" then
        SDwidth = "158"
        SDheight = "204"
        HDwidth = "214"
        HDheight = "306"
    else if style = "arced-landscape" then
        SDwidth = "214"
        SDheight = "144"
        HDwidth = "290"
        HDheight = "218"
    else if style = "arced-16x9" then
        SDwidth = "285"
        SDheight = "145"
        HDwidth = "385"
        HDheight = "218"
    else if style = "arced-square" then
        SDwidth = "223"
        SDheight = "200"
        HDwidth = "300"
        HDheight = "300"
    else if style = "flat-category" then
        SDwidth = "224"
        SDheight = "158"
        HDwidth = "304"
        HDheight = "237"
    else if style = "flat-episodic" then
        SDwidth = "166"
        SDheight = "112"
        HDwidth = "224"
        HDheight = "168"
    else if style = "rounded-rect-16x9-generic" then
        SDwidth = "177"
        SDheight = "90"
        HDwidth = "269"
        HDheight = "152"
    else if style = "flat-episodic-16x9" then
        SDwidth = "185"
        SDheight = "94"
        HDwidth = "250"
        HDheight = "141"
    else 
        'default to something
        sdWidth = "223"
        sdHeight = "200"
        hdWidth = "300"
        hdHeight = "300"
    end if

    sizes = CreateObject("roAssociativeArray")
    sizes.sdWidth = sdWidth
    sizes.sdHeight = sdHeight
    sizes.hdWidth = hdWidth
    sizes.hdHeight = hdHeight
    return sizes
End Function


sub SetGlobalGridStyle(style = invalid) 
    GetGlobalAA().AddReplace("GlobalGridStyle", style)
    GetGlobalAA().AddReplace("GlobalNewScreen", "grid")
end sub

sub SetGlobalPosterStyle(style = invalid) 
    GetGlobalAA().AddReplace("GlobalPosterStyle", style)
    GetGlobalAA().AddReplace("GlobalNewScreen", "poster")
end sub

Function getRARflixTools(server) as object

    if type(server.rarflixtools) = "roAssociativeArray" then 
       Debug("server tools already checked - installed: " + tostr(server.rarflixtools.installed))
       return server.rarflixtools
    end if

    'if NOT isRFdev() then return invalid

    content = CreateObject("roAssociativeArray")

    r1=CreateObject("roRegex", ":\d+", "")
    baseUrl = server.serverurl
    baseUrl = r1.Replace(baseUrl, ":32499") ' RARflix Poster Util needs to run on port 32499 (internal and external!) - apache/nginx/dnat/etc..
    baseUrl = baseUrl + "/RARflixTools/"
    Debug("---- checking if the RARflixTools are installed on PMS: " + tostr(baseUrl))

    req = CreateURLTransferObject(baseUrl)
    port = CreateObject("roMessagePort")
    req.SetPort(port)
    req.AsyncGetToString()
    event = wait(1500, port)

    ResponseCode = invalid
    if type(event) = "roUrlEvent"
        ResponseCode = event.GetResponseCode()
    else if event = invalid
        Debug("url timeout")
        req.AsyncCancel()
    else
        Debug("url unknown event: " + type(event))
    end if

    if ResponseCode = invalid or ResponseCode <> 200 return invalid

    ' Parse the result to see if the RARflixTools are working properly
    json=ParseJSON(event.GetString())
    
    ' must have a valid json result and access to the PMS (PMSaccess)
    if json <> invalid and json.rarflix <> invalid and json.rarflix.PMSaccess = true then
        Debug("---- RARflixTools are installed")
        content.installed = true
        content.sourceurl = baseUrl
        
        ' for now we only have one tool, but set them from teh json results to verify they are working properly
        content.PosterTranscoder = json.rarflix.PosterTranscoder
        content.PosterTranscoderUrl = json.rarflix.PosterTranscoderUrl
        content.PosterTranscoderType = json.rarflix.PosterTranscoderType

    else
        content.installed = false
        Debug("---- RARflixTools are NOT installed")
    end if

    return content
End Function

sub PosterIndicators(item)
    progress = 0 ' default no progress
    watched  = 0 ' default unwatched

    'if NOT isRFdev() then return

    ' things that are not supported '
    if item = invalid or item.server = invalid or tostr(item.server.rarflixtools) = "invalid" or item.server.rarflixtools.PosterTranscoder <> true then return 
    baseUrl = item.server.rarflixtools.PosterTranscoderUrl
    if baseUrl = invalid then return
   

    ' initialize some vars
    if item.ThumbIndicators = invalid then item.ThumbIndicators = false

    ' this would include music/photos ( for now we only want video )
    ' supportedIdentifier = (item.mediaContainerIdentifier = "com.plexapp.plugins.library" OR item.mediaContainerIdentifier = "com.plexapp.plugins.myplex")
    isSupported = (item.ContentType = "movie" or item.ContentType = "show" or item.ContentType = "episode" or item.ContentType = "series" or item.type = "season" or item.viewgroup = "season" or item.viewgroup = "show")
    if not isSupported then 
        'Debug("skipping poster overlay (indicators) " + tostr(item.title) + " type:" + tostr(item.ContentType))
        'if item.hasdetails and (item.type <> "album" and item.type <> "artist" and item.type <> "photo") then 
        '    print item
        'end if
	return
    end if

    ' this can probably be removed -- it to exclude myplex server during testing. The checks above should already handle this
    skip=CreateObject("roRegex", "https", "")
    if skip.isMatch(baseUrl) then return 

    if item.viewedLeafCount <> invalid and item.leafCount <> invalid 
        ' for seasons / mixedParent we will either show progress or wathched indication, but not both
        if val(item.viewedLeafCount) = val(item.leafCount) then 
           watched = 1
        else if val(item.viewedLeafCount) > 0 then
            progress = int( (val(item.viewedLeafCount)/val(item.leafCount)) * 100)
        end if
    else 
        ' Video Meta data -- OK to show both progress indicator and watched 
        if item.viewOffset <> invalid and item.rawlength <> invalid then progress = int( (item.viewOffset.toInt()/item.rawlength) * 100)
        if item.Watched <> invalid and item.Watched then watched = 1
    end if

    createOverlay = false 
    if item.ThumbIndicators then 
        createOverlay = true
    else if tostr(item.server.rarflixtools.PosterTranscoderType) = "CHECK" then 
         if watched = 1 OR progress > 0 then createOverlay = true
    else 
         if watched = 0 OR progress > 0 then createOverlay = true
    end if

    if createOverlay then 
       item.ThumbIndicators = true

       if item.hdposterurl <> invalid then item.hdposterurl = buildPosterIndicatorUrl(baseUrl, item.hdposterurl, progress, watched)
       if item.sdposterurl <> invalid then item.sdposterurl = buildPosterIndicatorUrl(baseUrl, item.sdposterurl, progress, watched)

       if item.hdgridthumb <> invalid then item.hdgridthumb = buildPosterIndicatorUrl(baseUrl, item.hdgridthumb, progress, watched)
       if item.sdgridthumb <> invalid then item.sdgridthumb = buildPosterIndicatorUrl(baseUrl, item.sdgridthumb, progress, watched)

       if item.HDDetailThumb <> invalid then item.HDDetailThumb = buildPosterIndicatorUrl(baseUrl, item.HDDetailThumb, progress, watched)
       if item.SDDetailThumb <> invalid then item.SDDetailThumb = buildPosterIndicatorUrl(baseUrl, item.SDDetailThumb, progress, watched)

       if item.HDsbThumb <> invalid then item.HDsbThumb = buildPosterIndicatorUrl(baseUrl, item.HDsbThumb, progress, watched)
       if item.SDsbThumb <> invalid then item.SDsbThumb = buildPosterIndicatorUrl(baseUrl, item.SDsbThumb, progress, watched)
    end if

end sub

function buildPosterIndicatorUrl(baseUrl, thumbUrl, progress, watched) as string
    ' the thumbnail might alrady be converted -- if so, replace changes instead of building
    r=CreateObject("roRegex", baseUrl, "")
    if r.isMatch(thumbUrl) then 
        r1 = CreateObject("roRegex", "progress=\d+", "i")
        thumbUrl = r1.Replace(thumbUrl, "progress="+tostr(progress))
        r2 = CreateObject("roRegex", "watched=\d+", "i")
        thumbUrl = r2.Replace(thumbUrl, "watched="+tostr(watched))
        newThumb = thumbUrl
    else 
        newThumb = baseUrl + "?progress=" + tostr(progress) + "&watched=" + tostr(watched) + "&thumb=" + thumbUrl
    end if

    return newThumb
end function

function supportsTextScreen() as boolean
    major = GetGlobalAA().Lookup("rokuVersionArr")[0]
    minor = GetGlobalAA().Lookup("rokuVersionArr")[1]
    textScreen = false
    if (major > 4) or (major = 4 and minor > 2) then textScreen = true
    return textScreen
end function
