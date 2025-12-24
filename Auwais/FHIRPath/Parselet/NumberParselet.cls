Class Auwais.FHIRPath.Parselet.NumberParselet Extends Prefix
{

Method Parse(pParser As Auwais.FHIRPath.Parser, pToken As Auwais.FHIRPath.Tokens.Token) As Auwais.FHIRPath.Expr.Expression
{
	If (pToken.Literal [ ".") {
		Return ##class(Auwais.FHIRPath.Expr.DecimalExpr).%New(pToken.Literal)
	} Else {
		Return ##class(Auwais.FHIRPath.Expr.NumberExpr).%New(pToken.Literal)
	}
}

}
