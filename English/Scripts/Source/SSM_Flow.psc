Scriptname SSM_Flow Hidden

Int Function TickAction(Int phase, Int adultCount, Bool dominantListed, Bool alone, Bool interior, Bool crowded, Bool groupOwned, Bool lureOk, Bool childHere, Float now, Float retryAt, Float nextRepeatAt) Global
	If phase == 1 || phase == 2
		Return 0
	EndIf
	If phase == 5
		If childHere
			Return 0
		EndIf
		Return 50
	EndIf
	If phase == 6
		If childHere
			Return 0
		EndIf
		Return 60
	EndIf
	If now < retryAt
		Return 0
	EndIf
	; hard rule: no speech is started while a child is present
	If childHere
		Return 0
	EndIf

	If phase == 0
		If alone
			Return 11
		EndIf
		Return 0
	EndIf
	If phase == 3
		If dominantListed
			Return 12
		EndIf
		Return 0
	EndIf
	If phase == 4
		If groupOwned && now >= nextRepeatAt
			Return 13
		ElseIf lureOk
			Return 14
		EndIf
		Return 0
	EndIf
	Return 0
EndFunction

Int Function AfterSpeech(Int lineId, Bool childHere) Global
	If lineId == 2
		If childHere
			Return 6
		EndIf
		Return 4
	ElseIf lineId == 1
		Return 21
	ElseIf lineId == 3
		Return 22
	ElseIf lineId == 4
		Return 23
	EndIf
	Return 0
EndFunction

Int Function AfterScene(Int sceneProfile, Bool childHere) Global
	If sceneProfile == 1
		Return 3
	ElseIf sceneProfile == 2
		Return 4
	ElseIf sceneProfile == 3
		If childHere
			Return 5
		EndIf
		Return 7
	EndIf
	Return 4
EndFunction

Int Function PhaseAfterSpeechFailure(Int lineId) Global
	If lineId == 1
		Return 0
	ElseIf lineId == 2
		Return 3
	EndIf
	Return 4
EndFunction

Int Function PhaseAfterSceneFailure(Int sceneProfile) Global
	If sceneProfile == 1
		Return 0
	EndIf
	Return 4
EndFunction
