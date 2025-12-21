Class Auwais.FHIRPath.Parselet.Infix Extends %RegisteredObject [ Abstract ]
{

Property Precedence As %Integer;

Method Precedence() As %Integer
{
	Return ..Precedence
}

Method Parse(pParser As Auwais.FHIRPath.Parser, pLeft As Auwais.FHIRPath.Expr.Expression, pToken As Auwais.FHIRPath.Tokens.Token) [ Abstract ]
{
}

}
