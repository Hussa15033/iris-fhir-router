///
/// A parselet to parse the tokens for a grouping using "(" and ")"
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Parselet.GroupParselet Extends Prefix
{

Method Parse(pParser As FHIR.FHIRPath.Parser, pToken As FHIR.FHIRPath.Tokens.Token) As FHIR.FHIRPath.Expr.Expression
{
	Set expr = pParser.Parse(0)
	Do pParser.Expect("RPAREN")
	Return expr
}

}
