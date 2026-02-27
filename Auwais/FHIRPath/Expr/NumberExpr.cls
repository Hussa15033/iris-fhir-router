Class FHIR.FHIRPath.Expr.NumberExpr Extends Expression
{

Property Value As %Integer;

Method %OnNew(pValue As %Integer) As %Status
{
	Set ..Value = pValue
	Return $$$OK
}

}
