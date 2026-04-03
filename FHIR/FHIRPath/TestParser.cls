/// /
/// This class is used for testing the FHIRPath Parser
/// It contains various test cases to see if the autocompletion feature works
/// as expected.
/// 
/// Run via
/// 	##class(FHIR.FHIRPath.TestParser).Run()
/// 
/// To debug and run a specific test case, use:
/// 	##class(FHIR.FHIRPath.TestParser).Run(1, <test-case-number>)
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.TestParser Extends %RegisteredObject
{

ClassMethod RunOneTest(pI, pSearchTerm, pSuggestion, pPackage = "hl7.fhir.r4.core@4.0.1", pResourceFilter = "") As %Boolean
{
		Quit:(^AFPTestNumber'="")&&(pI'=^AFPTestNumber) 0
		Write "Running test " _ pI _ "(" _ pSearchTerm _ ")"
		
		Set $ECODE = ""
		Set ^AFPTests = ^AFPTests + 1
		/// Run a search term and ensure pSuggestion is in the list of suggestions returned
		Try {
			Set isNegativeTest = 0
			If ($EXTRACT(pSuggestion, 1, 1) = "!") {
				Set pSuggestion = $EXTRACT(pSuggestion, 2, *)
				Set isNegativeTest = 1
			}
			Set autocomplete = ##class(FHIR.FHIRPath.Autocomplete).%New(pPackage, pResourceFilter)

			Set suggestionList = autocomplete.Suggest(pSearchTerm)

			Set found = suggestionList.Find(pSuggestion) '= ""

			If (pSuggestion = "") {
				Set found = (suggestionList.Size = 0)
			}

			zw:^AFPDEBUG suggestionList
		} Catch ex {
			W:^AFPDEBUG "Exception occurred"
			W:^AFPDEBUG ex.DisplayString()
	
			If $LF($LISTFROMSTRING($EC), "ZINTERRUPT") {
				Write !,!,"Tests interrupted"
				Throw ex
			}
			Set found = ""
			W " - Exception occurred",!
			Return 0
		}

		If (^AFPDEBUG) {
			Write !," Expression: " _ pSearchTerm,!
			Write "==> Expected suggestion: '" _ pSuggestion _ "'",!
			Write "==> Package: " _ pPackage,!
			Write "==> Resource filter: " _ pResourceFilter,!
		}

		/// If the test is negative 
		If (found && 'isNegativeTest) || ('found && isNegativeTest) {
			Set ^AFPTestsSuccess = ^AFPTestsSuccess + 1
			Write " - Success",!
			Return 1
		} Else {
			Write " - **Failed",!
			Return 0
		}
}

ClassMethod Test(pDebug = 0, pTestNumber = "")
{
	Kill ^AFPDEBUG
	Kill ^AFPTests
	Kill ^AFPTestsSuccess
	Kill ^AFPTestNumber
	Set ^AFPTests = 0
	Set ^AFPTestsSuccess = 0
	Set ^AFPTestNumber = pTestNumber
	Set ^AFPDEBUG = pDebug
	Set startTime = $ZHOROLOG
	Do ..RunOneTest(1, "Patient.", "name.")
	Do ..RunOneTest(2, "Patient.", "telecom.")
	Do ..RunOneTest(3, "Patient.na", "name.")
	Do ..RunOneTest(4, "Patient.name.", "where(")
	Do ..RunOneTest(5, "Patient.telecom.where(system='phone' and use='mobile').", "value.")
	Do ..RunOneTest(6, "Patient.identifier.where(", "system")
	Do ..RunOneTest(7, "Patient.identifier.where(sys", "system")
	Do ..RunOneTest(8, "Patient.bi", "birthDate.")
	Do ..RunOneTest(9, "Patient.nAm", "")
	Do ..RunOneTest(10, "Patient.name.t", "text.")
	Do ..RunOneTest(11, "Patient.name.text.fir", "first()")
	Do ..RunOneTest(12, "Patient.name.text.first().", "substring(")
	Do ..RunOneTest(13, "Patient.telecom.where(system='phone' and use='mobile').", "first()")
	Do ..RunOneTest(14, "Patient.telecom.where(system='phone' and use='mobile').", "last()")
	Do ..RunOneTest(15, "Patient.telecom.where(system='phone' and use='mobile').first().", "value.")
	Do ..RunOneTest(16, "Practitioner.nam", "name[")
	Do ..RunOneTest(17, "Practitioner.nam", "name.")
	Do ..RunOneTest(18, "Questionnaire.descendan", "descendants()")
	Do ..RunOneTest(19, "Observation.component.where(value.as(Qu", "Quantity)")
	Do ..RunOneTest(20, "Patient.name.give", "given.")
	Do ..RunOneTest(21, "Patient.name.given.ex", "extension.")
	#; Do ..RunOneTest(22, "Patient.name.given.h", "hasExtension(") /// Not a valid function(?)
	Do ..RunOneTest(23, "Patient.mu", "multipleBirthInteger.")
	Do ..RunOneTest(24, "Patient.de", "deceasedDateTime.")
	Do ..RunOneTest(25, "Observation.val", "valueInteger.")
	#; Do ..RunOneTest(26, "Observation.value.a", "aggregate.")
	Do ..RunOneTest(27, "Observation.value.aggregate(", "$this")
	Do ..RunOneTest(28, "Observation.value.aggregate(", "iif(")
	Do ..RunOneTest(29, "Observation.value.aggregate(iif(", "$total")
	Do ..RunOneTest(30, "Observation.value.aggregate(iif($total.", "empty()")
	Do ..RunOneTest(31, "Patient.name.text.first().", "indexOf(")
	Do ..RunOneTest(32, "Observation.component.where(value.", "as(")
	Do ..RunOneTest(33, "Condition.abatement.i", "is(")
	Do ..RunOneTest(34, "Condition.abatement.is(", "dateTime")
	Do ..RunOneTest(35, "Bundle.entry.resource.ofType(Patient).gender.n", "!not()")
	Do ..RunOneTest(36, "Bundle.entry.resource.ofType(P", "Patient")
	Do ..RunOneTest(37, "Organization.partOf.re", "resolve()")
	Do ..RunOneTest(38, "Bundle.entry.resource.ofType(Encounter).s", "skip(")
	Do ..RunOneTest(39, "'abcdefg'.star", "startsWith(", "Patient")
	Do ..RunOneTest(40, "Bundle.entry.resource.ofType(Observation).t", "tail()")
	Do ..RunOneTest(41, "Patient.name.tak", "take(")
	Do ..RunOneTest(42, "Practitioner.name.family.unio", "union(")
	Do ..RunOneTest(43, "Practitioner.name.family.union(P", "Practitioner")
	Do ..RunOneTest(44, "Practitioner.name.family.union(Practitioner.", "id")
	Do ..RunOneTest(45, "Bundle.entry.resource.ofType(P", "Patient")
	Do ..RunOneTest(46, "Patient.telecom.wher", "where(")
	Do ..RunOneTest(47, "Patient.telecom.where(", "use")
	#; Do ..RunOneTest(48, "Patient.telecom.where(use", "=")
	Do ..RunOneTest(49, "Patient.telecom.where(1 > -1).first().", "use.")
	Do ..RunOneTest(50, "Patient.telecom.where(1 and 1).first().", "value.")
	Do ..RunOneTest(51, "Patient.telecom.where(1 or 0).first()", "")
	Do ..RunOneTest(52, "Practitioner.name[1].family != 'Smith'", "")
	Do ..RunOneTest(53, "Practitioner.name.family | Pra", "Practitioner.")
	#; Do ..RunOneTest(54, "true and fal", "false")
	Do ..RunOneTest(55, "Practitioner.name[0].family = 'Cooper'", "")
		Do ..RunOneTest(56, "Pat", "Patient.")
	Do ..RunOneTest(57, "Pa", "Parameters.")
	Do ..RunOneTest(58, "Bundle.entry.resource.ofType(Patient).gend", "gender.")
	Do ..RunOneTest(59, "Patient.name.given.f", "first()")
	Do ..RunOneTest(60, "Observation.component.where(value.as(Quantity.v", "")
	Do ..RunOneTest(61, "Observation.component.where(value.as(", "string)")
	Do ..RunOneTest(62, "Observation.component.where(value.as(", "Ratio)")
	Do ..RunOneTest(63, "Observation.component.where(value.as(p", "")
	Do ..RunOneTest(64, "Observation.component.where(value.a", "as(")
	Do ..RunOneTest(65, "Observation.component.where(value.OfTy", "")
	Do ..RunOneTest(66, "Observation.component.where(value.ofTy", "ofType(")
	Do ..RunOneTest(67, "Observation.component.where(value.as(P", "Period)")
	Do ..RunOneTest(68, "Observation.component.where(value as Qu", "Quantity")
	Do ..RunOneTest(69, "true or false", "",, "Patient")
	Do ..RunOneTest(70, "true xor false", "",, "Patient")
	Do ..RunOneTest(71, "true implies false", "",, "Patient")
	Do ..RunOneTest(72, "Practitioner.name[0] is Huma", "HumanName")
	Do ..RunOneTest(73, "'string1' & ' and ' & 'string2'", "",, "Patient")
	Do ..RunOneTest(74, "5 seconds + 3 seconds", "",, "Patient")
	Do ..RunOneTest(75, "Patient.contact.telecom.where(use = 'official').ex", "exists()")
	Do ..RunOneTest(76, "Patient.contact.telecom.where(use = 'official').ex", "!not()")
	Do ..RunOneTest(77, "Patient.contact.telecom.where(use = 'official').exists().", "not()")
	Do ..RunOneTest(78, "Practitioner.name.family.union(", "id")
	Do ..RunOneTest(79, "Patient.name | Bundle.", "!active.")
	Do ..RunOneTest(80, "Patient.telecom.where(use=", "'home'")
	Do ..RunOneTest(81, "Patient.telecom.where(use=", "'work'")
	Do ..RunOneTest(82, "Patient.telecom.where(use=", "'temp'")
	Do ..RunOneTest(83, "Patient.telecom.where(use='home' ", "and")
	Do ..RunOneTest(84, "Patient.telecom.where(use='old' ", "or")
	Do ..RunOneTest(85, "Patient.telecom.where(use='mobile' or system=", "'phone'")
	/// Commented some of the below tests as not possible to do mid-literal parsing currently 24.03.2026
	#; Do ..RunOneTest(86, "Patient.telecom.where(use='mobile' or system='p", "hone'")
	Do ..RunOneTest(87, "Patient.identifier.where(system=", "'https://fhir.nhs.uk/Id/nhs-number'", "fhir.r4.ukcore.stu3.currentbuild@0.25.0-pre-release")
	Do ..RunOneTest(88, "Patient.identifier.where(system=", "!'https://fhir.nhs.uk/Id/nhs-number'")
	#; Do ..RunOneTest(89, "Patient.identifier.where(system='https://f", "hir.nhs.uk/Id/nhs-number'", "fhir.r4.ukcore.stu3.currentbuild@0.25.0-pre-release")
	Do ..RunOneTest(90, "Patient.identifier.extension(", "'https://fhir.hl7.org.uk/StructureDefinition/Extension-UKCore-NHSNumberVerificationStatus'", "fhir.r4.ukcore.stu3.currentbuild@0.25.0-pre-release")
	Do ..RunOneTest(91, "Patient.identifier.extension(", "!'https://fhir.hl7.org.uk/StructureDefinition/Extension-UKCore-NHSNumberVerificationStatus'")
	#; Do ..RunOneTest(92, "Patient.identifier.extension('https://fhir.hl7.org.uk/Stru", "ctureDefinition/Extension-UKCore-NHSNumberVerificationStatus'", "fhir.r4.ukcore.stu3.currentbuild@0.25.0-pre-release")
	Do ..RunOneTest(93, "Patient.identifier.extension.where(url=", "'https://fhir.hl7.org.uk/StructureDefinition/Extension-UKCore-NHSNumberVerificationStatus'", "fhir.r4.ukcore.stu3.currentbuild@0.25.0-pre-release")
	#; Do ..RunOneTest(94, "Patient.identifier.extension.where(url='https://fhir.hl7.org.uk/Stru", "ctureDefinition/Extension-UKCore-NHSNumberVerificationStatus'", "fhir.r4.ukcore.stu3.currentbuild@0.25.0-pre-release")
	Do ..RunOneTest(95, "Patient.identifier.extension.where(url='https://fhir.hl7.org.uk/StructureDefinition/Extension-UKCore-NHSNumberVerificationStatus').where(value.coding.code=", "'01'", "fhir.r4.ukcore.stu3.currentbuild@0.25.0-pre-release")
	Do ..RunOneTest(96, "Patient.identifier.extension.where(url='https://fhir.hl7.org.uk/StructureDefinition/Extension-UKCore-NHSNumberVerificationStatus').where(value.coding.code=", "!'01'")
	Do ..RunOneTest(97, "ServiceRequest.category.coding.where(system=", "'https://fhir.hl7.org.uk/CodeSystem/UKCore-GenomeSequencingCategory'", "fhir.r4.ukcore.stu3.currentbuild@0.25.0-pre-release")
	Do ..RunOneTest(98, "ServiceRequest.category.coding.where(system='https://fhir.hl7.org.uk/CodeSystem/UKCore-GenomeSequencingCategory' and code=", "'cancer-wgs'", "fhir.r4.ukcore.stu3.currentbuild@0.25.0-pre-release")
	Do ..RunOneTest(99, "ServiceRequest.category.coding.where(system='https://fhir.hl7.org.uk/CodeSystem/UKCore-GenomeSequencingCategory' and code=", "!'cancer-wgs'")
	#; Do ..RunOneTest(100, "ServiceRequest.category.coding.where(system='https://fhir.hl7.org.uk/CodeSystem/UKCore-GenomeSequencingCategory' and code=", "!'cancer-wgs'")
	Do ..RunOneTest(101, "Observation.value.aggregate(iif(", "$this")
	Do ..RunOneTest(102, "Observation.component.where(value.as(Quantity) ", ">")
	Do ..RunOneTest(103, "Observation.component.where(value.as(Quantity) ", "<")
	Do ..RunOneTest(104, "Observation.component.where(value.as(Quantity) ", "=")
	Do ..RunOneTest(105, "Observation.component.where(value.as(Quantity) ", ">=")
	Do ..RunOneTest(106, "Observation.component.where(value.as(Quantity) ", "<=")
	Do ..RunOneTest(107, "Observation.component.where(value.as(Quantity) ", "!and")
	Do ..RunOneTest(108, "Observation.component.where(value.as(Quantity) ", "!or")
	Do ..RunOneTest(109, "Observation.component.where(value.as(Quantity) > 30 ", "'mg'")
	Do ..RunOneTest(110, "Observation.component.where(value.as(Quantity) > 30 'mg' ", "and")
	Do ..RunOneTest(111, "Observation.component.where(value.as(Quantity) > 30 'mg' ", "or")
	Do ..RunOneTest(112, "Observation.component.where(value.as(Quantity) > 30 'mg' ", "!<")
	Do ..RunOneTest(113, "Observation.component.where(value.as(Quantity) > 30 'mg' ", "!>")
	Do ..RunOneTest(114, "Observation.component.where(value.as(Quantity) > 30 'mg' ", "!<=")
	Do ..RunOneTest(115, "Observation.component.where(value.as(Quantity) > 30 'mg' ", "!>=")
	Do ..RunOneTest(116, "Observation.component.where((value.as(Quantity) > 30 'mg') and ", "code")
	Do ..RunOneTest(117, "Practitioner.name.family | Practi", "Practitioner.")
	Do ..RunOneTest(118, "Patient.telecom.where(use='mobile' and system=", "'phone'")
	Do ..RunOneTest(119, "Observation.component.where(value.as(Qua", "Quantity)")
	Do ..RunOneTest(120, "Observation.component.where(value is Qua", "Quantity")
	Do ..RunOneTest(121, "Patient.name.where(fa", "family")
	Do ..RunOneTest(122, "true and fal", "false",, "Patient")
	Do ..RunOneTest(123, "Patient.telecom.where(use='home' a", "and")
	Do ..RunOneTest(124, "(Bundle.entry.resource.ofType(Patient) | Bundle.entry.resource.ofType(Observation)).n", "name.")
	Do ..RunOneTest(125, "(Bundle.entry.resource.ofType(Patient) | Bundle.entry.resource.ofType(Observation)).bir", "birthDate.")
	Do ..RunOneTest(126, "(Bundle.entry.resource.ofType(Patient) | Bundle.entry.resource.ofType(Observation)).", "value.")
	Do ..RunOneTest(127, "(Bundle.entry.resource.ofType(Patient) | Bundle.entry.resource.ofType(Observation)).c", "code.")
	Do ..RunOneTest(128, "(Patient.name | Patient.address).", "use.")
	Do ..RunOneTest(129, "(Patient.name | Patient.address).", "first()")
	Do ..RunOneTest(130, "(Patient.name | Patient.address).giv", "given.")
	Do ..RunOneTest(131, "(Patient.name | Patient.address).giv", "!use.")
	Do ..RunOneTest(132, "(Patient.name | Patient.address).p", "postalCode.")
	Do ..RunOneTest(133, "(Patient.name.given | Patient.birthDate).", "substring(")
	Do ..RunOneTest(134, "Patient.union(Observation).", "meta.")
	Do ..RunOneTest(135, "Patient.name.union(Patient.address).", "text.")
	Do ..RunOneTest(136, "Patient.name.union(Patient.address).gi", "given.")
	Do ..RunOneTest(137, "Patient.name.union(Patient.address).", "city.")
	Do ..RunOneTest(138, "Patient.name.union(Patient.address).pos", "postalCode.")
	Do ..RunOneTest(139, "Practitioner.name.family.union(", "birthDate")
	Do ..RunOneTest(140, "Practitioner.name.family.union(", "address")

	
	
	
	Set percentPassed = $NUMBER((^AFPTestsSuccess / ^AFPTests) * 100, 1)
	Write !,"Tests passed: " _ ^AFPTestsSuccess _ " / " _ ^AFPTests _ "(" _ percentPassed _ "%)",!
	Write "Time taken for tests to run: " _ ($ZHOROLOG - startTime) _ " seconds"
}

}
