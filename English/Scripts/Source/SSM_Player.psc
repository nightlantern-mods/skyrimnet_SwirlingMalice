Scriptname SSM_Player extends ReferenceAlias

Event OnInit()
	RegisterForSingleUpdate(5.0)
EndEvent

Event OnPlayerLoadGame()
	SSM_Main m = GetOwningQuest() as SSM_Main
	If m != None
		m.OnGameLoad()
	EndIf
	RegisterForSingleUpdate(5.0)
EndEvent

Event OnUpdate()
	SSM_Main m = GetOwningQuest() as SSM_Main
	If m != None
		m.Tick()
	EndIf
	RegisterForSingleUpdate(5.0)
EndEvent
