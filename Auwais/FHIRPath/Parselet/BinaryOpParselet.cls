Class FHIR.FHIRPath.Parselet.BinaryOpParselet Extends Infix
{

Property Op As %String;

Method %OnNew(pPrecedence As %Integer) As %Status
{
	Set ..Precedence = pPrecedence
	Quit $$$OK
}

Method Parse(pParser As FHIR.FHIRPath.Parser, pLeft As FHIR.FHIRPath.Expr.Expression, pToken As FHIR.FHIRPath.Tokens.Token)
{
	Set right = pParser.Parse(..Precedence())
	Return ##class(FHIR.FHIRPath.Expr.BinaryExpr).%New(pLeft, pToken.Literal, right)
}

}
