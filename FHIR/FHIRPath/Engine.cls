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

Method AddEqualityOperators(pSuggestions As %ListOfDataTypes) [ Private ]
{
	Do pSuggestions.Insert("=")
	Do pSuggestions.Insert("!=")
}

Method AddComparisonOperators(pSuggestions As %ListOfDataTypes) [ Private ]
{
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
	Do pSuggestions.Insert("resolve()")
	Do pSuggestions.Insert("descendants()")
	Do pSuggestions.Insert("single()")

	Do pSuggestions.Insert("where(")
	Do pSuggestions.Insert("as(")
	Do pSuggestions.Insert("is(")
	Do pSuggestions.Insert("ofType(")
	Do pSuggestions.Insert("skip(")
	Do pSuggestions.Insert("take(")
	Do pSuggestions.Insert("union(")
}

Method AddBooleanSingletonFunctions(pSuggestions As %ListOfDataTypes) [ Private ]
{
	Do pSuggestions.Insert("not()")
}

Method AddStringFunctions(pSuggestions As %ListOfDataTypes) [ Private ]
{
	Do pSuggestions.Insert("substring(")
	Do pSuggestions.Insert("startsWith(")
	Do pSuggestions.Insert("endsWith(")
	Do pSuggestions.Insert("indexOf(")
}

Method AddStringOperators(pSuggestions As %ListOfDataTypes) [Private] {
	Do pSuggestions.Insert("&")
}

Method AddBooleanIdentifiers(pSuggestions As %ListOfDataTypes) [Private] {
	Do pSuggestions.Insert("true")
	Do pSuggestions.Insert("false")
}

Method HasComparisonType(pTypes As %String) As %Boolean {
	Set comparisonTypes = $lb("integer","decimal","Quantity","date","dateTime","time","string")
	For i=1:1:$LL(comparisonTypes) {
		If $LF(pTypes, $LG(comparisonTypes, i)) {
			/// If the type is a valid ordering type
			Return 1
		}
	}

	Return 0
}

/// TODO: The prefix should be used to filter suggestions before returning them,
/// rather than returning all suggestions and filtering in the caller
Method Suggest(pScope As FHIR.FHIRPath.Context.Scope) As %ListOfDataTypes
{
	Set completionTypes = $LISTFROMSTRING(pScope.CompletionType)
	#define HasCT(%a)				$LF(completionTypes, %a)
	#define COP						$$$HasCT("OPERATOR")
	#define CANY					$$$HasCT("ANY")
	#define CPROP					$$$HasCT("PROPERTY")
	#define CFN						$$$HasCT("FUNCTION")
	#define CRESOURCE				$$$HasCT("RESOURCE")
	#define CTYPE					$$$HasCT("TYPE")
	#define CVAL					$$$HasCT("VALUE")
	#define CNONE					$$$HasCT("NONE")
	#define CBOOL					$$$HasCT("BOOLEAN")
	/// TODO: Clean up the logic within the function to other helper functions and perhaps using basic
	/// branches, based on how DataType and CompletionType are used
	/// This type assist engine uses the scope to determine what suggestions to provide
	Set suggestions = ##class(%ListOfDataTypes).%New()

	Return:$$$CNONE suggestions

	Set ctxHelper = ##class(FHIR.TypeAssist.FHIRContextHelper).%New(..Loader)

	If ($$$COP) {
		Do ..AddEqualityOperators(suggestions)

	
		Set hasComparisonTypes = ..HasComparisonType($LISTFROMSTRING(pScope.FHIRType))

		If (hasComparisonTypes) {
			Do ..AddComparisonOperators(suggestions)
		} Else {
			Do ..AddBooleanOperators(suggestions)
		}

		If ($LF(pScope.FHIRType, "string") || $LF(pScope.FHIRType, "code") || (pScope.DataType = "STRING")) {
			Do ..AddStringOperators(suggestions)
		}

		Return suggestions
	}

	/// TODO#3ERL: We need a consistent way of representing data stored in the scope. Use DataType="FHIRType" and
	/// FHIRType = "boolean" | "string" | ...
	If ($LF(pScope.FHIRType, "boolean")) {
		If (($$$CANY || $$$COP)) {
			Do ..AddBooleanOperators(suggestions)
		}

		If (($$$CANY || $$$CFN)) {
			Do ..AddBooleanSingletonFunctions(suggestions)
		}

		Return suggestions
	}

	If $$$CFN || $$$CANY {
		/// If we're looking for functions or operators, we add comparison operators and functions
		Do ..AddFunctions(suggestions)
	}

	If ($$$CANY) || (pScope.DataType = "") {
		Do ..AddBooleanIdentifiers(suggestions)
	}

	If (pScope.DataType = "RESOURCE") && (pScope.FHIRType'="") && ($LL(pScope.FHIRType) = 1) {
		/// Find all properties of this resource type
		Set desc = ##class(Utils).FindImmediateDescendants(pScope.GlobalRefs)

		For i=1:1:$LL(desc) {
			Set ref = $LG(desc, i)
			Set cardinality = ##class(Utils).FindMaxCardinality(ref)

			Do suggestions.Insert(ctxHelper.GetFieldDisplayName(ref) _ ".")

			If (cardinality = "*") {
				Do suggestions.Insert(ctxHelper.GetFieldDisplayName(ref) _ "[")
			}
		}
	}

	/// TODO: Make appropriate use of pScope.CompletionScope below
	If (($$$CPROP) || ($$$CANY) || ($$$CPROP)) && (pScope.DataType = "FHIRTYPE") {
		/// TODO: We don't need a context helper, but only used so we have access to the FindImmediateDescendants function
		Set refs = pScope.GlobalRefs

		Set suggestions2 = ##class(Utils).FindImmediateDescendants(refs)

		/// Now find descendants of its type
		Set suggestions2 = suggestions2 _ ##class(Utils).FindImmediateDescendants(##class(Utils).GetTypeRefsMultiple(refs))
		Set suffix = ""

		If (pScope.Function = "") || (pScope.Function = "|") {
			Set suffix = "."
		}
		For i=1:1:$LL(suggestions2) {
			Do suggestions.Insert(ctxHelper.GetFieldDisplayName($LG(suggestions2, i)) _ suffix)

			Set cardinality = ##class(Utils).FindMaxCardinality($LG(suggestions2, i))

			If (cardinality = "*") {
				Do suggestions.Insert(ctxHelper.GetFieldDisplayName($LG(suggestions2, i)) _ "[")
			}
		}

		Do suggestions.Insert("iif(")
	}

	If ($LF(pScope.FHIRType, "string") || $LF(pScope.FHIRType, "code") || (pScope.DataType = "STRING")) {
		If (($$$CPROP || $$$CANY || $$$CFN)) {
			Do ..AddStringFunctions(suggestions)
		}
	}

	If ($$$CVAL) {
		/// Create a generic context helper up above.
		Set ctxHelper = ##class(FHIR.FHIRPath.FHIRContextHelper).%New(..Loader, "Patient")

		/// TODO: This is a bit of a hacky way of differentiating value suggestions from
		/// codes, which may include the system property, and other fields.
		/// May be a better idea to filter on the "code" and "system" siblings directly
		/// rather than on other fields, needs to be investigated mroe to see if
		/// system/code are the only relevant fields with valuesets and codesystems

		Set children = pScope.GlobalRefs
		If (pScope.PrefixToken = "code") {
			/// TODO: For codes, we should check sibling properties, although
			/// might be better to check for "system" (see above)
			Set parentRefs = ""
			For i=1:1:$LL(pScope.GlobalRefs) {
				Set parentRefs = parentRefs _ ctxHelper.AscendSubscript(pScope.GlobalRef)
			}

			Set children = ##class(Utils).FindImmediateDescendants(parentRefs)
		}

		Set originalSystems = ctxHelper.FindProperty(pScope.Context, "system")
		Set systems = ""

		Set suggestions2 = ""

		For i=1:1:$LL(children) {
			Set ref = $LG(children, i)

			/// Look up details of the ValueSets according to the current ref
			Set valueSets = ctxHelper.FindPropertyFromRef(ref, "vs")
			Set fixedValues = ctxHelper.FindPropertyFromRef(ref, "fv")

			Set systems = systems _ valueSets _ fixedValues
			Set suggestions2 = suggestions2 _ fixedValues
		}

		Set codeSystems = ctxHelper.FindProperty(pScope.Context, "system")
		Set codeURLs = ctxHelper.FindProperty(pScope.Context, "url")

		Set systems = systems _ codeSystems _ codeURLs

		Do ..ExpandSystems(systems, .suggestions2)

		For i=1:1:$LL(suggestions2) {
			Do suggestions.Insert("'" _ $LG(suggestions2, i) _ "'")
		}
	}

	If ($$$CANY || $$$CTYPE) {
		If (pScope.CompletionScope = "ALL") {
			/// TODO: FHIRPath is case sensitive, make the necessary modifications to ensure all fields
			/// properties and functions are case sensitive
			/// Select all types from SQL
			/// TODO: Use the FHIR.TypeAssist global for this..
			Set tRS = ##class(%SQL.Statement).%ExecDirectNoPrivNoAudit(,"SELECT DISTINCT(type) FROM HS_FHIRMeta_Storage.Rsrc WHERE coreVersion=? AND (kind='resource' OR kind='complex-type' OR kind='primitive-type')", ..Loader.coreVersion)
			While tRS.%Next() {
				Do suggestions.Insert(tRS.%Get("type"))
			}
		} ElseIf (pScope.CompletionScope = "DIRECT") {
			Set types = pScope.FHIRType
			If '$LISTVALID(types) {
				Set types = $lb(types)
			}

			Set suffix = ""
			If (pScope.Function '= "") {
				Set suffix = ")"
			}

			Set types = $LISTFROMSTRING($LISTTOSTRING(types))
			For i=1:1:$LL(types) {
				Do suggestions.Insert($LG(types, i) _ suffix)
			}
		}
	}

	If ($$$CRESOURCE) {
		Set tRS = ##class(%SQL.Statement).%ExecDirectNoPrivNoAudit(,"SELECT DISTINCT(type) FROM HS_FHIRMeta_Storage.Rsrc WHERE coreVersion=? AND (kind='resource') AND id=type", ..Loader.coreVersion)
		Set suffix = ""
		Set:(pScope.Function="")||(pScope.Function="|") suffix = "."
		While tRS.%Next() {

			Do suggestions.Insert(tRS.%Get("type") _ suffix)
		}
	}

	For i=1:1:$LL(pScope.ScopedVariables) {
		Do suggestions.Insert($LG(pScope.ScopedVariables, i))
	}
	Return suggestions
}

Method ExpandSystems(systems As %List, Output codes As %List = "") [ Private ]
{
	For i=1:1:$LL(systems) {
		Set url = $LG(systems, i)

		If ('$DATA(^FHIR.TypeAssist("Data", url))) {
			Set general = $PIECE(url, "|")

			If ($DATA(^FHIR.TypeAssist("Data", general))) {
				Set url = general
			} Else {
				Continue
			}
		}

		For i=1:1:$LL(..Loader.packageIdList) {
			Set pkg = $LG(..Loader.packageIdList, i)
			Set data = $G(^FHIR.TypeAssist("Data", url, pkg))
			Continue:data=""

			Set data = ^FHIR.TypeAssist("Data", url, pkg)

			For j=1:1:$LL(data) {
				Set value = $LG(data, j)
				Set type = $PIECE(value, ":", 1)

				If (type = value) || (type = "code") {
					/// This is most likely a code
					Set codes = codes _ $lb(value)
				} ElseIf (type = "cs") || (type = "vs") {
					/// This is a code system or another valueset, call recursively
					Do ..ExpandSystems($lb($PIECE(value, ":", 2, *)), .codes)
				}
			}
		}
	}

	Return ""
}

}
