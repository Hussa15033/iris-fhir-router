/// 
/// The parser class itself. The parser class uses Pratt parsing
/// to parse the FHIRPath expression. This parser is extendible to other
/// syntaxes, not just FHIRPath.
/// 
/// The <method>ParseString</method> method creates a FHIRPath expression parser,
/// however similar parser could be created using the same setup process
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Parser Extends %RegisteredObject
{

Property Prefix As %ArrayOfObjects [Private];

Property Infix As %ArrayOfObjects [Private];

Property Root As FHIR.FHIRPath.Expr.Expression;

Property PrefixString As %String;

Property TokenStream As FHIR.FHIRPath.TokenStream;

Method %OnNew(pTokenStream As FHIR.FHIRPath.TokenStream) As %Status
{
	Set ..TokenStream = pTokenStream
	Quit $$$OK
}

Method LBP(pToken As FHIR.FHIRPath.Tokens.Token) As %Integer
{
	Set inf = ..Infix.GetAt(pToken.Type)

	Return:inf="" 0
	Return inf.Precedence()
}

Method ParseExpression(pRBP As %Integer) As FHIR.FHIRPath.Expr.Expression
{
	Set t1 = ..Consume()
	#; Write "Consumed " _ t1.Type _ ":" _ t1.Lexeme _ ":" _ t1.Literal,!
	#dim nud As FHIR.FHIRPath.Parselet.Prefix

	Set nud = ..Prefix.GetAt(t1.Type)

	If (t1.Type = "EOF") {
		Quit ##class(FHIR.FHIRPath.Expr.PartialExpr).%New()
	}

	Throw:nud="" ##class(%Exception.General).%New("No prefix parselet found","-3922",,"No prefix parselet found for " _ t1.Type)
	
	#; Write "nud is " _ $CLASSNAME(nud),!
	Set left = nud.Parse($THIS, t1)

	while (pRBP < ..LBP(..Peek())) {
		Set op = ..Consume()
		#; Write "OP token is " _ op.AsString()
		#dim led As FHIR.FHIRPath.Parselet.Infix
		Set led = ..Infix.GetAt(op.Type)
		Throw:led="" ##class(%Exception.General).%New("No infix parselet found","-3922",,"No infix parselet found for " _ op.Type)
		Set left = led.Parse($THIS, left, op)
	}

	Return left
}

/// TODO: Separate Parser from FHIRPath syntax, Parse should be a modular component that can be used on its own
ClassMethod ParseString(pInput As %String) As FHIR.FHIRPath.Parser
{
	Set tokenStream = ##class(FHIR.FHIRPath.TokenStream).%New(pInput)

	Set parser = ..%New(tokenStream)

	/// TODO: Add operator precedence according to the FHIRPath docs
	/// https://hl7.org/fhirpath/#operator-precedence
	/// Create the parsing rules for FHIRPath
	/// NOTE: OPERATOR PRECEDENCE IS INCORRECT IN THIS IMPLEMENTATION AND IS ROUGH ESTIMATE

	/// Ordered by operator precendence according to the FHIRPath specification:
	/// https://hl7.org/fhirpath/#operator-precedence
	/// Note: Website shows highest-lowest precedence

	/// Commented register* calls below have not been implemented in the current IRIS
	/// FHIRPath implementation

	/// Function call is the highest
	Do parser.RegisterInfix("LPAREN", ##class(FHIR.FHIRPath.Parselet.CallParselet).%New(15))
	
	/// 01
	Do parser.RegisterInfix("DOT", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(13))

	/// 02
	Do parser.RegisterInfix("LSQRBRACKET", ##class(FHIR.FHIRPath.Parselet.IndexParselet).%New(12))

	/// 03
	Do parser.RegisterPrefix("MINUS", ##class(FHIR.FHIRPath.Parselet.UnaryParselet).%New(11))
	Do parser.RegisterPrefix("PLUS", ##class(FHIR.FHIRPath.Parselet.UnaryParselet).%New(11))

	/// 04
	Do parser.RegisterInfix("MULTIPLY", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(10))
	Do parser.RegisterInfix("DIVISION", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(10))
	#; Do parser.RegisterInfix("DIV", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(10))
	#; Do parser.RegisterInfix("MOD", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(10))

	/// 05
	Do parser.RegisterInfix("PLUS", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(9))
	Do parser.RegisterInfix("MINUS", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(9))
	Do parser.RegisterInfix("CONCAT", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(9))

	/// 06
	Do parser.RegisterInfix("AS", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(8))
	Do parser.RegisterInfix("IS", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(8))
	
	/// 07
	Do parser.RegisterInfix("UNION", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(7))

	/// 08
	Do parser.RegisterInfix("GT", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(6))
	Do parser.RegisterInfix("GTE", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(6))
	Do parser.RegisterInfix("LT", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(6))
	Do parser.RegisterInfix("LTE", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(6))

	/// 09
	Do parser.RegisterInfix("EQUALS", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(5))
	Do parser.RegisterInfix("NOT_EQUALS", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(5))
	#; Do parser.RegisterInfix("EQUIV", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(5))
	#; Do parser.RegisterInfix("NOT_EQUIV", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(5))

	/// 10
	Do parser.RegisterInfix("IN", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(4))
	Do parser.RegisterInfix("CONTAINS", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(4))

	/// 11
	Do parser.RegisterInfix("LOGIC_AND", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(3))

	/// 12
	Do parser.RegisterInfix("LOGIC_OR", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(2))
	Do parser.RegisterInfix("LOGIC_XOR", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(2))

	/// 13
	Do parser.RegisterInfix("LOGIC_IMPLIES", ##class(FHIR.FHIRPath.Parselet.BinaryOpParselet).%New(1))

	Do parser.RegisterPrefix("NUMBER", ##class(FHIR.FHIRPath.Parselet.NumberParselet).%New())
	Do parser.RegisterPrefix("IDENT", ##class(FHIR.FHIRPath.Parselet.IdentParselet).%New())
	Do parser.RegisterPrefix("LPAREN", ##class(FHIR.FHIRPath.Parselet.GroupParselet).%New())
	
	Do parser.RegisterPrefix("STRING", ##class(FHIR.FHIRPath.Parselet.StringParselet).%New())
	Do parser.RegisterPrefix("AS", ##class(FHIR.FHIRPath.Parselet.IdentParselet).%New())
	Do parser.RegisterPrefix("IS", ##class(FHIR.FHIRPath.Parselet.IdentParselet).%New())
	

	Set parser.Root = parser.ParseExpression(0)
	Return parser
}

ClassMethod Test()
{
	Set input = "Patient.telecom.where(1 and 1).first().v"
	Set expr = ..ParseString(input)

	Return expr
}

// Register parselets

Method RegisterPrefix(pTokenType As %String, pParselet As FHIR.FHIRPath.Parselet.Prefix)
{
	Do ..Prefix.SetAt(pParselet, pTokenType)
}

Method RegisterInfix(pTokenType As %String, pParselet As FHIR.FHIRPath.Parselet.Infix)
{
	Do ..Infix.SetAt(pParselet, pTokenType)
}

/// Helper methods for the parselets
Method Parse(pRBP = 0)
{
	Return ..ParseExpression(pRBP)
}

Method Peek() As FHIR.FHIRPath.Tokens.Token
{
	Set nToken = ..TokenStream.Peek()
	Throw:nToken="" ##class(%Exception.General).%New("No token found","-302",,"Failed to peek at next token")
	Return nToken
}

Method Consume() As FHIR.FHIRPath.Tokens.Token
{
	Return ..TokenStream.Consume()
}

Method Match(pTokenType) As %Boolean
{
	Return ..TokenStream.Match(pTokenType)
}

Method Expect(pTokenType) As FHIR.FHIRPath.Tokens.Token
{
	Return ..TokenStream.Expect(pTokenType)
}

}
