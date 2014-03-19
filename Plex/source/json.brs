'Copyright (c) 2010, GandK Labs.  All rights reserved.
'
'Redistribution and use in source and binary forms, with or without
'modification, are permitted provided that the following conditions are met:
'    * Redistributions of source code must retain the above copyright
'      notice, this list of conditions and the following disclaimer.
'    * Redistributions in binary form must reproduce the above copyright
'      notice, this list of conditions and the following disclaimer in the
'      documentation and/or other materials provided with the distribution.
'    * Neither the GandK Labs name, the libRokuDev name, nor the
'      names of its contributors may be used to endorse or promote products
'      derived from this software without specific prior written permission.
'
'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
'ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
'WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
'DISCLAIMED. IN NO EVENT SHALL GANDK LABS BE LIABLE FOR ANY
'DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
'(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
'LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
'ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
'(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
'SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

' *************************************************************************
' * Recursive stringification of data structures, doubles as JSON creator *
' *************************************************************************
function rdSerialize(v as dynamic, outformat="BRS" as string) as string
	kq = "" ' for BRS
	if outformat = "JSON" then kq = chr(34)
	out = ""
	v = box(v)
	vType = type(v)
	if     vType = "roString" or vType = "String" 'Values in an AA seem to be of type 'String' rather than 'roString'.  Brilliant.
		re = CreateObject("roRegex",chr(34),"")
		v = re.replaceall(v, chr(34)+"+chr(34)+"+chr(34) )
		out = out + chr(34) + v + chr(34)
	elseif vType = "roInt"
		out = out + v.tostr()
	elseif vType = "roFloat"
		out = out + str(v)
	elseif vType = "roBoolean"
		bool = "false"
		if v then bool = "true"
		out = out + bool
	elseif vType = "roList" or vType = "roArray"
		out = out + "["
		sep = ""
		for each child in v
			out = out + sep + rdSerialize(child, outformat)
			sep = ","
		end for
		out = out + "]"
	elseif vType = "roAssociativeArray"
		out = out + "{"
		sep = ""
		for each key in v
			out = out + sep + kq + key + kq + ":"
			out = out + rdSerialize(v[key], outformat)
			sep = ","
		end for
		out = out + "}"
	elseif vType = "roFunction"
		out = out + "(Function)"
	else
		out = out + chr(34) + vType + chr(34)
	end if
	return out
end function

' *****************************************************************
' * Returns BrightScript object that matches passed JSON string   *
' * Original concept from hoffmcs, revised by TheEndless, further *
' * optimized by kbenson                                          *
' *****************************************************************
function rdJSONParser( jsonString as string ) as object
	q = chr(34)

	beforeKey  = "[,{]"
	keyFiller  = "[^:]*?"
	keyNospace = "[-_\w\d]+"
	valueStart = "[" +q+ "\d\[{]|true|false|null"
	reReplaceKeySpaces = "("+beforeKey+")\s*"+q+"("+keyFiller+")("+keyNospace+")\s+("+keyNospace+")\s*"+q+"\s*:\s*(" + valueStart + ")"
	
	regexKeyUnquote = CreateObject( "roRegex", q + "([a-zA-Z0-9_\-\s]*)" + q + "\s*:", "i" )
	regexKeyUnspace = CreateObject( "roRegex", reReplaceKeySpaces, "i" )
	regexQuote = CreateObject( "roRegex", "\\" + q, "i" )

	' setup "null" variable
	null = invalid

	' Replace escaped quotes
	jsonString = regexQuote.ReplaceAll( jsonString, q + " + q + " + q )
   
	while regexKeyUnspace.isMatch( jsonString )
		jsonString = regexKeyUnspace.ReplaceAll( jsonString, "\1"+q+"\2\3\4"+q+": \5" )
	end while

	jsonString = regexKeyUnquote.ReplaceAll( jsonString, "\1:" )

	jsonObject = invalid
	' Eval the BrightScript formatted JSON string
	eval( "jsonObject = " + jsonString )
	return jsonObject
end function

function rdJSONBuilder( jsonArray as object ) as string
	return rdSerialize( jsonArray, "JSON" )
end function
