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

Property CompletionType As %String(VALUELIST = "ANY,VALUE,TYPE,FUNCTION,IDENTIFIER,RESOURCE,LITERALTYPE,OPERATOR,NONE") [ InitialExpression = "RESOURCE" ];

Property CompletionScope As %String(VALUELIST = "ALL,DIRECT,CHILD");

Property FHIRType As %List;

Property Cardinality As %Integer [ InitialExpression = 1 ];

Property ScopedVariables As %List;

Property PrefixToken As %String;

Property GlobalRef As %String;

Property Function As %String;

Property LastField As %String;

/// Reference to the resource global
Property RootRef As %String;

Method MergeScope(pScope As FHIR.FHIRPath.Context.Scope)
{
	/// TODO: This merge function needs to be fixed to properly merge scopes
	/// it currently performs an extremely basic merge (that is technically incorrect)
	/// Merge another scope into this
	Set pScope.DataType = "FHIRTYPE"
	Set pScope.FHIRType = pScope.FHIRType _ ..FHIRType
	Set pScope.Cardinality = ..Cardinality

	Return pScope
}

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
	Set dupe.CompletionScope = ..CompletionScope
	Set dupe.RootRef = ..RootRef
	Set dupe.LastField = ..LastField
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
	Set ..CompletionScope = ""
	Set ..LastField = ""
}

Method FHIRTypeSet(pVal) As %Status
{
	If '$LISTVALID(pVal) && (pVal '= "") {
		Set pVal = $lb(pVal)
	}

	Set i%FHIRType = pVal
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
	} ElseIf ('$LISTVALID(pVal)) {
		Set i%ScopedVariables = $lb(pVal)
	}
	
	Return $$$OK
}

}
