Scriptname SSM_LeashRelease extends ReferenceAlias

; Optional. Names SeverActions_Kidnap and SeverActionsNativeExt, so it loads only when SeverActions
; is installed. SSM_Malice never names this script. It only sends SSM_MaliceRelease.
; strArg "captive": sent once per case, when she is placed in jail and the jail hold package has
; started. If she is a bound SeverActions captive, the jailer frees her through ReleaseCaptive:
; its leash and the follow package that pulls her go with it. The wrist chain of
; SkyrimNet_Leashed is not touched here.

Event OnInit()
	RegisterForModEvent("SSM_MaliceRelease", "OnMaliceRelease")
EndEvent

Event OnPlayerLoadGame()
	RegisterForModEvent("SSM_MaliceRelease", "OnMaliceRelease")
EndEvent

Event OnMaliceRelease(String eventName, String strArg, Float numArg, Form sender)
	If strArg != "captive"
		Return
	EndIf
	If !Game.IsPluginInstalled("SeverActions.esp")
		Return
	EndIf
	SSM_Malice q = GetOwningQuest() as SSM_Malice
	If q == None
		Return
	EndIf
	Actor victim = q.VictimActor()
	If victim == None || victim.IsDead() || victim.IsChild()
		Return
	EndIf
	; 0 not a captive, 1 only approached (no bonds yet); 2 and above are bound
	If SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) < 2
		Return
	EndIf
	; the one who frees her: the jailer. ReleaseCaptive refuses a bound captive as the freer.
	Actor freer = q.JailerActor()
	If freer == None || freer == victim || freer.IsDead() || freer.IsChild()
		Debug.Trace("[SSM_LeashRelease] no jailer to free " + victim.GetDisplayName() + "; not released")
		Return
	EndIf
	If SeverActionsNativeExt.Native_Kidnap_GetPhase(freer) >= 2
		Debug.Trace("[SSM_LeashRelease] the jailer is a bound captive himself; not released")
		Return
	EndIf
	String name = victim.GetDisplayName()
	If !ResolvesTo(victim, name)
		Debug.Trace("[SSM_LeashRelease] the name " + name + " would free another captive first; not released")
		Return
	EndIf
	SeverActions_Kidnap kidnap = (Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest) as SeverActions_Kidnap
	If kidnap == None
		Return
	EndIf
	kidnap.ReleaseCaptive(freer, name)
EndEvent

; ReleaseCaptive picks the first active captive whose name contains the given text.
; True only if that first match is her, so no other captive is freed by a shared name.
Bool Function ResolvesTo(Actor victim, String name)
	Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
	If victims == None || victims.Length == 0
		Return false
	EndIf
	Int i = 0
	While i < victims.Length
		If victims[i] != None && StringUtil.Find(victims[i].GetDisplayName(), name) >= 0
			Return victims[i] == victim
		EndIf
		i += 1
	EndWhile
	Return false
EndFunction
