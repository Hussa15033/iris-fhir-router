Class Auwais.FHIRPath.Expr.BinaryExpr Extends Expression
{

Property Left As Expression;

Property Op As %String;

Property Right As Expression;

Method %OnNew(pLeft As Expression, pOp As %String, pRight As Expression) As %Status
{
	Set ..Left = pLeft
	Set ..Op = pOp
	Set ..Right = pRight
	Return $$$OK
}

}
