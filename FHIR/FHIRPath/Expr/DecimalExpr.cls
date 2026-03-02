///
/// A decimal number expression representation for the AST
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Expr.DecimalExpr Extends Expression
{

Property Value As %Decimal;

Method %OnNew(pValue As %Decimal) As %Status
{
	Set ..Value = pValue
	Return $$$OK
}

}
