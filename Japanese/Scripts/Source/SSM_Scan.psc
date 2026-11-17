Scriptname SSM_Scan Hidden

Bool Function CellHasChild(Actor[] scanned) Global
	If scanned == None
		Return false
	EndIf
	Int i = 0
	While i < scanned.Length
		Actor a = scanned[i]
		If a != None
			If a.IsChild()
				Return true
			EndIf
		EndIf
		i += 1
	EndWhile
	Return false
EndFunction

Int Function CollectAdults(Actor[] scanned, Actor player, Actor[] adultsOut, Keyword npcType) Global
	If scanned == None || adultsOut == None || npcType == None
		Return 0
	EndIf
	Int count = 0
	Int cap = adultsOut.Length
	Int i = 0
	While i < scanned.Length
		Actor a = scanned[i]
		If a != None && a != player
			If !a.IsDead() && !a.IsDisabled() && !a.IsDeleted() && !a.IsChild()
				If a.HasKeyword(npcType)
					If count >= cap
						Return -1
					EndIf
					adultsOut[count] = a
					count += 1
				EndIf
			EndIf
		EndIf
		i += 1
	EndWhile
	Return count
EndFunction

Bool Function ActorReady(Actor who) Global
	If who == None
		Return false
	EndIf
	If who.IsDead() || who.IsDisabled() || who.IsDeleted()
		Return false
	EndIf
	If who.IsChild() || who.IsBleedingOut()
		Return false
	EndIf
	Return true
EndFunction
