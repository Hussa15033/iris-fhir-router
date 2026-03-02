///
/// A parselet to parse the tokens for a decimal/integer expression
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Parselet.NumberParselet Extends Prefix
{

Method Parse(pParser As FHIR.FHIRPath.Parser, pToken As FHIR.FHIRPath.Tokens.Token) As FHIR.FHIRPath.Expr.Expression
{
	If (pToken.Literal [ ".") {
		Return ##class(FHIR.FHIRPath.Expr.DecimalExpr).%New(pToken.Literal)
	} Else {
		Return ##class(FHIR.FHIRPath.Expr.NumberExpr).%New(pToken.Literal)
	}
}

}
