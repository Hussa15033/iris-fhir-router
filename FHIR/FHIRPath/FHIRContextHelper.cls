/// 
/// A helper function which keeps the context of a FHIRPath expression as we traverse through
/// its AST. It uses the internal FHIR classes to perform lookups on StructureDefinition resources
/// 
/// Needs modifications so it is more efficient as current implementation was made as the
/// parser was developed so tons of inefficiencies and unnecessary complexities in the code
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
/// 
/// TODO: This class contains 3 implementations of the ContextHelper that has evolved to now use
/// TypeAssist, a dedicated global for the Routing Engine assist class and an InferType method
/// to traverse the AST as opposed to a primitive InOrderTraversal. This class therefore needs to be cleaned up
/// to only support that implementation rather than the 2 implementations that preceded it
Class FHIR.FHIRPath.FHIRContextHelper Extends %RegisteredObject
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

Property Resource As %String;

/// List of packages to support....
Property PackageList As list Of %String;

/// Snapshot of the current element
Property Snapshot As %DynamicObject;

/// All fields/paths within this context and their snapshots
Property Definitions As %ArrayOfObjects;

/// A list of data structures available within this context.
/// This is the heart of this class, can be used to instantly
/// load a context or merge/save contexts
Property Context As %ListOfDataTypes;

/// Any additional custom suggestions based on the scope,
/// e.g. when within functions like `aggregate()`
Property ScopedVariables As %ListOfDataTypes;

/// Name of resource or primitive data type
Property SingletonDataType As %String(VALUELIST = ",string,boolean");

/// A property used to override the fields return by this context
Property OverrideFields As %ListOfDataTypes;

Property Function As %String;

Property GlobalRef As %String;

/// Appends a subscript to a global ref
Method AppendSubscript(base As %String = {..GlobalRef}, subscriptValue) As %String
{
	If ('$LISTVALID(subscriptValue))||(subscriptValue = "") {
		Set subscriptValue = $lb(subscriptValue)
	}

	For i=1:1:$LL(subscriptValue) { 
		Set base = $NAME(@base@($LG(subscriptValue, i)))
	}

	Return base
}

Method %OnNew(pLoader As HS.FHIRMeta.Load.NpmLoader, pResource = "") As %Status [ Private ]
{
	Set ..Loader = pLoader
	Set ..Resource = pResource
	Set ref = "^FHIR.TypeAssist"

	/// Check the first package that matches this resource
	Set packageIdList = pLoader.packageIdList
	Set ..GlobalRef = ""
	For i=$LL(packageIdList):-1:1 {
		Set tempRef = ..AppendSubscript(ref, $lb($LG(packageIdList, i), "Resource", pResource))
		Set tempRef = ..DescendSubscript(tempRef)

		If $DATA(@tempRef) {
			Set ..GlobalRef = tempRef
			Quit
		}
	}

	If ..GlobalRef = "" {
		Throw ##class(%Exception.General).%New("Resource '" _ pResource _ "' does not exist in packages")
	}

	Quit $$$OK
}

/// Create a copy context
Method Duplicate()
{
	Set ctx = ##class(FHIRContextHelper).%New(..Loader, ..Resource)
	Set ctx.GlobalRef = ..GlobalRef

	/// Copy scoped variables
	Set clonedScope = ..ScopedVariables.%ConstructClone(1, .clonedScope)

	Set ctx.ScopedVariables = clonedScope
	Return ctx
}

Method ResetContext(pContext = "")
{
	Quit:pContext=""

	Set ..Context = ##class(%ListOfDataTypes).%New()
	Do ..MergeContext(pContext)

	Do ..LoadContext()
}

/// Converts an $lb() into a %ListOfDataTypes if required
/// TODO: Change name of this fn or convert all lists in this class to one or the other..
Method ValidateList(pList = "") As %ListOfDataTypes [ Internal ]
{
	Set newList =  ##class(%ListOfDataTypes).%New()
	Quit:(pList="")||'$LISTVALID(pList) newList
	
	If (pList '= "") && $LISTVALID(pList) {
		For i=1:1:$LL(pList) {
			Do newList.Insert($LG(pList, i))
		}

		Set pList = newList
	}

	If '$ISOBJECT(pList) || '$METHOD(pList, "%Extends", "%ListOfDataTypes") {
		Throw ##class(%Exception.General).%New("Not a list",,,pList)
	}

	Return pList
}

Method CreateScope(pIdent As %String, pInitialScope As FHIR.FHIRPath.Context.Scope, ByRef success As %Boolean) As FHIR.FHIRPath.Context.Scope
{
	/// TODO: This should be handled via ClassMethods rather than
	/// recreating the context helper every time
	Set scope = pInitialScope.Duplicate()
	Do scope.Reset()
	Set success = 0
	If pInitialScope.DataType = "RESOURCE" {
		/// TODO: Change this to a proper search of all the resources within this type,
		/// the BuildResourceContext is a deprecated method for loading full context
		Set ctx = ..BuildResourceContext(..Loader, pInitialScope.FHIRType)

		Set success = ctx.AdvanceContext(pIdent)

		Return:'success pInitialScope
		Set scope.DataType = "FHIRTYPE"
		Set scope.Cardinality = ..FindPropertyFromRef(ctx.GlobalRef, "max")
		Set scope.FHIRType = ..FindPropertyFromRef(ctx.GlobalRef, "type")
		Set scope.GlobalRef = ctx.GlobalRef

		Return scope
	} ElseIf (pInitialScope.DataType = "FHIRTYPE") {
		/// First check if this is a direct descendant of the current type
		Set ref = ..AppendSubscript(pInitialScope.GlobalRef, pIdent)

		If ($DATA(@ref) '= 0) {
			/// This node has data in it, so it is a direct descendant of the current type
			Set scope.GlobalRef = ref
			Set scope.DataType = "FHIRTYPE"
			Set scope.Cardinality = ..FindPropertyFromRef(ref, "max")
			Set scope.FHIRType = ..FindPropertyFromRef(ref, "type")
			Set success = 1
			Return scope
		}
 

		/// If the node doesn't exist as a direct descendant, we check if it exists as a descendant of its type
		Set typeRef = ..GetTypeRef(pInitialScope.GlobalRef)
		
		Return:typeRef="" pInitialScope

		Set typeRef = ..AppendSubscript(typeRef, pIdent)

		If $DATA(@typeRef) '= 0 {
			Set scope.GlobalRef = typeRef
			Set scope.DataType = "FHIRTYPE"
			Set scope.FHIRType = ..FindPropertyFromRef(typeRef, "type")
			Set scope.Cardinality = ..FindPropertyFromRef(typeRef, "max")
			Set scope.CompletionType = "TYPE"
			Set success = 1
			Return scope
		}
	} ElseIf (pInitialScope.DataType = "") {
		/// This scope is a blank slate, we are not constricting ourselves to any particular resource/type
		/// Find the Type/Resource within the TypeAssist global
		Set base = "^FHIR.TypeAssist"
		Set corePkg = $LG(..Loader.packageIdList)
		Set base = ..AppendSubscript(base, corePkg)
		Set baseType = ..AppendSubscript(base, $lb("Type", pIdent))

		Set baseResource = ..AppendSubscript(base, $lb("Resource", pIdent))
		
		If pIdent '= "" {
			If ($DATA(@baseResource)) {
				/// Type is a resource
				Set scope.Cardinality = 1
				Set scope.DataType = "RESOURCE"
				Set scope.FHIRType = pIdent
				Set scope.GlobalRef = ..DescendSubscript(baseResource)
				Set scope.RootRef = scope.GlobalRef

				Set success = 1
				Return scope
			} ElseIf ($DATA(@baseType)) {
				/// Type is a FHIR Type
				Set scope.Cardinality = 1
				Set scope.DataType = "FHIRTYPE"
				Set scope.FHIRType = pIdent
				Set scope.GlobalRef = ..DescendSubscript(baseType)

				Set success = 1
				Return scope
			}
		}
	} Else {
		Write !,!,"Currently only resource level scopes are supported, returning empty scope",!
		Write !,"Scope provided: " _ pInitialScope.DataType
	}


	Return pInitialScope
}

/// Merges the context of one context list into this context
Method MergeContext(pContext)
{
	Set pList = ..ValidateList(pContext)
	For i=1:1:pList.Size {
		Set v = pList.GetAt(i)
		Set found = ..Context.Find(v)
		If found = "" {
			Do ..Context.Insert(v)
		}
	}
}

ClassMethod BuildResourceContext(pLoader As HS.FHIRMeta.Load.NpmLoader, pResource As %String) As FHIR.FHIRPath.FHIRContextHelper
{
	/// Find the snapshot element from the db based on the packageIdList
	/// Since the loader.packageIdList is ordered so the core version appears first
	/// We use the $LISTFIND method to order by the appearance in the packageIdList descending
	/// to prioritise custom profiles

	/// TODO: Should probably build a global for basedefinitions for faster access
	Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 1 url,version FROM HS_FHIRMeta_Storage.Rsrc WHERE (packageId %INLIST ?) AND kind='resource' AND %UPPER(type)=? ORDER BY $LISTFIND(?, packageId) DESC, (CASE WHEN id = type THEN 1 ELSE 0 END) DESC", pLoader.packageIdList, $ZCVT(pResource, "U"), pLoader.packageIdList)
	Throw:tRS.%Next()=0 ##class(%Exception.General).%New("Resource '" _ pResource _ "' does not exist", "-20322",,"")
	Set profileUrl = tRS.%Get("url")
	Set profileVersion = tRS.%Get("version")

	Set ctx = ..%New(pLoader, pResource)

	Return ctx
}

// Method AddFieldType(pName, pType)

// {

// 	Set currType = ..Fields.GetAt(pName)

// 	If currType = "" {

// 		Set newType = pType

// 	} Else {

// 		Set newType = currType _ "," _ pType

// 	}

// 	Do ..Fields.SetAt(newType, pName)

// }

/// InitialDefinitions are the field definitions we want to keep in the original context
Method LoadContext(InitialDefinitions = "") [ Private ]
{
	Quit:..Context.Size=0

	Do ..Definitions.Clear()
	Set ..Definitions = InitialDefinitions
	For i=1:1:..Context.Size {
		Set code = ..Context.GetAt(i)
		Set els = $LISTFROMSTRING(code, "|")
		Set resource = ##class(HS.FHIRMeta.Storage.Rsrc).UrlIndexOpen($LG(els, 1), $LG(els, 2))
		Throw:resource="" ##class(%Exception.General).%New("StructureDefinition for '" _ code _ "' does not exist", "-20322",,"")
		Set sd = resource.RsrcJsonAsDynObj()

		Do ..LoadDefinition(sd)
	}
}

Method LoadDefinition(pStructureDefinition As %DynamicObject) [ Private ]
{
	#; Write "Loading new context...",!
	
	/// This method traverses the StructureDefinition of an item
	/// and builds its context
	#dim elements As %DynamicArray
	Set elements = pStructureDefinition.snapshot.element
	Set iter = elements.iterator()
	
	//Set ..SingletonDataType = ""

	While (iter.%GetNext(.key, .value)) {
		Continue:(value.path = pStructureDefinition.name) /// Ignore first element

		Set path = $LISTFROMSTRING(value.path,".")
		Set props = $LIST(path, 2, *)
		
		/// Patient.contact.id => contact.id
		Set propName = $LISTTOSTRING(props, ".")

		Do ..AddFieldDefinition(propName, value)
	}
}

/// We use a helper method as a wrapper to filter out noise from the
/// definition
Method AddFieldDefinition(pFieldName As %String, pDefinition As %DynamicObject, pArray As %ArrayOfObjects = {..Definitions})
{
	Set path = pDefinition.path
	Set min = pDefinition.min
	Set max = pDefinition.max
	Set types = pDefinition.type
	Set bindings = pDefinition.binding
	Return:types=""
	Return:pFieldName=""
	Return:pDefinition.%IsDefined("sliceName")

	/// Add base definition
	Set json = {
		"path": ($REPLACE(path, "[x]", "")),
		"min": (min),
		"max": (max),
		"type": (types),
		"binding": (bindings)
	}

	Do pArray.SetAt(json, $REPLACE(pFieldName, "[x]", ""))
	If pFieldName [ "[x]" {
		/// Loop through the data types
		Set typeIter = types.iterator()
		While (typeIter.%GetNext(.k1, .type)) {
			Set code = type.code

			/// The value replacing [x] is camel case of the type of the property
			Set upperCaseType = $ZCVT($EXTRACT(code, 1, 1), "U") _ $EXTRACT(code, 2, *)
			Set fieldName = $REPLACE(pFieldName, "[x]", upperCaseType)
			Set path = $REPLACE(path, "[x]", upperCaseType)
			Set types = [(type)]

			Set json = {
				"path": (path),
				"min": (min),
				"max": (max),
				"type": (types),
				"binding": (bindings)
			}

			Do pArray.SetAt(json, fieldName)
		}
	}
}

Method IsGlobalRef(pGlobalRef As %String) As %Boolean
{
	Return $EXTRACT(pGlobalRef)="^"
}

Method GetFieldDisplayName(pGlobalRef As %String) As %String
{
	Return:'..IsGlobalRef(pGlobalRef) pGlobalRef
	Return $QS(pGlobalRef, $QL(pGlobalRef))
}

Method FindPropertyFromRef(pGlobalRef As %String, pName As %String) As %String
{
	Return:'..IsGlobalRef(pGlobalRef) ""
	Return ..FindProperty(@pGlobalRef, pName)
}

Method FindCardinalityFromRef(pGlobalRef As %String) As %String
{
	Return:'..IsGlobalRef(pGlobalRef) ""
	Return $LG(..FindPropertyFromRef(pGlobalRef, "max"), 1)
}

Method IsCollectionField(pGlobalRef As %String) As %Boolean
{
	Set maxCardinality = ..FindPropertyFromRef(pGlobalRef, "max")
	Set:$LL(maxCardinality)=1 maxCardinality = $LG(maxCardinality, 1)

	Return:(maxCardinality '= "")&&((maxCardinality="*")||(maxCardinality>1)) 1

	Return 0
}

Method TranslateFunctionToSuggestion(pFunctionName As %String) As %String
{
	Set fnName = $ZCVT(pFunctionName, "L")

	/// Functions that take no parameters
	Set zeroParameterFunctions = $LISTFROMSTRING("exists,empty,first,last,tail,not,resolve,descendants",",")

	/// Function that return a primitive, not a collection
	Set primitiveFunctions = $LISTFROMSTRING("exists,empty",",")

	Quit:$LISTFIND(zeroParameterFunctions, fnName) pFunctionName _ "()"
	Quit pFunctionName _ "("
}

Method AdvanceFunction(pFunctionName As %String, pIsOp As %Boolean = 0) As %Boolean [ Private ]
{
	#; w "Advancing function.. gref="_..GlobalRef,!
	Set ..Function = pFunctionName
	Set fnName = $ZCVT(pFunctionName, "L")
	
	#; Write "Advancing function..." _ pFunctionName,!
	/// Function that return a primitive, not a collection
	Set primitiveFunctions = $LISTFROMSTRING("exists,empty",",")
	Set ..SingletonDataType = ""

	/// Special cases
	If (fnName = "aggregate") {
		/// Add scoped variables and fields to the context
		Do ..ScopedVariables.Insert("iif(")
		Do ..ScopedVariables.Insert("$this")
		Do ..ScopedVariables.Insert("$total")
	} ElseIf (fnName = "iif") {
		Do ..ScopedVariables.Insert("$index")
	} ElseIf (fnName = "as") {
		/// We want to enumerate the types of all fields
		/// Loop through all definitions and their snapshot

		/// We first convert to string to combine all comma-separated items, as a list may be defined like
		/// $lb("type1,type2,type3", "type4", "type5,type6") etc..
		Set types = $LISTFROMSTRING($LISTTOSTRING(..FindPropertyFromRef(..GlobalRef, "type")))

		If 'pIsOp {
			For i=1:1:$LL(types) {
				Set $LIST(types, i) = $LG(types, i) _ ")"
			}
		}

		Do ..OverrideFields.Clear()
		Set ..OverrideFields = ..ValidateList(types)
	} ElseIf (fnName = "oftype") || (fnName = "is") {
		/// Todo: FHIRPath is case sensitive, make the necessary modifications to ensure all fields
		/// properties and functions are case sensitive
		/// Select all types from SQL
		Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT DISTINCT(type) FROM HS_FHIRMeta_Storage.Rsrc WHERE coreVersion=? AND (kind='resource' OR kind='complex-type' OR kind='primitive-type')", ..Loader.coreVersion)
		While tRS.%Next() {
			Do ..OverrideFields.Insert(tRS.%Get("type"))
		}
	} ElseIf(fnName = "empty") {
	} ElseIf (fnName = "exists") {
		#; Write "Modified singleton type to bool"
	} ElseIf (fnName = "union") {
		#; W "Doing union...",!
		/// The current resource should be a scoped variable, we reset the context to be that of the resource
		Do ..OverrideFields.Clear()
		Do ..ScopedVariables.Insert(..Resource)

		/// Reset the context to be the resource's context
		Set ref = $NAME(@..GlobalRef, 1)
		Set ref = ..AppendSubscript(ref, "Resource")
		Set ref = ..AppendSubscript(ref, ..Resource)
		Set ref = ..DescendSubscript(ref)
		Set ..GlobalRef = ref
	}

	#; If $LISTFIND(primitiveFunctions, fnName) {
	#; 	Set ..IsCollection = 0
	#; }

	Quit 1
}

Method AdvanceOperator(pOp As %String) As %Boolean
{
	If (pOp = "as") {
		Quit ..AdvanceFunction("as", 1)
	} ElseIf (pOp = "|") {
		/// todo: Bad design for this method, this method tricks the caller into thinking the pOp
		/// parameter was NOT a function when it is. This is for nicer autocomplete suggestion
		/// i.e
		///		- "Practitioner.name[0] is HumanN" should suggest "HumanName" NOT "HumanName."
		///		- "Practitioner.name.family | Pra" should suggest "Practitioner." NOT "Practitioner"
		Do ..AdvanceFunction("union", 1)
		#; Write "Advancing operator..."
		Quit 0
	} ElseIf (pOp = "is") {
		Quit ..AdvanceFunction("is", 1)
	}

	Quit 0
}

Method AdvanceContext(pNextField As %String, pIsFunction As %Boolean = 0) As %Boolean
{
	#; Write !,"Advancing " _ pNextField _ "..."
	#; w "gRef = " _ ..GlobalRef,!,!
	/// Switch the FHIR context helper to the context
	/// specified by pNextField

	If (pIsFunction) {
		Set validFn = ..AdvanceFunction(pNextField)
		Set tSC = $$$OK
		Set:validFn="" tSC = $$$ERROR($$$GeneralError, "Function '" _ pNextField _ "' does not exist within this context")
		$$$ThrowOnError(tSC)
		Quit $$$ISOK(tSC)
	}

	Set ref = ..AppendSubscript(,pNextField)

	If ($DATA(@ref) '= 0) {
		/// This node has data in it
		Set ..GlobalRef = ref
		Return 1
	}

	/// Node doesn't exist if we add data, but may be possible that the type is valid
	Set typeRef = ..GetTypeRef(..GlobalRef)

	If (typeRef = "") {
		/// No types found or multiple types found
		Return 0
	}

	Set typeRef = ..AppendSubscript(typeRef, pNextField)

	If $DATA(@typeRef) '= 0 {
		Set ..GlobalRef = typeRef
		Return 1
	}


	/// No advancements to make to the context, this field
	/// does not exist as either a direct descendant of the resource field
	/// or a descendant of its type

	Return 0
}

ClassMethod Test()
{
	#; Set ctx = ##class(FHIR.FHIRPath.FHIRContextHelper).%New($LB("http://hl7.org/fhir/StructureDefinition/Patient|4.0.1"))
	Set loader = ##class(HS.FHIRMeta.Load.NpmLoader).%New($lb("hl7.fhir.r4.core@4.0.1"))
	Set ac = ##class(FHIR.FHIRPath.Autocomplete).%New()
	Set ctx = ..BuildResourceContext(loader, "Patient")
	Set ast = ##class(FHIR.FHIRPath.Parser).ParseString("name.text.first()")

	Do ac.InorderTraversal(ast, .ctx, .ftp, .sg, .rwfc)

	#; w ctx.Snapshot.%ToJSON()
	#; zw ctx.GetPropertyList()
	#; zw ctx.GetSuggestionsList()
	Do ctx.GetFunctionsList()

	Return $$$OK
}

Method GetTypes(gList As %List) As %List
{
	Return ..FindProperty(gList, "type")
}

Method FindProperty(gList As %List, propName As %String) As %String
{
	Set list = ""
	For i=1:1:$LL(gList) {
		Set item = $LG(gList, i)
		Continue:item=""

		Set type = $PIECE(item, ":", 1)
		Set val = $PIECE(item, ":", 2, *)

		Continue:type'=propName

		Set:val'="" list = list _ $lb(val)
	}

	Return list
}

Method GetTypeRef(rootRef As %String) As %String
{
	Set list = @rootRef
	Set typeList = ..GetTypes(list)
	Return:$LL(typeList)'=1 ""

	Set profileList = ..FindProperty(list, "profile")

	Set type = $LG(typeList, 1)
	Set base = $NAME(@rootRef, 1)
	Set base = ..AppendSubscript(base, $lb("Type", type))

	/// TODO: Deal with cases with multiple profile types rather than just the first...
	If $LL(profileList) > 0 {
		Set profile = $LG(profileList, 1)
		Set base2 = ..AppendSubscript(base, profile)
		Return:$DATA(@base2) base2
	}

	Return:'$DATA(@base) ""


	Return ..DescendSubscript(base)
}

Method AscendSubscript(ref As %String) As %String
{
	Return $NAME(@ref, $QL(ref) - 1)
}

Method DescendSubscript(ref As %String) As %String
{
	Set child = $O(@ref@(""))
	Return:child="" child
	Return ..AppendSubscript(ref, child)
}

Method ExpandTypeSet(rootRef As %String)
{
	Set data = $GET(@rootRef)

	Return:(data="")||'$LISTVALID(data) ""
	
	Set types = ..GetTypes(data)

	Set list = ""
	Set baseTypesRef = $NAME(@rootRef, 1)
	Set baseTypesRef = ..AppendSubscript(baseTypesRef, "Type")
	while $LL(types) > 0 {
		Set type = $LG(types, 1)
		Set types = $LIST(types, 2, *)

		Set baseRef = ..AppendSubscript(baseTypesRef, type)
		Write !,"Checking base ref: " _ baseRef

		Continue:$DATA(@baseRef)<=1

		Set nextChild = ..DescendSubscript(baseRef)

		Set child = ""
	}

	Return list
}

/// Helper method to convert a type code into
/// a canonical URL StructureDefinition
Method ToCanonSD(pDatatype) As %String
{
	Return "http://hl7.org/fhir/StructureDefinition/" _ pDatatype _ "|" _ ..Loader.coreVersion
}

Method FindImmediateDescendants(gRef As %String) As %List
{
	Return:(gRef="")||($DATA(@gRef)<=1) ""
	
	#; w "Finding desc of " _ gRef
	Set list = ""

	Set next = ""
	For {
		Set subRef = ..AppendSubscript(gRef, next)
		Set next = $O(@subRef)
		Quit:next=""

		Set list = list _ $lb(..AppendSubscript(gRef, next))
	}

	Return list
}

Method GetPropertyList() As %ListOfDataTypes
{
	#; Set nextSubscript = $O(@..AppendSubscript(,""))
	#; Write nextSubscript
	If (..OverrideFields.Size > 0) {
		Return ..OverrideFields
	}

	/// Starting at the GlobalRef position, we want to expand and find all descendant fields, as well as
	/// all types referenced by these fields
	Set ref = ..GlobalRef

	Set propFields = ..FindImmediateDescendants(ref)

	/// Now find descendants of its type
	Set propFields = propFields _ ..FindImmediateDescendants(..GetTypeRef(ref))

	For i=1:1:$LL(propFields) {
		Set type = $LG(propFields, i)
	}
	Set props = ..ValidateList(propFields)

	#; Set child = ""
	#; while $LL(expansionList) > 0 {
	#; 	Set ref = $LG(expansionList, 1)
	#; 	Set expansionList = $LIST(expansionList, 2, *)
		
	#; 	Set child = $O(@..AppendSubscript(ref, child))

	#; 	If ($DATA(child) = 1) {
	#; 		Set types = ..GetTypes($GET(child))


	#; 	}

	#; 	Do props.Insert(child)
	#; }
	For i=1:1:..ScopedVariables.Size {
		Do props.Insert(..ScopedVariables.GetAt(i))
	}
	Return props
}

/// Helper method to check if the current/given snapshot contains a given data type
Method GetSnapshotTypes(pSnapshot As %DynamicObject = {..Snapshot}, pAcc As %List = "") As %List [ Private ]
{

	Return:'pSnapshot.%IsDefined("type") $lb()

	#dim jsonArray As %DynamicArray
	Set jsonArray = pSnapshot.%Get("type")

	Set iter = jsonArray.%GetIterator()

	Set types = ""
	While iter.%GetNext(.key, .value, .type) {
		/// Types always have a "code" element
		Continue:value.%IsDefined("extension")

		Set code = value.%Get("code")

		Continue:pAcc'=""&&$LF(pAcc, code)

		Set:code'="" types = types _ $lb(code)
	}

	Return types
}

Method GetFunctionsList() As %ListOfDataTypes
{
	Set fns = ##class(%ListOfDataTypes).%New()

	/// Todo: Modify this IF statement, if all outputs are truly collections
	/// Add collection functions
	Do fns.Insert(..TranslateFunctionToSuggestion("where"))
	Do fns.Insert(..TranslateFunctionToSuggestion("exists"))
	Do fns.Insert(..TranslateFunctionToSuggestion("empty"))
	Do fns.Insert(..TranslateFunctionToSuggestion("first"))
	Do fns.Insert(..TranslateFunctionToSuggestion("last"))
	Do fns.Insert(..TranslateFunctionToSuggestion("skip"))
	Do fns.Insert(..TranslateFunctionToSuggestion("tail"))
	Do fns.Insert(..TranslateFunctionToSuggestion("take"))
	Do fns.Insert(..TranslateFunctionToSuggestion("hasExtension"))
	Do fns.Insert(..TranslateFunctionToSuggestion("ofType"))
	Do fns.Insert(..TranslateFunctionToSuggestion("as"))
	Do fns.Insert(..TranslateFunctionToSuggestion("is"))
	Do fns.Insert(..TranslateFunctionToSuggestion("resolve"))
	Do fns.Insert(..TranslateFunctionToSuggestion("union"))
	Do fns.Insert(..TranslateFunctionToSuggestion("descendants"))

	/// Check primitive-type specific functions, only if this snapshot
	/// can contain a primitive data type
	Set types = ..GetTypes(@..GlobalRef)
	

	If $LF(types, "string") || $LF(types, "code") {
		Do fns.Insert(..TranslateFunctionToSuggestion("substring"))
		Do fns.Insert(..TranslateFunctionToSuggestion("startsWith"))
		Do fns.Insert(..TranslateFunctionToSuggestion("endsWith"))
		Do fns.Insert(..TranslateFunctionToSuggestion("indexOf"))
	}
	
	If $LF(types, "boolean") {
		Do fns.Insert(..TranslateFunctionToSuggestion("not"))
	}
	
	If $LF(types, "date") {
		Throw ##class(%Exception.General).%New("Cannot handle primitive type " _ $LISTTOSTRING(types, ","),"-303444",,"Failed to handle primitive data type '" _ type _ "' for autocomplete")
	}

	Return fns
}

/// TODO: Implement and use this method
/// Helper method to perform a lookup and return a %DynamicObject
Method Lookup(pCanonicalURL, pVersion = "") As HS.FHIRMeta.Storage.Rsrc
{
	/// TODO:
	/// Utilise this lookup everywhere thats needed
	If pVersion = "" {
		Set pVersion = $PIECE(pCanonicalURL, "|", 2)
	}
	Return ##class(HS.FHIRMeta.Storage.Rsrc).UrlIndexOpen(pCanonicalURL, pVersion)
}

Method GetSuggestionsList() As %ListOfDataTypes
{
	Set suggestions = ""
	/// Look up details of the ValueSets according to the current snapshot
	
	Set valueSets = ..FindPropertyFromRef(..GlobalRef, "vs")
	Set fixedValues = ..FindPropertyFromRef(..GlobalRef, "fv")

	Set suggestions = suggestions _ fixedValues
	
	For i=1:1:$LL(valueSets) {
		Set suggestions = suggestions _ ..ExpandValueSet($LG(valueSets, i))
	}

	Return ..ValidateList(suggestions)
}

Method ExpandValueSet(valueSetURL As %String)
{
	Set suggestions = ""

	Set url = $PIECE(valueSetURL, "|", 1)
	Set version = $PIECE(valueSetURL, "|", 2)

	/// If version was passed in, we need an exact match
	Return:version'="" $GET(^FHIR.TypeAssist("ValueSet", url, version))

	/// If version was not passed in, we can get away with returning the first node (if it exists)
	Set gRef = ..DescendSubscript(..AppendSubscript("^FHIR.TypeAssist", $lb("ValueSet", url)))

	If (gRef = "") {
		Return ""
	} Else {
		Return $GET(@gRef)
	}
}

}
