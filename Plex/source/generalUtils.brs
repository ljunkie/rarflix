'**********************************************************
'**  Video Player Example Application - General Utilities
'**  November 2009
'**  Copyright (c) 2009 Roku Inc. All Rights Reserved.
'**********************************************************

'******************************************************
'Registry Helper Functions
'******************************************************
Function RegRead(key, section=invalid, default=invalid)
    ' Reading from the registry is somewhat expensive, especially for keys that
    ' may be read repeatedly in a loop. We don't have that many keys anyway, keep
    ' a cache of our keys in memory.

    if section = invalid then section = "Default"
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
    if section = invalid then section = "Default"
    sec = CreateObject("roRegistrySection", section)
    sec.Write(key, val)
    m.RegistryCache[key + section] = val
    sec.Flush() 'commit it
End Function

Function RegDelete(key, section=invalid)
    if section = invalid then section = "Default"
    sec = CreateObject("roRegistrySection", section)
    sec.Delete(key)
    m.RegistryCache.Delete(key + section)
    sec.Flush()
End Function


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
