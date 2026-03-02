///
/// A literal string expression representation for the AST
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Expr.StringExpr Extends Expression
{

Property Value As %String;

Method %OnNew(pValue As %String) As %Status
{
	Set ..Value = pValue
	Return $$$OK
}

}
