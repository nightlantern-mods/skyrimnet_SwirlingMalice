Scriptname SSM_Speech Hidden

; 0 = success, 1 = failure
Int Function Send(Int lineId, Actor speaker, Actor hearer, String victimName) Global
	If speaker == None || hearer == None
		Return 1
	EndIf
	If speaker.IsChild() || hearer.IsChild()
		Return 1
	EndIf
	String content = SSM_Lines.Text(lineId, victimName)
	If content == ""
		Return 1
	EndIf
	Return SkyrimNetApi.DirectNarration(content, speaker, hearer)
EndFunction
