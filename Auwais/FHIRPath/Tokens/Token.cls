Class Auwais.FHIRPath.Tokens.Token Extends %RegisteredObject
{

Property Type As %String(VALUELIST = ",NUMBER,IDENT,PLUS,MINUS,STAR,SLASH,LPAREN,RPAREN,DOT,COMMA,EOF");

Property Lexeme As %String;

Property Literal As %String;

Property Pos As %Integer;

Method %OnNew(pType As %String(VALUELIST=",NUMBER,IDENT,PLUS,MINUS,STAR,SLASH,LPAREN,RPAREN,DOT,COMMA,EOF"), pLexeme = "", pLiteral = "", pPos = 0) As %Status
{
		Set ..Type = pType
		Set ..Lexeme = pLexeme
		Set ..Literal = pLiteral
		Set ..Pos = pPos
		Quit $$$OK
}

}
