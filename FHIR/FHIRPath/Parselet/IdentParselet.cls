///
/// A parselet to parse the tokens for an identity expression
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Parselet.IdentParselet Extends Prefix
{

Method Parse(pParser As FHIR.FHIRPath.Parser, pToken As FHIR.FHIRPath.Tokens.Token) As FHIR.FHIRPath.Expr.Expression
{
	Return ##class(FHIR.FHIRPath.Expr.IdentExpr).%New(pToken.Lexeme)
}

}
