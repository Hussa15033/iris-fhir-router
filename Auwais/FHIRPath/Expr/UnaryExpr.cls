Class Auwais.FHIRPath.Expr.UnaryExpr Extends Expression
{

Property Op As %String;

Property pRight As Expression;

Method %OnNew(pOp As %String, pRight As Expression) As %Status
{
	Set ..Op = pOp
	Set ..pRight = pRight
	Return $$$OK
}

}
