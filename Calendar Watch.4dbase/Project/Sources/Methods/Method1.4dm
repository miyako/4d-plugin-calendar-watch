//%attributes = {}
//internally the plugin is not calling EventKit or CalendarStore.
//it is using sqlite3 APIs to query the database at ~Library/Calendar

ARRAY TEXT:C222($uids; 0)  //the UUID of a calendar
ARRAY TEXT:C222($paths; 0)  //the full path of the folder that contains the .ics files
ARRAY TEXT:C222($titles; 0)  //the title
ARRAY LONGINT:C221($types; 0)  //1:caldav (e.g.iCloud), 5:exchange
ARRAY LONGINT:C221($watchings; 0)  //if the calendar path is watched by the plugin

Calendar GET LIST($uids; $paths; $titles; $types; $watchings)

For ($i; 1; Size of array:C274($paths))
	Calendar ADD TO WATCH($paths{$i}; "CALLBACK")
End for 