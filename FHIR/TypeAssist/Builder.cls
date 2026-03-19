Class FHIR.TypeAssist.Builder Extends %RegisteredObject
{

Property types;

ClassMethod Load(loader As HS.FHIRMeta.Load.NpmLoader)
{
	Kill ^FHIR.TypeAssist
	Set iter = loader.getRsrcIterator("StructureDefinition")

	While iter.Next(.json) {
		Set kind = $REPLACE(json.kind, "-", " ")
		Set kind = $ZCONVERT(kind, "W")
		Set kind = $REPLACE(kind, " ", "")
		Try {
			Do $CLASSMETHOD($THIS, "Load" _ kind, json)
		} Catch ex {
			/// Todo: This try/catch should be removed once typeassist is completed,
			/// we do not expect any exceptions to occur
			If (ex.DisplayString() [ "METHOD DOES NOT EXIST") {
				Write kind _ " not supported yet",!
			} Else {
				zw json.url
				Throw ##class(%Exception.General).%New("Exception: " _ ex.DisplayString())
			}
		}
		
	}
}

ClassMethod LoadResource(sd As %DynamicObject)
{
	Set rType = sd.type
	Set els = sd.snapshot.element
	Throw:els="" ##class(%Exception.General).%New("Snapshot not defined for resource " _ rType _ ": " _ sd.url)

	Set global = "^FHIR.TypeAssist"
	Set global = ..AppendSubscript(global, "Resource")

	Do ..ParseSnapshot(sd, global, sd.type)
}

ClassMethod GetValueSets(sd As %DynamicObject)
{
	Set list = ""
	If sd.%IsDefined("binding") {
		Set iter = sd.binding.iterator()
		While iter.%GetNext(.k1, .v1, .t1) {
			Continue:k1'["valueSet"
			Set list = list _ $lb(v1)
		}
	}

	Return list
}

/// Appends a subscript to a global ref
ClassMethod AppendSubscript(base As %String, subscriptValue) As %String
{
	Return:subscriptValue="" base

	If '$LISTVALID(subscriptValue) {
		Set subscriptValue = $lb(subscriptValue)
	}

	For i=1:1:$LL(subscriptValue) { 
		Set base = $NAME(@base@($LG(subscriptValue, i)))
	}

	Return base
}

ClassMethod ParseSnapshot(sd As %DynamicObject, baseGlobal As %String, elementType As %String)
{
	Set els = sd.snapshot.element
	Throw:els="" ##class(%Exception.General).%New("Snapshot not defined for element type '" _ elementType _ "': " _ sd.url)

	Set baseGlobal = ..AppendSubscript(baseGlobal, elementType)
	Set baseGlobal = ..AppendSubscript(baseGlobal, sd.url)

	Set iter = els.iterator()

	Set aux = ""
	While (iter.%GetNext(.key, .val, .type)) {

		Set field = $PIECE(val.path, ".", 2, *)

		Set fieldSet = $lb(field)

		Set choices = ..ExpandChoiceField(field, val.type, .aux)

		Set:(choices'="")&&$LISTVALID(choices) fieldSet = choices

		Set fixedVals = ..GetFixedValues(val)
		Set bindings = ..GetValueSets(val)
		#; zw val.path
		#; zw sd.url
		#; zw fieldSet
		#; zw choices
		#; zw aux
		For i=1:1:$LL(fieldSet) {
			Set fNameType = $LG(fieldSet, i)
			Set fName = $PIECE(fNameType, ":", 1)
			Set type = $PIECE(fNameType, ":", 2, *)

			Set fieldSplit = $LISTFROMSTRING(fName, ".")

			Set base2 = baseGlobal

			For j=1:1:$LL(fieldSplit) {
				Set base2 = ..AppendSubscript(base2, $LG(fieldSplit, j))
			}

			Set data = ""

			If '$DATA(@base2) {
				Set data = data _ $lb("type:" _ type)
			} Else {
				Set data = $GET(@base2)
			}

			If bindings '= "" {
				For k=1:1:$LL(bindings) {
					Set vs = "vs:" _ $LG(bindings, k)
					Set:'$LF(data, vs) data = data _ $lb(vs)
				}
			}

			If fixedVals '= "" {
				For l=1:1:$LL(fixedVals) {
					Set fv = "fv:" _ $LG(fixedVals, l)
					Set:'$LF(data, fv) data = data _ $lb(fv)
				}
			}

			Set @base2 = data
		}
	}
}

/// sd: StructureDefinition resource
/// elementType: Resource, Type, Extension
ClassMethod ParseDifferential(sd As %DynamicObject, baseGlobal As %String, elementType As %String)
{
	Throw:'sd.%IsDefined("differential") ##class(%Exception.General).%New("Differential not defined: " _ sd.url)

	Set baseGlobal = ..AppendSubscript(baseGlobal, elementType)
	Set baseGlobal = ..AppendSubscript(baseGlobal, sd.url)

	Set els = sd.differential.element
	Set iter = els.iterator()
	While (iter.%GetNext(.key, .val, .type)) {
		Set field = $PIECE(val.path, ".", 2)
		Continue:(field="extension")||(val.path="Extension")

		Set fields = $lb(field)
		Set choices = ..ExpandChoiceField(field, val.type)
		Set:$LISTVALID(choices) fields = choices

		Set fixedVals = ..GetFixedValues(val)
		
		For i=1:1:$LL(fields) {
			Set fName = $PIECE($LG(fields, i), ":", 1)
			Set type = $PIECE($LG(fields, i), ":", 2, *)
			Set global = ..AppendSubscript(baseGlobal, fName)

			Set @global = $lb("type:" _ type)
		}
	}
}

ClassMethod LoadComplexType(sd As %DynamicObject)
{
	Set global = "^FHIR.TypeAssist"
	Set global = ..AppendSubscript(global, "Type")

	If (sd.%IsDefined("snapshot")) {
		Do ..ParseSnapshot(sd, global, sd.type)
	}
	#; Throw:'$CASE(sd.type, "Extension":1, :0) ##class(%Exception.General).%New("Complex type not handled: " _ sd.type _ ", url: " _ sd.url)


	If ('sd.%IsDefined("differential")) {
		Throw ##class(%Exception.General).%New("Differential must be defined in extension " _ sd.url)
	}

	Set global = "^FHIR.TypeAssist"
	Do ..ParseDifferential(sd, global, "Extension")
}

ClassMethod GetFixedValues(val As %DynamicObject)
{
	Set objIter = val.iterator()

	Set fixedVals = ""
	While objIter.%GetNext(.k2, .v2, .t2) {
		If k2 [ "fixed" {
			Set fixedVals = fixedVals _ $lb(v2)
		}
	}

	Return fixedVals
}

ClassMethod ExpandChoiceField(pFieldName, pTypes, aux = "") As %List
{
	Return:pTypes="" ""

	Set path = $LISTFROMSTRING($PIECE(pFieldName, ".", 1, *-1), ".")

	If (path '= "") && ($GET(aux(path))) {
		Set pTypes = aux(path)
	}
	Set list = ""
	Set aux(pFieldName) = pTypes
	/// Loop through the data types
	Set typeIter = pTypes.iterator()
	While (typeIter.%GetNext(.k1, .type)) {
		Set code = type.code

		/// The value replacing [x] is camel case of the type of the property
		Set upperCaseType = $ZCVT($EXTRACT(code, 1, 1), "U") _ $EXTRACT(code, 2, *)
		Set fieldName = $REPLACE(pFieldName, "[x]", upperCaseType)
		
		Set list = list _ $lb(fieldName _ ":" _ code)
	}

	Return list
}

}
