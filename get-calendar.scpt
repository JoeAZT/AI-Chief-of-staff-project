tell application "Calendar"
	launch
	delay 2
	set output to ""
	set todayStart to current date
	set hours of todayStart to 0
	set minutes of todayStart to 0
	set seconds of todayStart to 0
	set todayEnd to current date
	set hours of todayEnd to 23
	set minutes of todayEnd to 59
	set seconds of todayEnd to 59

	repeat with cal in calendars
		set calEvents to (every event of cal whose start date ≥ todayStart and start date ≤ todayEnd)
		repeat with e in calEvents
			set eventTitle to summary of e
			set eventStart to start date of e
			set eventEnd to end date of e
			set isAllDay to allday event of e
			if isAllDay then
				set output to output & "All day: " & eventTitle & linefeed
			else
				-- Format times
				set startH to hours of eventStart
				set startM to minutes of eventStart
				set endH to hours of eventEnd
				set endM to minutes of eventEnd
				if startH < 10 then set startH to "0" & startH
				if startM < 10 then set startM to "0" & startM
				if endH < 10 then set endH to "0" & endH
				if endM < 10 then set endM to "0" & endM
				set output to output & startH & ":" & startM & " - " & endH & ":" & endM & ": " & eventTitle & linefeed
			end if
		end repeat
	end repeat

	if output is "" then
		return "No events today."
	end if
	return output
end tell
