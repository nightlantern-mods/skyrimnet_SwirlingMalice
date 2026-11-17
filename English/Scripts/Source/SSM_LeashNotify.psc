Scriptname SSM_LeashNotify extends ReferenceAlias

; Optional. Names SkyrimNet_Leashed_Native and LeashFramework, so it loads only when both exist.
; SSM_Malice never names this script.
Bool pending = false

Event OnInit()
	RegisterForModEvent("SSM_MaliceLeash", "OnLeash")
EndEvent

Event OnPlayerLoadGame()
	RegisterForModEvent("SSM_MaliceLeash", "OnLeash")
EndEvent

Event OnLeash(String eventName, String strArg, Float numArg, Form sender)
	If !Game.IsPluginInstalled("SkyrimNet_Leashed.esp")
		Return
	EndIf
	SSM_Malice q = GetOwningQuest() as SSM_Malice
	If q == None
		Return
	EndIf
	Actor victim = q.VictimActor()
	If victim == None || victim.IsChild()
		Return
	EndIf
	If strArg == "clear"
		pending = false
		SkyrimNet_Leashed_Native.NotifyUnleash(victim)
		Return
	EndIf
	pending = true
	RegisterForSingleUpdate(1.5)
EndEvent

Event OnUpdate()
	If !pending
		Return
	EndIf
	pending = false
	If !Game.IsPluginInstalled("Leash.esm") || !Game.IsPluginInstalled("SkyrimNet_Leashed.esp")
		Return
	EndIf
	SSM_Malice q = GetOwningQuest() as SSM_Malice
	If q == None
		Return
	EndIf
	Actor victim = q.VictimActor()
	Actor holder = q.GuardActor()
	If victim == None || holder == None
		Return
	EndIf
	If victim.IsChild() || holder.IsChild()
		Return
	EndIf
	If LeashFramework.IsLeashed(victim)
		SkyrimNet_Leashed_Native.NotifyLeash(holder, victim, "chain", "short", "wrists", false)
	EndIf
EndEvent
