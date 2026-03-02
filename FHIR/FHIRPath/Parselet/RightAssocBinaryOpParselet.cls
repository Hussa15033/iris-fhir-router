///
/// A parselet to parse a right assosciated binary expression
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Parselet.RightAssocBinaryOpParselet Extends Infix
{

Property Op As %String;

Method %OnNew(pOp As %String, pPrecedence As %Integer) As %Status
{
	Set ..Precedence = pPrecedence
	Quit $$$OK
}

Method Parse(pParser As FHIR.FHIRPath.Parser, pLeft As FHIR.FHIRPath.Expr.Expression, pToken As FHIR.FHIRPath.Tokens.Token)
{
	Set right = pParser.Parse(..Precedence() - 1)
	Return ##class(FHIR.FHIRPath.Expr.BinaryExpr).%New(pLeft, ..Op, right)
}

}
