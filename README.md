![version](https://img.shields.io/badge/version-19%2B-5682DF)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-calendar-watch)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-calendar-watch/total)

# 4d-plugin-calendar-watch

Calendar Watch lists the calendars known to macOS's built-in Calendar app and lets you watch one for changes. It works by reading Calendar.app's own local SQLite cache directly (`~/Library/Calendar/Calendar Cache`) and by watching the `.ics` files under each calendar's on-disk folder with the OS's file-system events (FSEvents) API — it never calls EventKit or CalendarStore. Results come back as `Text` (UUIDs, paths, titles) and `Longint` (calendar type, watch state) values; there's no `Picture`/`Blob` involved.

Because it bypasses EventKit entirely, **macOS never shows its Calendar-access permission prompt for this plugin** — see [Requirements & platform notes](#requirements--platform-notes) before you rely on that.

## Summary

Command | Returns | Purpose
---|---|---
[`Calendar GET LIST`](#calendar-get-list) | *(fills 5 arrays)* | List the user's calendars: UID, local folder path, title, type, and whether each is currently watched.
[`Calendar ADD TO WATCH`](#calendar-add-to-watch) | *(none)* | Start watching a calendar's folder for changes, calling a named 4D method when one occurs.
[`Calendar REMOVE FROM WATCH`](#calendar-remove-from-watch) | *(none)* | Stop watching a calendar's folder.

**Platforms:** macOS only (Intel and Apple Silicon).

---

## Requirements & platform notes

- **macOS only.** There is no Windows build; nothing here is available on that platform.
- **Reads Calendar.app's private cache, not a documented Apple API.** The plugin queries the SQLite database Calendar.app maintains for itself at `~/Library/Calendar/Calendar Cache`. This is an internal, undocumented format — it is not EventKit, and Apple can change or relocate it in a future macOS release without notice. Treat this plugin as tied to the current on-disk cache layout, not to a stable public interface.
- **No calendar-access permission prompt.** Because EventKit is never touched, macOS's usual "Calendar" privacy prompt never appears for this plugin. Don't use `Calendar GET LIST`/`Calendar ADD TO WATCH` as a stand-in for requesting or checking calendar permission elsewhere in your application.
- **Only CalDAV and Exchange calendars are recognized.** `Calendar GET LIST` only returns calendars for which it can resolve a `.caldav` (type `1`, e.g. iCloud) or `.exchange` (type `5`) folder on disk. A plain local, on-this-Mac-only calendar (not synced through either) has no such folder and will not appear in the result at all.
- **One background watcher for all watched paths.** Adding or removing a watched path doesn't start a separate watcher per calendar — internally the plugin tears down and restarts a single file-system watcher covering the full current set of watched folders each time you call `Calendar ADD TO WATCH` or `Calendar REMOVE FROM WATCH`.
- **Change notifications are not instantaneous.** The underlying watcher batches filesystem changes with roughly a 1-second latency, so expect a short delay between an edit in Calendar.app and your callback method firing.
- **Adding an already-watched path is a no-op.** If you call `Calendar ADD TO WATCH` for a path that's already being watched, the call does nothing — including not updating the callback method. Call `Calendar REMOVE FROM WATCH` first if you need to point an already-watched calendar at a different method.
- **Unknown callback method names fail silently.** `Calendar ADD TO WATCH` resolves the `method` parameter to a real 4D method before adding the path to the watch list; if the name doesn't match an existing method, the path is never watched and no error is raised.

---

## Calendar GET LIST

### Syntax

```4d
Calendar GET LIST ( ids ; paths ; titles ; types ; watchings )
```

Parameter | Type | Description
---|---|---
`ids` | ARRAY TEXT | *(output)* UUID of each calendar.
`paths` | ARRAY TEXT | *(output)* Full path of the folder holding that calendar's `.ics` files (its `Events` subfolder).
`titles` | ARRAY TEXT | *(output)* Calendar title, as shown in Calendar.app.
`types` | ARRAY LONGINT | *(output)* `1` for a CalDAV calendar (e.g. iCloud); `5` for an Exchange calendar.
`watchings` | ARRAY LONGINT | *(output)* `1` if this calendar's path is currently registered with `Calendar ADD TO WATCH`; `0` otherwise.
Result | — | None — this command does not return a value; it only fills the five arrays above.

### Description

All five arrays come back the same length and index-aligned: `ids{i}`/`paths{i}`/`titles{i}`/`types{i}`/`watchings{i}` all describe the same calendar. Only calendars the plugin can resolve to an actual `.caldav` or `.exchange` folder on disk are included — a calendar present in Calendar.app's cache but without a matching local folder (for example, a purely local, non-synced calendar) is left out of every array, not padded with empty values.

Existing arrays passed in are resized and overwritten; there's no accumulate/append behavior across calls.

### Example

From the plugin's own sample method (`Method1.4dm`):

```4d
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
```

A read-only variant that just prints what's found, without also starting to watch everything:

```4d
ARRAY TEXT($uids; 0)
ARRAY TEXT($paths; 0)
ARRAY TEXT($titles; 0)
ARRAY LONGINT($types; 0)
ARRAY LONGINT($watchings; 0)

Calendar GET LIST($uids; $paths; $titles; $types; $watchings)

For ($i; 1; Size of array($titles))
  Case of
    : ($types{$i}=1)
      $typeName:="CalDAV"
    : ($types{$i}=5)
      $typeName:="Exchange"
    Else
      $typeName:="Unknown"
  End case
  ALERT($titles{$i}+" ("+$typeName+") — watched: "+String($watchings{$i}=1))
End for
```

---

## Calendar ADD TO WATCH

### Syntax

```4d
Calendar ADD TO WATCH ( path ; method )
```

Parameter | Type | Description
---|---|---
`path` | TEXT | Full path of the folder containing the `.ics` files to watch — the value returned in `Calendar GET LIST`'s `paths` array.
`method` | TEXT | Name of the 4D method to call when a change is detected in that folder. See [The callback method](#the-callback-method) for its expected signature.
Result | — | None — this command does not return a value.

### Description

If `method` doesn't name an existing 4D method, the call is silently ignored (see [Requirements & platform notes](#requirements--platform-notes)). If `path` is already being watched, the call is also a no-op — the originally-registered method stays in effect even if you pass a different one here.

You can watch multiple calendar folders at once, each with its own callback method; internally a single file-system watcher is (re)started to cover the full set whenever the watch list changes.

### Example

The loop shown under [`Calendar GET LIST`](#calendar-get-list) is the plugin's own pattern for this: fetch every calendar's path, then register the same callback method for each one. To watch just one specific calendar picked out from that list — say, the first CalDAV calendar found:

```4d
ARRAY TEXT($uids; 0)
ARRAY TEXT($paths; 0)
ARRAY TEXT($titles; 0)
ARRAY LONGINT($types; 0)
ARRAY LONGINT($watchings; 0)

Calendar GET LIST($uids; $paths; $titles; $types; $watchings)

For ($i; 1; Size of array($types))
  If ($types{$i}=1)
    Calendar ADD TO WATCH($paths{$i}; "CALLBACK")
    $i:=Size of array($types)  //stop after the first match
  End if
End for
```

---

## Calendar REMOVE FROM WATCH

### Syntax

```4d
Calendar REMOVE FROM WATCH ( path )
```

Parameter | Type | Description
---|---|---
`path` | TEXT | Full path previously passed to `Calendar ADD TO WATCH`.
Result | — | None — this command does not return a value.

### Description

Removing a path that isn't currently watched is a harmless no-op — no error is raised either way. Once every watched path has been removed, the plugin's internal background watcher process shuts down; adding a new watch afterward starts it again.

### Example

```4d
ARRAY TEXT($uids; 0)
ARRAY TEXT($paths; 0)
ARRAY TEXT($titles; 0)
ARRAY LONGINT($types; 0)
ARRAY LONGINT($watchings; 0)

Calendar GET LIST($uids; $paths; $titles; $types; $watchings)

For ($i; 1; Size of array($watchings))
  If ($watchings{$i}=1)
    Calendar REMOVE FROM WATCH($paths{$i})
  End if
End for
```

---

## The callback method

Not a plugin command itself — this is the signature the method you name in `Calendar ADD TO WATCH` must implement. The plugin calls it with two parameters whenever a watched calendar's `.ics` files change.

Parameter | Type | Description
---|---|---
`$1` | TEXT | UUID of the calendar item (event) that changed, including its hyphens (e.g. `1234ABCD-1234-1234-1234-123456789ABC`).
`$2` | LONGINT | Which kind of change occurred: created, updated, or deleted — compared against the constants below.

From the plugin's own sample method (`CALLBACK.4dm`):

```4d
//%attributes = {}
C_TEXT:C284($1; $event)
C_LONGINT:C283($2; $type)

$event:=$1
$type:=$2

Case of 
  : ($type=Calendar Event Create)
    
  : ($type=Calendar Event Update)
    
  : ($type=Calendar Event Delete)
    
End case 
```

`Calendar Event Create`, `Calendar Event Update`, and `Calendar Event Delete` are constants the plugin registers for this comparison — their underlying numeric values aren't defined in the plugin's manifest or source reviewed here, so use these names as shown (your 4D editor should offer them as auto-complete once the plugin is installed) rather than hardcoding a literal number for them.

The method receives no return-value slot to fill and isn't expected to signal anything back to the plugin — treat it as a one-way notification.

---

## Error handling & troubleshooting

- **A calendar you expect is missing from `Calendar GET LIST`.** Only CalDAV (`1`) and Exchange (`5`) calendars are included — a purely local macOS calendar has no `.caldav`/`.exchange` folder and is never returned.
- **`Calendar ADD TO WATCH` seems to do nothing.** Check the `method` name for typos and confirm the method actually exists in your project — an unresolved method name fails silently, with no 4D error.
- **Changing a calendar's callback method doesn't take effect.** `Calendar ADD TO WATCH` on a path that's already watched is a no-op; call `Calendar REMOVE FROM WATCH` on that path first, then re-add it with the new method name.
- **Your callback fires later than expected.** The file-system watcher batches changes with roughly a 1-second latency by design — this isn't an error, just the expected delay.
- **Results look stale or don't reflect a very recent Calendar.app change.** The plugin reads Calendar.app's own local cache rather than the live application state; if Calendar.app hasn't finished writing its cache yet, `Calendar GET LIST` can briefly lag behind what you see on screen.
- **No macOS "Calendar access" permission dialog ever appears.** That's expected — this plugin doesn't use EventKit, so it never triggers that prompt. It also means it can't be used to establish calendar permission for other, EventKit-based parts of your application.

---

## Quick reference

```4d
ARRAY TEXT($uids; 0)
ARRAY TEXT($paths; 0)
ARRAY TEXT($titles; 0)
ARRAY LONGINT($types; 0)
ARRAY LONGINT($watchings; 0)

Calendar GET LIST($uids; $paths; $titles; $types; $watchings)

For ($i; 1; Size of array($paths))
  Calendar ADD TO WATCH($paths{$i}; "CALLBACK")
End for

// ... later, to stop watching one of them:
Calendar REMOVE FROM WATCH($paths{1})
```

```4d
//CALLBACK
C_TEXT($1; $event)
C_LONGINT($2; $type)

Case of 
  : ($2=Calendar Event Create)
  : ($2=Calendar Event Update)
  : ($2=Calendar Event Delete)
End case 
```
