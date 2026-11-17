Scriptname SSM_Slot extends Quest

SSM_Main Property Main Auto
GlobalVariable Property OwnedCount Auto

Int phase = 0
Int speechKind = 0
Int sceneKind = 0
Int threadId = -1
Bool threadIsOStim = false
Actor sceneVictim = None
Float speechStart = 0.0
Bool speechHeard = false
Bool speechPlaying = false
Bool speechEnded = false
Float sceneStart = 0.0
Float retryAt = 0.0
Float nextRepeatAt = 0.0
Actor pinned = None
Int emptyTicks = 0

; This dominant's slaves live in a PapyrusUtil StorageUtil FormList owned by this quest,
; so each of the five dominant quests keeps its own list. No Actor[] member is used:
; on a save that already started the quest, a member array could not be created.

; ---------------------------------------------------------------- init / audio

Event OnInit()
	RegisterAudio()
EndEvent

Function RegisterAudio()
	UnregisterForModEvent("SkyrimNet_AudioStarted")
	UnregisterForModEvent("SkyrimNet_AudioEnded")
	RegisterForModEvent("SkyrimNet_AudioStarted", "OnAudioStarted")
	RegisterForModEvent("SkyrimNet_AudioEnded", "OnAudioEnded")
EndFunction

; Called by Main after a game load. Does not reset phase.
; Real-time values do not survive a restart of the game, so they are rebased here.
Function Resume()
	RegisterAudio()
	Float now = Utility.GetCurrentRealTime()
	speechStart = now
	sceneStart = now
	retryAt = now + 5.0
	nextRepeatAt = now + Main.IntervalSeconds()
	If phase == 1
		RegisterForSingleUpdate(1.0)
	ElseIf phase == 2
		RegisterForSingleUpdate(2.0)
	EndIf
EndFunction

Event OnAudioStarted(String eventName, String strArg, Float numArg, Form sender)
	If phase != 1
		Return
	EndIf
	Actor dom = Dominant()
	If dom == None
		Return
	EndIf
	Actor who = sender as Actor
	If who != dom
		Return
	EndIf
	speechHeard = true
	speechPlaying = true
EndEvent

Event OnAudioEnded(String eventName, String strArg, Float numArg, Form sender)
	If phase != 1
		Return
	EndIf
	Actor dom = Dominant()
	If dom == None
		Return
	EndIf
	Actor who = sender as Actor
	If who != dom
		Return
	EndIf
	If !speechHeard
		Return
	EndIf
	speechPlaying = false
	speechEnded = true
EndEvent

; ---------------------------------------------------------------- slave list (StorageUtil)

String Function SlaveKey()
	Return "SSM_Slaves"
EndFunction

; Number of entries in this quest's list, including any that no longer resolve.
Int Function SlaveEntries()
	Return StorageUtil.FormListCount(self, SlaveKey())
EndFunction

Actor Function SlaveAt(Int index)
	Return StorageUtil.FormListGet(self, SlaveKey(), index) as Actor
EndFunction

Function ClearSlaves()
	StorageUtil.FormListClear(self, SlaveKey())
EndFunction

; ---------------------------------------------------------------- public reads

Actor Function Dominant()
	ReferenceAlias a = GetAlias(0) as ReferenceAlias
	If a == None
		Return None
	EndIf
	Return a.GetActorReference()
EndFunction

Actor Function Pinned()
	Return pinned
EndFunction

Bool Function Busy()
	Return phase == 1 || phase == 2
EndFunction

Bool Function HasSlave(Actor who)
	If who == None
		Return false
	EndIf
	Return StorageUtil.FormListHas(self, SlaveKey(), who)
EndFunction

; The number of people stored for this dominant (entries that still resolve to an actor).
Int Function SlaveTotal()
	Int total = 0
	Int n = SlaveEntries()
	Int i = 0
	While i < n
		If SlaveAt(i) != None
			total += 1
		EndIf
		i += 1
	EndWhile
	Return total
EndFunction

; The display names of this slot's slaves, comma separated; "" when there are none.
String Function SlaveNames()
	String result = ""
	Int n = SlaveEntries()
	Int i = 0
	While i < n
		Actor a = SlaveAt(i)
		If a != None
			If result != ""
				result = result + ", "
			EndIf
			result = result + a.GetDisplayName()
		EndIf
		i += 1
	EndWhile
	Return result
EndFunction

; ---------------------------------------------------------------- lifecycle

Function Arm()
	ClearSlaves()
	phase = 0
	speechKind = 0
	sceneKind = 0
	threadId = -1
	threadIsOStim = false
	sceneVictim = None
	speechStart = 0.0
	speechHeard = false
	speechPlaying = false
	speechEnded = false
	sceneStart = 0.0
	retryAt = 0.0
	nextRepeatAt = 0.0
	If OwnedCount != None
		OwnedCount.SetValue(0.0)
	EndIf
	SetObjectiveDisplayed(10, true)
	SetActive(true)
EndFunction

Function Pin(Actor who)
	pinned = who
	emptyTicks = 0
EndFunction

Function Repair()
	Actor dom = Dominant()
	If dom != None
		If pinned == None
			pinned = dom
		EndIf
		emptyTicks = 0
		Return
	EndIf
	If pinned == None
		Return
	EndIf
	If !SSM_Scan.ActorReady(pinned)
		Return
	EndIf
	If Main.PinnedElsewhere(self, pinned)
		Return
	EndIf
	emptyTicks += 1
	If emptyTicks >= 2
		ReferenceAlias a = GetAlias(0) as ReferenceAlias
		If a != None
			a.ForceRefTo(pinned)
		EndIf
		emptyTicks = 0
	EndIf
EndFunction

Function Shutdown()
	UnregisterForUpdate()
	If threadId >= 0
		SSM_Scene.End(threadId, threadIsOStim)
	EndIf
	ClearSlaves()
	phase = 0
	speechKind = 0
	sceneKind = 0
	threadId = -1
	threadIsOStim = false
	sceneVictim = None
	speechHeard = false
	speechPlaying = false
	speechEnded = false
	retryAt = 0.0
	nextRepeatAt = 0.0
	If OwnedCount != None
		OwnedCount.SetValue(0.0)
	EndIf
	Int obj = 10
	While obj <= 30
		SetObjectiveCompleted(obj, false)
		SetObjectiveDisplayed(obj, false)
		obj += 10
	EndWhile
	SetActive(false)
	ReferenceAlias a = GetAlias(0) as ReferenceAlias
	If a != None
		a.Clear()
	EndIf
	pinned = None
	emptyTicks = 0
	Main.Release(self)
EndFunction

; ---------------------------------------------------------------- list helpers

Bool Function IsListed(Actor[] adults, Int count, Actor who)
	If who == None || adults == None
		Return false
	EndIf
	Int i = 0
	While i < count && i < adults.Length
		If adults[i] == who
			Return true
		EndIf
		i += 1
	EndWhile
	Return false
EndFunction

Bool Function GroupIsOwned(Actor[] adults, Int count, Actor dom)
	If !IsListed(adults, count, dom)
		Return false
	EndIf
	Int i = 0
	While i < count && i < adults.Length
		Actor a = adults[i]
		If a != None && a != dom
			If !HasSlave(a)
				Return false
			EndIf
		EndIf
		i += 1
	EndWhile
	Return true
EndFunction

; The one adult here who is neither the dominant nor one of this slot's slaves.
; None when there is no such adult, or more than one.
Actor Function Stranger(Actor[] adults, Int count, Actor dom)
	If dom == None || adults == None
		Return None
	EndIf
	Actor found = None
	Int strangers = 0
	Int i = 0
	While i < count && i < adults.Length
		Actor a = adults[i]
		If a != None && a != dom && !HasSlave(a)
			found = a
			strangers += 1
		EndIf
		i += 1
	EndWhile
	If strangers == 1
		Return found
	EndIf
	Return None
EndFunction

Actor Function PickVictim(Actor[] adults, Int count)
	Actor[] pool = new Actor[11]
	Int n = 0
	Actor player = Game.GetPlayer()
	If player != None && !player.IsDead()
		pool[n] = player
		n += 1
	EndIf
	Int entries = SlaveEntries()
	Int i = 0
	While i < entries && n < pool.Length
		Actor s = SlaveAt(i)
		If s != None && s != player && !s.IsChild()
			If IsListed(adults, count, s) && SSM_Scan.ActorReady(s)
				pool[n] = s
				n += 1
			EndIf
		EndIf
		i += 1
	EndWhile
	If n == 0
		Return None
	EndIf
	Return pool[Utility.RandomInt(0, n - 1)]
EndFunction

; Indoors, not crowded, the dominant present, and exactly one adult who is not already
; this dominant's slave; everyone else present is this dominant's slave.
Bool Function LureOk(Actor[] adults, Int count, Bool interior, Bool crowded, Actor dom)
	If !interior || crowded
		Return false
	EndIf
	If !IsListed(adults, count, dom)
		Return false
	EndIf
	If SlaveTotal() >= 10
		Return false
	EndIf
	If IsObjectiveCompleted(30)
		Return false
	EndIf
	Actor other = Stranger(adults, count, dom)
	If other == None
		Return false
	EndIf
	If Main.IsSlaveOfAnyone(other) || Main.IsDominant(other)
		Return false
	EndIf
	Return true
EndFunction

; Records one person as this dominant's slave. Recording someone already recorded
; does nothing, so the count rises once per person.
Bool Function Remember(Actor who)
	If who == None || who == Game.GetPlayer()
		Main.Note("slot: nobody to record as a slave")
		Return false
	EndIf
	If who.IsChild()
		Main.Note("slot: a child is never recorded")
		Return false
	EndIf
	If HasSlave(who)
		Main.Note("slot: " + who.GetDisplayName() + " is already recorded; the count is not raised again")
		Return false
	EndIf
	Int before = SlaveTotal()
	If before >= 10
		Main.Note("slot: " + who.GetDisplayName() + " not recorded, this dominant already has 10")
		Return false
	EndIf
	Int idx = StorageUtil.FormListAdd(self, SlaveKey(), who, false)
	If idx < 0 || !HasSlave(who)
		Main.Note("slot: " + who.GetDisplayName() + " not recorded, the slave list cannot be used")
		Return false
	EndIf
	Int after = SlaveTotal()
	If after <= before
		Main.Note("slot: " + who.GetDisplayName() + " not recorded, the slave list cannot be used (count did not rise)")
		Return false
	EndIf
	If OwnedCount != None
		ModObjectiveGlobal(1.0, OwnedCount, 30, 10.0, true, true, true)
	Else
		Main.Note("slot: OwnedCount is not filled; the journal count cannot move")
	EndIf
	Main.Note("slot: " + who.GetDisplayName() + " recorded as a slave, " + after + "/10")
	Return true
EndFunction

; Direct scan right before a decisive step (speech, scene, journal).
Bool Function ChildInCell()
	Actor player = Game.GetPlayer()
	If player == None
		Return true
	EndIf
	Actor[] found = MiscUtil.ScanCellNPCs(player, 0.0, None, true)
	Return SSM_Scan.CellHasChild(found)
EndFunction

; ---------------------------------------------------------------- decisions

Function Consider(Actor[] adults, Int count, Bool interior, Bool crowded)
	If phase == 1 || phase == 2
		Return
	EndIf
	Actor dom = Dominant()
	Actor player = Game.GetPlayer()
	Float now = Utility.GetCurrentRealTime()
	Bool listed = IsListed(adults, count, dom)
	Bool alone = (count == 1) && !crowded && listed
	Bool owned = (!crowded) && GroupIsOwned(adults, count, dom)
	Bool lure = LureOk(adults, count, interior, crowded, dom)
	; Main never calls Consider while a child is in the cell, so childHere is false here.
	Int act = SSM_Flow.TickAction(phase, count, listed, alone, interior, crowded, owned, lure, false, now, retryAt, nextRepeatAt)
	If act == 0
		Return
	EndIf

	If act == 11
		StartSpeech(1, dom, player, "")
	ElseIf act == 12
		StartSpeech(2, dom, player, "")
	ElseIf act == 13
		Actor v = PickVictim(adults, count)
		If v != None
			StartSpeech(3, dom, v, v.GetDisplayName())
		EndIf
	ElseIf act == 14
		Actor other = Stranger(adults, count, dom)
		If other != None
			StartSpeech(4, dom, other, other.GetDisplayName())
		EndIf
	ElseIf act == 50
		Remember(sceneVictim)
		sceneVictim = None
		phase = 4
	ElseIf act == 60
		FinishOpening()
	EndIf
EndFunction

; ---------------------------------------------------------------- speech

Function StartSpeech(Int lineId, Actor dom, Actor victim, String victimName)
	Float now = Utility.GetCurrentRealTime()
	If !Main.TryClaim(self)
		Return
	EndIf
	If !Main.FrameworkReady()
		Main.WarnFramework()
		retryAt = now + 30.0
		Main.Release(self)
		Return
	EndIf
	If ChildInCell()
		Main.Release(self)
		Return
	EndIf
	Actor player = Game.GetPlayer()
	If victim == None || !SSM_Scan.ActorReady(dom) || !SSM_Scan.ActorReady(player)
		Main.Release(self)
		Return
	EndIf
	If lineId == 3 || lineId == 4
		If victim.IsChild() || !SSM_Scan.ActorReady(victim)
			Main.Release(self)
			Return
		EndIf
	EndIf
	Bool useOStim = Main.UseOStim()
	If SSM_Scene.ActorBusy(dom, useOStim) || SSM_Scene.ActorBusy(victim, useOStim)
		Main.Note("slot: line " + lineId + " waits, someone is already in a scene")
		retryAt = now + 15.0
		Main.Release(self)
		Return
	EndIf

	Int code = SSM_Speech.Send(lineId, dom, player, victimName)
	If code != 0
		FailSpeech(lineId, "SkyrimNet refused the narration")
		Return
	EndIf

	Main.Note("slot: line " + lineId + " sent, victim " + victim.GetDisplayName())
	speechKind = lineId
	sceneVictim = victim
	speechStart = now
	speechHeard = false
	speechPlaying = false
	speechEnded = false
	phase = 1
	RegisterForSingleUpdate(1.0)
EndFunction

Function FailSpeech(Int lineId, String why)
	Main.Note("slot: line " + lineId + " failed: " + why)
	phase = SSM_Flow.PhaseAfterSpeechFailure(lineId)
	speechKind = 0
	speechHeard = false
	speechPlaying = false
	speechEnded = false
	sceneVictim = None
	retryAt = Utility.GetCurrentRealTime() + 30.0
	Main.Release(self)
EndFunction

Function PollSpeech()
	If Dominant() == None
		FailSpeech(speechKind, "the dominant alias is empty")
		Return
	EndIf
	Float elapsed = Utility.GetCurrentRealTime() - speechStart
	If speechEnded
		SpeechDone()
		Return
	EndIf
	If !speechHeard && elapsed > 20.0
		FailSpeech(speechKind, "no audio from the dominant within 20 seconds")
		Return
	EndIf
	If elapsed > 60.0
		FailSpeech(speechKind, "the audio did not end within 60 seconds")
		Return
	EndIf
	RegisterForSingleUpdate(1.0)
EndFunction

Function SpeechDone()
	Int lineId = speechKind
	Bool childHere = ChildInCell()
	Int nextStep = SSM_Flow.AfterSpeech(lineId, childHere)
	speechKind = 0
	speechHeard = false
	speechPlaying = false
	speechEnded = false
	If nextStep == 6
		phase = 6
		Main.Release(self)
	ElseIf nextStep == 4
		FinishOpening()
	ElseIf nextStep >= 21 && nextStep <= 23
		StartScene(nextStep - 20)
	Else
		FailSpeech(lineId, "no next step after the line")
	EndIf
EndFunction

Function FinishOpening()
	If ChildInCell()
		; no journal update while a child is present
		phase = 6
		Main.Release(self)
		Return
	EndIf
	If !IsObjectiveCompleted(10)
		SetObjectiveCompleted(10, true)
	EndIf
	SetObjectiveDisplayed(20, true)
	SetObjectiveDisplayed(30, true)
	phase = 4
	nextRepeatAt = Utility.GetCurrentRealTime() + Main.IntervalSeconds()
	Main.Release(self)
EndFunction

; ---------------------------------------------------------------- scene

Function StartScene(Int profile)
	Actor dom = Dominant()
	Actor victim = None
	If profile == 1
		victim = Game.GetPlayer()
	Else
		victim = sceneVictim
	EndIf
	If dom == None || victim == None
		FailScene(profile, "the dominant or the victim is missing")
		Return
	EndIf
	If ChildInCell()
		FailScene(profile, "a child is in the cell")
		Return
	EndIf
	If !SSM_Scan.ActorReady(dom) || !SSM_Scan.ActorReady(victim)
		FailScene(profile, "the dominant or the victim is not ready")
		Return
	EndIf
	If dom.IsChild() || victim.IsChild()
		FailScene(profile, "a child")
		Return
	EndIf
	If !dom.Is3DLoaded() || !victim.Is3DLoaded()
		FailScene(profile, "the dominant or the victim is not loaded")
		Return
	EndIf
	If !Main.FrameworkReady()
		Main.WarnFramework()
		FailScene(profile, "the scene framework is missing")
		Return
	EndIf
	Bool useOStim = Main.UseOStim()
	Int tid = SSM_Scene.Begin(profile, dom, victim, useOStim)
	If tid < 0
		FailScene(profile, "the framework did not start the scene")
		Return
	EndIf
	Main.Note("slot: scene " + profile + " started with " + victim.GetDisplayName())
	sceneKind = profile
	threadId = tid
	threadIsOStim = useOStim
	sceneVictim = victim
	sceneStart = Utility.GetCurrentRealTime()
	phase = 2
	; Only the recruitment scene adds a new person. It counts once the scene has started;
	; the end-of-scene record and the delayed record stay as the fallback.
	If profile == 3
		If ChildInCell()
			Main.Note("slot: a child is here as scene 3 starts; the slave is recorded later")
		Else
			Remember(victim)
		EndIf
	EndIf
	RegisterForSingleUpdate(2.0)
EndFunction

Function FailScene(Int profile, String why)
	Main.Note("slot: scene " + profile + " failed: " + why)
	phase = SSM_Flow.PhaseAfterSceneFailure(profile)
	sceneKind = 0
	threadId = -1
	sceneVictim = None
	retryAt = Utility.GetCurrentRealTime() + 30.0
	Main.Release(self)
EndFunction

Function PollScene()
	Bool running = false
	If threadId >= 0
		running = SSM_Scene.Running(threadId, threadIsOStim)
	EndIf
	If running
		If Utility.GetCurrentRealTime() - sceneStart >= 180.0
			SSM_Scene.End(threadId, threadIsOStim)
		Else
			RegisterForSingleUpdate(2.0)
			Return
		EndIf
	EndIf
	EndScene()
EndFunction

Function EndScene()
	Int profile = sceneKind
	Bool childHere = ChildInCell()
	Int nextStep = SSM_Flow.AfterScene(profile, childHere)
	sceneKind = 0
	threadId = -1
	threadIsOStim = false
	If nextStep == 3
		sceneVictim = None
		phase = 3
		; the claim is still held by this slot, so TryClaim succeeds again
		StartSpeech(2, Dominant(), Game.GetPlayer(), "")
	ElseIf nextStep == 5
		Main.Note("slot: a child is here; the slave is recorded once no child is present")
		phase = 5
		Main.Release(self)
	ElseIf nextStep == 7
		Remember(sceneVictim)
		sceneVictim = None
		phase = 4
		Main.Release(self)
	Else
		sceneVictim = None
		phase = 4
		If profile == 2
			nextRepeatAt = Utility.GetCurrentRealTime() + Main.IntervalSeconds()
		EndIf
		Main.Release(self)
	EndIf
EndFunction

Event OnUpdate()
	If phase == 1
		PollSpeech()
	ElseIf phase == 2
		PollScene()
	EndIf
EndEvent
