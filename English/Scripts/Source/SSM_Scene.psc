Scriptname SSM_Scene Hidden

; Returns a thread id (0 is valid) or -1 on failure.
Int Function Begin(Int sceneId, Actor dominant, Actor victim, Bool useOStim) Global
	If dominant == None || victim == None
		Return -1
	EndIf
	If dominant.IsChild() || victim.IsChild()
		Return -1
	EndIf

	Actor[] positions = new Actor[2]
	positions[0] = dominant
	positions[1] = victim

	; just before the scene: the closest free furniture of any type OStim follows, close to the victim
	ObjectReference nearSpot = NearFurniture(victim)

	If useOStim
		Int builderId = OThreadBuilder.Create(positions)
		If builderId < 0
			Return -1
		EndIf
		OThreadBuilder.SetDuration(builderId, 120.0)
		OThreadBuilder.UndressActors(builderId)
		If nearSpot != None
			; the closest furniture found: the scene starts on it. NoFurniture is not needed then.
			OThreadBuilder.SetFurniture(builderId, nearSpot)
		Else
			; nothing close: no furniture search, so it plays where they stand in the cell
			OThreadBuilder.NoFurniture(builderId)
		EndIf
		Int startedId = OThreadBuilder.Start(builderId)
		If startedId < 0
			Return -1
		EndIf
		Return startedId
	EndIf

	SexLabFramework sl = SexLabUtil.GetAPI() as SexLabFramework
	If sl == None
		Return -1
	EndIf
	String tags = SSM_Lines.SceneTags(sceneId)
	SexLabThread started = None
	If nearSpot != None
		; centred on the furniture found, furniture preferred (aiFurniture 2)
		started = sl.StartScene(positions, tags, victim, nearSpot, 2, "")
	EndIf
	If started == None
		; centred on the victim, no furniture (aiFurniture 0): nothing found, or no scene fits it
		started = sl.StartScene(positions, tags, victim, victim, 0, "")
	EndIf
	If started == None
		Return -1
	EndIf
	Return started.GetThreadID()
EndFunction

; OStim's own search: every furniture type OStim follows that has animations for two actors and is
; not occupied or reserved, within 150 units of the victim and 96 units up or down (the band
; OStim's FindBed passes). The array is sorted by distance; the first is the closest.
; None if nothing is found, or if OStim is not installed.
ObjectReference Function NearFurniture(Actor victim) Global
	If victim == None
		Return None
	EndIf
	ObjectReference[] found = OFurniture.FindFurniture(2, victim, 150.0, 96.0)
	If found == None || found.Length < 1
		Return None
	EndIf
	Return found[0]
EndFunction

Bool Function Running(Int threadId, Bool useOStim) Global
	If threadId < 0
		Return false
	EndIf
	If useOStim
		Return OThread.IsRunning(threadId)
	EndIf
	SexLabFramework sl = SexLabUtil.GetAPI() as SexLabFramework
	If sl == None
		Return false
	EndIf
	; NOTE: GetThread is the only call outside the list in the spec; see notes.
	SexLabThread t = sl.GetThread(threadId)
	If t == None
		Return false
	EndIf
	Int st = t.GetStatus()
	; 2 = STATUS_SETUP, 3 = STATUS_INSCENE
	Return st == 2 || st == 3
EndFunction

Function End(Int threadId, Bool useOStim) Global
	If threadId < 0
		Return
	EndIf
	If useOStim
		If OThread.IsRunning(threadId)
			OThread.Stop(threadId)
		EndIf
		Return
	EndIf
	SexLabFramework sl = SexLabUtil.GetAPI() as SexLabFramework
	If sl == None
		Return
	EndIf
	SexLabThread t = sl.GetThread(threadId)
	If t != None
		t.StopAnimation()
	EndIf
EndFunction

Bool Function ActorBusy(Actor who, Bool useOStim) Global
	If who == None
		Return false
	EndIf
	If useOStim
		Return OActor.IsInOStim(who)
	EndIf
	SexLabFramework sl = SexLabUtil.GetAPI() as SexLabFramework
	If sl == None
		Return false
	EndIf
	Return sl.IsActorActive(who)
EndFunction
