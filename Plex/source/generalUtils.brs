'**********************************************************
'**  Video Player Example Application - General Utilities
'**  November 2009
'**  Copyright (c) 2009 Roku Inc. All Rights Reserved.
'**********************************************************

'******************************************************
' MULTI USER HELPERS
'******************************************************
sub RegSetUserPrefsToCurrentUser()
    for each key in m.userRegPrefs
        if m.userNum = -1 then
            m.userRegPrefs[key] = AnyToString(key)
        else
            m.userRegPrefs[key] = AnyToString(key) + "_u" + numtostr(m.userNum)
        end if
    next  
end sub

'much faster to use the AA then to generate the name each time we need to convert the section
Function RegGetSectionName(section=invalid) as string
    if section = invalid then 
        return "Default"
    else if m.userRegPrefs[section] <> invalid then
        return m.userRegPrefs[section]
    end if     
    return section
end function

function RegGetSectionByUserNumber(userNumber as integer, section = invalid) as string
    'this is slow but rarely gets called
    if section = invalid then return "Default"
    for each key in m.userRegPrefs
        if key = section then
            if userNumber = -1 then
                return AnyToString(key)
            else
                return AnyToString(key) + "_u" + numtostr(userNumber)
            end if
        end if
    next  
    return section
end function


'Much slower
'Function RegGetSectionName2(section=invalid) as string
'    if section = invalid then section = "Default"
'    if m.userNum = -1 then return section
'    if section="myplex" or section="preferences" or section="servers" or section="userinfo" then
'        'return AnyToString(section) + "_u" + AnyToString(m.userNum)
'        return section + "_u" + numtostr(m.userNum)
'    end if
'    return section     
'end function

'Copies the the old pref sections to the new sections and remove the old.  Will copy to whatever the current user is
sub RegConvertRegistryToMultiUser()
    Debug("Converting Registry to Multiuser")
    for each section in m.userRegPrefs
        old = CreateObject("roRegistrySection", section)
        new = CreateObject("roRegistrySection", m.userRegPrefs[section])
        'print section; " "; m.userRegPrefs[section]
        keyList = old.GetKeyList()
        for each key in keyList
            value = old.Read(key)
            new.Write(key,value)
            old.Delete(key)            
            'print key; ":"; value
        next
    next
    reg = CreateObject("roRegistry")
    reg.Flush() 'write out changes
    m.RegistryCache.Clear()
end sub

'Erases all the prefs for a usernumber
sub RegEraseUser(userNumber as integer)
    Debug("Erasing user " + AnyToString(userNumber))
    for each section in m.userRegPrefs
        old = CreateObject("roRegistrySection", RegGetSectionByUserNumber(section, userNumber))
        print section; " "; m.userRegPrefs[section]
        keyList = old.GetKeyList()
        for each key in keyList
            old.Delete(key)            
            print key
        next
    next
    reg = CreateObject("roRegistry")
    reg.Flush() 'write out changes
    m.RegistryCache.Clear()
end sub


'******************************************************
'Registry Helper Functions
'******************************************************
Function RegReadByUser(userNumber as integer, key, section=invalid, default=invalid)
    ' Reading from the registry is somewhat expensive, especially for keys that
    ' may be read repeatedly in a loop. We don't have that many keys anyway, keep
    ' a cache of our keys in memory.
    section = RegGetSectionByUserNumber(userNumber, section)
    cacheKey = key + section
    if m.RegistryCache.DoesExist(cacheKey) then return m.RegistryCache[cacheKey]

    value = default
    sec = CreateObject("roRegistrySection", section)
    if sec.Exists(key) then value = sec.Read(key)

    if value <> invalid then
        m.RegistryCache[cacheKey] = value
    end if

    return value
End Function

Function RegRead(key, section=invalid, default=invalid)
    ' Reading from the registry is somewhat expensive, especially for keys that
    ' may be read repeatedly in a loop. We don't have that many keys anyway, keep
    ' a cache of our keys in memory.
    section = RegGetSectionName(section)
    print "RegRead:"+AnyToString(section)+":"+AnyToString(key)+":"+AnyToString(default)
    cacheKey = key + section
    if m.RegistryCache.DoesExist(cacheKey) then return m.RegistryCache[cacheKey]

    value = default
    sec = CreateObject("roRegistrySection", section)
    if sec.Exists(key) then value = sec.Read(key)

    if value <> invalid then
        m.RegistryCache[cacheKey] = value
    end if

    return value
End Function

Function RegWrite(key, val, section=invalid)
    section = RegGetSectionName(section)
    sec = CreateObject("roRegistrySection", section)
    sec.Write(key, val)
    m.RegistryCache[key + section] = val
    sec.Flush() 'commit it
End Function

Function RegDelete(key, section=invalid)
    section = RegGetSectionName(section)
    sec = CreateObject("roRegistrySection", section)
    sec.Delete(key)
    m.RegistryCache.Delete(key + section)
    sec.Flush()
End Function

sub PrintRegistry()
    Debug("------- REGISTRY --------")
    reg = CreateObject("roRegistry")
    regList = reg.GetSectionList()
    for each e in regList
        Debug("Section->" + AnyToString(e))
        sec = CreateObject("roRegistrySection", e)
        keyList = sec.GetKeyList()
        for each key in keyList
            value = sec.Read(key)
            Debug(AnyToString(key) + " : " + AnyToString(value))
        next
    next
    Debug("--- END OF REGISTRY -----")
end sub

'Erases everything in the Registry for Plex
sub EraseRegistry() 
    Debug("Erasing Registry")
    reg = CreateObject("roRegistry")
    regList = reg.GetSectionList()
    for each e in regList
        sec = CreateObject("roRegistrySection", e)
        keyList = sec.GetKeyList()
        for each key in keyList
            sec.Delete(key)
        next
    next
    m.RegistryCache.Clear()
end sub

'******************************************************
'Convert anything to a string
'
'Always returns a string
'******************************************************
Function tostr(any)
    ret = AnyToString(any)
    if ret = invalid ret = type(any)
    if ret = invalid ret = "unknown" 'failsafe
    return ret
End Function


'******************************************************
'isint
'
'Determine if the given object supports the ifInt interface
'******************************************************
Function isint(obj as dynamic) As Boolean
    if obj = invalid return false
    if GetInterface(obj, "ifInt") = invalid return false
    return true
End Function

Function validint(obj As Dynamic) As Integer
    if obj <> invalid and GetInterface(obj, "ifInt") <> invalid then
        return obj
    else
        return 0
    end if
End Function

'******************************************************
' validstr
'
' always return a valid string. if the argument is
' invalid or not a string, return an empty string
'******************************************************
Function validstr(obj As Dynamic) As String
    if isnonemptystr(obj) return obj
    return ""
End Function


'******************************************************
'isstr
'
'Determine if the given object supports the ifString interface
'******************************************************
Function isstr(obj as dynamic) As Boolean
    if obj = invalid return false
    if GetInterface(obj, "ifString") = invalid return false
    return true
End Function


'******************************************************
'isnonemptystr
'
'Determine if the given object supports the ifString interface
'and returns a string of non zero length
'******************************************************
Function isnonemptystr(obj)
    if obj = invalid return false
    if not isstr(obj) return false
    if Len(obj) = 0 return false
    return true
End Function


'******************************************************
'numtostr
'
'Convert an int or float to string. This is necessary because
'the builtin Str[i](x) prepends whitespace
'******************************************************
Function numtostr(num) As String
    st=CreateObject("roString")
    if GetInterface(num, "ifInt") <> invalid then
        st.SetString(Stri(num))
    else if GetInterface(num, "ifFloat") <> invalid then
        st.SetString(Str(num))
    end if
    return st.Trim()
End Function


'******************************************************
'Tokenize a string. Return roList of strings
'******************************************************
Function strTokenize(str As String, delim As String) As Object
    st=CreateObject("roString")
    st.SetString(str)
    return st.Tokenize(delim)
End Function


'******************************************************
'Replace substrings in a string. Return new string
'******************************************************
Function strReplace(basestr As String, oldsub As String, newsub As String) As String
    newstr = ""

    i = 1
    while i <= Len(basestr)
        x = Instr(i, basestr, oldsub)
        if x = 0 then
            newstr = newstr + Mid(basestr, i)
            exit while
        endif

        if x > i then
            newstr = newstr + Mid(basestr, i, x-i)
            i = x
        endif

        newstr = newstr + newsub
        i = i + Len(oldsub)
    end while

    return newstr
End Function


'******************************************************
'Walk an AA and print it
'******************************************************
Sub PrintAA(aa as Object)
    Debug("---- AA ----")
    if aa = invalid
        Debug("invalid")
        return
    else
        cnt = 0
        for each e in aa
            x = aa[e]
            PrintAny(0, e + ": ", aa[e])
            cnt = cnt + 1
        next
        if cnt = 0
            PrintAny(0, "Nothing from for each. Looks like :", aa)
        endif
    endif
    Debug("------------")
End Sub


'******************************************************
'Print an associativearray
'******************************************************
Sub PrintAnyAA(depth As Integer, aa as Object)
    for each e in aa
        x = aa[e]
        PrintAny(depth, e + ": ", aa[e])
    next
End Sub


'******************************************************
'Print a list with indent depth
'******************************************************
Sub PrintAnyList(depth As Integer, list as Object)
    i = 0
    for each e in list
        PrintAny(depth, "List(" + tostr(i) + ")= ", e)
        i = i + 1
    next
End Sub


'******************************************************
'Print anything
'******************************************************
Sub PrintAny(depth As Integer, prefix As String, any As Dynamic)
    if depth >= 10
        Debug("**** TOO DEEP " + tostr(5))
        return
    endif
    prefix = string(depth*2," ") + prefix
    depth = depth + 1
    str = AnyToString(any)
    if str <> invalid
        Debug(prefix + str)
        return
    endif
    if type(any) = "roAssociativeArray"
        Debug(prefix + "(assocarr)...")
        PrintAnyAA(depth, any)
        return
    endif
    if GetInterface(any, "ifArray") <> invalid
        Debug(prefix + "(list of " + tostr(any.Count()) + ")...")
        PrintAnyList(depth, any)
        return
    endif

    Debug(prefix + "?" + type(any) + "?")
End Sub


'******************************************************
'Try to convert anything to a string. Only works on simple items.
'
'Test with this script...
'
'    s$ = "yo1"
'    ss = "yo2"
'    i% = 111
'    ii = 222
'    f! = 333.333
'    ff = 444.444
'    d# = 555.555
'    dd = 555.555
'    bb = true
'
'    so = CreateObject("roString")
'    so.SetString("strobj")
'    io = CreateObject("roInt")
'    io.SetInt(666)
'    tm = CreateObject("roTimespan")
'
'    Dbg("", s$ ) 'call the Dbg() function which calls AnyToString()
'    Dbg("", ss )
'    Dbg("", "yo3")
'    Dbg("", i% )
'    Dbg("", ii )
'    Dbg("", 2222 )
'    Dbg("", f! )
'    Dbg("", ff )
'    Dbg("", 3333.3333 )
'    Dbg("", d# )
'    Dbg("", dd )
'    Dbg("", so )
'    Dbg("", io )
'    Dbg("", bb )
'    Dbg("", true )
'    Dbg("", tm )
'
'try to convert an object to a string. return invalid if can't
'******************************************************
Function AnyToString(any As Dynamic) As dynamic
    if any = invalid return "invalid"
    if isstr(any) return any
    if isint(any) return numtostr(any)
    if GetInterface(any, "ifBoolean") <> invalid
        if any = true return "true"
        return "false"
    endif
    if GetInterface(any, "ifFloat") <> invalid then return numtostr(any)
    if type(any) = "roTimespan" return numtostr(any.TotalMilliseconds()) + "ms"
    return invalid
End Function


'******************************************************
'Truncate long strings
'******************************************************
Function truncateString(s, maxLength=180 As Integer, missingValue="(No summary available)")
    if s = invalid then
        return missingValue
    else if len(s) <= maxLength then
        return s
    else
        return left(s, maxLength - 3) + "..."
    end if
End Function

'******************************************************
'Return the first valid argument
'******************************************************
Function firstOf(first, second, third=invalid, fourth=invalid)
    if first <> invalid then return first
    if second <> invalid then return second
    if third <> invalid then return third
    return fourth
End Function

'******************************************************
'Given an array of items and a list of keys in priority order, reorder the
'array so that the priority items are at the beginning.
'******************************************************
Sub ReorderItemsByKeyPriority(items, keys)
    ' Accept keys either as comma delimited list or already separated into an array.
    if isstr(keys) then keys = keys.Tokenize(",")

    for j = keys.Count() - 1 to 0 step -1
        key = keys[j]
        for i = 0 to items.Count() - 1
            if items[i].key = key then
                item = items[i]
                items.Delete(i)
                items.Unshift(item)
                exit for
            end if
        end for
    next
End Sub

'******************************************************
'Check for minimum version support
'******************************************************
Function CheckMinimumVersion(versionArr, requiredVersion) As Boolean
    index = 0
    for each num in versionArr
        if index >= requiredVersion.count() then exit for
        if num < requiredVersion[index] then
            return false
        else if num > requiredVersion[index] then
            return true
        end if
        index = index + 1
    next
    return true
End Function

Function CurrentTimeAsString(localized=true As Boolean) As String
    time = CreateObject("roDateTime")

    if localized then
        time.ToLocalTime()
    end if

    hours = time.GetHours()
    if hours >= 12 then
        hours = hours - 12
        suffix = " pm"
    else
        suffix = " am"
    end if
    if hours = 0 then hours = 12
    timeStr = tostr(hours) + ":"

    minutes = time.GetMinutes()
    if minutes < 10 then
        timeStr = timeStr + "0"
    end if
    return timeStr + tostr(minutes) + suffix
End Function

'******************************************************
'Scale down a rectangle from HD to SD
' Works on any object that has any of x,y,w,h 
'******************************************************
Sub HDRectToSDRect(rect As Object)
   wMultiplier = 720 / 1280
   hMultiplier = 480 / 720
   
   If rect.x <> invalid Then
      rect.x = Int(rect.x * wMultiplier + .5)
      rect.x = IIf(rect.x < 1, 1, rect.x)
   End If
   If rect.y <> invalid Then
      rect.y = Int(rect.y * hMultiplier + .5)
      rect.y = IIf(rect.y < 1, 1, rect.y)
   End If
   If rect.w <> invalid Then
      rect.w = Int(rect.w * wMultiplier + .5)
      rect.w = IIf(rect.w < 1, 1, rect.w)
   End If
   If rect.h <> invalid Then
      rect.h = Int(rect.h * hMultiplier + .5)
      rect.h = IIf(rect.h < 1, 1, rect.h)
   End If
End Sub

'******************************************************
'Helper for cleaner code 
'******************************************************
Function IIf(Condition, Result1, Result2) As Dynamic
   If Condition Then
      Return Result1
   Else
      Return Result2
   End If
End Function