Class Auwais.FHIRPath.Tokens.Token Extends %RegisteredObject
{

Property Type As %String(VALUELIST = ",NUMBER,IDENT,PLUS,MINUS,STAR,SLASH,LPAREN,RPAREN,DOT,COMMA,LSQRBRACKET,RSQRBRACKET,EOF");

Property Lexeme As %String;

Property Literal As %String;

Property Pos As %Integer;

Method %OnNew(pType As %String, pLexeme = "", pLiteral = "", pPos = 0) As %Status
{
		Set ..Type = pType
		Set ..Lexeme = pLexeme
		Set ..Literal = pLiteral
		Set ..Pos = pPos
		Set tSC = ..%ValidateObject()
		$$$ThrowOnError(tSC)
		
		Quit tSC
}

Method AsString()
{
	Return ..Type _ ":" _ ..Lexeme _ ":" _ ..Literal
}

}
