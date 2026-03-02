///
/// A parselet for providing prefix operator functionality
/// e.g. "(", "-", ...
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Parselet.Prefix Extends %RegisteredObject [ Abstract ]
{

Method Parse(pParser As FHIR.FHIRPath.Parser, pToken As FHIR.FHIRPath.Tokens.Token) As FHIR.FHIRPath.Expr.Expression [ Abstract ]
{
}

}
