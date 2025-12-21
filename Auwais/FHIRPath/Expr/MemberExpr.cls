Class Auwais.FHIRPath.Expr.MemberExpr Extends Expression
{

Property Name As %String;

Property Obj As Expression;

Method %OnNew(pObj As Expression, pName As %String) As %Status
{
	Set ..Name = pName
	Set ..Obj = pObj
	Return $$$OK
}

}
