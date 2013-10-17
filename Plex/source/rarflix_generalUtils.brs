' ljunkie - really no function for this or am I blind?
' haystack: must be an array
' needle: string or array
' *  needle array? then see if any needles exist in haystack
function inArray(haystack as dynamic,needles = dynamic) as boolean
    if type(haystack) = "roArray" and haystack.count() > 0 then

        if type(needles) = "roString" then
            new = []
            new.Push(needles)
            needles = new
        end if

        if type(needles) = "roArray" and needles.count() > 0 then 
            for each needle in needles
                for each item in haystack
                    if item = needle then return true
                next
            next
        end if
    end if
 return false
end function
