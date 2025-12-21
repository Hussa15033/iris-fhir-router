Class Auwais.FHIRPath.Parselet.GroupParselet Extends Prefix
{

Method Parse(pParser As Auwais.FHIRPath.Parser, pToken As Auwais.FHIRPath.Tokens.Token) As Auwais.FHIRPath.Expr.Expression
{
	Set expr = pParser.Parse(0)
	Do pParser.Expect("RPAREN")
	Return expr
}

}
