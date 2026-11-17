Scriptname SSM_Leash Hidden

; Wrist cuffs only. The leash lives in SSM_LeashAlias so a missing Leash.esm
; does not stop this script, or the quest that calls it, from loading.

; Cuffs only. The standing bound idle stops a walking package, so the march uses this
; and BindWrists plays that idle after the jail MoveTo.
Function EquipCuffs(Actor who) Global
	If who == None || who.IsChild()
		Return
	EndIf
	Armor cuffs = Game.GetFormFromFile(0x0010E039, "Skyrim.esm") as Armor
	Wear(who, cuffs)
EndFunction

; Puts one silent copy on the actor if missing, then equips it so it cannot be taken off.
Function Wear(Actor who, Armor item) Global
	If who == None || item == None
		Return
	EndIf
	If who.GetItemCount(item) < 1
		who.AddItem(item, 1, true)
	EndIf
	who.EquipItem(item, true, true)
EndFunction

; Takes the item off and removes one copy, if the actor has it.
Function Strip(Actor who, Armor item) Global
	If who == None || item == None
		Return
	EndIf
	If who.GetItemCount(item) > 0
		who.UnequipItem(item, false, true)
		who.RemoveItem(item, 1, true)
	EndIf
EndFunction

Function BindWrists(Actor who) Global
	If who == None || who.IsChild()
		Return
	EndIf
	EquipCuffs(who)
	Idle boundIdle = Game.GetFormFromFile(0x00109837, "Skyrim.esm") as Idle
	Bool played = false
	If boundIdle != None
		played = who.PlayIdle(boundIdle)
	EndIf
	If !played
		Debug.SendAnimationEvent(who, "OffsetBoundStandingPlayerInstant")
	EndIf
EndFunction

Function ClearWrists(Actor who) Global
	If who == None
		Return
	EndIf
	Idle cutIdle = Game.GetFormFromFile(0x00109B6A, "Skyrim.esm") as Idle
	Bool played = false
	If cutIdle != None
		played = who.PlayIdle(cutIdle)
	EndIf
	If !played
		Debug.SendAnimationEvent(who, "BoundStandingCut")
	EndIf
	Armor cuffs = Game.GetFormFromFile(0x0010E039, "Skyrim.esm") as Armor
	Strip(who, cuffs)
	who.SetRestrained(false)
EndFunction
