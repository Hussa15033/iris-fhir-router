Class Auwais.FHIRPath.Expr.UnaryExpr Extends Expression
{

Property Op As %String;

Property Expr As Expression;

Method %OnNew(pOp As %String, pRight As Expression) As %Status
{
	Set ..Op = pOp
	Set ..Expr = pRight
	Return $$$OK
}

}
