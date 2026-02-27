Class FHIR.FHIRPath.Parselet.IndexParselet Extends Infix
{

Method %OnNew(pPrecedence As %Integer) As %Status
{
	Set ..Precedence = pPrecedence
	Quit $$$OK
}

Method Parse(pParser As FHIR.FHIRPath.Parser, pLeft As FHIR.FHIRPath.Expr.Expression, pToken As FHIR.FHIRPath.Tokens.Token)
{
	Set expr = pParser.Parse(0)

	If (pParser.Peek().Type = "EOF") {
		Return ##class(FHIR.FHIRPath.Expr.PartialExpr).%New()
	}
	
	Do pParser.Expect("RSQRBRACKET")

	Return ##class(FHIR.FHIRPath.Expr.IndexExpr).%New(pLeft, expr)
}

}
