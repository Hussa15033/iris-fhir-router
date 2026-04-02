Class FHIR.FHIRPath.Context.Scope Extends %RegisteredObject
{

Property DataType As %String(VALUELIST = "RESOURCE,FHIRTYPE,BOOLEAN,STRING,INTEGER,LITERAL,UNKNOWN");

Property CompletionType As %String(VALUELIST = "VALUE,TYPE,FUNCTION,OPERATOR");

Property FHIRType As %String;

Property Cardinality As %Integer;

Property ScopedVariables As %List;

Property GlobalRef As %String;

Method Duplicate()
{
	Set dupe = ..%New()
	Set dupe.DataType = ..DataType
	Set dupe.FHIRType = ..FHIRType
	Set dupe.Cardinality = ..Cardinality
	Set dupe.ScopedVariables = ..ScopedVariables
	Set dupe.GlobalRef = ..GlobalRef
	Return dupe
}

}
