Scriptname SSM_Lines Hidden

String Function Text(Int lineId, String victimName) Global
	If lineId == 1
		Return "You are alone with the player. Demand, in your own words, that the player become your sex slave. Draw on your recent memories, events, and conversations with the player. Speak one short line to the player. Do not describe actions."
	ElseIf lineId == 2
		Return "The player just submitted to you sexually. Demand that they deceive a second person and bring that person to you, so you can make that person a sex slave as well. Draw on your recent memories and what just happened. Speak one short line to the player. Do not describe actions."
	ElseIf lineId == 3
		Return "You are alone with the player and the people you already own. You are about to force " + victimName + " again. Say one short line that makes that intent plain, drawing on your recent memories and conversations. Speak only the line."
	ElseIf lineId == 4
		Return "The player brought " + victimName + " here. You are indoors with the player, " + victimName + ", and no one else except people you already own. Praise the player for deceiving this person into coming. Declare that you will make " + victimName + " your sex slave. Draw on your recent memories. Speak one short line. Do not describe actions."
	ElseIf lineId == 5
		Return "You are a guard. You just caught " + victimName + " stealing, and you are arresting them for theft. Say one short line to " + victimName + " that makes the arrest plain. Do not describe actions."
	ElseIf lineId == 7
		Return "You are not a guard. The guards are busy, so you are taking " + victimName + " to jail yourself. You just caught them stealing. Say one short line to " + victimName + " that makes that plain. Do not describe actions."
	ElseIf lineId == 6
		Return "You are about to force " + victimName + " as a jail sentence. Say, in one short line, that this is the punishment. Draw on your recent memories and conversations. Do not describe actions."
	EndIf
	Return ""
EndFunction

String Function SceneTags(Int sceneId) Global
	If sceneId >= 1 && sceneId <= 3
		Return "Aggressive"
	ElseIf sceneId == 4
		Return "Aggressive"
	EndIf
	Return ""
EndFunction
