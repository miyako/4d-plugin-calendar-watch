![version](https://img.shields.io/badge/version-19%2B-5682DF)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-calendar-watch)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-calendar-watch/total)

# 4d-plugin-calendar-watch
Return event IDs of modified calendar item by monitoring the sqlite directory used by Calendar.app.

## Syntax

```
Calendar GET LIST (ids;paths;titles;types;watchings)
```

Parameter|Type|Description
------------|------------|----
ids|ARRAY TEXT|UUID of a calendar
paths|ARRAY TEXT|Full path of the folder that contains the .ics files
titles|ARRAY TEXT|Title
types|ARRAY INT32|``1``: caldav (e.g. iCloud), ``5``: Exchange
watchings|ARRAY INT32|``!`` If the calendar path is watched by the plugin

```
Calendar ADD TO WATCH (path;method)
```

Parameter|Type|Description
------------|------------|----
path|TEXT|Full path of the folder that contains the .ics files
method|TEXT|Callback method name

```
Calendar REMOVE FROM WATCH (path)
```

Parameter|Type|Description
------------|------------|----
path|TEXT|Full path of the folder that contains the .ics files

##Examples

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
