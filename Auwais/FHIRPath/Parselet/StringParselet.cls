Class FHIR.FHIRPath.Parselet.StringParselet Extends Prefix
{

Method Parse(pParser As FHIR.FHIRPath.Parser, pToken As FHIR.FHIRPath.Tokens.Token) As FHIR.FHIRPath.Expr.Expression
{
	Return ##class(FHIR.FHIRPath.Expr.StringExpr).%New(pToken.Literal)
}

}
