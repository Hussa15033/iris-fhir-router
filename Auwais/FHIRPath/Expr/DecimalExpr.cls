Class Auwais.FHIRPath.Expr.DecimalExpr Extends Expression
{

Property Value As %Decimal;

Method %OnNew(pValue As %Decimal) As %Status
{
	Set ..Value = pValue
	Return $$$OK
}

}
