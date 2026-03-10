/// 
/// A helper function which keeps the context of a FHIRPath expression as we traverse through
/// its AST. It uses the internal FHIR classes to perform lookups on StructureDefinition resources
/// 
/// Needs modifications so it is more efficient as current implementation was made as the
/// parser was developed so tons of inefficiencies and unnecessary complexities in the code
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.FHIRContextHelper Extends %RegisteredObject
{

/// Todo: This class should be modified as follows:
/// - Should be a class that can be used independently of the autocomplete engine
/// - it's sole focus should be to hold the context to a FHIR resource/object
/// - it should NOT have any knowledge of the full expression
/// - it SHOULD have context of the root resource type
/// - The Autocomplete class should deal with traversing the AST and updating field suggestions,
///   NOT this class...
Property ResourceContext As %DynamicObject;

Property CurrentContext As %DynamicObject;

Property Fields As %ArrayOfDataTypes;

Property CollectionFields As %ListOfDataTypes;

Property AvailableFields As %ListOfDataTypes;

Property IsCollection As %Boolean;

Property WithinFunction As %String;

Property Loader As HS.FHIRMeta.Load.NpmLoader;

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
Property ScopedVariables As list Of %String;

/// Name of resource or primitive data type
Property SingletonDataType As %String(VALUELIST = ",string,boolean");

Property Function As %String;

Method %OnNew(pLoader As HS.FHIRMeta.Load.NpmLoader, pInitialContext = "") As %Status [ Private ]
{
	Set ..Loader = pLoader
	Do ..ResetContext(pInitialContext)

	Quit $$$OK
}

/// Create a copy context
Method Duplicate()
{
	Set ctx = ##class(FHIRContextHelper).%New(..Loader, ..Context)
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
Method ValidateList(pList = "") As %ListOfDataTypes [ Internal ]
{
	Quit:pList="" ""
	If (pList '= "") && $LISTVALID(pList) {
		Set newList = ##class(%ListOfDataTypes).%New()
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
	Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT url,version FROM HS_FHIRMeta_Storage.Rsrc WHERE (packageId %INLIST ?) AND kind='resource' AND %UPPER(type)=? ORDER BY $LISTFIND(?, packageId) DESC", pLoader.packageIdList, $ZCVT(pResource, "U"), pLoader.packageIdList)
	Throw:tRS.%Next()=0 ##class(%Exception.General).%New("Resource '" _ pResource _ "' does not exist", "-20322",,"")
	Set profileUrl = tRS.%Get("url")
	Set profileVersion = tRS.%Get("version")

	Set ctx = ..%New(pLoader, $lb(profileUrl _ "|" _ profileVersion))

	Return ctx
}

Method AddFieldType(pName, pType)
{
	Set currType = ..Fields.GetAt(pName)
	If currType = "" {
		Set newType = pType
	} Else {
		Set newType = currType _ "," _ pType
	}

	Do ..Fields.SetAt(newType, pName)
}

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

		Set types = value.type
		Continue:types=""	
		Set typeIter = types.iterator()
		While (typeIter.%GetNext(.k1, .type)) {
			Set code = type.code
			Set fieldName = propName

			/// TODO: ADD SUPPORT FOR [X] ELEMENTS
			#; If (propName [ "[x]") {
			#; 	/// The value replacing [x] is camel case of the type of the property
			#; 	Set upperCaseType = $ZCVT($EXTRACT(code, 1, 1), "U") _ $EXTRACT(code, 2, *)
			#; 	Set fieldName = $REPLACE(propName, "[x]", upperCaseType)

			#; 	/// We also want to add this data type to the original field definition
			#; 	Do ..AddFieldType($REPLACE(propName, "[x]", ""), code)
			#; }

			#; Write "Setting definition " _ fieldName _ "..",!
			Do ..Definitions.SetAt(value, fieldName)
		}
	}
}

Method AdvanceString()
{
	Set ..IsCollection = 0
	Set ..SingletonDataType = "string"
}

Method Reset()
{
	Do ..LoadContext(..ResourceContext)
}

Method TranslateFunctionToSuggestion(pFunctionName As %String) As %String
{
	Set fnName = $ZCVT(pFunctionName, "L")

	/// Functions that take no parameters
	Set zeroParameterFunctions = $LISTFROMSTRING("exists,empty,first,last,tail,not,resolve",",")

	/// Function that return a primitive, not a collection
	Set primitiveFunctions = $LISTFROMSTRING("exists,empty",",")

	Quit:$LISTFIND(zeroParameterFunctions, fnName) pFunctionName _ "()"
	Quit pFunctionName _ "("
}

Method AdvanceFunction(pFunctionName As %String, pIsOp As %Boolean = 0) As %Boolean [ Private ]
{
	Set ..Function = pFunctionName
	Set fnName = $ZCVT(pFunctionName, "L")
	
	#; Write "Advancing function..." _ pFunctionName,!
	/// Function that return a primitive, not a collection
	Set primitiveFunctions = $LISTFROMSTRING("exists,empty",",")
	Set ..SingletonDataType = ""

	/// Special cases
	If (fnName = "aggregate") {
		/// TODO: Perhaps don't need to use ..AvailableFields, should be enough to set the
		/// type of the field to "" within ..Fields
		Do ..AvailableFields.Insert("iif(")
		Do ..Fields.SetAt("", "$this")
		Do ..Fields.SetAt("", "$total")

		Do ..CollectionFields.Insert("$this")
		Do ..CollectionFields.Insert("$total")
	} ElseIf (fnName = "as") {
		/// We want to enumerate the types of all fields
		Set iKey = ..Fields.Next("")
		Set replaceFields = ##class(%ArrayOfDataTypes).%New()
		While iKey '= "" {
			Set types = $LISTFROMSTRING(..Fields.GetAt(iKey), ",")
			For i=1:1:$LL(types) {
				Set type = $LG(types, i)
				Set fieldText = type
				Set:'pIsOp fieldText = type _ ")"
				Do replaceFields.SetAt(type, fieldText)
			}
			Set iKey = ..Fields.Next(iKey)
		}

		Set ..Fields = replaceFields
	} ElseIf (fnName = "oftype") || (fnName = "is") {
		/// Todo: FHIRPath is case sensitive, make the necessary modifications to ensure all fields
		/// properties and functions are case sensitive
		/// Select all types from SQL
		Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT DISTINCT(type) FROM HS_FHIRMeta_Storage.Rsrc WHERE coreVersion=? AND (kind='resource' OR kind='complex-type' OR kind='primitive-type')", "4.0.1")
		While tRS.%Next() {
			Do ..Fields.SetAt(tRS.%Get("type"), tRS.%Get("type"))
		}
	} ElseIf(fnName = "empty") {
		Set ..SingletonDataType = "string"
	} ElseIf (fnName = "exists") {
		#; Write "Modified singleton type to bool"
		Set ..IsCollection = 0
		Set ..SingletonDataType = "boolean"
	} ElseIf (fnName = "union") {
		#; Do ..Reset()

		/// After resetting context, we add the current resource type to the list of available fields
		Do ..Fields.SetAt(..ResourceContext.type, ..ResourceContext.type)
	}


	If $LISTFIND(primitiveFunctions, fnName) {
		Set ..IsCollection = 0
	}

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
		Quit 0
	} ElseIf (pOp = "is") {
		Quit ..AdvanceFunction("is", 1)
	}

	Quit 0
}

Method AdvanceContext(pNextField As %String, pIsFunction As %Boolean = 0) As %Boolean
{
	#; Write !,"Advancing " _ pNextField _ "..."
	/// Switch the FHIR context helper to the context
	/// specified by pNextField
	If (pIsFunction) {
		Set validFn = ..AdvanceFunction(pNextField)
		Set tSC = $$$OK
		Set:validFn="" tSC = $$$ERROR($$$GeneralError, "Function '" _ pNextField _ "' does not exist within this context")
		$$$ThrowOnError(tSC)
		Quit $$$ISOK(tSC)
	}

	Set definition = ..Definitions.GetAt(pNextField)

	If (definition = "") {
		/// Definition not found (yet..)
		#; Set tSC = $$$ERROR($$$GeneralError, "Field '" _ pNextField _ "' is not valid within this context")
		#; $$$ThrowOnError(tSC)
		Quit 0
	}

	/// Loop through all definitions, as this may be part of a
	/// sub element of a BackboneElement directly embedded in the resource
	Set replaceDefinitions = ##class(%ArrayOfObjects).%New()
	Set key = ""
	While (..Definitions.GetNext(.key)) {
		Set props2 = $LISTFROMSTRING(..Definitions.GetAt(key), ".")
		If (pNextField = $LISTGET(props2, 1)) {
			/// This field is hanging
			Do replaceDefinitions.SetAt(..Definitions.GetAt(key), $LG(props2, 2))
		}
	}

	If replaceDefinitions.Count() > 0 {
		/// Hanging fields found, replace parent definitions
		Set ..Definitions = replaceDefinitions
		Quit 1
	}


	/// Definition exists and is of a particular type
	Set ..Snapshot = definition

	If definition.type.%Size()=1 {
		Set nextType = definition.type.%Get(0).code
		#; Write "Next type found: " _ nextType
		Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT * FROM HS_FHIRMeta_Storage.Rsrc WHERE coreVersion=? AND %UPPER(id)=? AND resourceType='StructureDefinition'", "4.0.1", $ZCVT(nextType, "U"))
		Set validField = tRS.%Next()
		Set tSC = $$$OK
		Set:(pNextField'="")&&(validField=0) tSC = $$$ERROR($$$GeneralError, "Field '" _ pNextField _ "' is not valid within this context")
		$$$ThrowOnError(tSC)
		Quit:validField=0 0
	} Else {
		Throw ##class(%Exception.General).%New("Multiple data types for code found...")
		/// This field has multiple next types because it is a choice field
		/// Only keep this field within the current context
		Set nextTypes = ..Fields.GetAt(pNextField)
		Do ..Fields.Clear()
		Do ..Fields.SetAt(nextTypes, pNextField)
		Quit 1
	}


	Do ..Context.Clear()
	Do ..Context.Insert(tRS.%Get("url") _ "|" _ tRS.%Get("version"))

	/// Now find any "hanging fields" before loading the new context
	/// This ensures any hanging fields are included when traversing
	/// BackBoneElements.
	Set newDefinitions = ##class(%ArrayOfObjects).%New()
	While ..Definitions.GetNext(.key) {
		Set split = $LISTFROMSTRING(key, ".")
		#; Write "Key = " _ key _ ","_ $LG(split, 1),!
		If ($LG(split, 1) = pNextField) && ($LL(split) = 2) {
			Do newDefinitions.SetAt(..Definitions.GetAt(key), $LG(split, 2))
		}
	}

	Do ..LoadContext(newDefinitions)

	Return 1
}

ClassMethod Test()
{
	#; Set ctx = ##class(FHIR.FHIRPath.FHIRContextHelper).%New($LB("http://hl7.org/fhir/StructureDefinition/Patient|4.0.1"))
	Set ac = ##class(FHIR.FHIRPath.Autocomplete).%New()
	Set ctx = ..BuildResourceContext("Patient")
	Set ast = ##class(FHIR.FHIRPath.Parser).ParseString("telecom.where(use=")

	Do ac.InorderTraversal(ast, .ctx, .ftp, .sg, .rwfc)

	#; w ctx.Snapshot.%ToJSON()
	#; zw ctx.GetPropertyList()
	#; zw ctx.GetSuggestionsList()
	#; zw ctx.GetFunctionsList()

	Return $$$OK
}

Method GetPropertyList() As %ListOfDataTypes
{
	Set props = ##class(%ListOfDataTypes).%New()
	While ..Definitions.GetNext(.k) {
		Set broken = $LISTFROMSTRING(k, ".")
		Do props.Insert($LG(broken, 1))
		#; Write "Looping through properties..." _ k,!
	}

	While ..ScopedVariables.Next(.k) {
		Do props.Insert(..ScopedVariables.GetAt(k))
	}

	Return props
}

Method GetFunctionsList() As %ListOfDataTypes
{
	Set fns = ##class(%ListOfDataTypes).%New()

	/// Todo: Modify this IF statement, if all outputs are truly collections
	If ..IsCollection||1 {
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
	}

	Set primitiveType = ""

	#; Write !,"Singletondatatype: "_..SingletonDataType,!
	If ('..IsCollection) && (..SingletonDataType '= "") {
		Set primitiveType = ..SingletonDataType
	} ElseIf (..CurrentContext.kind = "primitive-type") {
		Set primitiveType = ..CurrentContext.type
	}

	#; Write !,..SingletonDataType,!,!,!
	#; Write ..CurrentContext.type

	#; w !,"Primtype: " _ primitiveType,!
	If (primitiveType = "string") || (primitiveType = "code") {
		Do fns.Insert(..TranslateFunctionToSuggestion("substring"))
		Do fns.Insert(..TranslateFunctionToSuggestion("startsWith"))
		Do fns.Insert(..TranslateFunctionToSuggestion("endsWith"))
		Do fns.Insert(..TranslateFunctionToSuggestion("indexOf"))
	} ElseIf (primitiveType = "boolean") {
		Do fns.Insert(..TranslateFunctionToSuggestion("not"))
	} ElseIf (primitiveType = "date") {
		/// No supported date/time functions
	} ElseIf (primitiveType = "") {
		/// This is not a primitive type
		Do fns.Insert("descendants()")
	} Else {
		Throw ##class(%Exception.General).%New("Cannot handle primitive type " _ type,"-303444",,"Failed to handle primitive data type '" _ type _ "' for autocomplete")
	}

	Return fns
}

/// TODO: Implement and use this method
/// Helper method to perform a lookup and return a %DynamicObject
Method Lookup(pResourceType, pCanonicalURL, pVersion)
{
}

Method GetSuggestionsList() As %ListOfDataTypes
{
	Set suggestions = ##class(%ListOfDataTypes).%New()
	/// Look up details of the ValueSets according to the current snapshot
	If '..Snapshot.%IsDefined("binding") {
		Return suggestions
	}

	Set binding = ..Snapshot.%Get("binding")

	If 'binding.%IsDefined("valueSet") {
		Return suggestions
	}

	Set valueSet = binding.%Get("valueSet")

	/// Rather than following the logic for the $expand operation,
	/// use the built in expand operation
	#; Set ..PackageList = $lb("hl7.fhir.r4.core@4.0.1")
	Set meta = ##class(HS.FHIRMeta.Impl.MetaRsrcInfo).%New($lb("hl7.fhir.r4.core@4.0.1"))
	
	Do meta.ExpandValueSet(valueSet, .codes)
	// codeSystemAndVersion can be:
	// - CodeSystemUri|CodeSystemVersion, when the ValueSet specified a version.
	// - CodeSystemUri only, when the ValueSet did not specify a version.
	Set codeSystemAndVersion = ""
	
	For {
		Set codeSystemAndVersion = $Order(codes(codeSystemAndVersion))
		Quit:codeSystemAndVersion=""

		Set codeSystemUri = $Piece(codeSystemAndVersion, "|", 1)
		Set codeSystemVersion = $Piece(codeSystemAndVersion, "|", 2)
		Set code = ""
		For {
			Set code = $Order(codes(codeSystemAndVersion, code), 1, display)
			Quit:code=""
			
			Do suggestions.Insert(code)
		}
	}

	Return suggestions
}

}
