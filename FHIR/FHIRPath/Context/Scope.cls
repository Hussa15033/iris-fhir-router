Class FHIR.FHIRPath.Context.Scope Extends %RegisteredObject
{

/// TODO: Use the DataType and CompletionType properties properly,
/// DataType: Data type of the current item stored
/// CompletionType: The type of completion suggestions we're looking for (e.g. function, operator, etc.)
/// 
/// E.g. the initial data type and completion type for a blank expression is the root context,
/// 	- DataType: "ANY"
/// 	- CompletionType: "RESOURCE"
/// 	- All other vars are null/empty
/// 
Property DataType As %String(VALUELIST = "NONE,RESOURCE,FHIRTYPE,BOOLEAN,STRING,INTEGER,LITERAL,UNKNOWN");

Property CompletionType As %String(VALUELIST = "ANY,VALUE,TYPE,FUNCTION,OPERATOR,RESOURCE,LITERALTYPE");

Property FHIRType As %List;

Property Cardinality As %Integer;

Property ScopedVariables As %List;

Property PrefixToken As %String;

Property GlobalRef As %String;

Property Function As %String;

Method Duplicate()
{
	Set dupe = ..%New()
	Set dupe.DataType = ..DataType
	Set dupe.FHIRType = ..FHIRType
	Set dupe.Cardinality = ..Cardinality
	Set dupe.ScopedVariables = ..ScopedVariables
	Set dupe.CompletionType = ..CompletionType
	Set dupe.GlobalRef = ..GlobalRef
	Set dupe.Function = ..Function
	Return dupe
}

Method Reset()
{
	Set ..DataType = ""
	Set ..FHIRType = ""
	Set ..Cardinality = 0
	Set ..ScopedVariables = ""
	Set ..CompletionType = ""
	Set ..GlobalRef = ""
	Set ..Function = ""
	Set ..PrefixToken = ""
}

Method ScopedVariablesSet(pVal) As %Status
{
	/// Convert %list to a set
	If $LISTVALID(pVal) && (pVal '= "") {
		Set globSet = ""
		Set i%ScopedVariables = ""
		For i=1:1:$LL(pVal) {
			Set v = $LG(pVal, i)
			If ('$DATA(globSet(v))) {
				Set globSet(v) = 1
				Set i%ScopedVariables = i%ScopedVariables _ $lb(v)
			}
		}
	}
	
	Return $$$OK
}

}
