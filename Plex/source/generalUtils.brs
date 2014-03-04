'**********************************************************
'**  Video Player Example Application - General Utilities
'**  November 2009
'**  Copyright (c) 2009 Roku Inc. All Rights Reserved.
'**********************************************************

'******************************************************
' MULTI USER HELPERS
'
'For multiple users the registry settings are unique
'for each user.  When accessing user-specific registry
'settings the RegGetSectionName() function will return
'the user-specific registry.  The user-specific registry
'section is the same as the regular section, except that
'"_uN" is appended to it.  
'For example, calling  RegGetSectionName("preferences")
'when m.userNum = 3 will return "preferencese_u3" 
'
'Note that user 0 does not have anything appended so in the
'previous example for user0 RegGetSectionName("preferences")
'will return just "preferences"
'
'Note that only "myplex", "preferences", "servers" and "userinfo"
'are converted for multiuser support.  If you use additional
'preferences then you must add them to the list in RegSetUserPrefsToCurrentUser()
'
'
'******************************************************

function RegGetUniqueSections()
    obj = { myplex:"",preferences:"",servers:"",userinfo:"",server_tokens:"", servers:""} 'list of prefs that are customized for each user.
    return obj  
end function

'Create AA keyed off of section for quick lookup 
sub RegSetUserPrefsToCurrentUser()
    m.userRegPrefs = RegGetUniqueSections() 'list of prefs that are customized for each user.  
    for each key in m.userRegPrefs
        if (m.userNum = invalid) or (m.userNum <= 0) then  'for user of 0 or -1, just use the standard name
            m.userRegPrefs[key] = tostr(key)
        else
            m.userRegPrefs[key] = tostr(key) + "_u" + numtostr(m.userNum)
        end if
    next  
end sub

'Return the section name, converting the required ones to the right format
Function RegGetSectionName(section=invalid) as string
    if section = invalid then  return "Default"
    userRegPrefs = m.userRegPrefs
    if userRegPrefs = invalid then userRegPrefs = RegGetUniqueSections()
    if userRegPrefs[section] <> invalid then   
        return userRegPrefs[section]
    end if     
    return section
end function

'use this to get section names for a usernumber different from the current user
function RegGetSectionByUserNumber(userNumber as integer, section = invalid) as string
    'this is slow but rarely gets called
    if section = invalid then return "Default"
    userRegPrefs = m.userRegPrefs
    if userRegPrefs = invalid then userRegPrefs = RegGetUniqueSections()
    for each key in userRegPrefs
        if key = section then
            if userNumber <= 0 then 'for user of 0 or -1, just use the standard name
                return tostr(key)
            else
                return tostr(key) + "_u" + numtostr(userNumber)
            end if
        end if
    next  
    return section
end function

'Erases all the prefs for a usernumber
sub RegEraseUser(userNumber as integer)
    Debug("Erasing user " + numtostr(userNumber))
    userRegPrefs = m.userRegPrefs
    if userRegPrefs = invalid then userRegPrefs = RegGetUniqueSections()
    for each section in userRegPrefs
        print "section="; section
        old = CreateObject("roRegistrySection", RegGetSectionByUserNumber(userNumber, section))
        keyList = old.GetKeyList()
        for each key in keyList
            old.Delete(key)            
        next
    next
    reg = CreateObject("roRegistry")
    reg.Flush() 'write out changes
    m.RegistryCache.Clear() 'just clear the entire cache
end sub

'******************************************************
'Registry Helper Functions
'******************************************************
Function RegRead(key, section=invalid, default=invalid, userNumber=invalid)
    ' Reading from the registry is somewhat expensive, especially for keys that
    ' may be read repeatedly in a loop. We don't have that many keys anyway, keep
    ' a cache of our keys in memory.
    if (userNumber <> invalid) and isint(userNumber) then
        section = RegGetSectionByUserNumber(userNumber, section)
    else     
        section = RegGetSectionName(section)
    endif
    'print "RegRead:"+tostr(section)+":"+tostr(key)+":"+tostr(default)+" user("+tostr(userNumber)+")"
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

Sub RegWrite(key, val, section=invalid, userNumber=invalid)
    if (userNumber <> invalid) and isint(userNumber) then
        section = RegGetSectionByUserNumber(userNumber, section)
    else
        section = RegGetSectionName(section)
    endif

    if val = invalid then
        RegDelete(key, section)
        return
    end if

    'print "RegWrite:"+tostr(section)+":"+tostr(key)+":"+tostr(val)+" user("+tostr(userNumber)+")"
    sec = CreateObject("roRegistrySection", section)
    sec.Write(key, val)
    m.RegistryCache[key + section] = val
    sec.Flush() 'commit it
End Sub

Sub RegDelete(key, section=invalid)
    section = RegGetSectionName(section)
    sec = CreateObject("roRegistrySection", section)
    sec.Delete(key)
    m.RegistryCache.Delete(key + section)
    sec.Flush()
End Sub

'Outputs the entire registry for Plex
'sub PrintRegistry()
'    Debug("------- REGISTRY --------")
'    reg = CreateObject("roRegistry")
'    regList = reg.GetSectionList()
'    for each e in regList
'        Debug("Section->" + tostr(e))
'        sec = CreateObject("roRegistrySection", e)
'        keyList = sec.GetKeyList()
'        for each key in keyList
'            value = sec.Read(key)
'            Debug(tostr(key) + " : " + tostr(value))
'        next
'    next
'    Debug("--- END OF REGISTRY -----")
'end sub

'Erases everything in the Registry for Plex
'sub EraseRegistry() 
'    Debug("Erasing Registry")
'    reg = CreateObject("roRegistry")
'    regList = reg.GetSectionList()
'    for each e in regList
'        sec = CreateObject("roRegistrySection", e)
'        keyList = sec.GetKeyList()
'        for each key in keyList
'            sec.Delete(key)
'        next
'    next
'    m.RegistryCache.Clear()
'end sub

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
    if type(obj) = "" return false   'this can happen with uninitialized variables
    if GetInterface(obj, "ifInt") = invalid return false
    return true
End Function

Function validint(obj As Dynamic) As Integer
    if type(obj) = "" return false   'this can happen with uninitialized variables
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
    if type(obj) = "" return false   'this can happen with uninitialized variables
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
    if type(any) = "<uninitialized>" return "invalid"   'ljunkie -- this is what happens with uninitialized variables (maybe newer firmware?)
    if any = invalid return "invalid"
    if type(any) = "" return "empty"   'this can happen with uninitialized variables
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
            ' ljunkie - we want to be able to change the Plex-Container size with a toggle-- we will strip this from the key to match the order
            r  = CreateObject("roRegex", "\&X-Plex-Container-Start=0\&X-Plex-Container-Size\=.*", "")
            rf_test = invalid           
            if r.IsMatch(items[i].key) then rf_test = r.replace(items[i].key,"")

            if (items[i].key = key) or (rf_test <> invalid and rf_test = key) then
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
' Helper to trace functions 
'******************************************************
sub TraceFunction(fcnName as string, arg0=invalid as dynamic, arg1=invalid as dynamic,arg2=invalid as dynamic,arg3=invalid as dynamic,arg4=invalid as dynamic,arg5=invalid as dynamic,arg6=invalid as dynamic)
    args = [ arg0,arg1,arg2,arg3,arg4,arg5,arg6 ] 
    'print type(arg0); type(arg1); type(arg2); type(arg3)
    'find last arg
    for i = args.Count() - 1 to 0 step -1
        if args[i] <> invalid then exit for
        args.Delete(i)
    end for
    s = "TRACE:" + tostr(fcnName) + tostr(" - ")
    for i = 0 to args.Count() - 1 step 1
        if i <> 0 then s = s + " , "
        s = tostr(s) + tostr(args[i])
    end for
    Debug(s)
end sub 

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

end Function

Sub SwapArray(arr, i, j, setOrigIndex=false)
    ' ljunkie -- sometimes the orignal and random number can be the same
    ' we should still set the OrigIndex to be able to unShuffleArray later
    ' note: moved out of the "i <> j" if statement

    if setOrigIndex then
        if arr[i].OrigIndex = invalid then arr[i].OrigIndex = i
        if arr[j].OrigIndex = invalid then arr[j].OrigIndex = j
    end if

    ' if Orignal and Random are different, swap items place in array
    if i <> j then
        temp = arr[i]
        arr[i] = arr[j]
        arr[j] = temp
    end if
End Sub

Function ShuffleArray(arr, focusedIndex)
    ' Start by moving the current focused item to the front.
    SwapArray(arr, 0, focusedIndex, true)

    ' Now loop from the end to 1. Rnd doesn't return 0, so the item we just put
    ' up front won't be touched.
    for i = arr.Count() - 1 to 1 step -1
        SwapArray(arr, i, Rnd(i), true)
    next

    return 0
End Function

Function UnshuffleArray(arr, focusedIndex)
    item = arr[focusedIndex]

    sanity=0:buffer=500000 ' ljunkie -- keeping from an infinite loop ( buffer is large, but we should be able to handle it )
    i = 0
    while i < arr.Count()
        if arr[i].OrigIndex = invalid then return 0
        SwapArray(arr, i, arr[i].OrigIndex)
        if i = arr[i].OrigIndex then i = i + 1
        ' the above line can be really bad if the origIndex is set on ALL the items, yet is the same (shouldn't happen.. but you know...)
        ' infinite loop killer
        sanity = sanity + 1
        if sanity > arr.Count()+buffer then 
           Debug("!! exiting UnshuffleArray -- something is really wrong! " + " processed " + tostr(sanity) + " of a total " + tostr(arr.count()) + "total items!")
           return firstOf(item.OrigIndex, 0)
        end if
    end while

    return firstOf(item.OrigIndex, 0)
End Function
