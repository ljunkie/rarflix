'*
'* TESTING...
'*

' Initial Filter screen containing [type], filters, sorts, clear filters, close
Function createFilterSortListScreen(item, gridScreen, typeKey=invalid) As Object
    ' Facade screen create to keep home screen from showing when we have to 
    ' reload the grid on close due to filters/types changing
    facade = CreateObject("roGridScreen")
    facade.show()

    ' create the standard list screen
    obj = createBasePrefsScreen(GetViewController())

    obj.Screen.SetHeader("Filter & Sorting")
    obj.HandleMessage = prefsFilterSortHandleMessage
    obj.Activate = prefsFilterSortActivate
    obj.refreshOnActivate = true

    obj.filterItem = item
    obj.facade = facade
    obj.parentscreen = gridScreen
    obj.sourceUrl = item.sourceUrl
    obj.server = item.server

    ' other screen created from within this screen
    obj.createFilterListScreen = createFilterListScreen
    obj.createTypeListScreen = createTypeListScreen

    obj.filterOnClose = true
    ' force a new full grid if the type is modified or the item calls for a it (viewing filters item from a non full grid)
    obj.forcefilterOnClose = (NOT(typeKey=invalid) or item.forcefilterOnClose=true)

    obj.clearFilters = clearFilterList
    obj.getFilterKeyString = getFilterKeyString
    obj.getSortString = getSortString

    ' update and get filter keys
    obj.cacheKeys = getFilterSortCacheKeys(item.server,item.sourceurl,typeKey)
    if obj.cachekeys = invalid then return invalid
    
    filterSortObj = getFilterSortParams(item.server,item.sourceurl)
    obj.initialFilterParamsString = filterSortObj.filterParamsString

    ' obtain any filter in place - state saved per session per section
    obj.filterValues = GetGlobal(obj.cachekeys.filterValuesCacheKey)
    if obj.filterValues = invalid then obj.filterValues = {}

    ' Add buttons to the screen. If you need to add any other buttons, make sure to update
    ' the fuck prefsFilterSortActivate() with any new button logic - ordering of buttons
    ' will break logic

    sec_metadata = getSectionType()
    obj.defaultTypes = defaultTypes(firstof(sec_metadata.type,item.type),obj.cacheKeys.typeKey)
    if obj.defaultTypes <> invalid then 
        obj.AddItem({title: "Type",}, "create_type_screen", getDefaultType(obj.defaultTypes))
    end if

    ' TODO(lunkie) verify one can still sort if filters are not available -- all sections *should* have filters
    obj.validFilters = getValidFilters(obj.server,obj.sourceurl)
    if obj.validFilters = invalid or obj.validFilters.count() = 0 then
        Debug("no valid filters found for this section? " + tostr(obj.cacheKeys.sectionKey) + "/filters")
    else 
        obj.AddItem({title: "Filters"}, "create_filter_screen", obj.getFilterKeyString())
    end if

    obj.AddItem({title: "Sorting"}, "create_sort_screen", obj.getSortString())
    if filterSortObj.hasFilters = true then 
        obj.AddItem({title: "Clear Filters"}, "clear_filters")
    end if

    obj.AddItem({title: "Close"}, "close")

    return obj
End Function

function getDefaultType(types)
    if types <> invalid and types.title <> invalid then return types.title
    return ""
end function

function getSortString()
    sort = getSortingOption(m.server,m.sourceurl)
    sortString = ""
    if sort <> invalid and sort.item <> invalid and sort.item.title <> invalid then 
        sortString = sort.item.title
    end if
    return sortString
end function

function getSortkey()
    sort = getSortingOption(m.server,m.sourceurl)
    sortKey = RegRead("section_sort", "preferences","titleSort:asc")
    if sort <> invalid and sort.item <> invalid and sort.item.key <> invalid then 
        sortKey = sort.item.key
    end if
    return sortKey
end function

function getFilterKeyString()
    filterSortObj = getFilterSortParams(m.server,m.sourceurl)
    keyString = ""
    if filterSortObj <> invalid and filterSortObj.filterKeysString <> invalid then 
        keyString = filterSortObj.filterKeysString
    end if
    if keyString = "" then keyString = "None"
    return keyString
end function

Function createFilterListScreen() As Object
    obj = createBasePrefsScreen(GetViewController())

    obj.Screen.SetHeader("Filter Options")
    obj.parentscreen = GetViewController().screens.peek()

    obj.HandleMessage = prefsFilterHandleMessage
    obj.Activate = prefsFilterActivate
    obj.refreshOnActivate = true

    ' other screen options in the filter/sort screen
    obj.createSubFilterListScreen = createSubFilterListScreen

    ' filters - in use for this server/section (saved per session)
    obj.filterValues = obj.parentscreen.filterValues
    obj.cacheKeys = obj.parentscreen.cacheKeys

    ' filters - valid for use (cache) for base url
    obj.validFilters = obj.parentscreen.ValidFilters
    if obj.validFilters = invalid or obj.validFilters.count() = 0 then
        Debug("no valid filters found for this section? " + tostr(sectionKey) + "/filters")
        return invalid
    end if   

    for each filter in obj.validFilters
        if obj.filterValues[filter.key] = invalid then 
            obj.filterValues[filter.key] = {}
            obj.filterValues[filter.key].filter = filter
            obj.filterValues[filter.key].values = {}
        end if

        if filter.filtertype = "integer" or filter.filtertype = "string" then 
            obj.AddItem({title: filter.title, key: filter.key, type: filter.filterType}, "filter_toggle",  filterList(obj.filterValues[filter.key]))
        end if

        if filter.filtertype = "boolean" then
            if obj.filterValues[filter.key].title = "true" then 
                obj.filterValues[filter.key].value = 1
            else if obj.filterValues[filter.key].title = "false" then 
                obj.filterValues[filter.key].value = 0
            else 
                obj.filterValues[filter.key].title = ""
                obj.filterValues[filter.key].value = invalid
            end if
            obj.AddItem({title: filter.title, key: filter.key, type: filter.filterType}, "filter_toggle", filterList(obj.filterValues[filter.key]))
        end if
    end for

    obj.AddItem({title: "Close"}, "close")

    return obj
End Function


Function createTypeListScreen() As Object
    obj = createBasePrefsScreen(GetViewController())

    obj.Screen.SetHeader("Type Options")
    obj.parentscreen = m

    obj.HandleMessage = prefsTypeHandleMessage
    obj.refreshOnActivate = false

    for index = 0 to m.defaultTypes.values.count()-1
        item = m.defaultTypes.values[index]
        if item.key = m.defaultTypes.key then focusedIndex = index
        obj.AddItem({title: item.title, key: item.key}, "filter_type_toggle")
    end for
 
    if focusedIndex <> invalid then obj.screen.SetFocusedListItem(focusedIndex)

    return obj
End Function


Function createSubFilterListScreen(key) As Object
    ' instant feedback 
    facade = CreateObject("roGridScreen")
    facade.show()

    obj = createBasePrefsScreen(GetViewController())
    obj.Screen.SetHeader("Filter by " + m.filterValues[key].filter.title)

    obj.FilterSelection = m.filterValues[key]
    obj.ParentScreen = m
    obj.isFilterEnabled = isFilterEnabled
    obj.filterAdd = filterListAdd
    obj.filterDel = filterListDelete

    obj.HandleMessage = prefsSubFilterHandleMessage

    item = obj.FilterSelection.filter
    container = createPlexContainerForUrl(item.server, "", item.key)
    metadata = container.getmetadata()

    ' parent array
    for each item in metadata
        obj.AddItem({title: item.title, key: item.key, metadata: item}, "sub_filter_toggle", obj.isFilterEnabled(item.key))
    end for 

    obj.AddItem({title: "Close"}, "close")

    facade.close()
    return obj
End Function

function isFilterEnabled(filterKey,typeBoolean=false)
    if typeBoolean then 
        enabled = true
        disabled = false
    else 
        enabled = "X"
        disabled = ""
    end if
    if m.filterSelection <> invalid and m.filterSelection.values <> invalid then 
        for each enabledKey in m.filterSelection.values
            if filterKey = enabledKey
                return enabled
                exit for
            end if
        end for
    end if

    return disabled
end function

sub filterListAdd(key, title) 
    if m.filterSelection <> invalid and m.filterSelection.values <> invalid then
        m.filterSelection.values[key] = title
    end if
end sub

sub filterListDelete(key, title) 
    if m.filterSelection <> invalid and m.filterSelection.values <> invalid then
        m.filterSelection.values.Delete(key)
    end if
end sub

function filterList(obj) 
    values = ""
    if obj <> invalid and obj.filter <> invalid then 
        if obj.filter.filtertype = "boolean" then 
            return tostr(obj.title)
        else 
            first = true
            for each key in obj.values
                if values = "" then 
                   values = obj.values[key]
                else 
                   values = values + "," + obj.values[key]
                end if
            end for
        end if
    end if
    return values
end function

function clearfilterList() 
    for each key in m.filterValues 
        if tostr(m.filterValues[key].filter.filtertype) = "boolean" then 
            m.filterValues[key].value = invalid
            m.filterValues[key].title = ""
        end if
        m.filterValues[key].values = {}
    end for
end function

Function prefsFilterSortHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
             gridScreen = m.parentscreen

             if m.callBackItem <> invalid then 
                ' recreate the list screen ( probably due to type change )
                Debug("filter type changed - recreate the list screen")
                callback = m.CallBackItem
                GetViewController().afterCloseCallback = callback
             else if m.filterOnClose = true then 
                ' recreate or refresh the full grid screen with the new filters/sorts
                GetGlobalAA().AddReplace(m.cachekeys.filterValuesCacheKey,m.filterValues)

                filterSortObj = getFilterSortParams(m.server,m.sourceurl)
                gridItem = gridScreen.originalitem
                breadcrumbs = getFilterBreadcrumbs(filterSortObj,gridItem)

                ' recreate the full grid if filters changed or we are forceing a filter change
                '  forcefilterOnClose: due to recreating list screen with a typeKey set ( changing types )
                if (m.initialFilterParamsString <> filterSortObj.filterParamsString) or m.forcefilterOnClose = true then 
                    Debug("filter options or type changed -- refreshing the grid (new)")
                    m.ViewController.PopScreen(m)

                    ' create a call back item for the viewController to receate it (the full grid screen)
                    callback = CreateObject("roAssociativeArray")
                    callback.facade = m.facade
                    callback.item = gridItem
                    callback.item.callbackFullGrid = true ' always use the fullgrid when re-creating
                    callback.breadcrumbs = breadcrumbs
                    callback.OnAfterClose = createScreenForItemCallback

                    ' assign the callback item to the viewcontroller and close the grid
                    GetViewController().afterCloseCallback = callback
                    gridScreen.screen.Close()
                    return true
                else 
                    Debug("filter options and type did not change (sorting may have and will reload if needed)")
                    GetViewController().AddBreadcrumbs(gridScreen, breadcrumbs)
                    GetViewController().UpdateScreenProperties(gridScreen)
                end if
            end if

            if m.facade <> invalid then m.facade.close()
            m.ViewController.PopScreen(m)

        else if msg.isListItemSelected() then
            m.FocusedIndex = msg.GetIndex()
            command = m.GetSelectedCommand(m.FocusedIndex)

            if command = "close" then
                m.Screen.Close()
            else if command = "clear_filters" then
                ' TODO(ljunkie) sould we change this to a "reset" and clear sorting too?
                m.ClearFilters()
                ' reactivate this screen (refresh all items)
                m.Activate(m)
            else if command = "create_filter_screen" then
                screen = m.createFilterListScreen()
                screen.ScreenName = "Filter Options"
                GetViewController().InitializeOtherScreen(screen, invalid)
                screen.screen.show()
            else if command = "create_type_screen" then
                screen = m.createTypeListScreen()
                screen.ScreenName = "View Type"
                GetViewController().InitializeOtherScreen(screen, invalid)
                screen.screen.show()
            else if command = "create_sort_screen" then
                ' TODO(ljunkie) - do we need to make this a list screen instead of a dialog?
                ' sorting was creating before filtering. It uses a dialog. It could be changed to a list screen to match 
                ' the existing format, but it will be a bit of work.
                dialog = createGridSortingDialog(m,m.parentscreen)
                if dialog <> invalid then dialog.Show(true)
            end if
        end if

    end if

    return handled
End Function

Function prefsFilterHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            m.FocusedIndex = msg.GetIndex()
            command = m.GetSelectedCommand(m.FocusedIndex)

            if command = "close" then
                m.Screen.Close()
            else if command = "filter_toggle" then
                item = m.contentarray[m.FocusedIndex]
                if item = invalid then return handled

                ' boolean filter types we just toggle through 
                if item.type = "boolean" then 
                    if m.filterValues[item.key].value = invalid then 
                        m.filterValues[item.key].value = 1
                        m.filterValues[item.key].title = "true"
                    else if m.filterValues[item.key].value = 1 then 
                        m.filterValues[item.key].value = 0
                        m.filterValues[item.key].title = "false"
                    else 
                        m.filterValues[item.key].value = invalid 
                        m.filterValues[item.key].title = ""
                    end if
                    
                    m.AppendValue(m.FocusedIndex, m.filterValues[item.key].title)
                else 
                    ' other filter types (string/integer) need another screen to toggle sub filters
                    screen = m.createSubFilterListScreen(item.key)
                    screen.ScreenName = "Sub Filters"
                    GetViewController().InitializeOtherScreen(screen, invalid)
                    screen.screen.show()
                end if
            end if
        end if

    end if

    return handled
End Function

Function prefsSubFilterHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            m.FocusedIndex = msg.GetIndex()
            command = m.GetSelectedCommand(m.FocusedIndex)

            if command = "close" then
                m.Screen.Close()
            else if command = "sub_filter_toggle" then
                ' filter is toggles
                ' * update the list item value to show it's marked
                ' * add/delete the specific filterValues (m.filterselection.values) depending if it's on/off
                item = m.contentarray[m.FocusedIndex]

                if m.isFilterEnabled(item.key,1) = true then 
                    m.filterDel(item.key, item.title) 
                else 
                    m.filterAdd(item.key, item.title) 
                end if 

                m.AppendValue(m.FocusedIndex, m.isFilterEnabled(item.key))

            end if

        end if
    end if

    return handled
End Function


Function prefsTypeHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            m.FocusedIndex = msg.GetIndex()
            command = m.GetSelectedCommand(m.FocusedIndex)

            if command = "close" then
                m.Screen.Close()
            else if command = "filter_type_toggle" then
                item = m.contentarray[m.FocusedIndex]

                ' closing the filter screen (m.parentscreen) will close the originalfacade. This needs
                ' to a new facade to hide the grid below while recreateing the list screen.
                facade = CreateObject("roGridScreen")
                facade.show()

                ' clear any filters
                m.parentscreen.ClearFilters()
                m.screen.close()

                ' recreate the list screen with a callback
                callback = CreateObject("roAssociativeArray")
                callback.Item = m.parentscreen.filterItem
                callback.Item.typeKey = item.key
                callback.breadcrumbs = ["","Filters & Sorting"]
                callback.facade = facade
                callback.OnAfterClose = createScreenForItemCallback

                ' set a callbackItem on the parent screen. It will try to re-create the items screen
                ' (new filter/sort list screen) after closing the current list filter/sort screen
                m.parentscreen.callbackitem = callback
                m.parentscreen.screen.Close()
            end if
        end if

    end if

    return handled
End Function


Sub prefsFilterActivate(priorScreen)
    ' save the filters for the session ( per section )
    GetGlobalAA().AddReplace(m.cachekeys.filterValuesCacheKey,m.filterValues)

    for index = 0 to m.contentarray.count()-1
        item = m.contentarray[index]
        if item.key <> invalid and item.type <> invalid then 
           if m.filterValues <> invalid and m.filterValues[item.key] <> invalid then 
               m.AppendValue(index, filterList(m.filterValues[item.key]))
           else 
               m.AppendValue(index, "")
           end if
        end if
    end for
End Sub

Sub prefsFilterSortActivate(priorScreen)
    ' refresh all the buttons
    hasClearButton = false
    for index = 0 to m.contentarray.count()-1
        command = m.GetSelectedCommand(index)
        filterSortObj = getFilterSortParams(m.server,m.sourceurl)

        if command = "create_filter_screen" then 
            m.AppendValue(index, m.getFilterKeyString())
        else if command = "create_sort_screen" then 
            m.AppendValue(index, m.getSortString())
        else if command = "create_type_screen" then 
            m.AppendValue(index, getDefaultType(m.defaultTypes))
        else if command = "clear_filters" 
            hasClearButton = true
            'remove button if filters do not exist
            if filterSortObj.hasFilters = false then 
                hasClearButton = false
                m.contentArray.Delete(index)
                m.screen.setcontent(m.contentArray)
            end if
        else if command = "close" then 
            if hasClearButton = false and filterSortObj.hasFilters = true then
                ' delete the close button and add clear/close back
                m.contentArray.Delete(index)
                m.screen.setcontent(m.contentArray)
                m.AddItem({title: "Clear Filters"}, "clear_filters")
                m.AddItem({title: "Close"}, "close")
            end if

        end if
    end for

End Sub

function getFilterSortParams(server,sourceUrl)
    ' always pass back a valid object
    obj = {}
    obj.filterParamsString = ""
    obj.filterKeysString = ""
    obj.hasFilters = false
    obj.filterParams = []
    obj.filterKeys = []
    obj.cacheKeys = getFilterSortCachekeys(server,sourceurl)

    if obj.cachekeys = invalid then return obj

    ' attach the sorting object
    obj.sorts = getSortingOption(server,sourceUrl)
    if obj.sorts <> invalid and obj.sorts.item <> invalid then obj.sortItem = obj.sorts.item

    ' obtain any filter in place - state saved per session per section
    obj.filterValues = GetGlobal(obj.cachekeys.filterValuesCacheKey)

    ' type added here - it's not really a filter but will ONLY be changed during the filter process
    if obj.cacheKeys.typeKey <> invalid then
        obj.filterParams.Push("type="+tostr(obj.cacheKeys.typeKey))
    end if

    for each key in obj.filterValues 
        item = obj.filterValues[key]
        values = ""
        if item.values <> invalid and item.filter <> invalid then 
            if item.filter.filtertype = "boolean" then 
                if item.value <> invalid  then 
                    obj.filterKeys.Push(item.filter.key)
                    obj.filterParams.Push(item.filter.filter + "=" + tostr(item.value))
                end if
            else 
                first = true
                for each key in item.values
                    if values = "" then 
                       values = key
                    else 
                       values = values + "," + key
                    end if
                end for

                if values <> "" then 
                    obj.filterKeys.Push(item.filter.key)
                    obj.filterParams.Push(item.filter.filter + "=" + tostr(values))
                end if
            end if
        end if
    end for 

    for each param in obj.filterParams
        if obj.filterParamsString = "" then
            obj.filterParamsString = param
        else 
            obj.filterParamsString = obj.filterParamsString + "&" + param
        end if
    end for

    for each key in obj.filterkeys
        title = obj.filterValues[key].filter.title
        if obj.filterkeysString = "" then
            obj.filterkeysString = title
        else 
            obj.filterkeysString = obj.filterkeysString + ", " + title
        end if
    end for

    obj.hasFilters = (obj.filterParams.count() > 0)
    if obj.filterParams.count() = 1 and obj.cacheKeys.typeKey <> invalid then
        obj.hasFilters = false
    end if

    return obj
end function

function addFiltersToUrl(sourceurl,filterSortObj)
    filterValues = filterSortObj.filterValues
    filterParamsString = filterSortObj.filterParamsString

    ' always clear filters before replacing ( or removing all )
    for each key in filterValues
        strip = filterValues[key].filter.filter
        re = CreateObject("roRegex", "([\&\?]"+strip+"=[^\&\?]+)", "i")
        sourceurl = re.ReplaceAll(sourceurl, "")
    end for 

    ' always clear type - either it will be in the filterParamsString or not (which mean default sorting)
    re = CreateObject("roRegex", "([\&\?]type=[^\&\?]+)", "i")
    sourceurl = re.ReplaceAll(sourceurl, "")

    ' need a better way to to this... 
    ' BUG - could be fixed with recent updates. Adding filters/sorts/types and removing some
    ' resulted in the first paramater having & instead of ? - This will only fix /all but it 
    ' should be the only endpoint we are filtering anyways (for now)
    re = CreateObject("roRegex", "/all&", "i")
    sourceurl = re.ReplaceAll(sourceurl, "/all?")

    ' this should be last filterParamsString empty/invalid means wew need to strip any 
    ' filters/sorts to return an unadulterated sourceUrl
    if filterParamsString = invalid or filterParamsString = "" then return sourceurl
    f = "?"
    if instr(1, sourceurl, "?") > 0 then f = "&"    
    sourceurl = sourceurl + f + filterParamsString

    return sourceurl
end function

function getFilterSortDescription(server,sourceurl)
    description = "None"
    if server = invalid or sourceurl = invalid then return description
    
    filterSortObj = getFilterSortParams(server,sourceurl)
    
    if filterSortObj <> invalid then
        description = "Filters: None"
        if filterSortObj.filterKeysString <> "" then
            description = "Filters: " + filterSortObj.filterKeysString
        end if

        if filterSortObj.sortItem <> invalid and filterSortObj.sortItem.title <> invalid then
            description = description + chr(10)+chr(10) + "Sort: " + filterSortObj.sortItem.title
        end if
    end if

    return description
end function

function createSectionFilterItem(server=invalid,sourceurl=invalid,itemType=invalid)
    sectionKey = getBaseSectionKey(sourceurl)

    if server <> invalid and sourceurl <> invalid then 
        sec_metadata = getSectionType()
        imageDir = GetGlobalAA().Lookup("rf_theme_dir")
        filterItem = {}
        filterItem.key = "_section_filters_"
        filterItem.type = firstof(sec_metadata.type,itemType)
        filterItem.server = server
        filterItem.sourceurl = server.serverurl + sectionKey + "/filters"
        filterItem.name = "Filters"
        filterItem.umtitle = "Enabled Filters & Sorting"
        filterItem.title = filterItem.umtitle
        filterItem.viewGroup = "section"
        filterItem.SDPosterURL = imageDir + "gear.png"
        filterItem.HDPosterURL = imageDir + "gear.png"
        rfCDNthumb(filterItem,filterItem.name,invalid)
        Debug("-- dummy filter item created -- sourceUrl:" + tostr(sourceurl) + " type:" + tostr(itemType))
        print filterItem
        return filterItem
    end if
    Debug("-- dummy filter item NOT created -- sourceUrl:" + tostr(sourceurl) + " type:" + tostr(itemType))
    return invalid
end function


function getValidFilters(server,sourceUrl)
    if server = invalid or sourceUrl = invalid then return invalid

    cacheKeys = getFilterSortCacheKeys(server,sourceurl)
    validFilters = GetGlobal(cacheKeys.filterCacheKey)
    sectionKey = cacheKeys.sectionKey

    if validFilters = invalid then 
        Debug("caching Valid Filters for this section")
        ' set cache to empty ( not invalid -- so we don't keep retrying )
        GetGlobalAA().AddReplace(cacheKeys.filterCacheKey, {})        
        typeKey = "?type="+tostr(cacheKeys.typeKey)
        if cacheKeys.typeKey = invalid then typeKey = ""
        obj = createPlexContainerForUrl(server, "", sectionKey + "/filters" + typeKey)
        if obj <> invalid then 
            ' using an assoc array ( we might want more key/values later )
            GetGlobalAA().AddReplace(cacheKeys.filterCacheKey, obj.getmetadata())        
            validFilters = GetGlobal(cacheKeys.filterCacheKey)
        end if
    end if

    if validFilters = invalid or validFilters.count() = 0 then return invalid
    return validFilters
end function

function getFilterBreadcrumbs(filterSortObj,item)
    breadcrumbs = ["",""]

    sortTitle = invalid
    if filterSortObj.sortItem <> invalid then 
        ' only include sortTitle if not the default Sort
        if RegRead("section_sort", "preferences","titleSort:asc") <> filterSortObj.sortItem.key then sortTitle = filterSortObj.sortitem.title
    end if

    if filterSortObj.hasFilters = true and sortTitle = invalid then 
         ' only filters are enable (default sorting)
         breadcrumbs = [item.title,"Filters Enabled"]
    else if filterSortObj.hasFilters = true and sortTitle <>  invalid then 
         ' filters and sorting have been modified
         breadcrumbs = ["Filters Enabled", sortTitle]
    else if sortTitle <> invalid then 
         ' only sorting has been modified
         breadcrumbs = [item.title,sortTitle]
    else 
         ' back to defaults
         breadcrumbs = [firstof(item.server.name,""),item.title]
    end if

    return breadcrumbs
end function

sub createFilterSortScreenFromItem(item=invalid,parentScreen=invalid)
        if item <> invalid and parentScreen <> invalid then 
            ' item types can sometimes be something we are not expecting - we really care about section type, not item
            ' TODO(ljunkie) possibly use this elsewhere when expecting SECTION TYPE instead of item.type (sec_metadata.type)
            ' filterItem = createSectionFilterItem(item.server,item.sourceurl,item.type)
            filterItem = createSectionFilterItem(item.server,item.sourceurl,item.type)
            if filterItem = invalid then return
            screen = createFilterSortListScreen(filterItem,parentScreen)
            screenName = "Grid Filters"
            screen.ScreenName = screenName
            breadcrumbs =  ["Filters: " + item.title]
            m.ViewController.InitializeOtherScreen(screen, breadcrumbs)
            screen.Show()
        end if
end sub

sub clearFiltersForUrl(server,sourceUrl)
    filterSortObj = getFilterSortParams(server,sourceurl)
    if filterSortObj <> invalid and filterSortObj.cachekeys <> invalid and filterSortObj.cachekeys.filterValuesCacheKey <> invalid then 
        Debug("clearing filter values for sectionKey" + tostr(filterSortObj.cachekeys.filterValuesCacheKey))
        obj={}
        obj.filterValues = GetGlobal(filterSortObj.cachekeys.filterValuesCacheKey)
        obj.clearFilterList = clearfilterList
        obj.clearfilterList()
    end if
end sub

' deprecated -- to remove
'
' Inline Filtering - refreshes grid on activate -- this is just gross and too many odd issues with filters
' Instead we will close the grid and recreate with a callback
'sub gridFilterSection()
'    Debug("gridFilterSection:: called")
'    grid = m.parentscreen
'
'    if grid = invalid or grid.loader = invalid or grid.loader.sourceurl = invalid or grid.loader.server = invalid then 
'        Debug("gridSortSection:: cannot filter! grid is invalid or requied loader data is missing")
'        return
'    end if
'
'    ' get filter string
'    filterSortObj = getFilterSortParams(grid.loader.server,grid.loader.sourceurl)
'
'    sourceurl = grid.loader.sourceurl
'    if sourceurl <> invalid then 
'        sourceurl = addFiltersToUrl(sourceurl,filterSortObj)
'        grid.loader.sourceurl = sourceurl
'        grid.loader.sortingForceReload = true
'        if grid.loader.listener <> invalid and grid.loader.listener.loader <> invalid then 
'            grid.loader.listener.loader.sourceurl = sourceurl
'            print grid.loader.listener.loader.sourceurl
'        end if
'    end if
'
'    contentArray =  grid.loader.contentArray
'    if contentArray <> invalid and contentArray.count() > 0 then 
'        for index = 0 to contentArray.count()-1
'            if contentArray[index].key <> invalid then 
'                contentArray[index].key = addFiltersToUrl(contentArray[index].key,filterSortObj)
'                print contentArray[index].key
'            end if
'        end for
'    end if
'
'end sub
'
