Class Auwais.FHIRRouter.RuleAssist Extends EnsLib.MsgRouter.RuleAssist
{

ClassMethod GetMetaData() As %String
{
	Quit "source:Source:#configname,FHIRVersion:FHIR Version:#query,resourceFilter:Resource Filter:#query"
}

ClassMethod GetDescription() As %String
{
	quit "FHIR R4 Routing Rule"
}

ClassMethod GetContextClass() As %String
{
	quit "Auwais.FHIRRouter.RoutingEngine"
}

ClassMethod GetIsRoutingRule() As %String
{
	quit 1
}

ClassMethod GetQueryData(ByRef pArray, pParam) As %String
{
	Set tVal=""
	Try {
		If pParam="FHIRVersion" {
			Set tVal = tVal _ ",4.0.1"
		} ElseIf pParam="resourceFilter" {
			Set tResourceVersion = $G(pArray("FHIRVersion"))
			Quit:tResourceVersion=""

			Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT id FROM HS_FHIRMeta_Storage.Rsrc WHERE kind='resource' AND coreVersion=? AND type=id", tResourceVersion)
			While (tRS.%Next()) {
				Set tVal = tVal _ "," _ tRS.%Get("id")
			}
		}
	} Catch {
	}
	Quit $E(tVal,2,*)
}

ClassMethod GetPropertyList(ByRef pArray, pText) As %String
{
	#; Return "," _ pArray("segName") _ ",test"
	Set autocomplete = ##class(Auwais.FHIRPath.Autocomplete).%New()
	Set pSearch = pText
	Set:pSearch="" pSearch = pArray("segName")
	Set pathList = autocomplete.Suggest(pSearch)
	Set tVal = ""
	For k=1:1:pathList.Size {
		Set tVal = tVal _ "," _ pathList.GetAt(k)
	}
	Return tVal
}

ClassMethod RuntimeConstraintCheck(ByRef pArray, pContext, Output pPassed) As %Status
{
	#; Set pPassed=0
	#; Set tSource=$G(pArray("source"))  Quit:""'=tSource&&(tSource'=pContext.Source) $$$OK
	#; Set tMsgClass=$G(pArray("msgClass"))  Quit:""'=tMsgClass&&(tMsgClass'=pContext.MsgClass) $$$OK
	#; Set tDocNames=$G(pArray("docName")), tDocCategory=$G(pArray("docCategory"))
	#; Set cDocName=pContext.DocName, cDocType=pContext.DocType
	#; If ""=tDocCategory||(tDocCategory=$P(cDocType,":")) {
	#; 	#; loop over constraint tDocNames, comparing with context cDocName
	#; 	For n=1:1:$L(tDocNames,",") {
	#; 		Set tName=$P(tDocNames,",",n)
	#; 		Continue:""=tName&&(n>1)
	#; 		#; Perform the comparison between document name and constraint name, if present.
	#; 		#; For non-HL7 messages, the name constraint may refer to the DocTypeName, and so this is checked too. 
	#; 		Continue:""'=tName&&(tName'=cDocName)&&((pArray("msgClass")="EnsLib.HL7.Message")||(tName'=$P(cDocType,":",2)))
	#; 		Set pPassed=1
	#; 		Quit
	#; 	}
	#; }
	Quit $$$OK
}

/// Add constraint to user-visible properties of routing rule Rules
ClassMethod GenerateRuleSchema() As %DynamicObject
{
	set schema = ##super()
	set schema.properties.constraints = {
		"type": "array"
	}
	return schema
}

ClassMethod GetValidActions()
{
	return ##class(EnsLib.MsgRouter.RuleAssist).GetValidActions()
}

ClassMethod GenerateDelegateSchema()
{
	return ##class(EnsLib.MsgRouter.RuleAssist).GenerateDelegateSchema()
}

ClassMethod GenerateDeleteSchema() As %DynamicObject
{
	return ##class(EnsLib.MsgRouter.RuleAssist).GenerateDeleteSchema()
}

ClassMethod GenerateSendSchema()
{
	return ##class(EnsLib.MsgRouter.RuleAssist).GenerateSendSchema()
}

ClassMethod GenerateReturnSchema()
{
	return ##class(EnsLib.MsgRouter.RuleAssist).GenerateReturnSchema()
}

}
