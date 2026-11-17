Scriptname SSM_Malice_TIF extends TopicInfo Hidden

;BEGIN FRAGMENT CODE - Do not edit anything between this and the end comment
;BEGIN FRAGMENT Fragment_0
Function Fragment_0(ObjectReference akSpeakerRef)
	(GetOwningQuest() as SSM_Malice).StartFrame(akSpeakerRef as Actor)
EndFunction
;END FRAGMENT
;END FRAGMENT CODE - Do not edit anything above this line, except for the CK fragment markers
