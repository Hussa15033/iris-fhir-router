/// 
/// A helper function which keeps the context of a FHIRPath expression as we traverse through
/// its AST. It uses the internal FHIR classes to perform lookups on StructureDefinition resources
/// 
/// Needs modifications so it is more efficient as current implementation was made as the
/// parser was developed so tons of inefficiencies and unnecessary complexities in the code
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// @version 21.04.2026
/// 
/// TODO: This class contains 3 implementations of the ContextHelper that has evolved to now use
/// TypeAssist, a dedicated global for the Routing Engine assist class and an InferType method
/// to traverse the AST as opposed to a primitive InOrderTraversal. This class therefore needs to be cleaned up
/// to only support that implementation rather than the 2 implementations that preceded it
Class FHIR.TypeAssist.FHIRContextHelper Extends %RegisteredObject
{

// Property Fields As %ArrayOfDataTypes;

/// Todo: This class should be modified as follows:
/// - Should be a class that can be used independently of the autocomplete engine
/// - it's sole focus should be to hold the context to a FHIR resource/object
/// - it should NOT have any knowledge of the full expression
/// - it SHOULD have context of the root resource type
/// - The Autocomplete class should deal with traversing the AST and updating field suggestions,
///   NOT this class...
Property Loader As HS.FHIRMeta.Load.NpmLoader;

Property Scope As FHIR.FHIRPath.Context.Scope;

Method %OnNew(pLoader As HS.FHIRMeta.Load.NpmLoader) As %Status
{
	Set ..Loader = pLoader
	Quit $$$OK
}


/// Given a scope and an identifier, we create a new scope out of it
Method CreateScope(pIdent As %String, pInScope As FHIR.FHIRPath.Context.Scope, ByRef success As %Boolean) As FHIR.FHIRPath.Context.Scope
{
	/// TODO: This should be handled via ClassMethods rather than
	/// recreating the context helper every time
	Set scope = ##class(FHIR.FHIRPath.Context.Scope).%New()
	Set scope.Function = pInScope.Function
	Set success = 0

	If (pInScope.DataType = "RESOURCE") && ($LL(pInScope.FHIRType) = 1) {
		/// The scope is a valid resource
		Set type = $LG(pInScope.FHIRType, 1)

		Set resourceBase = ##class(Utils).AppendSubscript("^FHIR.TypeAssist", $lb($LG(..Loader.packageIdList), "Resource", type))

		If ('$DATA(@resourceBase)) {
			Throw ##class(%Exception.General).%New("No resource found","-10393",,"A resource named '" _ type _ "' was not found in core version " _ ..Loader.coreVersion)
		}

		Set gRef = ##class(Utils).DescendSubscript(resourceBase)
		Set gRef = ##class(Utils).AppendSubscript(gRef, pIdent)

		Set success = $DATA(@gRef)

		Return:'success pInScope

		/// If successful
		Set scope.DataType = "FHIRTYPE"
		Set scope.Cardinality = ##class(Utils).FindMaxCardinality(gRef)
		Set scope.FHIRType = ##class(Utils).GetTypesFromRef(gRef)
		Set scope.GlobalRefs = gRef

		Return scope
	} ElseIf (pInScope.DataType = "FHIRTYPE") {
		Set validRefs = ""

		For i=1:1:$LL(pInScope.GlobalRefs) {

			/// First check if this is a direct descendant of the current type
			Set ref = ##class(Utils).AppendSubscript($LG(pInScope.GlobalRefs, i), pIdent)
			If ($DATA(@ref) '= 0) {
				/// This node has data in it, so it is a direct descendant of the current type
				Set validRefs = validRefs _ $lb(ref)
			}
		}

		If (validRefs '= "") {
			/// The node is a direct descendant
			Set scope.GlobalRefs = validRefs
			Set scope.DataType = "FHIRTYPE"
			Set scope.Cardinality = ##class(Utils).FindMaxCardinality(validRefs)
			Set scope.FHIRType = ##class(Utils).GetDirectTypesFromRefs(validRefs)

			zw scope
			Set success = 1
			Return scope
		}
 
		/// If the node doesn't exist as a direct descendant, we check if it exists as a descendant of any types
		Set typeRefs = ""
		For i=1:1:$LL(pInScope.GlobalRefs) {
			Set typeRefs = typeRefs _ ##class(Utils).GetTypeRefs($LG(pInScope.GlobalRefs, i))
		}

		w "Checking type descs...",!,!,!

		Return:typeRefs="" pInScope

		zw typeRefs
		Set validTypeRefs = ""
		For i=1:1:$LL(typeRefs) {
			Set typeRef = ##class(Utils).AppendSubscript($LG(typeRefs, i), pIdent)
			If (typeRef '= "") && $DATA(@typeRef) {
				Set validTypeRefs = validTypeRefs _ typeRef
			}
		}


		If (validTypeRefs '= "") {
			Set scope.GlobalRefs = validTypeRefs
			Set scope.DataType = "FHIRTYPE"
			Set scope.FHIRType = ##class(Utils).GetDirectTypesFromRefs(validTypeRefs)
			Set scope.Cardinality = ##class(Utils).FindMaxCardinality(validTypeRefs)
			Set scope.CompletionType = "TYPE"
			Set success = 1
			Return scope
		}
	} ElseIf (pInScope.DataType = "") {
		/// This scope is a blank slate, we are not constricting ourselves to any particular resource/type
		/// Find the Type/Resource within the TypeAssist global
		Set base = "^FHIR.TypeAssist"
		Set corePkg = $LG(..Loader.packageIdList)
		Set base = ##class(Utils).AppendSubscript(base, corePkg)
		Set baseType = ##class(Utils).AppendSubscript(base, $lb("Type", pIdent))

		Set baseResource = ##class(Utils).AppendSubscript(base, $lb("Resource", pIdent))
		
		Quit:pIdent=""
		
		If ($DATA(@baseResource)) {
			/// Type is a resource
			Set scope.Cardinality = 1
			Set scope.DataType = "RESOURCE"
			Set scope.FHIRType = pIdent
			Set scope.GlobalRefs = ##class(Utils).DescendSubscript(baseResource)
			Set scope.RootRef = scope.GlobalRefs

			Set success = 1
			Return scope
		} ElseIf ($DATA(@baseType)) {
			/// Type is a FHIR Type
			Set scope.Cardinality = 1
			Set scope.DataType = "FHIRTYPE"
			Set scope.FHIRType = pIdent
			Set scope.GlobalRefs = ##class(Utils).DescendSubscript(baseType)

			Set success = 1
			Return scope
		}
	} Else {
		Write !,!,"Currently only resource level scopes are supported, returning empty scope",!
		Write !,"Scope provided: " _ pInScope.DataType
	}


	Return pInScope
}

Method GetFieldDisplayName(pGlobalRef As %String) As %String
{
	Return:'##class(Utils).IsGlobalRef(pGlobalRef) pGlobalRef
	Return $QS(pGlobalRef, $QL(pGlobalRef))
}

Method IsCollectionField(pGlobalRef As %String) As %Boolean
{
	Set maxCardinality = ##class(Utils).FindMaxCardinality(pGlobalRef)

	Return:(maxCardinality '= "")&&((maxCardinality="*")||(maxCardinality>1)) 1

	Return 0
}


}
