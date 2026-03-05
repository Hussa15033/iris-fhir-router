/// 
/// Encapsulates a stream of tokens and converts them from the native FHIRPath
/// parser into the custom parser created. All operators have been mapped as
/// needed
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.TokenStream Extends %RegisteredObject
{

Property TokenIndex As %Integer [ InitialExpression = 1 ];

Property Tokens As %ListOfObjects;

Method %OnNew(pInput As %String) As %Status
{
	/// Lex using the built in FHIRPath lexer
	/// Then translate tokens for custom parser
	Set lexer = ##class(HS.FHIRPath.Lexer).%New()
	Do lexer.lex(pInput, .output)

	For i=1:1:output {
		#dim token As HS.FHIRPath.Token
		Set token = output(i)
		If token.opName '= "" {
			Set opType = $CASE(token.opName,
			".":"DOT",
			"=":"EQUALS",
			"and":"LOGIC_AND",
			"or":"LOGIC_OR",
			"xor":"LOGIC_XOR",
			"implies":"LOGIC_IMPLIES",
			"<":"LT",
			"<=":"LTE",
			">":"GT",
			">=":"GTE",
			")":"RPAREN",
			"+":"PLUS",
			"-":"MINUS",
			"*":"MULTIPLY",
			"/":"DIVISION",
			"div":"DIV",
			"mod":"MOD",
			"as":"AS",
			"is":"IS",
			"]":"RSQRBRACKET",
			"&":"CONCAT",
			"!=":"NOT_EQUALS",
			"~":"EQUIV",
			"!~":"NOT_EQUIV",
			"|":"UNION",
			"in":"IN",
			"contains":"CONTAINS",
			"EOT":"EOF",
			:"")
			Throw:opType="" ##class(%Exception.General).%New("No matching token for operator","-303282",,"Cannot handle operator '" _token.opName_"'")
			Set t1 = ##class(FHIR.FHIRPath.Tokens.Token).%New(opType,token.opName,token.opName)
		} ElseIf (token.idName = "(") {
			Set t1 = ##class(FHIR.FHIRPath.Tokens.Token).%New("LPAREN")
		} ElseIf (token.idName = "[") {
			Set t1 = ##class(FHIR.FHIRPath.Tokens.Token).%New("LSQRBRACKET")
		} ElseIf (token.literalType = "string") {
			Set t1 = ##class(FHIR.FHIRPath.Tokens.Token).%New("STRING",,token.idName)
		} ElseIf (token.literalType = "integer") || (token.literalType = "decimal") {
			Set t1 = ##class(FHIR.FHIRPath.Tokens.Token).%New("NUMBER",,token.idName)
		} Else {
			Set t1 = ##class(FHIR.FHIRPath.Tokens.Token).%New("IDENT",token.idName)
		}

		Do ..Tokens.Insert(t1)
	}

	Quit $$$OK
}

Method Peek() As FHIR.FHIRPath.Tokens.Token
{
	If (..TokenIndex > ..Tokens.Size) {
		Set ..TokenIndex = ..Tokens.Size
	}
	Return ..Tokens.GetAt(..TokenIndex)
}

Method Consume() As FHIR.FHIRPath.Tokens.Token
{
	Set token = ..Peek()
	Set ..TokenIndex = ..TokenIndex + 1
	Return token
}

Method Match(pTokenType As %String) As %Boolean
{
	If (..Peek().Type '= pTokenType) {
		Return 0
	}

	Do ..Consume()
	Return 1
}

Method Expect(pTokenType As %String) As FHIR.FHIRPath.Tokens.Token
{
	If (..Peek().Type '= pTokenType) {
		Throw ##class(%Exception.General).%New("Expected " _ pTokenType,"-302",,"Expected " _ pTokenType _ " but got " _ ..Peek().Type)
	}

	Return ..Consume()
}

}
