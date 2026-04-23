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

Property CorePkg As %String;

Method %OnNew(pLoader As HS.FHIRMeta.Load.NpmLoader) As %Status
{
	Set ..Loader = pLoader
	Set ..CorePkg = $LG(..Loader.packageIdList)
	Quit $$$OK
}


/// Given a scope and an identifier, we create a new scope out of it
Method CreateScope(pIdent As %String, pInScope As FHIR.FHIRPath.Context.Scope, ByRef success As %Boolean) As FHIR.FHIRPath.Context.Scope
{
	/// TODO: This should be handled via ClassMethods rather than
	/// recreating the context helper every time
	Set scope = ##class(FHIR.FHIRPath.Context.Scope).%New()
	Set scope.Function = pInScope.Function
	Set scope.RootScope = pInScope.RootScope
	Set success = 0

	If (pIdent = "Quantity") {
		zw pInScope
		w "test.."
		#; hang 10
	}
	If ($LF($LISTFROMSTRING(pInScope.CompletionType), "TYPE"))&&((pInScope.Function = "as") || (pInScope.Function = "ofType")) {
		w "here..."
		#; hang 5
		/// This is a type of this property and we are casting it
		Set types = ##class(Utils).GetDirectTypesFromRefs(pInScope.GlobalRefs)
		If ($LF(types, pIdent)) {
			/// This type is a valid type, move the ref to the type ref
			Set typeRef = ##class(FHIR.TypeAssist.Utils).GetTypeRefFromTypeName(..CorePkg, pIdent)

			Return:typeRef="" pInScope
			
			Set success = 1
			Set pInScope.DataType = "FHIRTYPE"
			Set pInScope.FHIRType = $lb(pIdent)
			Set pInScope.GlobalRefs = typeRef
		}

		#; For i=1:1:$LL(tScope.GlobalRefs) {
		#; 	Set tempRefs = tempRefs _ $lb(##class(FHIR.TypeAssist.Utils).AscendSubscript($LG(tScope.GlobalRefs, i)))
		#; }
		#; 		Set tScope.GlobalRefs = tempRefs
		#; 		Set nScope = ..CreateScope(tScope.LastField _ type, tScope, .success)
		w "here...",!
		#; hang 10
		Return pInScope
	} ElseIf (pInScope.DataType = "RESOURCE") && ($LL(pInScope.FHIRType) = 1) {
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
		Set scope.FHIRType = ##class(Utils).GetDirectTypesFromRefs(gRef)
		Set scope.GlobalRefs = gRef

		Return scope
	} ElseIf (pInScope.DataType = "FHIRTYPE") {
		If ($LF($LISTFROMSTRING(pInScope.CompletionType), "RESOURCE")) {
			/// Completion type includes Resource
			Set base = ##class(Utils).AppendSubscript("^FHIR.TypeAssist", $lb(..CorePkg, "Resource", pIdent))
			If ($DATA(@base) = 10) {
				Set scope.Cardinality = 1
				Set scope.GlobalRefs = ##class(Utils).DescendSubscript(base)
				Set scope.DataType = "RESOURCE"
				Set scope.FHIRType = pIdent
				#; Set scope.Cardinality = 1
				#; Set scope.DataType = "RESOURCE"
				#; Set scope.FHIRType = pIdent
				#; Set scope.GlobalRefs = baseResourceGlobalRefs
				Set scope.RootScope = pInScope.RootScope

				#; zw scope
				#; hang 5
				Set success = 1
				Return scope
			}
		}
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

		/// If we got to this point, this field is not a valid property nor is it a valid descendant of a type
		Return pInScope
	} ElseIf (pInScope.DataType = "") {
		Quit:pIdent=""

		w !,!,!
		zw pIdent
		/// This scope is a blank slate, we are not constricting ourselves to any particular resource/type
		/// Find the Type/Resource within the TypeAssist global
		Set base = "^FHIR.TypeAssist"

		Set baseResourceGlobalRefs = ""
		Set baseTypeGlobalRefs = ""

		For i=1:1:$LL(..Loader.packageIdList) {
			Set pkg = $LG(..Loader.packageIdList, i)
			Set resourceRef = ##class(Utils).AppendSubscript(base, $lb(pkg, "Resource", pIdent))

			If ($DATA(@resourceRef)) {
				Set baseResourceGlobalRefs = baseResourceGlobalRefs _ $lb(##class(Utils).DescendSubscript(resourceRef))
			}

			Set typeRef = ##class(Utils).AppendSubscript(base, $lb(pkg, "Type", pIdent))
			If ($DATA(@typeRef)) {
				Set baseTypeGlobalRefs = baseTypeGlobalRefs _ $lb(##class(Utils).DescendSubscript(typeRef))
			}
		}
		
		If (baseResourceGlobalRefs '= "") {
			/// Type is a resource
			Set scope.Cardinality = 1
			Set scope.DataType = "RESOURCE"
			Set scope.FHIRType = pIdent
			Set scope.GlobalRefs = baseResourceGlobalRefs
			Set scope.RootScope = scope

			Set success = 1
			Return scope
		} ElseIf (baseTypeGlobalRefs '= "") {
			/// Type is a FHIR Type
			Set scope.Cardinality = 1
			Set scope.DataType = "FHIRTYPE"
			Set scope.FHIRType = pIdent
			Set scope.GlobalRefs = baseTypeGlobalRefs

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
