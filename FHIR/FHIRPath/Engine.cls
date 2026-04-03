Class FHIR.TypeAssist.Engine Extends %RegisteredObject
{

Property Loader As HS.FHIRMeta.Load.NpmLoader;

Method %OnNew(pLoader As HS.FHIRMeta.Load.NpmLoader) As %Status
{
	Set ..Loader = pLoader
	Return $$$OK
}

Method AddBooleanOperators(pSuggestions As %ListOfDataTypes) [ Private ]
{
	Do pSuggestions.Insert("and")
	Do pSuggestions.Insert("or")
	Do pSuggestions.Insert("xor")
	Do pSuggestions.Insert("implies")
}

Method AddComparisonOperators(pSuggestions As %ListOfDataTypes) [ Private ]
{
	Do pSuggestions.Insert("=")
	Do pSuggestions.Insert("!=")
	Do pSuggestions.Insert("<")
	Do pSuggestions.Insert(">")
	Do pSuggestions.Insert("<=")
	Do pSuggestions.Insert(">=")
}

Method AddFunctions(pSuggestions As %ListOfDataTypes) [ Private ]
{
	Do pSuggestions.Insert("exists()")
	Do pSuggestions.Insert("empty()")
	Do pSuggestions.Insert("first()")
	Do pSuggestions.Insert("last()")
	Do pSuggestions.Insert("tail()")
	Do pSuggestions.Insert("not()")
	Do pSuggestions.Insert("resolve()")
	Do pSuggestions.Insert("descendants()")

	Do pSuggestions.Insert("where(")
}

Method AddStringFunctions(pSuggestions As %ListOfDataTypes) [ Private ]
{
	Do pSuggestions.Insert("substring(")
	Do pSuggestions.Insert("startsWith(")
	Do pSuggestions.Insert("endsWith(")
	Do pSuggestions.Insert("indexOf(")
}

/// TODO: The prefix should be used to filter suggestions before returning them,
/// rather than returning all suggestions and filtering in the caller
Method Suggest(pScope As FHIR.FHIRPath.Context.Scope) As %ListOfDataTypes
{
	/// TODO: Clean up the logic within the function to other helper functions and perhaps using basic
	/// branches, based on how DataType and CompletionType are used
	/// This type assist engine uses the scope to determine what suggestions to provide
	Set suggestions = ##class(%ListOfDataTypes).%New()

	If (pScope.DataType = "BOOLEAN") && (pScope.CompletionType = "OPERATOR") {
		/// If the data type is boolean and we're looking for operators
		Do ..AddBooleanOperators(suggestions)
	}

	If (pScope.CompletionType = "FUNCTION") || (pScope.CompletionType = "ANY") {
		/// If we're looking for functions or operators, we add comparison operators and functions
		Do ..AddFunctions(suggestions)
	}

	If (pScope.DataType = "RESOURCE") && (pScope.FHIRType'="") {
		/// Find all properties of this resource type
		Set ctxHelper = ##class(FHIR.FHIRPath.FHIRContextHelper).%New(..Loader, pScope.FHIRType)
		Set desc = ctxHelper.FindImmediateDescendants(ctxHelper.GlobalRef)

		For i=1:1:$LL(desc) {
			Set cardinality = ctxHelper.FindCardinalityFromRef($LG(desc, i))
			Do suggestions.Insert(ctxHelper.GetFieldDisplayName($LG(desc, i)) _ ".")

			If (cardinality = "*") {
				Do suggestions.Insert(ctxHelper.GetFieldDisplayName($LG(desc, i)) _ "[")
			}
		}
	}
	If ((pScope.CompletionType = "TYPE") || (pScope.CompletionType = "ANY")) && (pScope.DataType = "FHIRTYPE") {
		Set ctxHelper = ##class(FHIR.FHIRPath.FHIRContextHelper).%New(..Loader, "Patient")
		Set ref = pScope.GlobalRef

		Set suggestions2 = ""
		Set suggestions2 = ctxHelper.FindImmediateDescendants(ref)

		/// Now find descendants of its type
		Set suggestions2 = suggestions2 _ ctxHelper.FindImmediateDescendants(ctxHelper.GetTypeRef(ref))
		Set suffix = ""

		If pScope.Function = "" {
			Set suffix = "."
		}
		For i=1:1:$LL(suggestions2) {
			Do suggestions.Insert(ctxHelper.GetFieldDisplayName($LG(suggestions2, i)) _ suffix)
		}

		Do suggestions.Insert("iif(")

		If $LF(pScope.FHIRType, "string") || $LF(pScope.FHIRType, "code") {
			Do ..AddStringFunctions(suggestions)
		}
	}

	If (pScope.CompletionType = "LITERALTYPE") {
		Set types = pScope.FHIRType
		Set suffix = ""
		If (pScope.Function '= "") {
			Set suffix = ")"
		}

		Set types = $LISTFROMSTRING($LISTTOSTRING(pScope.FHIRType))
		For i=1:1:$LL(types) {
			Do suggestions.Insert($LG(types, i) _ suffix)
		}
	}

	For i=1:1:$LL(pScope.ScopedVariables) {
		Do suggestions.Insert($LG(pScope.ScopedVariables, i))
	}
	Return suggestions
}

}
