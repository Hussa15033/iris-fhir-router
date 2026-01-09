Class Auwais.FHIRRouter.RoutingEngine Extends EnsLib.MsgRouter.RoutingEngine [ ClassType = persistent ]
{

Property FHIRJSON As %DynamicObject;

Method OnRequest(request As Ens.StreamContainer, Output response As %Persistent) As %Status
{
	Set ..FHIRJSON = {}.%FromJSON(request.Stream.Read())
	Set tSC = ##super(request,.response)
	Quit tSC
}

Storage Default
{
<Data name="FHIRJSON">
<Attribute>FHIRJSON</Attribute>
<Structure>node</Structure>
<Subscript>"Auwais.FHIRRouter.RoutingEngine.FHIRJSON"</Subscript>
</Data>
<Type>%Storage.Persistent</Type>
}

}
