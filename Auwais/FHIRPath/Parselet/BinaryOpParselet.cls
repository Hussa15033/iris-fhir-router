Class Auwais.FHIRPath.Parselet.BinaryOpParselet Extends Infix
{

Property Op As %String;

Method %OnNew(pPrecedence As %Integer) As %Status
{
	Set ..Precedence = pPrecedence
	Quit $$$OK
}

Method Parse(pParser As Auwais.FHIRPath.Parser, pLeft As Auwais.FHIRPath.Expr.Expression, pToken As Auwais.FHIRPath.Tokens.Token)
{
	Set right = pParser.Parse(..Precedence())
	Return ##class(Auwais.FHIRPath.Expr.BinaryExpr).%New(pLeft, pToken.Literal, right)
}

}
