Scriptname SSM_Malice extends Quest

SSM_Main Property Main Auto
Actor Property Punisher Auto
ObjectReference Property ReturnSpot Auto
ObjectReference Property HoldingSpot Auto
ObjectReference Property JailWhiterun Auto
ObjectReference Property JailSolitude Auto
ObjectReference Property JailWindhelm Auto
ObjectReference Property JailRiften Auto
ObjectReference Property JailMarkarth Auto
ObjectReference Property JailFalkreath Auto
ObjectReference Property JailMorthal Auto
ObjectReference Property JailDawnstar Auto
ObjectReference Property JailWinterhold Auto
Location Property LocWhiterun Auto
Location Property LocSolitude Auto
Location Property LocWindhelm Auto
Location Property LocRiften Auto
Location Property LocMarkarth Auto
Location Property LocFalkreath Auto
Location Property LocMorthal Auto
Location Property LocDawnstar Auto
Location Property LocWinterhold Auto
Keyword Property NpcType Auto
GlobalVariable Property Busy Auto
ReferenceAlias Property VictimAlias Auto
ReferenceAlias Property GuardAlias Auto
ReferenceAlias Property MarchVictimAlias Auto
ReferenceAlias Property MarchGuardAlias Auto
ReferenceAlias Property MarchGoalAlias Auto
ObjectReference Property ExtWhiterun Auto
ObjectReference Property ExtSolitude Auto
ObjectReference Property ExtWindhelm Auto
ObjectReference Property ExtRiften Auto
ObjectReference Property ExtMarkarth Auto
ObjectReference Property ExtFalkreath Auto
ObjectReference Property ExtMorthal Auto
ObjectReference Property ExtDawnstar Auto
ObjectReference Property ExtWinterhold Auto

; phase: 0 idle, 1 guard walking to the victim, 2 bind (and fade, only as the fallback),
; 3 move to jail, 4 in jail (waiting), 5 scene running, 6 on-foot march to the exterior jail marker,
; 7 the speaker is remembered; waiting for the Dialogue Menu to close, then the guard scan,
; 8 the jail MoveTo has been issued, and a later tick judges the cell
Int phase = 0
Float releaseAt = 0.0
Float nextSceneAt = 0.0
Float approachDeadline = 0.0
Float fadeDeadline = 0.0
Float marchDeadline = 0.0
Float sceneStart = 0.0
Float lastTick = 0.0
Int threadId = -1
Bool threadIsOStim = false
Bool arrestDone = false
Bool fadedOut = false
Bool punisherPlaced = false
Actor victimRef = None
Actor guardRef = None
; how many guard scans of this search RETURNED with no eligible escort. A scan that dies at the
; None cast in FindGuard runs nothing after it and is never counted.
Int emptyScans = 0
; real time at which the escort search gives up when scans keep dying: 20 seconds after the first
; tick of this search that found the Dialogue Menu closed. 0.0 until that tick.
Float scanDeadline = 0.0
; how many times phase 8 has judged the cell
Int placeChecks = 0
; the victim is held in jail: by the jail hold package (aliases 6 and 7), or, when those aliases
; are missing, by a stopped AI
Bool aiStopped = false
; who stands in the cage: the arresting guard, or the dedicated punisher (jailerIsOwn)
Actor jailerRef = None
Bool jailerIsOwn = false
; the jail marker that matched in phase 8. JailFor is not asked again after that:
; her location can change later, and JailFor would then name another hold's jail.
ObjectReference jailRef = None
; how many times the victim was brought back into the jail cell
Int recaptures = 0
; the captive release was sent for this case. Sent once, at jail placement; never on a
; recapture or before a scene. Cleared when the case ends.
Bool captiveReleaseSent = false
; the one actor this case gave the stick-to-victim offset (KeepPace) to. A new holder clears the
; previous one first; a failed escort search clears it before the case is forgotten.
Actor pacedRef = None
; the escort search set the speaker not to move (SetDontMove). A failed search lets her move again.
Bool victimHeldStill = false
; a scene is being staged: both actors were moved onto jailRef (0,0,0) and set not to move, while
; the jail hold stays on. A later update starts the scene once she is within 128 of the marker.
Bool staging = false
; real time of the first staging move of this attempt
Float stageStart = 0.0
; the 10 second "still far" note was written for this staging
Bool stageFarNoted = false

; ---------------------------------------------------------------- init / resume

Event OnInit()
	; Do not clear a case that a save already stored. A new quest starts at phase 0.
	If phase == 0
		If Busy != None
			Busy.SetValue(0.0)
		EndIf
		UnregisterForUpdate()
	Else
		RegisterForSingleUpdate(1.0)
	EndIf
EndEvent

; Called after a game load. Does not reset phase, releaseAt, the victim or the aliases.
; Thread ids do not survive a load, so a scene that was running counts as ended.
; Real-time values do not survive a restart of the game, so they are rebased here.
; A staging in progress is abandoned: she may move again, and the next scene attempt stages anew.
Function Resume()
	If phase == 0
		UnregisterForUpdate()
		; no case is running: a Busy flag left at 1 would block the frame dialogue for good
		If Busy != None
			Busy.SetValue(0.0)
		EndIf
		Return
	EndIf
	Float now = Utility.GetCurrentRealTime()
	If now < lastTick
		Rebase(now)
	EndIf
	lastTick = now
	; a staging does not survive a load
	AbandonStaging("a load")
	; a save made before the jail marker was stored: ask JailFor once
	If jailRef == None
		jailRef = JailFor(VictimActor())
	EndIf
	; a save made before the jailer was stored: the placed punisher is the jailer
	If jailerRef == None && punisherPlaced
		jailerRef = Punisher
		jailerIsOwn = true
	EndIf
	If phase == 5
		threadId = -1
		threadIsOStim = false
		phase = 4
		nextSceneAt = now + Interval()
		; the scene had released the jail hold; put it back once, as a scene end does
		RestoreAfterScene()
	EndIf
	If aiStopped
		Actor held = VictimActor()
		If held != None && !held.IsDead()
			; the jail hold package, not a frozen AI; a save that froze her is thawed here
			BeginJailHold(held)
		EndIf
	EndIf
	; the leash watch is not running after a load until it hears this again
	If phase == 4 || phase == 5
		SendModEvent("SSM_MaliceLeash", "hold", 0.0)
	EndIf
	RegisterForSingleUpdate(1.0)
EndFunction

; A saved real-time stamp that lies in the future belongs to a previous run of the game.
; Replace it with now. releaseAt is game time and is never touched here.
; The escort search deadline is capped at a fresh 20 seconds instead, so a load does not end
; the search at once.
Function Rebase(Float now)
	If now < approachDeadline
		approachDeadline = now
	EndIf
	If now < fadeDeadline
		fadeDeadline = now
	EndIf
	If now < marchDeadline
		marchDeadline = now
	EndIf
	If now < nextSceneAt
		nextSceneAt = now
	EndIf
	If now < sceneStart
		sceneStart = now
	EndIf
	If now < stageStart
		stageStart = now
	EndIf
	If scanDeadline > now + 20.0
		scanDeadline = now + 20.0
	EndIf
EndFunction

Function ClearState()
	phase = 0
	releaseAt = 0.0
	nextSceneAt = 0.0
	approachDeadline = 0.0
	fadeDeadline = 0.0
	marchDeadline = 0.0
	sceneStart = 0.0
	threadId = -1
	threadIsOStim = false
	arrestDone = false
	fadedOut = false
	punisherPlaced = false
	victimRef = None
	guardRef = None
	emptyScans = 0
	scanDeadline = 0.0
	placeChecks = 0
	aiStopped = false
	jailerRef = None
	jailerIsOwn = false
	jailRef = None
	recaptures = 0
	captiveReleaseSent = false
	pacedRef = None
	victimHeldStill = false
	staging = false
	stageStart = 0.0
	stageFarNoted = false
EndFunction

; ---------------------------------------------------------------- helpers

Function Note(String text)
	If Main != None
		Main.Note(text)
	EndIf
EndFunction

Float Function Interval()
	If Main == None
		Return 0.0
	EndIf
	Return Main.MaliceIntervalSeconds()
EndFunction

Actor Function VictimActor()
	If VictimAlias != None
		Actor fromAlias = VictimAlias.GetActorReference()
		If fromAlias != None
			Return fromAlias
		EndIf
	EndIf
	Return victimRef
EndFunction

Actor Function GuardActor()
	If GuardAlias != None
		Actor fromAlias = GuardAlias.GetActorReference()
		If fromAlias != None
			Return fromAlias
		EndIf
	EndIf
	Return guardRef
EndFunction

; Who stands in the cage: the arresting guard or the dedicated punisher. None before phase 8
; settles it, or when no jailer is usable. Read by SSM_LeashRelease.
Actor Function JailerActor()
	Return jailerRef
EndFunction

; The guard keeps close to the victim whatever its package does.
; The gap is the offset (80) plus the catch-up radius (60): at most about 140.
; That stays under the leash's maximum length (220), so the leash never goes taut and
; never holds the victim back. The old radius of 200 let the gap reach about 280.
; Only one actor holds the offset in a case: a different previous holder is cleared before the
; new one receives it. pacedRef is written before any call, so two updates running at once
; cannot both believe they hold it; the one replaced while setting it clears his own.
Function KeepPace(Actor guard, Actor victim)
	If guard == None || victim == None
		Return
	EndIf
	Actor previous = pacedRef
	pacedRef = guard
	If previous != None && previous != guard
		ClearPace(previous)
	EndIf
	guard.KeepOffsetFromActor(victim, 80.0, 0.0, 0.0, 0.0, 0.0, 0.0, 60.0, 30.0)
	If pacedRef != guard
		; replaced (or the case was cleared) while the offset was being set: he does not keep it
		ClearPace(guard)
	EndIf
EndFunction

; Clears the stick-to-victim offset on one actor so his own package takes over again.
; He is not moved, disabled or given a package.
Function ClearPace(Actor who)
	If who == None
		Return
	EndIf
	who.ClearKeepOffsetFromActor()
	who.EvaluatePackage()
EndFunction

; The escort search failed and no march follows. Called before ClearState, while the case still
; knows its actors: the offset is cleared on every actor this case gave it to (the holder, and the
; chosen escort if a race left him different), and a speaker this case set not to move may move
; again where she stands. Nobody is moved, faded, disabled, sent to jail or given a package.
Function ReleaseSearchHold()
	Actor paced = pacedRef
	pacedRef = None
	Actor kept = guardRef
	Actor aliased = None
	If GuardAlias != None
		aliased = GuardAlias.GetActorReference()
	EndIf
	ClearPace(paced)
	If kept != None && kept != paced
		ClearPace(kept)
	EndIf
	If aliased != None && aliased != paced && aliased != kept
		ClearPace(aliased)
	EndIf
	If victimHeldStill
		victimHeldStill = false
		Actor held = victimRef
		If held == None
			held = VictimActor()
		EndIf
		If held != None
			held.SetDontMove(false)
		EndIf
	EndIf
EndFunction

Bool Function IsMale(Actor who)
	If who == None
		Return false
	EndIf
	ActorBase base = who.GetActorBase()
	If base == None
		Return false
	EndIf
	Return base.GetSex() == 0
EndFunction

Bool Function PunisherMale()
	Return IsMale(Punisher)
EndFunction

; Alive, not a child, and male: the only punisher that is moved to jail or starts a scene.
Bool Function PunisherUsable()
	If Punisher == None
		Return false
	EndIf
	If Punisher.IsChild() || Punisher.IsDead()
		Return false
	EndIf
	Return PunisherMale()
EndFunction

; The arresting escort stays in the cage if he is present, an adult, alive, enabled and male,
; whether or not he is a guard. A civilian escort stays the same way a guard does.
; Otherwise (missing, a child, dead, disabled, or not male) the dedicated punisher takes the cage.
Bool Function GuardCanJail(Actor guard)
	If guard == None
		Return false
	EndIf
	If guard.IsChild() || guard.IsDead() || guard.IsDisabled()
		Return false
	EndIf
	Return IsMale(guard)
EndFunction

; Places the dedicated punisher at the jail marker and makes him the jailer.
; False if he is not usable; nothing is moved then.
Bool Function PlacePunisher(ObjectReference jail)
	If jail == None || !PunisherUsable()
		Return false
	EndIf
	If Punisher.IsDisabled()
		Punisher.Enable(false)
	EndIf
	Punisher.MoveTo(jail, 120.0, 0.0, 0.0, false)
	Punisher.SetDontMove(true)
	punisherPlaced = true
	jailerRef = Punisher
	jailerIsOwn = true
	Return true
EndFunction

; The cell of the stored jail marker. None if no marker is stored.
Cell Function JailCell()
	If jailRef == None
		Return None
	EndIf
	Return jailRef.GetParentCell()
EndFunction

; The player stands in the jail cell. Not IsInLocation: a parent location stays true after the
; player has left the interior. No stored marker means false.
Bool Function PlayerInJail()
	Cell jailCell = JailCell()
	If jailCell == None
		Return false
	EndIf
	Return Game.GetPlayer().GetParentCell() == jailCell
EndFunction

; Both the victim and the jailer are in the stored jail cell.
Bool Function BothInJail()
	Cell jailCell = JailCell()
	If jailCell == None
		Return false
	EndIf
	Actor victim = VictimActor()
	If victim == None || jailerRef == None
		Return false
	EndIf
	Return victim.GetParentCell() == jailCell && jailerRef.GetParentCell() == jailCell
EndFunction

Bool Function InLoc(ObjectReference who, Location place)
	If who == None || place == None
		Return false
	EndIf
	Return who.IsInLocation(place)
EndFunction

; IsInLocation is true for a location and its children.
ObjectReference Function JailFor(ObjectReference who)
	If who == None
		Return None
	EndIf
	If InLoc(who, LocWhiterun)
		Return JailWhiterun
	ElseIf InLoc(who, LocSolitude)
		Return JailSolitude
	ElseIf InLoc(who, LocWindhelm)
		Return JailWindhelm
	ElseIf InLoc(who, LocRiften)
		Return JailRiften
	ElseIf InLoc(who, LocMarkarth)
		Return JailMarkarth
	ElseIf InLoc(who, LocFalkreath)
		Return JailFalkreath
	ElseIf InLoc(who, LocMorthal)
		Return JailMorthal
	ElseIf InLoc(who, LocDawnstar)
		Return JailDawnstar
	ElseIf InLoc(who, LocWinterhold)
		Return JailWinterhold
	EndIf
	Return None
EndFunction

; The exterior jail door that belongs to an interior jail marker. None if unset.
ObjectReference Function ExteriorFor(ObjectReference jail)
	If jail == None
		Return None
	EndIf
	If jail == JailWhiterun
		Return ExtWhiterun
	ElseIf jail == JailSolitude
		Return ExtSolitude
	ElseIf jail == JailWindhelm
		Return ExtWindhelm
	ElseIf jail == JailRiften
		Return ExtRiften
	ElseIf jail == JailMarkarth
		Return ExtMarkarth
	ElseIf jail == JailFalkreath
		Return ExtFalkreath
	ElseIf jail == JailMorthal
		Return ExtMorthal
	ElseIf jail == JailDawnstar
		Return ExtDawnstar
	ElseIf jail == JailWinterhold
		Return ExtWinterhold
	EndIf
	Return None
EndFunction

; A cell as text for a note: its form id, or the word none.
String Function CellText(Cell c)
	If c == None
		Return "none"
	EndIf
	Return "" + c.GetFormID()
EndFunction

; Who can be framed: an adult NPC (by keyword), alive and enabled, not the player, not a guard,
; and not the dedicated punisher. Essential and non-essential adults are treated the same: the
; essential flag only keeps an actor from dying, and nothing in a case kills or harms her.
Bool Function SpeakerOk(Actor speaker)
	If speaker == None
		Return false
	EndIf
	If speaker.IsChild()
		Return false
	EndIf
	If speaker == Game.GetPlayer()
		Return false
	EndIf
	If speaker == Punisher
		Return false
	EndIf
	If speaker.IsDead() || speaker.IsDisabled()
		Return false
	EndIf
	If speaker.IsGuard()
		Return false
	EndIf
	If NpcType == None || !speaker.HasKeyword(NpcType)
		Return false
	EndIf
	Return true
EndFunction

; The checks both escort passes share: present, not the speaker, the player or the punisher,
; an adult, alive, enabled, not fighting, and an NPC by keyword.
Bool Function EscortBaseOk(Actor candidate, Actor speaker)
	If candidate == None || candidate == speaker
		Return false
	EndIf
	If candidate == Game.GetPlayer() || candidate == Punisher
		Return false
	EndIf
	If candidate.IsChild() || candidate.IsDead() || candidate.IsDisabled()
		Return false
	EndIf
	If candidate.IsInCombat()
		Return false
	EndIf
	If NpcType == None || !candidate.HasKeyword(NpcType)
		Return false
	EndIf
	Return true
EndFunction

; Pass 1: a guard. A guard may be essential.
Bool Function GuardEscortOk(Actor candidate, Actor speaker)
	If !EscortBaseOk(candidate, speaker)
		Return false
	EndIf
	Return candidate.IsGuard()
EndFunction

; Pass 2: a civilian. Not a guard, not essential, not a follower, awake, standing,
; and not held by any running slot as a dominant or a slave.
Bool Function CivilianEscortOk(Actor candidate, Actor speaker)
	If !EscortBaseOk(candidate, speaker)
		Return false
	EndIf
	If candidate.IsGuard() || candidate.IsEssential() || candidate.IsPlayerTeammate()
		Return false
	EndIf
	; 3 sleeping, 4 sleeping and wants to wake
	Int sleep = candidate.GetSleepState()
	If sleep == 3 || sleep == 4
		Return false
	EndIf
	; 3 sitting, 4 sitting and wants to stand
	Int sit = candidate.GetSitState()
	If sit == 3 || sit == 4
		Return false
	EndIf
	If Main == None
		Return false
	EndIf
	If Main.IsDominant(candidate) || Main.IsSlaveOfAnyone(candidate)
		Return false
	EndIf
	Return true
EndFunction

; The escort nearest to the speaker in the player's cell. Never spawns one.
; One scan, two passes over its result: a guard first, and a civilian only if no guard qualifies.
; The scan is centred on the player, the same call that SSM_Main.Tick makes, and it is
; only ever made from OnUpdate with the Dialogue Menu closed. The player and the speaker
; share a cell. The scan is never centred on the speaker: that call returned None and
; ended the script stack.
; When the native returns None, the assignment below errors (Cannot cast from None to Actor[])
; and this call, and the update that made it, end there: nothing after it runs. StepFindGuard
; therefore never counts or judges anything for a scan that has not returned.
Actor Function FindGuard(Actor speaker)
	Actor[] found = MiscUtil.ScanCellNPCs(Game.GetPlayer(), 0.0, None, true)
	If found == None
		Return None
	EndIf
	Actor best = None
	Float bestDistance = -1.0
	Int i = 0
	While i < found.Length
		Actor candidate = found[i]
		If GuardEscortOk(candidate, speaker)
			Float d = candidate.GetDistance(speaker)
			If best == None || d < bestDistance
				best = candidate
				bestDistance = d
			EndIf
		EndIf
		i += 1
	EndWhile
	If best != None
		Return best
	EndIf
	; no guard qualified: the same array, searched for a civilian
	i = 0
	While i < found.Length
		Actor civilian = found[i]
		If CivilianEscortOk(civilian, speaker)
			Float cd = civilian.GetDistance(speaker)
			If best == None || cd < bestDistance
				best = civilian
				bestDistance = cd
			EndIf
		EndIf
		i += 1
	EndWhile
	Return best
EndFunction

; ---------------------------------------------------------------- entry (dialogue fragment)

; The fragment's argument is gone after this call returns, so the speaker is kept on the
; quest. No scan is made here: the guard is looked for from OnUpdate (phase 7).
Bool Function StartFrame(Actor speaker)
	If Main == None
		Return false
	EndIf
	If !Main.Enabled() || !Main.MaliceEnabled()
		Return false
	EndIf
	If !Main.FrameworkReady()
		Main.WarnFramework()
		Return false
	EndIf
	If phase != 0
		Return false
	EndIf
	If !SpeakerOk(speaker)
		Return false
	EndIf
	; a child punisher stops the whole feature: nobody is framed
	If Punisher != None && Punisher.IsChild()
		Note("malice: the punisher is a child; nothing started")
		Return false
	EndIf
	If ReturnSpot == None || VictimAlias == None || GuardAlias == None || Busy == None
		Note("malice: a required property is not set; nothing started")
		Return false
	EndIf
	; the same rule as the topic's condition: a Busy value that is not 0 starts nothing
	If Busy.GetValue() != 0.0
		Note("malice: a case is already marked busy; nothing started")
		Return false
	EndIf
	If JailFor(speaker) == None
		Note("malice: no jail for this location; nothing started")
		Return false
	EndIf

	ClearState()
	victimRef = speaker
	Busy.SetValue(1.0)
	lastTick = Utility.GetCurrentRealTime()
	phase = 7
	Note("malice: the speaker is kept; the guard is looked for once the dialogue closes")
	RegisterForSingleUpdate(1.0)
	Return true
EndFunction

; ---------------------------------------------------------------- phase 7: guard scan after the dialogue

; Scans repeat until one returns an escort. The next update is registered BEFORE the scan,
; because a scan that dies runs nothing after it, not even OnUpdate's own register.
; A scan that dies is not counted and never ends the case. Only a scan that RETURNS with no
; eligible escort is counted; two of those end the search with the failure notice.
; Scans that keep dying are stopped by scanDeadline: 20 real seconds from the first tick of this
; search with the Dialogue Menu closed. Then, with no escort stored, the same failure notice.
; Once an escort is stored in guardRef, no later scan, count or deadline of this search touches
; the case: the checks and the store below run with no call leaving this script in between, so
; two updates running at once cannot both pass them.
Function StepFindGuard(Float now)
	; the Dialogue Menu is still open: the scan waits, as SSM_Main.Tick does.
	; This is not an attempt, is not counted, and does not start the deadline.
	If UI.IsMenuOpen("Dialogue Menu")
		Return
	EndIf
	Float t = Utility.GetCurrentRealTime()
	; an escort is already stored (another update is setting him up), or the search has ended
	If phase != 7 || guardRef != None
		Return
	EndIf
	If scanDeadline <= 0.0
		scanDeadline = t + 20.0
	ElseIf t >= scanDeadline
		FrameFailed("the escort search ran out of time")
		Return
	EndIf
	Actor speaker = victimRef
	If !SpeakerOk(speaker)
		NoGuard("the speaker can no longer be arrested")
		Return
	EndIf
	If JailFor(speaker) == None
		NoGuard("no jail for this location")
		Return
	EndIf
	RegisterForSingleUpdate(1.0)
	Actor chosen = FindGuard(speaker)
	; the scan returned. The search already ended, another case began, or another update already
	; stored an escort while this scan ran: this result is not used and nothing is undone.
	If phase != 7 || victimRef != speaker || guardRef != None
		Return
	EndIf
	If chosen == None
		emptyScans += 1
		If emptyScans >= 2
			FrameFailed("no escort was found after two scans")
		Else
			Note("malice: no escort found; one more scan on the next update")
		EndIf
		Return
	EndIf
	; stored at once, in the same step as the checks above: from here on the escort is this case's
	guardRef = chosen

	ReturnSpot.MoveTo(speaker)
	VictimAlias.ForceRefTo(speaker)
	GuardAlias.ForceRefTo(chosen)
	speaker.StopCombat()
	victimHeldStill = true
	speaker.SetDontMove(true)
	chosen.StopCombat()
	; the arrest line is spoken in StepApproach, once the guard has reached the victim
	KeepPace(chosen, speaker)
	; the case ended while this escort was being set (the speaker is gone or can no longer be
	; arrested): what this call gave is taken back
	If phase == 0 || victimRef != speaker
		ClearPace(chosen)
		If pacedRef == chosen
			pacedRef = None
		EndIf
		If guardRef == chosen
			guardRef = None
		EndIf
		speaker.SetDontMove(false)
		If phase == 0
			victimHeldStill = false
		EndIf
		Return
	EndIf
	approachDeadline = now + 15.0
	phase = 1
	Note("malice: arrest of " + speaker.GetDisplayName() + " started")
EndFunction

; The case ends before anything was placed: no aliases, no packages, no moves to undo.
; EndCase is not used because it would move the speaker to ReturnSpot, which is not set yet.
; Any stick-to-victim offset this case gave, and a speaker set not to move, are released first.
Function NoGuard(String why)
	ReleaseSearchHold()
	Note("malice: nothing started, " + why)
	Debug.Notification("$SSM_NoGuard")
	UnregisterForUpdate()
	If Busy != None
		Busy.SetValue(0.0)
	EndIf
	ClearState()
EndFunction

; The guard search failed: two scans returned with no eligible escort, or the scans kept dying
; until the search deadline. Nothing was placed. The speaker is not moved or restrained.
; The text comes from the translation files.
; Does nothing once an escort is stored or the search has ended. The check and the claim
; (phase 0) are one step, so an escort stored by a concurrent update is never cancelled, and a
; scan returning while this runs finds phase 0 and leaves the case alone.
; Any stick-to-victim offset this case gave, and a speaker set not to move, are released first.
Function FrameFailed(String why)
	If phase != 7 || guardRef != None
		Return
	EndIf
	phase = 0
	ReleaseSearchHold()
	Note("malice: nothing started, " + why)
	Debug.Notification("$SSM_FrameFailed")
	UnregisterForUpdate()
	If Busy != None
		Busy.SetValue(0.0)
	EndIf
	ClearState()
EndFunction

; ---------------------------------------------------------------- tick

Event OnUpdate()
	If phase == 0
		UnregisterForUpdate()
		; no case is running: a Busy flag left at 1 would block the frame dialogue for good
		If Busy != None
			Busy.SetValue(0.0)
		EndIf
		Return
	EndIf
	Float now = Utility.GetCurrentRealTime()
	If now < lastTick
		; the real-time clock restarted with the game
		Rebase(now)
	EndIf
	lastTick = now

	Actor victim = VictimActor()
	If victim == None || victim.IsDead()
		If phase == 7
			NoGuard("the speaker is gone")
		Else
			EndCase("the victim is gone")
		EndIf
		Return
	EndIf

	If phase == 7
		StepFindGuard(now)
	ElseIf phase == 1
		StepApproach(now)
	ElseIf phase == 2
		StepFade(now)
	ElseIf phase == 3
		StepMove(now)
	ElseIf phase == 8
		StepPlace(now)
	ElseIf phase == 4
		StepJail(now)
	ElseIf phase == 5
		StepScene(now)
	ElseIf phase == 6
		StepMarch(now)
	EndIf

	If phase != 0
		RegisterForSingleUpdate(1.0)
	EndIf
EndEvent

; ---------------------------------------------------------------- phase 1: guard walks over

Function StepApproach(Float now)
	Actor victim = VictimActor()
	Actor guard = GuardActor()
	If guard == None || guard.IsDead()
		EndCase("the guard is gone")
		Return
	EndIf
	If guard.GetDistance(victim) < 200.0
		Note("malice: the guard reached the victim")
	ElseIf now >= approachDeadline
		guard.MoveTo(victim, 80.0, 0.0, 0.0, false)
		Note("malice: the guard was moved next to the victim after the wait")
	Else
		Return
	EndIf
	; the arrest line starts here, after the escort has arrived: a guard's line, or a civilian's
	If guard.IsGuard()
		SkyrimNetApi.DirectNarration(SSM_Lines.Text(5, victim.GetDisplayName()), guard, victim)
	Else
		SkyrimNetApi.DirectNarration(SSM_Lines.Text(7, victim.GetDisplayName()), guard, victim)
	EndIf
	; the offset is kept on purpose: it keeps the guard beside the victim through the march
	phase = 2
	BindAndFade(now)
EndFunction

; ---------------------------------------------------------------- phase 2: bind, optional leash, start the march

; The fade now happens only in StepFade, as the fallback.
; The victim is not restrained here: a restrained actor cannot walk.
; The standing bound idle is also withheld until the jail MoveTo.
Function BindAndFade(Float now)
	Actor victim = VictimActor()
	SSM_Leash.EquipCuffs(victim)
	; Heard by the leash alias script when Leash.esm is installed. No script dependency here.
	SendModEvent("SSM_MaliceLeash", "apply", 1.0)
	arrestDone = true
	victim.SetDontMove(false)
	If !StartMarch(now)
		Note("malice: no march possible; the fade fallback is used")
		victim.SetDontMove(true)
		fadeDeadline = now + 2.0
	EndIf
EndFunction

; Fills the three march aliases. The packages on those aliases do the walking.
Bool Function StartMarch(Float now)
	If MarchVictimAlias == None || MarchGuardAlias == None || MarchGoalAlias == None
		Return false
	EndIf
	Actor victim = VictimActor()
	Actor guard = GuardActor()
	If victim == None || guard == None
		Return false
	EndIf
	ObjectReference goal = ExteriorFor(JailFor(victim))
	If goal == None
		Return false
	EndIf
	MarchGoalAlias.ForceRefTo(goal)
	MarchGuardAlias.ForceRefTo(guard)
	MarchVictimAlias.ForceRefTo(victim)
	victim.EvaluatePackage()
	guard.EvaluatePackage()
	; the guard keeps pace with the victim whatever its package does: the leash then never goes taut
	KeepPace(guard, victim)
	; the cap is read once here from the MCM; later ticks only compare against marchDeadline
	Float marchCap = 120.0
	If Main != None
		marchCap = Main.MarchSeconds()
	EndIf
	marchDeadline = now + marchCap
	phase = 6
	Note("malice: the march to the jail started, limit " + (marchCap as Int) + " seconds")
	Return true
EndFunction

; Empties the march aliases so their packages stop. Safe to call at any time.
Function EndMarch()
	Actor victim = VictimActor()
	Actor guard = GuardActor()
	If MarchVictimAlias != None
		MarchVictimAlias.Clear()
	EndIf
	If MarchGuardAlias != None
		MarchGuardAlias.Clear()
	EndIf
	If MarchGoalAlias != None
		MarchGoalAlias.Clear()
	EndIf
	If guard != None
		guard.ClearKeepOffsetFromActor()
	EndIf
	If victim != None
		victim.EvaluatePackage()
	EndIf
	If guard != None
		guard.EvaluatePackage()
	EndIf
EndFunction

Function StepFade(Float now)
	If !arrestDone
		BindAndFade(now)
		Return
	EndIf
	If now < fadeDeadline
		Return
	EndIf
	If !fadedOut
		Game.FadeOutGame(true, true, 0.0, 1.0)
		fadedOut = true
		fadeDeadline = now + 1.5
		Return
	EndIf
	phase = 3
	StepMove(now)
EndFunction

; ---------------------------------------------------------------- phase 6: on foot to the exterior jail marker

Function StepMarch(Float now)
	Actor victim = VictimActor()
	Actor guard = GuardActor()
	If guard == None || guard.IsDead()
		MarchFallback(now, "the guard is gone")
		Return
	EndIf
	ObjectReference goal = None
	If MarchGoalAlias != None
		goal = MarchGoalAlias.GetReference()
	EndIf
	If goal != None && goal.Is3DLoaded() && victim.Is3DLoaded()
		If victim.GetDistance(goal) < 700.0
			Note("malice: the victim arrived at the jail on foot")
			EndMarch()
			phase = 3
			StepMove(now)
			Return
		EndIf
	EndIf
	If now >= marchDeadline
		MarchFallback(now, "the march ran out of time")
	EndIf
EndFunction

; The only place a fade is chosen: the walk failed or took too long.
Function MarchFallback(Float now, String why)
	Note("malice: " + why + "; the fade fallback is used")
	EndMarch()
	Actor victim = VictimActor()
	If victim != None
		victim.SetDontMove(true)
	EndIf
	fadeDeadline = now
	phase = 2
EndFunction

; ---------------------------------------------------------------- phase 3: move to jail

; Issues the jail MoveTo and nothing else. A later tick (phase 8) judges whether it happened.
; Her AI stays stopped only until StepPlace finds her in the jail cell; BeginJailHold then
; turns it back on under the jail hold package.
Function StepMove(Float now)
	Actor victim = VictimActor()
	If victim.IsChild()
		EndCase("the victim is a child")
		Return
	EndIf
	ObjectReference jail = JailFor(victim)
	If jail == None
		EndCase("no jail marker matches the victim's location")
		Return
	EndIf

	victim.SetDontMove(false)
	; heard by the leash alias script, which clears the leash on a later tick: not synchronous
	SendModEvent("SSM_MaliceLeash", "clear", 0.0)
	victim.MoveTo(jail, 0.0, 0.0, 0.0, false)
	phase = 8
	placeChecks = 0
	If !victim.IsDead()
		victim.EnableAI(false)
		aiStopped = true
		Note("malice: the victim's AI is stopped until release")
	EndIf
	; a note, not a verdict: the judgment is made by StepPlace on a later tick
	Note("malice: the move into the jail was issued; victim cell " + CellText(victim.GetParentCell()) + ", jail cell " + CellText(jail.GetParentCell()))
EndFunction

; ---------------------------------------------------------------- phase 8: judge the jail move

Function StepPlace(Float now)
	Actor victim = VictimActor()
	Actor guard = GuardActor()
	ObjectReference jail = JailFor(victim)
	Cell jailCell = None
	If jail != None
		jailCell = jail.GetParentCell()
	EndIf
	Cell victimCell = victim.GetParentCell()
	placeChecks += 1
	Note("malice: judging the jail move; victim cell " + CellText(victimCell) + ", jail cell " + CellText(jailCell))

	If victimCell != None && jailCell != None && victimCell == jailCell
		; the marker that matched is kept for the rest of the case; JailFor is not asked again
		jailRef = jail

		If GuardCanJail(guard)
			; the arresting guard stays in the cage as the jailer. His alias stays filled.
			; EndMarch stops the march packages first; SetDontMove comes after it.
			EndMarch()
			guard.ClearKeepOffsetFromActor()
			guard.MoveTo(jail, 120.0, 0.0, 0.0, false)
			guard.SetDontMove(true)
			jailerRef = guard
			jailerIsOwn = false
			Note("malice: the arresting guard stays in the jail as the jailer")
		Else
			If !PlacePunisher(jail)
				; missing, dead, a child, or not male: no scenes, the release timer still runs
				Note("malice: no usable punisher; the sentence is served without scenes")
			EndIf

			EndMarch()
			GuardAlias.Clear()
			If guard != None
				guard.ClearKeepOffsetFromActor()
			EndIf
			guardRef = None
		EndIf

		; the jailer is settled: she waits under the jail hold package, her AI running, not bound
		BeginJailHold(victim)

		releaseAt = Utility.GetCurrentGameTime() + 1.0
		nextSceneAt = now + Interval()
		If fadedOut
			Game.FadeOutGame(false, true, 0.0, 1.0)
			fadedOut = false
		EndIf
		phase = 4
		Note("malice: the victim is in jail")
		; heard by the leash alias script: from now on it keeps any leash off her until the case ends
		SendModEvent("SSM_MaliceLeash", "hold", 0.0)
		; once per case, after the jail hold package started: a captive held by another mod is freed
		SendCaptiveRelease(victim)
		Return
	EndIf

	If (victimCell == None || jailCell == None) && placeChecks == 1
		Note("malice: a cell is not known yet; the judgment is deferred once")
		Return
	EndIf

	MoveFailed()
EndFunction

; The jail MoveTo did not put the victim in the jail cell. Nobody is moved here.
; EndCase is not used because it would move the victim to ReturnSpot.
; This runs on a later tick than the clear event, which is the gap the leash script needs.
Function MoveFailed()
	Note("malice: the move into the jail did not happen; the victim is still outside")
	Actor victim = VictimActor()
	Actor guard = GuardActor()
	; a load in phase 8 may have started the jail hold package; it must not walk her to the jail
	ClearJailHold()
	If victim != None && !victim.IsDead()
		SSM_Leash.ClearWrists(victim)
		victim.SetRestrained(false)
		victim.SetDontMove(false)
		victim.EnableAI(true)
		Note("malice: the victim's AI is restored")
	EndIf
	EndMarch()
	If guard != None
		guard.ClearKeepOffsetFromActor()
	EndIf
	If fadedOut
		Game.FadeOutGame(false, true, 0.0, 1.0)
	EndIf
	If GuardAlias != None
		GuardAlias.Clear()
	EndIf
	If VictimAlias != None
		VictimAlias.Clear()
	EndIf
	UnregisterForUpdate()
	If Busy != None
		Busy.SetValue(0.0)
	EndIf
	ClearState()
EndFunction

; ---------------------------------------------------------------- captive release (once per case)

; Heard by SSM_LeashRelease when the captive mod is installed. No script dependency here.
; Sent only from StepPlace, once per case, and only when alias 6 holds her: the jail hold package
; has started, so the stand-up from the release ends inside the hold. Not sent on a recapture,
; not before a scene, not after a load. ClearState clears the flag when the case ends.
Function SendCaptiveRelease(Actor victim)
	If captiveReleaseSent
		Return
	EndIf
	If victim == None || victim.IsDead() || victim.IsChild()
		Return
	EndIf
	ReferenceAlias holdAlias = GetAlias(6) as ReferenceAlias
	If holdAlias == None || holdAlias.GetReference() != victim
		Note("malice: the jail hold package is not running; the captive release is not sent")
		Return
	EndIf
	captiveReleaseSent = true
	SendModEvent("SSM_MaliceRelease", "captive", 0.0)
	Note("malice: the captive release was sent")
EndFunction

; ---------------------------------------------------------------- jail hold package (aliases 6 and 7)

; Puts the victim under the jail hold package: alias 6 (JailHold) carries SSM_JailHold, a Sandbox
; of radius 400 anchored on alias 7 (JailSpot), which holds the stored jail marker. The alias
; package outranks her own travel package, so she stays near the marker while her AI keeps running.
; Safe to call again: EvaluatePackage, the wrist clear and the note run only when alias 6 is newly
; filled with her, never on a repeat call.
; Without the aliases the old freeze is the fallback: it is all that keeps her from walking home.
Function BeginJailHold(Actor victim)
	If victim == None || victim.IsDead() || victim.IsChild()
		Return
	EndIf
	If jailRef == None
		Return
	EndIf
	ReferenceAlias holdAlias = GetAlias(6) as ReferenceAlias
	ReferenceAlias spotAlias = GetAlias(7) as ReferenceAlias
	If holdAlias == None || spotAlias == None
		victim.EnableAI(false)
		aiStopped = true
		Note("malice: the jail hold package is missing; her AI is stopped")
		Return
	EndIf
	If spotAlias.GetReference() != jailRef
		spotAlias.ForceRefTo(jailRef)
	EndIf
	Bool fresh = holdAlias.GetReference() != victim
	If fresh
		holdAlias.ForceRefTo(victim)
	EndIf
	victim.EnableAI(true)
	victim.SetDontMove(false)
	If fresh
		SSM_Leash.ClearWrists(victim)
		; a save from before the package may still have her restrained; a restrained actor cannot sandbox
		victim.SetRestrained(false)
		victim.EvaluatePackage()
		Note("malice: the jail hold package started")
	EndIf
	aiStopped = true
EndFunction

; Empties aliases 6 and 7, so the jail hold package stops. The references themselves are left as
; they are: the jail marker is never deleted or disabled. aiStopped is not changed here.
Function ClearJailHold()
	ReferenceAlias holdAlias = GetAlias(6) as ReferenceAlias
	ReferenceAlias spotAlias = GetAlias(7) as ReferenceAlias
	Bool held = false
	If holdAlias != None
		held = holdAlias.GetReference() != None
		holdAlias.Clear()
	EndIf
	If spotAlias != None
		spotAlias.Clear()
	EndIf
	If held
		Note("malice: the jail hold package cleared")
	EndIf
EndFunction

; ---------------------------------------------------------------- phase 4: in jail

Function StepJail(Float now)
	If Utility.GetCurrentGameTime() >= releaseAt
		EndCase("the sentence is served")
		Return
	EndIf
	; the sentence runs on while the player is away, but nothing is held or staged out of sight
	If !PlayerInJail()
		; a return visit stages anew instead of resuming an old staging on the same tick
		AbandonStaging("the player left the jail")
		Return
	EndIf
	; every tick in jail, also while the next scene is waiting: keep both in the cell
	KeepInJail(true)
	If now < nextSceneAt
		Return
	EndIf
	TryScene(now)
EndFunction

; Runs every tick in phase 4 and phase 5. Brings the victim and the jailer back into the stored
; jail cell if either has left it, and replaces an arresting guard who can no longer be the jailer.
; The victim is held by the jail hold package, not frozen, so nothing is reapplied to her on a
; normal tick. With hold false (a scene is running in the cell) the jailer's SetDontMove is not
; reapplied, so the framework keeps both actors for the scene.
Function KeepInJail(Bool hold)
	Cell jailCell = JailCell()
	; actors are brought back only while the player is there to see the cell
	Bool playerHere = PlayerInJail()
	Actor victim = VictimActor()
	If victim != None && !victim.IsDead()
		If playerHere && jailCell != None && victim.GetParentCell() != jailCell
			victim.MoveTo(jailRef, 0.0, 0.0, 0.0, false)
			BeginJailHold(victim)
			recaptures += 1
			Note("malice: the victim was brought back to jail")
		EndIf
	EndIf

	Actor jailer = jailerRef
	If jailer == None
		Return
	EndIf
	If jailer.IsDead() || jailer.IsDisabled() || jailer.IsChild()
		If !jailerIsOwn
			DropGuardJailer(jailer)
		EndIf
		Return
	EndIf
	If playerHere && jailCell != None && jailer.GetParentCell() != jailCell
		jailer.MoveTo(jailRef, 120.0, 0.0, 0.0, false)
		jailer.SetDontMove(true)
		Note("malice: the jailer was brought back")
	ElseIf hold
		jailer.SetDontMove(true)
	EndIf
EndFunction

; The arresting guard can no longer be the jailer. He is let go, not disabled,
; and the dedicated punisher takes his place if he is usable.
Function DropGuardJailer(Actor jailer)
	If jailer != None
		jailer.SetDontMove(false)
	EndIf
	If GuardAlias != None
		GuardAlias.Clear()
	EndIf
	guardRef = None
	jailerRef = None
	If PlacePunisher(jailRef)
		Note("malice: the jailer can no longer serve; the punisher took his place")
	Else
		Note("malice: the jailer can no longer serve and no punisher is usable; the sentence is served without scenes")
	EndIf
EndFunction

; Kept so old calls compile. The jail hold package (BeginJailHold) replaced the frozen AI;
; this no longer stops her AI or touches her at all.
Function HoldInJail()
	Return
EndFunction

; Lifts the victim's jail hold for the length of one scene, inside the cell. The jail hold package
; is cleared first so it does not fight the scene, then her AI is on and the wrist pose cleared.
; aiStopped stays set, so RestoreAfterScene puts the package back when the scene ends or fails.
; The jailer's SetDontMove is left on. It stops pathing only; the framework still animates him,
; and clearing it lets his package walk him out of the cell, which ends the scene.
Function ReleaseForScene(Actor victim, Actor jailer)
	ClearJailHold()
	If victim != None && !victim.IsDead()
		victim.EnableAI(true)
		SSM_Leash.ClearWrists(victim)
		victim.SetRestrained(false)
		victim.SetDontMove(false)
	EndIf
	Note("malice: the jail hold is lifted for the scene")
EndFunction

; Stages a scene at the jail marker while the jail hold is still on: the victim and the jailer are
; both moved onto jailRef with no offset, and both are set not to move, so the jail sandbox cannot
; walk her back to the bench before the distance check on a later update. Called again on every
; later update while she is farther than 128 from the marker.
; The 120 offset is not used here; it stays in KeepInJail and in the release move out of the cell.
Function StageAtMarker(Actor victim, Actor jailer)
	If jailRef == None || victim == None || jailer == None
		Return
	EndIf
	If victim.IsChild() || jailer.IsChild()
		Return
	EndIf
	victim.MoveTo(jailRef, 0.0, 0.0, 0.0, false)
	victim.SetDontMove(true)
	jailer.MoveTo(jailRef, 0.0, 0.0, 0.0, false)
	jailer.SetDontMove(true)
EndFunction

; A staging ends without a scene (the framework is not ready, a load, the feature is off, or an
; actor can no longer take part). She may move again before the staging is forgotten; the jail
; hold package is still on and keeps her in the cell. Does nothing when no staging is running.
Function AbandonStaging(String why)
	If !staging
		Return
	EndIf
	Actor held = VictimActor()
	If held != None && !held.IsDead()
		held.SetDontMove(false)
	EndIf
	staging = false
	stageStart = 0.0
	stageFarNoted = false
	Note("malice: the scene staging was abandoned, " + why)
EndFunction

; Two steps over two or more updates. First update: StageAtMarker moves both onto jailRef and
; returns; the jail hold is not cleared and no scene starts on that update. Later updates: if she
; is within 128 of the marker the staging is cleared and the scene starts as before (the line,
; ReleaseForScene, SSM_Scene.Begin). If she is farther, both are moved again and nothing starts;
; the once-per-second update is the retry. After 10 real seconds still far, a note is written once,
; the jail hold stays on, and the moves go on until she is within 128 or the release ends the case.
Function TryScene(Float now)
	If Main == None || !Main.Enabled() || !Main.MaliceEnabled()
		AbandonStaging("the feature is off")
		Return
	EndIf
	Actor victim = VictimActor()
	Actor jailer = jailerRef
	If victim == None || jailer == None || jailRef == None
		AbandonStaging("an actor or the jail marker is missing")
		Return
	EndIf
	If victim.IsChild() || jailer.IsChild()
		AbandonStaging("an actor is a child")
		Return
	EndIf
	If victim.IsDead() || jailer.IsDead() || jailer.IsDisabled() || !IsMale(jailer)
		AbandonStaging("the jailer can no longer serve")
		Return
	EndIf
	; both must be in the stored jail cell; if not, the next tick brings them back
	If !BothInJail()
		Return
	EndIf
	If !victim.Is3DLoaded() || !jailer.Is3DLoaded()
		Return
	EndIf
	If !Main.FrameworkReady()
		Main.WarnFramework()
		AbandonStaging("the framework is not ready")
		nextSceneAt = now + 30.0
		Return
	EndIf
	Bool useOStim = Main.UseOStim()
	If SSM_Scene.ActorBusy(jailer, useOStim) || SSM_Scene.ActorBusy(victim, useOStim)
		AbandonStaging("an actor is busy in another scene")
		Return
	EndIf

	If !staging
		; first step: move both onto the marker; the jail hold stays and no scene starts this update
		StageAtMarker(victim, jailer)
		staging = true
		stageStart = now
		stageFarNoted = false
		Note("malice: both were moved to the jail marker; the scene is checked on the next update")
		Return
	EndIf

	If victim.GetDistance(jailRef) > 128.0
		; still far: move both again and do not start
		StageAtMarker(victim, jailer)
		If !stageFarNoted && now - stageStart >= 10.0
			stageFarNoted = true
			Note("malice: the victim is still away from the jail marker after 10 seconds; the jail hold stays and the moves go on")
		EndIf
		Return
	EndIf

	; within 128: the staging is cleared, then the scene starts as before
	staging = false
	stageStart = 0.0
	stageFarNoted = false

	SkyrimNetApi.DirectNarration(SSM_Lines.Text(6, victim.GetDisplayName()), jailer, victim)
	; both stay in the cell; only the hold that would keep her from the scene is lifted
	ReleaseForScene(victim, jailer)
	Int startedId = SSM_Scene.Begin(4, jailer, victim, useOStim)
	If startedId < 0
		; no scene: the hold goes back at once, as after a scene
		RestoreAfterScene()
		Float gap = Interval()
		If gap <= 0.0
			gap = 5.0
		EndIf
		nextSceneAt = now + gap
		Return
	EndIf
	threadId = startedId
	threadIsOStim = useOStim
	sceneStart = now
	phase = 5
EndFunction

; ---------------------------------------------------------------- phase 5: scene running

Function StepScene(Float now)
	If Utility.GetCurrentGameTime() >= releaseAt
		EndCase("the sentence is served")
		Return
	EndIf
	Bool running = false
	If threadId >= 0
		running = SSM_Scene.Running(threadId, threadIsOStim)
	EndIf
	If running
		If !BothInJail()
			; the scene left the jail cell: stop it, bring both back, try again shortly
			SSM_Scene.End(threadId, threadIsOStim)
			threadId = -1
			threadIsOStim = false
			phase = 4
			nextSceneAt = now + 5.0
			Note("malice: the scene left the jail cell; it is tried again once both are back")
			RestoreAfterScene()
			KeepInJail(true)
			Return
		EndIf
		If now - sceneStart >= 180.0
			SSM_Scene.End(threadId, threadIsOStim)
		Else
			KeepInJail(false)
			Return
		EndIf
	EndIf
	threadId = -1
	threadIsOStim = false
	phase = 4
	nextSceneAt = now + Interval()
	RestoreAfterScene()
	KeepInJail(true)
EndFunction

; After a scene (or a scene that did not start): the jail hold package goes back on.
; ReleaseForScene cleared alias 6, so BeginJailHold sees a fresh fill and re-evaluates once.
Function RestoreAfterScene()
	Actor victim = VictimActor()
	If victim != None && !victim.IsDead()
		BeginJailHold(victim)
	EndIf
EndFunction

; ---------------------------------------------------------------- release

; Ends the case from any phase: the sentence is served, or something went wrong.
Function EndCase(String why)
	Note("malice: case ends, " + why)
	UnregisterForUpdate()
	Actor victim = VictimActor()
	Actor guard = GuardActor()
	Actor jailer = jailerRef

	If threadId >= 0
		SSM_Scene.End(threadId, threadIsOStim)
	EndIf
	; heard by the leash alias script: clears the leash and stops its hold watch
	SendModEvent("SSM_MaliceLeash", "clear", 0.0)
	; before the move to ReturnSpot: a package still on would walk her back to the jail marker.
	; EndMarch below re-evaluates her packages.
	ClearJailHold()
	EndMarch()
	If guard != None
		guard.ClearKeepOffsetFromActor()
	EndIf
	If victim != None
		If !victim.IsDead()
			SSM_Leash.ClearWrists(victim)
			victim.SetRestrained(false)
			victim.SetDontMove(false)
			If ReturnSpot != None
				victim.MoveTo(ReturnSpot)
			EndIf
			victim.EnableAI(true)
			Note("malice: the victim's AI is restored")
		EndIf
	EndIf
	; the dedicated punisher goes back to the holding spot and is disabled
	If (jailerIsOwn || punisherPlaced) && Punisher != None
		Punisher.SetDontMove(false)
		If HoldingSpot != None
			Punisher.MoveTo(HoldingSpot)
		EndIf
		Punisher.Disable(false)
	EndIf
	; the arresting guard as jailer is let go and, if still in the jail cell, moved outside it.
	; Not disabled. jailRef is still set here; ClearState runs below.
	If jailer != None && !jailerIsOwn
		jailer.SetDontMove(false)
		jailer.ClearKeepOffsetFromActor()
		If !jailer.IsDead() && JailCell() != None && jailer.GetParentCell() == JailCell()
			ObjectReference outside = ExteriorFor(jailRef)
			If outside == None
				outside = ReturnSpot
			EndIf
			If outside != None
				jailer.MoveTo(outside, 120.0, 0.0, 0.0, false)
				Note("malice: the jailer was moved out of the jail cell")
			EndIf
		EndIf
		jailer.EvaluatePackage()
	EndIf
	If VictimAlias != None
		VictimAlias.Clear()
	EndIf
	If GuardAlias != None
		GuardAlias.Clear()
	EndIf
	If fadedOut
		Game.FadeOutGame(false, true, 0.0, 1.0)
	EndIf
	If Busy != None
		Busy.SetValue(0.0)
	EndIf
	ClearState()
EndFunction
