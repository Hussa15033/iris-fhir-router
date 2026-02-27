Class FHIR.FHIRPath.Parselet.Infix Extends %RegisteredObject [ Abstract ]
{

Property Precedence As %Integer;

Method Precedence() As %Integer
{
	Return ..Precedence
}

Method Parse(pParser As FHIR.FHIRPath.Parser, pLeft As FHIR.FHIRPath.Expr.Expression, pToken As FHIR.FHIRPath.Tokens.Token) [ Abstract ]
{
}

}
