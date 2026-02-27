Class FHIR.FHIRPath.Expr.CallExpr Extends Expression
{

Property Callee As Expression;

Property Args As %ListOfObjects;

/// True if this expression is an unclosed function
Property Partial As %Boolean;

Method %OnNew(pCallee As Expression, pArgs As %ListOfObjects, pPartial As %Boolean = 0) As %Status
{
		Set ..Callee = pCallee
		Set ..Args = pArgs
		Set ..Partial = pPartial
		Quit $$$OK
}

}
