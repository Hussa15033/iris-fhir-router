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
	Set inf = ..Infix.GetAt(pToken.Type)

	Return:inf="" 0
	Return inf.Precedence()
}

Method ParseExpression(pRBP As %Integer) As Auwais.FHIRPath.Expr.Expression
{
	Set t1 = ..Consume()
	#; Write "Consumed " _ t1.Type _ ":" _ t1.Lexeme _ ":" _ t1.Literal,!
	#dim nud As Auwais.FHIRPath.Parselet.Prefix

	Set nud = ..Prefix.GetAt(t1.Type)

	If (t1.Type = "EOF") {
		Quit ##class(Auwais.FHIRPath.Expr.PartialExpr).%New()
	}

	Throw:nud="" ##class(%Exception.General).%New("No prefix parselet found","-3922",,"No prefix parselet found for " _ t1.Type)
	
	#; Write "nud is " _ $CLASSNAME(nud),!
	Set left = nud.Parse($THIS, t1)

	while (pRBP < ..LBP(..Peek())) {
		Set op = ..Consume()
		#; Write "OP token is " _ op.AsString()
		#dim led As Auwais.FHIRPath.Parselet.Infix
		Set led = ..Infix.GetAt(op.Type)
		Throw:led="" ##class(%Exception.General).%New("No infix parselet found","-3922",,"No infix parselet found for " _ op.Type)
		Set left = led.Parse($THIS, left, op)
	}

	Return left
}

/// TODO: Separate Parser from FHIRPath syntax, Parse should be a modular component that can be used on its own
ClassMethod ParseString(pInput As %String) As Auwais.FHIRPath.Parser
{
	Set tokenStream = ##class(Auwais.FHIRPath.TokenStream).%New(pInput)

	Set parser = ##class(Auwais.FHIRPath.Parser).%New(tokenStream)

	/// TODO: Add operator precedence according to the FHIRPath docs
	/// https://hl7.org/fhirpath/#operator-precedence
	Do parser.RegisterPrefix("NUMBER", ##class(Auwais.FHIRPath.Parselet.NumberParselet).%New())
	Do parser.RegisterPrefix("IDENT", ##class(Auwais.FHIRPath.Parselet.IdentParselet).%New())
	Do parser.RegisterPrefix("LPAREN", ##class(Auwais.FHIRPath.Parselet.GroupParselet).%New())
	Do parser.RegisterPrefix("MINUS", ##class(Auwais.FHIRPath.Parselet.UnaryParselet).%New(130))
	Do parser.RegisterPrefix("STRING", ##class(Auwais.FHIRPath.Parselet.StringParselet).%New())
	Do parser.RegisterPrefix("AS", ##class(Auwais.FHIRPath.Parselet.IdentParselet).%New())
	Do parser.RegisterPrefix("IS", ##class(Auwais.FHIRPath.Parselet.IdentParselet).%New())

	Do parser.RegisterInfix("GT", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(5))
	Do parser.RegisterInfix("GTE", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(5))
	Do parser.RegisterInfix("LT", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(5))
	Do parser.RegisterInfix("LTE", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(5))
	Do parser.RegisterInfix("PLUS", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(10))
	Do parser.RegisterInfix("MINUS", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(10))
	Do parser.RegisterInfix("STAR", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(20))
	Do parser.RegisterInfix("SLASH", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(20))
	Do parser.RegisterInfix("DOT", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(100))
	Do parser.RegisterInfix("LPAREN", ##class(Auwais.FHIRPath.Parselet.CallParselet).%New(110))
	Do parser.RegisterInfix("EQUALS", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(112))
	Do parser.RegisterInfix("NOT_EQUALS", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(112))
	Do parser.RegisterInfix("LOGIC_AND", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(108))
	Do parser.RegisterInfix("LOGIC_OR", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(107))
	Do parser.RegisterInfix("LOGIC_XOR", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(107))
	Do parser.RegisterInfix("UNION", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(107))
	Do parser.RegisterInfix("LSQRBRACKET", ##class(Auwais.FHIRPath.Parselet.IndexParselet).%New(120))
	Do parser.RegisterInfix("AS", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(103))
	Do parser.RegisterInfix("IS", ##class(Auwais.FHIRPath.Parselet.BinaryOpParselet).%New(103))

	Return parser.ParseExpression(0)
}

ClassMethod Test()
{
	Set input = "Patient.telecom.where(1 and 1).first().v"
	Set expr = ..ParseString(input)

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
	Set nToken = ..TokenStream.Peek()
	Throw:nToken="" ##class(%Exception.General).%New("No token found","-302",,"Failed to peek at next token")
	Return nToken
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
