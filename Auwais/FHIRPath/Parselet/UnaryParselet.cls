Class FHIR.FHIRPath.Parselet.UnaryParselet Extends Prefix
{

Property Op As %String;

Property Precedence;

Method %OnNew(pPrecedence As %Integer) As %Status
{
	Set ..Precedence = pPrecedence
	Quit $$$OK
}

Method Parse(pParser As FHIR.FHIRPath.Parser, pToken As FHIR.FHIRPath.Tokens.Token) As FHIR.FHIRPath.Expr.Expression
{
	Set expr = pParser.Parse(..Precedence)
	Return ##class(FHIR.FHIRPath.Expr.UnaryExpr).%New(pToken.Literal, expr)
}

}
