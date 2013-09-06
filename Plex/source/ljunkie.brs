' other functions required for my mods
Function GetDurationString( TotalSeconds = 0 As Integer ) As String
   datetime = CreateObject( "roDateTime" )
   datetime.FromSeconds( TotalSeconds )
      
   hours = datetime.GetHours().ToStr()
   minutes = datetime.GetMinutes().ToStr()
   seconds = datetime.GetSeconds().ToStr()
   
   duration = ""
   If hours <> "0" Then
      duration = duration + hours + "h "
   End If
   If minutes <> "0" Then
      duration = duration + minutes + "m "
   End If
   If seconds <> "0" Then
      duration = duration + seconds + "s"
   End If
   
   Return duration
End Function


Function GetTime12Hour( epoch As Integer ) As String
    datetime = CreateObject("roDateTime")
    datetime.FromSeconds(epoch)
    datetime.ToLocalTime()
    hours = datetime.GetHours()
    minutes = datetime.GetMinutes()
    seconds = datetime.GetSeconds()
       
       duration = ""
       hour = hours
       If hours = 0 Then
           hour = 12
       End If

       If hours > 12 Then
           hour = hours-12
       End If

       If hours >= 0 and hours < 12 Then
          AMPM = "AM"
       else
	  AMPM = "PM"
       End if
       
       minute = minutes.ToStr()
       If minutes < 10 Then
         minute = "0" + minutes.ToStr()
       end if

       result = hour.ToStr() + ":" + minute + AMPM

       Return result
End Function
