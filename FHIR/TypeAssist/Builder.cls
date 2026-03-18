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

		}
		
	}
}

ClassMethod LoadComplexType(sd As %DynamicObject)
{
	Throw:'$CASE(sd.type, "Extension":1, :0) ##class(%Exception.General).%New("Complex type not handled: " _ sd.type _ ", url: " _ sd.url)

	If ('sd.%IsDefined("differential")) {
		Throw ##class(%Exception.General).%New("Differential must be defined in extension " _ sd.url)
	}

	Do ..LoadExtension(sd)
}

ClassMethod LoadExtension(sd As %DynamicObject)
{
	Set els = sd.differential.element
	Set iter = els.iterator()
	While (iter.%GetNext(.key, .val, .type)) {
		Set field = $PIECE(val.path, ".", 2)
		Continue:(field="extension")||(val.path="Extension")

		Set fields = $lb(field)
		Set choices = ..ExpandChoiceField(field, val.type)
		Set:choices'="" fields = choices

		Set fixedVal = ..GetFixedValue(val)
	
		For i=1:1:$LL(fields) {
			Set ^FHIR.TypeAssist("Extension", sd.url, $LG(fields, i)) = $lb(fixedVal)
		}
	}
}

ClassMethod GetFixedValue(val As %DynamicObject)
{
	Set objIter = val.iterator()

	Set fixedVal = ""
	While objIter.%GetNext(.k2, .v2, .t2) {
		If k2 [ "fixed" {
			Set fixedVal = v2
		}
	}

	Return fixedVal
}

ClassMethod ExpandChoiceField(pFieldName, pTypes)
{
	Return:pFieldName'["[x]" ""

	Set list = ""
	/// Loop through the data types
	Set typeIter = pTypes.iterator()
	While (typeIter.%GetNext(.k1, .type)) {
		Set code = type.code

		/// The value replacing [x] is camel case of the type of the property
		Set upperCaseType = $ZCVT($EXTRACT(code, 1, 1), "U") _ $EXTRACT(code, 2, *)
		Set fieldName = $REPLACE(pFieldName, "[x]", upperCaseType)
		
		Set list = list _ $lb(fieldName)
	}

	Return list
}

}
