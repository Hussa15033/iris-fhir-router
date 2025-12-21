Class Auwais.FHIRPath.Parselet.CallParselet Extends Infix
{

Method %OnNew(pPrecedence As %Integer) As %Status
{
	Set ..Precedence = pPrecedence
	Quit $$$OK
}

Method Parse(pParser As Auwais.FHIRPath.Parser, pLeft As Auwais.FHIRPath.Expr.Expression, pToken As Auwais.FHIRPath.Tokens.Token) As Auwais.FHIRPath.Expr.Expression
{
	Set PartialCall = 1
	Set Args = ##class(%ListOfObjects).%New()

	If '(pParser.Peek().Type = "RPAREN") {
		Do Args.Insert(pParser.Parse(0))
		While pParser.Match("COMMA") {
			Do Args.Insert(pParser.Parse(0))
		}

		/// After we have parsed the arguments, we expect a RIGHTPAREN
		If pParser.Peek().Type '= "EOF" {
			Set PartialCall = 0
			/// We expected RPAREN, but got an EOF
			Do pParser.Expect("RPAREN")
		}
	}

	Return ##class(Auwais.FHIRPath.Expr.CallExpr).%New(pLeft, Args, PartialCall)
}

}
