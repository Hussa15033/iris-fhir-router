Class Auwais.FHIRPath.FHIRContextHelper Extends %RegisteredObject
{

Property ResourceContext As %DynamicObject;

Property CurrentContext As %DynamicObject;

Property Fields As %ArrayOfDataTypes;

Property CollectionFields As %ListOfDataTypes;

Property AvailableFields As %ListOfDataTypes;

Property IsCollection As %Boolean;

Property WithinFunction As %String;

Property Status As %Status;

Method %OnNew() As %Status
{
	Set ..Status = $$$OK
	Quit $$$OK
}

ClassMethod BuildResourceContext(pResource As %String) As Auwais.FHIRPath.FHIRContextHelper
{
	Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT * FROM HS_FHIRMeta_Storage.Rsrc WHERE coreVersion=? AND id=type AND kind='resource' AND %UPPER(id)=?", "4.0.1", $ZCVT(pResource, "U"))
	Throw:tRS.%Next()=0 ##class(%Exception.General).%New("Resource '" _ pResource _ "' does not exist", "-20322",,"")
	Set sd = {}.%FromJSON(tRS.%Get("json"))

	Set ctx = ##class(Auwais.FHIRPath.FHIRContextHelper).%New()
	Set ctx.ResourceContext = sd

	Do ctx.LoadContext(sd)

	Return ctx
}

Method LoadContext(pStructureDefinition As %DynamicObject) [ Private ]
{
	/// Loads the context of a different structure into this helper
	Set ..CurrentContext = pStructureDefinition
	
	/// This method traverses the StructureDefinition of an item
	/// and builds its context
	#dim elements As %DynamicArray
	Set elements = pStructureDefinition.snapshot.element
	Set iter = elements.iterator()
	/// Reset fields context
	Do ..Fields.Clear()
	Do ..CollectionFields.Clear()

	While (iter.%GetNext(.key, .value)) {
		Continue:(value.path = pStructureDefinition.name) /// Ignore first element

		Set path = $LISTFROMSTRING(value.path,".")
		Set props = $LIST(path, 2, *)
		Set propName = $LISTTOSTRING(props, ".")

		Set types = value.type
		Continue:types=""	
		Set typeIter = types.iterator()
		While (typeIter.%GetNext(.k1, .type)) {
			Set code = type.code
			Do ..Fields.SetAt(code, propName)
		}

		If (value.max = "*") || (value.max > 1) {
			Do ..CollectionFields.Insert(propName)
		}
	}
}

Method Reset()
{
	Set ..CurrentContext = ..ResourceContext
}

Method AdvanceFunction(pFunctionName As %String) As %Boolean
{
	Set fnName = $ZCVT(pFunctionName, "L")
	If (fnName = "aggregate") {
		Do ..AvailableFields.Insert("$this")
		Do ..AvailableFields.Insert("$total")
		Quit 1
	}

	Quit 0
}

Method AdvanceContext(pNextField As %String, pIsFunction As %Boolean = 0) As %Boolean
{
	/// Switch the FHIR context helper to the context
	/// specified by pNextField
	If (pIsFunction) {
		Set validFn = ..AdvanceFunction(pNextField)
		Set:validFn=0 ..Status = $$$ERROR($$$GeneralError, "Function '" _ pNextField _ "' does not exist within this context")
		Quit validFn
	}
	Set nextType = ..Fields.GetAt(pNextField)
	Set:nextType="" ..Status = $$$ERROR($$$GeneralError, "Field '" _ pNextField _ "' is not valid within this context")
	Quit:nextType="" 0

	Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT * FROM HS_FHIRMeta_Storage.Rsrc WHERE coreVersion=? AND %UPPER(id)=? AND resourceType='StructureDefinition'", "4.0.1", $ZCVT(nextType, "U"))
	Set validField = tRS.%Next()
	Set:(pNextField'="")&&(validField=0) ..Status = $$$ERROR($$$GeneralError, "Field '" _ pNextField _ "' is not valid within this context")
	Quit:validField=0 0
	
	/// Loop through all fields to find any that are "hanging"
	/// Hanging fields are those specified in the path of a StructureDefinition
	/// but are subproperties of another field
	/// e.g. within a Patient resource we have:
	/// Patient.contact
	/// Patient.contact.address
	/// Patient.contact.gender
	/// The .address and .gender are considered "hanging"
	Set hangingFields = ##class(%ArrayOfDataTypes).%New()
	Set collectionHangingFields = ##class(%ListOfDataTypes).%New()
	Set nKey = ..Fields.Next("")
	While nKey '= "" {
		Set part = $LISTFROMSTRING(nKey, ".")
		If ($LG(part, 1) = pNextField) {
			If ($LL(part) > 2) {
				Throw ##class(%Exception.General).%New("More than 1 hanging field found","-30344",,)
			} ElseIf ($LL(part) = 2) {
				/// The 2nd element is hanging
				#; Write "Set hanging field " _ ..Fields.GetAt(nKey)
				Do hangingFields.SetAt(..Fields.GetAt(nKey), $LG(part, 2))

				If (..CollectionFields.Find(nKey, "") '= "") {
					Do collectionHangingFields.Insert($LG(part, 2))
				}
			}
		}

		Set nKey = ..Fields.Next(nKey)
	}

	Set ..IsCollection = 0
	If (..CollectionFields.Find(pNextField) '= "") {
		Set ..IsCollection = 1
	}

	Set sd = {}.%FromJSON(tRS.%Get("json"))
	Do ..LoadContext(sd)

	/// Copy all hanging fields into the current context
	Set cKey = hangingFields.Next("")
	While cKey '= "" {
		Do ..Fields.SetAt(hangingFields.GetAt(cKey), cKey)
		Do:collectionHangingFields.Find(cKey,"")'="" ..CollectionFields.Insert(cKey)
		Set cKey = hangingFields.Next(cKey)
	}
	Return 1
}

Method GetPropertyList() As %ListOfDataTypes
{
	Set props = ##class(%ListOfDataTypes).%New()
	Set k = ..Fields.Next("")
	While k '= "" {
		Do props.Insert(k)
		Set k = ..Fields.Next(k)
	}

	Set k = ..AvailableFields.Next("")
	While k '= "" {
		Do props.Insert(..AvailableFields.GetAt(k))
		Set k = ..AvailableFields.Next(k)
	}

	Return props
}

Method GetFunctionsList() As %ListOfDataTypes
{
	Set fns = ##class(%ListOfDataTypes).%New()

	If ..IsCollection {
		/// Add collection functions
		Do fns.Insert("where(")
		Do fns.Insert("exists()")
		Do fns.Insert("empty()")
		Do fns.Insert("first()")
		Do fns.Insert("last()")
		Do fns.Insert("skip()")
		Do fns.Insert("tail()")
		Do fns.Insert("take(")
		Do fns.Insert("hasExtension(")
	}

	If (..CurrentContext.kind = "primitive-type") {
		Set type = ..CurrentContext.type

		If (type = "string") || (type = "code") {
			Do fns.Insert("substring")
			Do fns.Insert("startsWith")
			Do fns.Insert("endsWith")
			Do fns.Insert("indexOf")
		} ElseIf (type = "date") {
			/// No supported date/time functions
		} Else {
			Throw ##class(%Exception.General).%New("Cannot handle primitive type " _ type,"-303444",,"Failed to handle primitive data type '" _ type _ "' for autocomplete")
		}
	} Else {
		Do fns.Insert("descendants()")
	}

	Return fns
}

}
