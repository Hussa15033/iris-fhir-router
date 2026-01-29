Class Auwais.FHIRPath.TokenStream Extends %RegisteredObject
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
			"<":"LT",
			"<=":"LTE",
			">":"GT",
			">=":"GTE",
			")":"RPAREN",
			"+":"PLUS",
			"-":"MINUS",
			"*":"STAR",
			"/":"SLASH",
			"]":"RSQRBRACKET",
			"!=":"NOT_EQUALS",
			"|":"UNION",
			"EOT":"EOF",
			:"")
			Throw:opType="" ##class(%Exception.General).%New("No matching token for operator","-303282",,"Cannot handle operator '" _token.opName_"'")
			Set t1 = ##class(Auwais.FHIRPath.Tokens.Token).%New(opType,,token.opName)
		} ElseIf (token.idName = "(") {
			Set t1 = ##class(Auwais.FHIRPath.Tokens.Token).%New("LPAREN")
		} ElseIf (token.idName = "[") {
			Set t1 = ##class(Auwais.FHIRPath.Tokens.Token).%New("LSQRBRACKET")
		} ElseIf (token.literalType = "string") {
			Set t1 = ##class(Auwais.FHIRPath.Tokens.Token).%New("STRING",,token.idName)
		} ElseIf (token.literalType = "integer") || (token.literalType = "decimal") {
			Set t1 = ##class(Auwais.FHIRPath.Tokens.Token).%New("NUMBER",,token.idName)
		} Else {
			Set t1 = ##class(Auwais.FHIRPath.Tokens.Token).%New("IDENT",token.idName)
		}

		Do ..Tokens.Insert(t1)
	}

	Quit $$$OK
}

Method Peek() As Auwais.FHIRPath.Tokens.Token
{
	If (..TokenIndex > ..Tokens.Size) {
		Set ..TokenIndex = ..Tokens.Size
	}
	Return ..Tokens.GetAt(..TokenIndex)
}

Method Consume() As Auwais.FHIRPath.Tokens.Token
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

Method Expect(pTokenType As %String) As Auwais.FHIRPath.Tokens.Token
{
	If (..Peek().Type '= pTokenType) {
		Throw ##class(%Exception.General).%New("Expected " _ pTokenType,"-302",,"Expected " _ pTokenType _ " but got " _ ..Peek().Type)
	}

	Return ..Consume()
}

}
