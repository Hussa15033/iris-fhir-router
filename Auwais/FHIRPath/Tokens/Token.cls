/// A single token string used by the parser
/// 
/// Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Tokens.Token Extends %RegisteredObject
{

Property Type As %String(VALUELIST = ",STRING,NUMBER,IDENT,PLUS,MINUS,AS,IS,STAR,SLASH,LPAREN,RPAREN,DOT,CONCAT,EQUALS,LOGIC_XOR,LOGIC_IMPLIES,LOGIC_AND,NOT_EQUALS,LOGIC_OR,LT,LTE,GT,GTE,COMMA,LSQRBRACKET,RSQRBRACKET,UNION,EOF");

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
