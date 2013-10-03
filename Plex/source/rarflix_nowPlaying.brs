Sub rf_homeNowPlayingChange()
    Debug("---- refreshing Now Playing")
    ' RefreshData() -  homeRefreshData() this would refresh all.. but we don't want to do that ( I think )
    ' might be usful to check audio now playing too

    rowkey = "now_playing"
    m.contentArray[m.RowIndexes[rowkey]].refreshContent = []
    m.contentArray[m.RowIndexes[rowkey]].loadedServers.Clear()

    for each server in GetOwnedPlexMediaServers()
        m.CreateServerRequests(server, true, true, invalid, rowkey) ' only request the nowPlaying;/status/sessions
        ' maybe we will update other later
    next

    ' Clear any screensaver images, use the default.
    SaveImagesForScreenSaver(invalid, {}) ' do we need this?
End Sub

sub rf_updateNowPlayingSB(screen)
    orig_offset = screen.metadata.viewOffset

    screen.metadata = rfUpdateNowPlayingMetadata(screen.metadata)

    if screen.metadata.viewOffset <> invalid then
        ' I should really make this a function to keep this standard on the 3 screens
        screen.metadata.description = " * Progress: " + GetDurationString(int(screen.metadata.viewOffset.toint()/1000),0,1,1) ' update progress - if we exit player
        screen.metadata.isStopped = invalid
    else 
        screen.metadata.description = " * User has stopped watching"
        screen.metadata.isStopped = true
        screen.metadata.viewOffset = orig_offset ' reset offset to this users offset, so they can resume even if EU stopped
        Debug("setting the video Offset to your offset (not remote) - user has stopped but you should be able to resume!")
    end if
    screen.metadata.description = screen.metadata.description + " on " + firstof(screen.metadata.nowplaying_platform_title, screen.metadata.nowplaying_platform, "")
    if screen.metadata.server.name <> invalid then screen.metadata.description = screen.metadata.description + " [" + screen.metadata.server.name + "]" ' show the server 
    screen.metadata.description = screen.metadata.description + chr(10) + screen.metadata.nowPlaying_orig_description ' append the original description
   
    ' on the spring board - we also only want to show the original title - the breadcrumbs will have the user
    if screen.metadata.episodestr <> invalid then 
        screen.metadata.titleseason = screen.metadata.cleantitle + " - " + screen.metadata.episodestr
    else
        screen.metadata.title = screen.metadata.cleantitle
    end if
     screen.Screen.setContent(screen.metadata)
    print "update NOW playing description with new time"
end sub

function rfUpdateNowPlayingMetadata(metadata,time = 0 as integer) as object
    container = createPlexContainerForUrl(metadata.server, metadata.serverurl, "/status/sessions")
    keys = container.getkeys()
    found = false
    for index = 0 to keys.Count() - 1
        print "Searching for key:" + metadata.key + " and machineID:" + metadata.nowPlaying_maid ' verify same machineID to sync (multiple people can be streaming same content)
        if keys[index] = metadata.key and container.xml.Video[index].Player@machineIdentifier = metadata.nowPlaying_maid then 
            Debug("----- nowPlaying match: key:" + tostr(metadata.key) + ", machineID:" + tostr(metadata.nowPlaying_maid) + " @ " + tostr(metadata.serverurl) + "/status/sessions")
            found = true
            Debug("----- prev offset " + tostr(metadata.viewOffset))
            metadata = container.metadata[index]
            metadata.viewOffset = tostr(metadata.viewOffset.toint() + int(time)) ' just best guess. add on a few seconds since it takes time to buffer
            Debug("-----  new offset " + tostr(metadata.viewOffset))
            if time > 0 then  debug("----- added " + tostr(int(time/1000)) + " seconds to offset for sync")
            exit for
        end if
    end for

    if NOT found then
        metadata.viewOffset = invalid
    end if

    return metadata
end function