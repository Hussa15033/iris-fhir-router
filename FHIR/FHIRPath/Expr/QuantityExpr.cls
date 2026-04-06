/// 
/// A Quantity expression representation for the AST. This takes in an amount (could be decimal or integer) and a unit
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Expr.QuantityExpr Extends Expression
{

Property Quantity As %String;

Property Unit As %String;

Method %OnNew(pQuantity As %String, pUnit As %String) As %Status
{
	Set ..Quantity = pQuantity
	Set ..Unit = pUnit
	Return $$$OK
}

}
