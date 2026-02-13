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
			Set:tVal="" tVal = ",4.0.1"
		} ElseIf pParam="resourceFilter" {
			Set tResourceVersion = $G(pArray("FHIRVersion"))
			Quit:tResourceVersion=""

			Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT id FROM HS_FHIRMeta_Storage.Rsrc WHERE kind='resource' AND coreVersion=? AND type=id", tResourceVersion)
			While (tRS.%Next()) {
				Set tVal = tVal _ "," _ tRS.%Get("id")
			}

			Set:tVal="" tVal = $CASE(tResourceVersion, "4.0.1":",Account,ActivityDefinition,AdverseEvent,AllergyIntolerance,Appointment,AppointmentResponse,AuditEvent,Basic,Binary,BiologicallyDerivedProduct,BodyStructure,Bundle,CapabilityStatement,CarePlan,CareTeam,CatalogEntry,ChargeItem,ChargeItemDefinition,Claim,ClaimResponse,ClinicalImpression,CodeSystem,Communication,CommunicationRequest,CompartmentDefinition,Composition,ConceptMap,Condition,Consent,Contract,Coverage,CoverageEligibilityRequest,CoverageEligibilityResponse,DetectedIssue,Device,DeviceDefinition,DeviceMetric,DeviceRequest,DeviceUseStatement,DiagnosticReport,DocumentManifest,DocumentReference,DomainResource,EffectEvidenceSynthesis,Encounter,Endpoint,EnrollmentRequest,EnrollmentResponse,EpisodeOfCare,EventDefinition,Evidence,EvidenceVariable,ExampleScenario,ExplanationOfBenefit,FamilyMemberHistory,Flag,Goal,GraphDefinition,Group,GuidanceResponse,HealthcareService,ImagingStudy,Immunization,ImmunizationEvaluation,ImmunizationRecommendation,ImplementationGuide,InsurancePlan,Invoice,Library,Linkage,List,Location,Measure,MeasureReport,Media,Medication,MedicationAdministration,MedicationDispense,MedicationKnowledge,MedicationRequest,MedicationStatement,MedicinalProduct,MedicinalProductAuthorization,MedicinalProductContraindication,MedicinalProductIndication,MedicinalProductIngredient,MedicinalProductInteraction,MedicinalProductManufactured,MedicinalProductPackaged,MedicinalProductPharmaceutical,MedicinalProductUndesirableEffect,MessageDefinition,MessageHeader,MolecularSequence,NamingSystem,NutritionOrder,Observation,ObservationDefinition,OperationDefinition,OperationOutcome,Organization,OrganizationAffiliation,Parameters,Patient,PaymentNotice,PaymentReconciliation,Person,PlanDefinition,Practitioner,PractitionerRole,Procedure,Provenance,Questionnaire,QuestionnaireResponse,RelatedPerson,RequestGroup,ResearchDefinition,ResearchElementDefinition,ResearchStudy,ResearchSubject,Resource,RiskAssessment,RiskEvidenceSynthesis,Schedule,SearchParameter,ServiceRequest,Slot,Specimen,SpecimenDefinition,StructureDefinition,StructureMap,Subscription,Substance,SubstanceNucleicAcid,SubstancePolymer,SubstanceProtein,SubstanceReferenceInformation,SubstanceSourceMaterial,SubstanceSpecification,SupplyDelivery,SupplyRequest,Task,TerminologyCapabilities,TestReport,TestScript,ValueSet,VerificationResult,VisionPrescription",
			:"")
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

	If (pContext.FHIRJSON.%Get("resourceType") = "") || ($ZCVT(pContext.FHIRJSON.resourceType, "U") '= $ZCVT(pArray("resourceFilter"), "U")) {
		Set pArray("constraintErrorMsg") = "Resource is not of type '" _ pArray("resourceFilter") _ "'"
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
	return ##class(EnsLib.MsgRouter.RuleAssist).GenerateSendSchema()
}

ClassMethod GenerateReturnSchema()
{
	return ##class(EnsLib.MsgRouter.RuleAssist).GenerateReturnSchema()
}

}
