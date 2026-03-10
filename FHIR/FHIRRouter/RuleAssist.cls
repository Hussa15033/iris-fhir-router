/// 
/// The RuleAssist class provides metadata to the rules editor over http
/// Modify RuntimeConstraintsCheck() to add additional checks at runtime
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRRouter.RuleAssist Extends EnsLib.MsgRouter.RuleAssist
{

ClassMethod GetMetaData() As %String
{
	Quit "source:Source:#configname,FHIRPackage:FHIR Package:#query,resourceFilter:Resource Filter:#query"
}

ClassMethod GetDescription() As %String
{
	quit "FHIR R4 Routing Rule"
}

ClassMethod GetContextClass() As %String
{
	quit "FHIR.FHIRRouter.RoutingEngine"
}

ClassMethod GetIsRoutingRule() As %String
{
	quit 1
}

ClassMethod GetQueryData(ByRef pArray, pParam) As %String
{
	Set tVal=""
	Try {
		If pParam="FHIRPackage" {
			
			Set tRS = ##class(%SQL.Statement).%ExecDirectNoPrivNoAudit(,"SELECT id FROM HS_FHIRMeta_Storage.Package")
			While tRS.%Next() {
				Set tVal = tVal _ "," _ tRS.%Get("id")
			}
		} ElseIf pParam="resourceFilter" {
			/// Select the core version this package depends on
			Set tResourceVersion = $G(pArray("FHIRPackage"))
			Quit:tResourceVersion="Nope"

			Set tRS = ##class(%SQL.Statement).%ExecDirectNoPrivNoAudit(,"SELECT coreVersion FROM HS_FHIRMeta_Storage.Package WHERE id=?", tResourceVersion)
			Do tRS.%Next()
			Set coreVersion = tRS.%Get("coreVersion")

			Set tRS = ##class(%SQL.Statement).%ExecDirectNoPrivNoAudit(,"SELECT id FROM HS_FHIRMeta_Storage.Rsrc WHERE kind='resource' AND coreVersion=? AND type=id", coreVersion)
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
	Set autocomplete = ##class(FHIR.FHIRPath.Autocomplete).%New($G(pArray("FHIRPackage")))
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

ClassMethod RuntimeConstraintCheck(ByRef pArray, pContext, Output pPassed = 0) As %Status
{
	Set pPassed = 0
	Set pArray("msgClass")=$CASE(pContext.MsgClass, "Ens.StreamContainer":"Ens.StreamContainer", "HS.Message.FHIR.Request":"HS.Message.FHIR.Request", :"")

	Set tSource=$G(pArray("source"))
	If (""'=tSource&&(tSource'=pContext.Source)) {
		Set pArray("constraintErrorMsg") = "Message source is not '" _ tSource _ "'"
		Quit $$$OK
	}

	
	Set tMsgClass=$G(pArray("msgClass")) 
	If (""'=tMsgClass&&(tMsgClass'=pContext.MsgClass)) {
		Set pArray("constraintErrorMsg") = "Message class is not valid"
		Quit $$$OK
	}

	/// Runtime constraint to check the FHIR resource is valid
	If ('$ISOBJECT(pContext.FHIRJSON)) || '$METHOD(pContext.FHIRJSON, "%Extends", "%DynamicObject") {
		Set pArray("constraintErrorMsg") = "Message does not contain valid JSON object"
		Quit $$$OK
	}

	If (pContext.FHIRJSON.%Get("resourceType") = "") {
		Set pArray("constraintErrorMsg") = "Resource type not found in FHIR data"
		Quit $$$OK
	}

	Set resourceFilter = $G(pArray("resourceFilter"))
	If (resourceFilter '= "") && ($ZCVT(pContext.FHIRJSON.resourceType, "U") '= $ZCVT(resourceFilter, "U")) {
		Set pArray("constraintErrorMsg") = "Resource is not of type '" _ resourceFilter _ "'"
		Quit $$$OK
	}
	
	/// If we reach here, the message is valid and satisfies the constraints set
	Set pPassed = 1
	Quit $$$OK
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
	return {
		"type":"object",
		"properties": {
			"target": {
				"type":"string"
			},
			"FHIRPath": {
				"type":"string"
			},
			"type": {
				"const":"send"
			}
		}
	}
	return ##class(EnsLib.MsgRouter.RuleAssist).GenerateSendSchema()
}

ClassMethod GenerateReturnSchema()
{
	return ##class(EnsLib.MsgRouter.RuleAssist).GenerateReturnSchema()
}

}
