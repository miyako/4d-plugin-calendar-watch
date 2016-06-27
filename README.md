# 4d-plugin-calendar-watch
Return event IDs of modified calendar item by monitoring the sqlite directory used by Calendar.app.

##Platform

| carbon | cocoa | win32 | win64 |
|:------:|:-----:|:---------:|:---------:|
|🆗|🆗|🚫|🚫|

Examples
---

```
  //internally the plugin is not calling EventKit or CalendarStore.
  //it is using sqlite3 APIs to query the database at ~Library/Calendar

ARRAY TEXT($uids;0)  //the UUID of a calendar
ARRAY TEXT($paths;0)  //the full path of the folder that contains the .ics files
ARRAY TEXT($titles;0)  //the title
ARRAY LONGINT($types;0)  //1:caldav (e.g.iCloud), 5:exchange
ARRAY LONGINT($watchings;0)  //if the calendar path is watched by the plugin

Calendar GET LIST ($uids;$paths;$titles;$types;$watchings)

For ($i;1;Size of array($paths))
Calendar ADD TO WATCH ($paths{$i};"CALLBACK")
End for 
```

``CALLBACK``

```
C_TEXT($1;$event)
C_LONGINT($2;$type)

$event:=$1
$type:=$2

Case of 
: ($type=Calendar Event Create)

: ($type=Calendar Event Update)

: ($type=Calendar Event Delete)

End case 

TRACE
```
