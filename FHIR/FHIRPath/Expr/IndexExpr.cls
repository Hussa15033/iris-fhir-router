///
/// An index expression representation for the AST
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Expr.IndexExpr Extends Expression
{

Property Field As Expression;

Property Index As Expression;

Method %OnNew(pField As Expression, pIndex As Expression) As %Status
{
	Set ..Field = pField
	Set ..Index = pIndex
	Return $$$OK
}

}
