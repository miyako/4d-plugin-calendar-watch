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