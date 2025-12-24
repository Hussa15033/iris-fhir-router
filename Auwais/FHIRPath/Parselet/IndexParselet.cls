Class Auwais.FHIRPath.Parselet.IndexParselet Extends Infix
{

Method %OnNew(pPrecedence As %Integer) As %Status
{
	Set ..Precedence = pPrecedence
	Quit $$$OK
}

Method Parse(pParser As Auwais.FHIRPath.Parser, pLeft As Auwais.FHIRPath.Expr.Expression, pToken As Auwais.FHIRPath.Tokens.Token)
{
	Set expr = pParser.Parse(0)

	If (pParser.Peek().Type = "EOF") {
		Return ##class(Auwais.FHIRPath.Expr.PartialExpr).%New()
	}
	
	Do pParser.Expect("RSQRBRACKET")

	Return ##class(Auwais.FHIRPath.Expr.IndexExpr).%New(pLeft, expr)
}

}
