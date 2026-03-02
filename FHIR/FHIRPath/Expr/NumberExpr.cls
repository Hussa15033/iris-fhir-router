///
/// An integer expression representation for the AST
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Expr.NumberExpr Extends Expression
{

Property Value As %Integer;

Method %OnNew(pValue As %Integer) As %Status
{
	Set ..Value = pValue
	Return $$$OK
}

}
