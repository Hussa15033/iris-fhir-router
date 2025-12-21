/// /
/// This class is used for testing the FHIRPath Parser
/// It contains various test cases to see if
/// the autocompletion feature works
Class Auwais.FHIRPath.TestParser Extends %RegisteredObject
{

ClassMethod RunOneTest(pI, pSearchTerm, pSuggestion) As %Boolean
{
		Write "Running test " _ pI
		/// Run a search term and ensure pSuggestion is in the list of suggestions returned
		Set autocomplete = ##class(Auwais.FHIRPath.Autocomplete).%New()
		Set suggestionList = autocomplete.Suggest(pSearchTerm)

		Set success = suggestionList.Find(pSuggestion) '= ""

		If (success) {
			Write " - Success",!
			Return 1
		} Else {
			Write " - **Failed",!
			Return 0
		}
}

ClassMethod Test()
{
	Do ..RunOneTest(1, "Patient.", "name.")
	Do ..RunOneTest(2, "Patient.", "telecom.")
	Do ..RunOneTest(3, "Patient.na", "name.")
	Do ..RunOneTest(4, "Patient.name.", "where(")
	Do ..RunOneTest(5, "Patient.telecom.where(system='phone' and use='mobile').", "value.")
	Do ..RunOneTest(6, "Patient.identifier.where(", "system")
	Do ..RunOneTest(7, "Patient.identifier.where(sys", "system")
	Do ..RunOneTest(8, "Patient.bi", "birthDate.")
	Do ..RunOneTest(9, "Patient.birthDate.", "toDate()")
	Do ..RunOneTest(10, "Patient.name.t", "text.")
	Do ..RunOneTest(11, "Patient.name.text.fir", "first()")
	Do ..RunOneTest(12, "Patient.name.text.first().", "substring")
}

}
