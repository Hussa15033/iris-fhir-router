Class Auwais.FHIRPath.Parser Extends %RegisteredObject
{

Property Prefix As %ArrayOfObjects;

Property Infix As %ArrayOfObjects;

Property TokenStream As Auwais.FHIRPath.TokenStream;

Method %OnNew(pTokenStream As Auwais.FHIRPath.TokenStream) As %Status
{
	Set ..TokenStream = pTokenStream
	Quit $$$OK
}

Method LBP(pToken As Auwais.FHIRPath.Tokens.Token) As %Integer
{
	Return:pToken.Type="EOF" 0
	Set inf = ..Infix.GetAt(pToken.Type)

	Return inf.Precedence()
}

Method ParseExpression(pRBP As %Integer) As Auwais.FHIRPath.Expr.Expression
{
	Set t1 = ..Consume()
	#dim nud As Auwais.FHIRPath.Parselet.Prefix
	Set nud = ..Prefix.GetAt(t1.Type)

	Throw:nud="" ##class(%Exception.General).%New("No prefix parselet found","-3922",,"No prefix parselet found for " _ t1.Type)
	
	Set left = nud.Parse($THIS, t1)

	while (pRBP < ..LBP(..Peek())) {
		Set op = ..Consume()
		#dim led As Auwais.FHIRPath.Parselet.Infix
		Set led = ..Infix.GetAt(op.Type)
		Throw:nud="" ##class(%Exception.General).%New("No infix parselet found","-3922",,"No infix parselet found for " _ op.Type)
		Set left = led.Parse($THIS, left, op)
	}

	Return left
}

ClassMethod Test()
{
	Set input = "1+2*3"
	Set tokenStream = ##class(Auwais.FHIRPath.TokenStream).%New(input)
	Set parser = ##class(Auwais.FHIRPath.Parser).%New(tokenStream)

	Do parser.RegisterPrefix("NUMBER", ##class(Auwais.FHIRPath.Parselet.NumberParselet).%New())
	Do parser.RegisterPrefix("IDENT", ##class(Auwais.FHIRPath.Parselet.IdentParselet).%New())
	Do parser.RegisterPrefix("LPAREN", ##class(Auwais.FHIRPath.Parselet.GroupParselet).%New())

	Do parser.RegisterInfix("PLUS", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New("PLUS", 10))
	Do parser.RegisterInfix("MINUS", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New("MINUS", 10))
	Do parser.RegisterInfix("STAR", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New("STAR", 20))
	Do parser.RegisterInfix("SLASH", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New("SLASH", 20))

	Set expr = parser.ParseExpression(0)
	Return expr
}

// Register parselets

Method RegisterPrefix(pTokenType As %String, pParselet As Auwais.FHIRPath.Parselet.Prefix)
{
	Do ..Prefix.SetAt(pParselet, pTokenType)
}

Method RegisterInfix(pTokenType As %String, pParselet As Auwais.FHIRPath.Parselet.Infix)
{
	Do ..Infix.SetAt(pParselet, pTokenType)
}

/// Helper methods for the parselets
Method Parse(pRBP = 0)
{
	Return ..ParseExpression(pRBP)
}

Method Peek() As Auwais.FHIRPath.Tokens.Token
{
	Return ..TokenStream.Peek()
}

Method Consume() As Auwais.FHIRPath.Tokens.Token
{
	Return ..TokenStream.Consume()
}

Method Match(pTokenType) As %Boolean
{
	Return ..TokenStream.Match(pTokenType)
}

Method Expect(pTokenType) As Auwais.FHIRPath.Tokens.Token
{
	Return ..TokenStream.Expect(pTokenType)
}

}
