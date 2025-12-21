Class Auwais.FHIRPath.Expr.CallExpr Extends Expression
{

Property Callee As Expression;

Property Args As %ListOfObjects;

Method %OnNew(pCallee As Expression, pArgs As %ListOfObjects) As %Status
{
		Set ..Callee = pCallee
		Set ..Args = pArgs
		Quit $$$OK
}

}
