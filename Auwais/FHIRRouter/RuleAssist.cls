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
			Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT DISTINCT coreVersion FROM HS_FHIRMeta_Storage.Rsrc")
			While tRS.%Next() {
				Set tVal = tVal _ "," _ tRS.%Get("coreVersion")
			}
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
	Set autocomplete = ##class(Auwais.FHIRPath.Autocomplete).%New(pArray("resourceFilter"))
	Set pSearch = pText
	Set:pSearch="" pSearch = pArray("segName")
	Set pathList = autocomplete.Suggest(pSearch)
	Set tVal = ""
	For k=1:1:pathList.Size {
		Set tVal = tVal _ "," _ pathList.GetAt(k)
	}
	Return tVal
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

ClassMethod RuntimeConstraintCheck(ByRef pArray, pContext, Output pPassed) As %Status
{
	set pArray("msgClass")="Ens.StreamContainer"
	Do ##super(.pArray,pContext,.pPassed)
	Quit pPassed
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
