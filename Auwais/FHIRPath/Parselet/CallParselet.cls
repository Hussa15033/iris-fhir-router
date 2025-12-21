Class Auwais.FHIRPath.Parselet.CallParselet Extends Infix
{

Method %OnNew(pPrecedence As %Integer) As %Status
{
	Set ..Precedence = pPrecedence
	Quit $$$OK
}

Method Parse(pParser As Auwais.FHIRPath.Parser, pLeft As Auwais.FHIRPath.Expr.Expression, pToken As Auwais.FHIRPath.Tokens.Token) As Auwais.FHIRPath.Expr.Expression
{
	Write !,"Parsing call...",!
	Set Args = ##class(%ListOfObjects).%New()

	If '(pParser.Peek().Type = "RPAREN") {
		Write "RPAREN not found.. parsing arguments",!
		Do Args.Insert(pParser.Parse(0))
		Write "Done parsing..."
		While pParser.Match("COMMA") {
			Do Args.Insert(pParser.Parse(0))
		}
		Do pParser.Expect("RPAREN")
	}

	Write "Expecting INFIX RPAREN"
	Return ##class(Auwais.FHIRPath.Expr.CallExpr).%New(pLeft, Args)
}

}
