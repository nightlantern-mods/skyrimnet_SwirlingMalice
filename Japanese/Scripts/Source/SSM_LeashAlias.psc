Scriptname SSM_LeashAlias extends ReferenceAlias

; Optional. This script names LeashFramework, so it does not load when Leash.esm
; is absent. SSM_Malice never names this script. It only sends SSM_MaliceLeash.
; strArg "apply": leash the victim to the guard, retried once on the next update.
; strArg "hold": she is in jail; every second, any leash on her is taken off. Never applied.
; strArg "clear": take the leash off and stop the hold watch.
Bool pending = false
Bool holding = false

Event OnInit()
	RegisterForModEvent("SSM_MaliceLeash", "OnLeash")
EndEvent

Event OnPlayerLoadGame()
	RegisterForModEvent("SSM_MaliceLeash", "OnLeash")
EndEvent

Event OnLeash(String eventName, String strArg, Float numArg, Form sender)
	SSM_Malice q = GetOwningQuest() as SSM_Malice
	If q == None
		Return
	EndIf
	Actor victim = q.VictimActor()
	If strArg == "clear"
		holding = false
		pending = false
		ClearLeash(victim)
		Return
	EndIf
	If strArg == "hold"
		pending = false
		holding = true
		RegisterForSingleUpdate(1.0)
		Return
	EndIf
	Actor holder = q.GuardActor()
	If !TryLeash(holder, victim)
		pending = true
		RegisterForSingleUpdate(1.0)
	EndIf
EndEvent

Event OnUpdate()
	If holding
		; registered first, so a failing check below cannot end the watch
		RegisterForSingleUpdate(1.0)
		SSM_Malice hq = GetOwningQuest() as SSM_Malice
		If hq == None
			Return
		EndIf
		Actor held = hq.VictimActor()
		If held != None && !held.IsChild() && Game.IsPluginInstalled("Leash.esm")
			If LeashFramework.IsLeashed(held)
				ClearLeash(held)
			EndIf
		EndIf
		Return
	EndIf
	If !pending
		Return
	EndIf
	pending = false
	SSM_Malice q = GetOwningQuest() as SSM_Malice
	If q == None
		Return
	EndIf
	TryLeash(q.GuardActor(), q.VictimActor())
EndEvent

Bool Function TryLeash(Actor holder, Actor leashed)
	If holder == None || leashed == None
		Return false
	EndIf
	If holder.IsChild() || leashed.IsChild()
		Return false
	EndIf
	If !Game.IsPluginInstalled("Leash.esm")
		Return false
	EndIf
	Armor collar = Game.GetFormFromFile(0x00000D69, "Leash.esm") as Armor
	If collar != None
		If leashed.GetItemCount(collar) < 1
			leashed.AddItem(collar, 1, true)
		EndIf
		leashed.EquipItem(collar, true, true)
	EndIf
	Return LeashFramework.ApplyLeash(holder, leashed, "NPC Spine2 [Spn2]", "Leash1", 90.0, 220.0, true)
EndFunction

Function ClearLeash(Actor leashed)
	If leashed == None
		Return
	EndIf
	If Game.IsPluginInstalled("Leash.esm")
		LeashFramework.UnleashAll(leashed)
		Armor collar = Game.GetFormFromFile(0x00000D69, "Leash.esm") as Armor
		If collar != None && leashed.GetItemCount(collar) > 0
			leashed.UnequipItem(collar, false, true)
			leashed.RemoveItem(collar, 1, true)
		EndIf
	EndIf
EndFunction
