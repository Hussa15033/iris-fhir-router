///
/// An identity expression representation for the AST
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Expr.IdentExpr Extends Expression
{

Property Name As %String;

Method %OnNew(pName As %String) As %Status
{
	Set ..Name = pName
	Return $$$OK
}

}
