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
/// 
/// TODO: DataType should be a list not a string.
Property DataType As %String(VALUELIST = "NONE,RESOURCE,FHIRTYPE,BOOLEAN,STRING,INTEGER,LITERAL,UNKNOWN,EMPTY");

Property CompletionType As %String(VALUELIST = "ANY,VALUE,TYPE,FUNCTION,PROPERTY,RESOURCE,OPERATOR,NONE") [ InitialExpression = "RESOURCE" ];

Property CompletionScope As %String(VALUELIST = "ALL,DIRECT");

/// TODO: Rename this to FHIRTypes (plural)
Property FHIRType As %List;

Property Cardinality As %Integer [ InitialExpression = 1 ];

Property ScopedVariables As %List;

/// Rename PrefixToken to Prefix
Property PrefixToken As %String;

Property GlobalRefs As %List;

Property Function As %String;

/// Rename LastField to LastToken
Property LastField As %String;

/// List of property:value splits
Property Context As %List;

/// Reference to the resource global
Property RootScope As Scope;

Method MergeScope(pScope As FHIR.FHIRPath.Context.Scope)
{
	/// TODO: This merge function needs to be fixed to properly merge scopes
	/// it currently performs an extremely basic merge (that is technically incorrect)
	/// Merge another scope into this
	Set ..DataType = "FHIRTYPE"
	Set ..FHIRType = pScope.FHIRType _ ..FHIRType
	Set ..Cardinality = "*"
	Set ..GlobalRefs = pScope.GlobalRefs _ ..GlobalRefs
	Set ..Context = pScope.Context _ ..Context
	Set ..LastField = ""
}

Method Duplicate()
{
	Set dupe = ..%New()
	Set dupe.DataType = ..DataType
	Set dupe.FHIRType = ..FHIRType
	Set dupe.Cardinality = ..Cardinality
	Set dupe.ScopedVariables = ..ScopedVariables
	Set dupe.CompletionType = ..CompletionType
	Set dupe.GlobalRefs = ..GlobalRefs
	Set dupe.Function = ..Function
	Set dupe.CompletionScope = ..CompletionScope
	Set dupe.RootScope = ..RootScope
	Set dupe.LastField = ..LastField
	Set dupe.Context = ..Context
	Return dupe
}

/// Create a child scope from this
Method Child()
{
	Set dupe = ..%New()
	Set dupe.DataType = ..DataType
	Set dupe.FHIRType = ..FHIRType
	Set dupe.Cardinality = ..Cardinality
	Set dupe.ScopedVariables = ..ScopedVariables
	Set dupe.CompletionType = ..CompletionType
	Set dupe.GlobalRefs = ..GlobalRefs
	Set dupe.Function = ..Function
	Set dupe.CompletionScope = ..CompletionScope
	Set dupe.RootScope = ..RootScope
	Set dupe.LastField = ..LastField
	Set dupe.Context = ..Context
	Return dupe
}

Method Reset()
{
	Set ..DataType = ""
	Set ..FHIRType = ""
	Set ..Cardinality = 0
	Set ..ScopedVariables = ""
	Set ..CompletionType = ""
	Set ..GlobalRefs = ""
	Set ..Function = ""
	Set ..PrefixToken = ""
	Set ..CompletionScope = ""
	Set ..LastField = ""
	Set ..Context = ""
}

Method ContextSet(pVal) As %Status
{
	If '$LISTVALID(pVal) && (pVal '= "") {
		Set pVal = $lb(pVal)
	}

	Set i%Context = pVal
}

Method FHIRTypeSet(pVal) As %Status
{
	If '$LISTVALID(pVal) && (pVal '= "") {
		Set pVal = $lb(pVal)
	}

	Set i%FHIRType = pVal
}

Method GlobalRefsSet(pVal) As %Status
{
	If '$LISTVALID(pVal) && (pVal '= "") {
		Set pVal = $lb(pVal)
	}

	Set i%GlobalRefs = pVal
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
