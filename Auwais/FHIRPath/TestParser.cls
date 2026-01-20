/// /
/// This class is used for testing the FHIRPath Parser
/// It contains various test cases to see if
/// the autocompletion feature works
Class Auwais.FHIRPath.TestParser Extends %RegisteredObject
{

ClassMethod RunOneTest(pI, pSearchTerm, pSuggestion) As %Boolean
{
		Write "Running test " _ pI _ "(" _ pSearchTerm _ ")"
		Set ^AFPTests = ^AFPTests + 1
		/// Run a search term and ensure pSuggestion is in the list of suggestions returned
		Try {
			Set isNegativeTest = 0
			If ($EXTRACT(pSuggestion, 1, 1) = "!") {
				Set pSuggestion = $EXTRACT(pSuggestion, 2, *)
				Set isNegativeTest = 1
			}
			Set autocomplete = ##class(Auwais.FHIRPath.Autocomplete).%New()
			Set suggestionList = autocomplete.Suggest(pSearchTerm)

			Set found = suggestionList.Find(pSuggestion) '= ""
		} Catch ex {
			Set found = ""
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

ClassMethod Test()
{
	
	Kill ^AFPTests
	Kill ^AFPTestsSuccess
	Set ^AFPTests = 0
	Set ^AFPTestsSuccess = 0
	Do ..RunOneTest(56, "Pat", "Patient.")
	Do ..RunOneTest(57, "Pa", "Parameters.")
	Do ..RunOneTest(58, "Bundle.entry.resource.ofType(Patient).gend", "gender.")
	Do ..RunOneTest(1, "Patient.", "name.")
	Do ..RunOneTest(2, "Patient.", "telecom.")
	Do ..RunOneTest(3, "Patient.na", "name.")
	Do ..RunOneTest(4, "Patient.name.", "where(")
	Do ..RunOneTest(5, "Patient.telecom.where(system='phone' and use='mobile').", "value.")
	Do ..RunOneTest(6, "Patient.identifier.where(", "system")
	Do ..RunOneTest(7, "Patient.identifier.where(sys", "system")
	Do ..RunOneTest(8, "Patient.bi", "birthDate.")
	Do ..RunOneTest(9, "Patient.nAm", "name.")
	Do ..RunOneTest(10, "Patient.name.t", "text.")
	Do ..RunOneTest(11, "Patient.name.text.fir", "first()")
	Do ..RunOneTest(12, "Patient.name.text.first().", "substring")
	Do ..RunOneTest(13, "Patient.telecom.where(system='phone' and use='mobile').", "first()")
	Do ..RunOneTest(14, "Patient.telecom.where(system='phone' and use='mobile').", "last()")
	Do ..RunOneTest(15, "Patient.telecom.where(system='phone' and use='mobile').first().", "value.")
	Do ..RunOneTest(16, "Practitioner.nam", "name[")
	Do ..RunOneTest(17, "Practitioner.nam", "name.")
	Do ..RunOneTest(18, "Questionnaire.descendan", "descendants()")
	Do ..RunOneTest(19, "Observation.component.where(value.as(Qu", "Quantity)")
	Do ..RunOneTest(20, "Patient.name.give", "given")
	Do ..RunOneTest(21, "Patient.name.given.ex", "!extension(")
	Do ..RunOneTest(22, "Patient.name.given.h", "!hasExtension(")
	Do ..RunOneTest(23, "Patient.mu", "multipleBirthInteger")
	Do ..RunOneTest(24, "Patient.de", "deceasedDateTime")
	Do ..RunOneTest(25, "Observation.val", "valueInteger")
	Do ..RunOneTest(26, "Observation.value.a", "aggregate")
	Do ..RunOneTest(27, "Observation.value.aggregate(", "$this")
	Do ..RunOneTest(28, "Observation.value.aggregate(", "iif")
	Do ..RunOneTest(29, "Observation.value.aggregate(iif(", "$total")
	Do ..RunOneTest(30, "Observation.value.aggregate(iif($total.", "empty()")
	Do ..RunOneTest(12, "Patient.name.text.first().", "indexOf(")
	Do ..RunOneTest(32, "Observation.component.where(value.", "as(")
	Do ..RunOneTest(33, "Condition.abatement.i", "is(")
	Do ..RunOneTest(34, "Condition.abatement.is(", "dateTime")
	Do ..RunOneTest(35, "Bundle.entry.resource.ofType(Patient).gender.n", "not()")
	Do ..RunOneTest(36, "Bundle.entry.resource.ofType(P", "Patient")
	Do ..RunOneTest(37, "Organization.partOf.re", "resolve()")
	Do ..RunOneTest(38, "Bundle.entry.resource.ofType(Encounter).s", "skip(")
	Do ..RunOneTest(39, "'abcdefg'.star", "startsWith(")
	Do ..RunOneTest(40, "Bundle.entry.resource.ofType(Observation).t", "tail()")
	Do ..RunOneTest(41, "Patient.name.tak", "take(")
	Do ..RunOneTest(42, "Practitioner.name.family.unio", "union(")
	Do ..RunOneTest(43, "Practitioner.name.family.union(P", "Practitioner")
	Do ..RunOneTest(44, "Practitioner.name.family.union(Practitioner.", "id")
	Do ..RunOneTest(45, "Bundle.entry.resource.ofType(P", "Patient")
	Do ..RunOneTest(46, "Patient.telecom.wher", "where(")
	Do ..RunOneTest(47, "Patient.telecom.where(", "use")
	Do ..RunOneTest(48, "Patient.telecom.where(use", "=")
	Do ..RunOneTest(49, "Patient.telecom.where(1 > -1).first()", "")
	Do ..RunOneTest(50, "Patient.telecom.where(1 and 1).first()", "")
	Do ..RunOneTest(51, "Patient.telecom.where(1 or 0).first()", "")
	Do ..RunOneTest(52, "Practitioner.name[1].family != 'Smith'", "")
	Do ..RunOneTest(53, "Practitioner.name.family | Pra", "Practitioner")
	Do ..RunOneTest(54, "true and fal", "false")
	Do ..RunOneTest(55, "Practitioner.name[0].family = 'Cooper'", "")
	Set percentPassed = $NUMBER((^AFPTestsSuccess / ^AFPTests) * 100, 1)
	Write !,"Tests passed: " _ ^AFPTestsSuccess _ " / " _ ^AFPTests _ "(" _ percentPassed _ "%)",!
}

}
