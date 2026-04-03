Class FHIR.FHIRPath.Context.Scope Extends %RegisteredObject
{

Property DataType As %String(VALUELIST = "RESOURCE,FHIRTYPE,BOOLEAN,STRING,INTEGER,LITERAL,UNKNOWN");

Property CompletionType As %String(VALUELIST = "ANY,VALUE,TYPE,FUNCTION,OPERATOR");

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

}
