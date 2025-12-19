/**
* This class is an autocomplete function for FHIRPath
*/

Class Auwais.FHIRPath.Autocomplete Extends %RegisteredObject
{

Property Resource As %String;

Property FHIRVersion As %String [ InitialExpression = "4.0.1" ];

Property Paths As %ListOfDataTypes;

Method %OnNew() As %Status
{
	Quit $$$OK
}

Method SearchPaths(pResourceType As %String, pSearchTerm As %String, ByRef paths As %ListOfDataTypes)
{
	Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT * FROM HS_FHIRMeta_Storage.Rsrc WHERE coreVersion=? AND id=type AND kind='resource' AND %UPPER(id)=?", "4.0.1", $ZCVT(pResourceType, "U"))
	Quit:tRS.%Next()=0
	Set obj = {}.%FromJSON(tRS.%Get("json"))


	#dim elements As %DynamicArray
	Set elements = obj.snapshot.element
	Set iter = elements.iterator()

	

	While (iter.%GetNext(.key, .value)) {
		Continue:($ZCVT($EXTRACT(value.path, 1, $L(pSearchTerm)), "L"))'=$ZCVT(pSearchTerm,"L")
		Continue:(pResourceType = value.path)
		If (value.path [ "[x]") {
			/// Enumerate paths
			Set types = value.type
			Set typeIter = types.iterator()
			While (typeIter.%GetNext(.key2, .value2)) {
				Do paths.Insert($EXTRACT(value.path,$F(value.path, "."),*-3)_$ZCVT(value2.code, "w"))
			}
		} Else {
			Do paths.Insert($EXTRACT(value.path, $F(value.path, "."),*))
		}
	}
}

Method Suggest(pExpression As %String) As %ListOfDataTypes
{
	/// First, locate the resource type.
	Set ..Resource = $PIECE(pExpression, ".")

	/// Check if this resource exists
	Set pathList = ##class(%ListOfDataTypes).%New()
	Do ..SearchPaths(..Resource, pExpression, .pathList)

	Return pathList
}

}
