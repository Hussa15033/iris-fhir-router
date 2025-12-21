Class Auwais.FHIRPath.Parselet.IdentParselet Extends Prefix
{

Method Parse(pParser As Auwais.FHIRPath.Parser, pToken As Auwais.FHIRPath.Tokens.Token) As Auwais.FHIRPath.Expr.Expression
{
	Return ##class(Auwais.FHIRPath.Expr.IdentExpr).%New(pToken.Lexeme)
}

}
