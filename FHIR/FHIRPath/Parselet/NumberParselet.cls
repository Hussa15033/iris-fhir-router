/// 
/// A parselet to parse the tokens for a decimal/integer expression
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Parselet.NumberParselet Extends Prefix
{

Method Parse(pParser As FHIR.FHIRPath.Parser, pToken As FHIR.FHIRPath.Tokens.Token) As FHIR.FHIRPath.Expr.Expression
{
	Set nextToken = pParser.Peek()

	If (nextToken.Type = "STRING") {
		Do pParser.Consume()
		/// If the next token is a STRING, we are dealing with a quantity
		Return ##class(FHIR.FHIRPath.Expr.QuantityExpr).%New(pToken.Literal, nextToken.Literal)
	}

	If nextToken.Type = "IDENTIFIER" {
		Do pParser.Consume()
	}
	If (pToken.Literal [ ".") {
		Return ##class(FHIR.FHIRPath.Expr.DecimalExpr).%New(pToken.Literal)
	} Else {
		Return ##class(FHIR.FHIRPath.Expr.NumberExpr).%New(pToken.Literal)
	}
}

}
