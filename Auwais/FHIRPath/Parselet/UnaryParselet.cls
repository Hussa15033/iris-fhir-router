Class Auwais.FHIRPath.Parselet.UnaryParselet Extends Prefix
{

Property Op As %String;

Property Precedence;

Method %OnNew(pPrecedence As %Integer) As %Status
{
	Set ..Precedence = pPrecedence
	Quit $$$OK
}

Method Parse(pParser As Auwais.FHIRPath.Parser, pToken As Auwais.FHIRPath.Tokens.Token) As Auwais.FHIRPath.Expr.Expression
{
	Set expr = pParser.Parse(..Precedence)
	Return ##class(Auwais.FHIRPath.Expr.UnaryExpr).%New(pToken.Literal, expr)
}

}
