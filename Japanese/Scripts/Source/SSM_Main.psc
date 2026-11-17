Scriptname SSM_Main extends MCM_ConfigBase

SSM_Slot Property Dom1 Auto
SSM_Slot Property Dom2 Auto
SSM_Slot Property Dom3 Auto
SSM_Slot Property Dom4 Auto
SSM_Slot Property Dom5 Auto
SSM_Malice Property Malice Auto

Keyword npcType
Quest claimHolder
Int childCellId = 0
Bool frameworkWarned = false

; ---------------------------------------------------------------- init

Event OnConfigInit()
	RefreshKeyword()
EndEvent

Function RefreshKeyword()
	npcType = Game.GetFormFromFile(0x00013794, "Skyrim.esm") as Keyword
EndFunction

Function OnGameLoad()
	RefreshKeyword()
	frameworkWarned = false
	childCellId = 0
	Int i = 0
	While i < 5
		SSM_Slot s = SlotAt(i)
		If s != None && s.IsRunning()
			s.Resume()
		EndIf
		i += 1
	EndWhile
	If Malice != None
		Malice.Resume()
	EndIf
EndFunction

SSM_Slot Function SlotAt(Int index)
	If index == 0
		Return Dom1
	ElseIf index == 1
		Return Dom2
	ElseIf index == 2
		Return Dom3
	ElseIf index == 3
		Return Dom4
	ElseIf index == 4
		Return Dom5
	EndIf
	Return None
EndFunction

; ---------------------------------------------------------------- settings

Bool Function Enabled()
	Return GetModSettingBool("bEnabled:General")
EndFunction

Bool Function Logging()
	Return GetModSettingInt("iLog:General") == 0
EndFunction

Float Function IntervalSeconds()
	Int v = GetModSettingInt("iInterval:General")
	If v < 0
		v = 0
	EndIf
	If v > 240
		v = 240
	EndIf
	Return v as Float
EndFunction

Bool Function MaliceEnabled()
	Return GetModSettingBool("bMalice:General")
EndFunction

Float Function MaliceIntervalSeconds()
	Int v = GetModSettingInt("iMaliceInterval:General")
	If v < 0
		v = 0
	EndIf
	If v > 600
		v = 600
	EndIf
	Return v as Float
EndFunction

Float Function MarchSeconds()
	Int v = GetModSettingInt("iMarchSeconds:General")
	If v < 10 || v > 600
		Return 120.0
	EndIf
	Return v as Float
EndFunction

Bool Function UseOStim()
	Return GetModSettingInt("iFramework:General") != 1
EndFunction

Bool Function FrameworkReady()
	If UseOStim()
		Return Game.IsPluginInstalled("OStim.esp")
	EndIf
	Return Game.IsPluginInstalled("SexLab.esm")
EndFunction

Function Note(String text)
	If Logging()
		Debug.OpenUserLog("skyrimnet_SwirlingMalice")
		Debug.TraceUser("skyrimnet_SwirlingMalice", text)
	EndIf
EndFunction

Function WarnFramework()
	If frameworkWarned
		Return
	EndIf
	frameworkWarned = true
	Debug.Notification("$SSM_NoFramework")
	Note("framework plugin is missing")
EndFunction

; ---------------------------------------------------------------- tick

Function Tick()
	If !Enabled()
		Return
	EndIf
	Actor player = Game.GetPlayer()
	If player == None || player.IsDead()
		Return
	EndIf
	If Utility.IsInMenuMode()
		Return
	EndIf
	If player.IsInCombat()
		Return
	EndIf
	If UI.IsMenuOpen("Dialogue Menu")
		Return
	EndIf
	If npcType == None
		RefreshKeyword()
	EndIf

	Actor[] scanned = MiscUtil.ScanCellNPCs(player, 0.0, None, true)

	Int i = 0
	While i < 5
		SSM_Slot s = SlotAt(i)
		If s != None && s.IsRunning()
			s.Repair()
		EndIf
		i += 1
	EndWhile

	Cell here = player.GetParentCell()
	If SSM_Scan.CellHasChild(scanned)
		Int cid = 0
		If here != None
			cid = here.GetFormID()
		EndIf
		If cid != childCellId
			childCellId = cid
			Note("child present in this cell; all actions paused")
		EndIf
		Return
	EndIf

	Actor[] adults = new Actor[32]
	Int n = SSM_Scan.CollectAdults(scanned, player, adults, npcType)
	Bool crowded = false
	If n < 0
		crowded = true
		n = adults.Length
	EndIf
	Bool interior = false
	If here != None
		interior = here.IsInterior()
	EndIf

	i = 0
	While i < 5
		SSM_Slot s2 = SlotAt(i)
		If s2 != None && s2.IsRunning()
			s2.Consider(adults, n, interior, crowded)
		EndIf
		i += 1
	EndWhile
EndFunction

; ---------------------------------------------------------------- claim

Bool Function TryClaim(Quest who)
	If who == None
		Return false
	EndIf
	If claimHolder != None && !claimHolder.IsRunning()
		claimHolder = None
	EndIf
	If claimHolder != None && claimHolder != who
		Return false
	EndIf
	claimHolder = who
	Return true
EndFunction

Function Release(Quest who)
	If claimHolder == who
		claimHolder = None
	EndIf
EndFunction

; ---------------------------------------------------------------- roster

Bool Function IsDominant(Actor who)
	If who == None
		Return false
	EndIf
	Int i = 0
	While i < 5
		SSM_Slot s = SlotAt(i)
		If s != None && s.IsRunning()
			If s.Dominant() == who || s.Pinned() == who
				Return true
			EndIf
		EndIf
		i += 1
	EndWhile
	Return false
EndFunction

Bool Function IsSlaveOfAnyone(Actor who)
	If who == None
		Return false
	EndIf
	Int i = 0
	While i < 5
		SSM_Slot s = SlotAt(i)
		If s != None && s.IsRunning()
			If s.HasSlave(who)
				Return true
			EndIf
		EndIf
		i += 1
	EndWhile
	Return false
EndFunction

Bool Function PinnedElsewhere(SSM_Slot selfSlot, Actor who)
	If who == None
		Return false
	EndIf
	Int i = 0
	While i < 5
		SSM_Slot s = SlotAt(i)
		If s != None && s != selfSlot && s.IsRunning()
			If s.Dominant() == who || s.Pinned() == who
				Return true
			EndIf
		EndIf
		i += 1
	EndWhile
	Return false
EndFunction

String Function Roster()
	String result = ""
	Int i = 0
	While i < 5
		SSM_Slot s = SlotAt(i)
		If s != None && s.IsRunning()
			Actor a = s.Dominant()
			If a == None
				a = s.Pinned()
			EndIf
			If a != None
				If result != ""
					result = result + ", "
				EndIf
				result = result + a.GetDisplayName()
			EndIf
		EndIf
		i += 1
	EndWhile
	Return result
EndFunction

Function UpdateRoster()
	SetModSettingString("sRoster:General", Roster())
EndFunction

; MCM button: shows each dominant's slaves in a message box. Reads only; writes no setting.
Function ShowSlaves()
	String text = ""
	Int i = 0
	While i < 5
		SSM_Slot s = SlotAt(i)
		If s != None && s.IsRunning()
			Actor a = s.Dominant()
			If a == None
				a = s.Pinned()
			EndIf
			If a != None
				String names = s.SlaveNames()
				If names == ""
					names = "-"
				EndIf
				If text != ""
					text = text + "\n"
				EndIf
				text = text + a.GetDisplayName() + " (" + s.SlaveTotal() + "/10): " + names
			EndIf
		EndIf
		i += 1
	EndWhile
	If text == ""
		Debug.MessageBox("$SSM_NoSlaves")
		Return
	EndIf
	Debug.MessageBox(text)
EndFunction

; ---------------------------------------------------------------- crosshair

Function AddCrosshair()
	Actor player = Game.GetPlayer()
	Actor target = Game.GetCurrentCrosshairRef() as Actor
	If target == None || target == player
		Debug.Notification("$SSM_NoTarget")
		Return
	EndIf
	If target.IsChild()
		Debug.Notification("$SSM_Child")
		Return
	EndIf
	If !target.IsPlayerTeammate()
		Debug.Notification("$SSM_NotFollower")
		Return
	EndIf

	Int i = 0
	While i < 5
		SSM_Slot s = SlotAt(i)
		If s != None && s.IsRunning()
			If s.Dominant() == target
				Debug.Notification("$SSM_Already")
				Return
			EndIf
		EndIf
		i += 1
	EndWhile
	If IsSlaveOfAnyone(target)
		Debug.Notification("$SSM_Already")
		Return
	EndIf

	; already pinned on a running slot (alias lost after load): repair, do not Arm
	i = 0
	While i < 5
		SSM_Slot s2 = SlotAt(i)
		If s2 != None && s2.IsRunning()
			If s2.Pinned() == target
				s2.Repair()
				UpdateRoster()
				Debug.Notification("$SSM_Added")
				Return
			EndIf
		EndIf
		i += 1
	EndWhile

	SSM_Slot free = None
	i = 0
	While i < 5 && free == None
		SSM_Slot s3 = SlotAt(i)
		If s3 != None && !s3.IsRunning()
			free = s3
		EndIf
		i += 1
	EndWhile
	If free == None
		Debug.Notification("$SSM_Full")
		Return
	EndIf

	ReferenceAlias a = free.GetAlias(0) as ReferenceAlias
	If a == None
		Debug.Notification("$SSM_NoTarget")
		Return
	EndIf
	a.ForceRefTo(target)
	If !free.IsRunning()
		If !free.Start()
			a.Clear()
			Debug.Notification("$SSM_Full")
			Return
		EndIf
		; Start() may refill aliases, so fill again once the quest is running
		a.ForceRefTo(target)
	EndIf
	free.Arm()
	free.Pin(target)
	UpdateRoster()
	Debug.Notification("$SSM_Added")
EndFunction

Function RemoveCrosshair()
	Actor target = Game.GetCurrentCrosshairRef() as Actor
	If target == None
		Debug.Notification("$SSM_NoTarget")
		Return
	EndIf
	Int i = 0
	While i < 5
		SSM_Slot s = SlotAt(i)
		If s != None && s.IsRunning()
			If s.Dominant() == target || s.Pinned() == target
				s.Shutdown()
				s.Stop()
				If claimHolder == s
					claimHolder = None
				EndIf
				UpdateRoster()
				Debug.Notification("$SSM_Removed")
				Return
			EndIf
		EndIf
		i += 1
	EndWhile
	Debug.Notification("$SSM_NotListed")
EndFunction
