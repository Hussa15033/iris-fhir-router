/// 
Class Auwais.FHIRRouter.RoutingRule Extends Ens.Rule.Definition
{

Parameter RuleAssistClass = "Auwais.FHIRRouter.RuleAssist";

ClassMethod evaluateRuleDefinition(pContext As %RegisteredObject, Output pRuleSet As %String, Output pEffectiveBegin As %String, Output pEffectiveEnd As %String, Output pReturnValue As %String, Output pReason As %String, pLogLevel As %String = {$$$eRuleLogTypeReturn}, pDebugId As %Integer = "") As %Status [ CodeMode = objectgenerator ]
{
	Quit ##class(Auwais.FHIRRouter.Rule.Generator).generateRuleDefinition(%compiledclass,%code)
}

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="" context="Auwais.FHIRRouter.RoutingEngine" production="HCCDEMOPKG.FoundationProduction">
<ruleSet name="" effectiveBegin="" effectiveEnd="">
<rule name="Test Rule" disabled="false">
<constraint name="source" value="FHIRRouter"></constraint>
<constraint name="FHIRVersion" value="4.0.1"></constraint>
<constraint name="resourceFilter" value="Patient"></constraint>
<when condition="(Patient.name.where(use=&quot;official&quot;))=&quot;John&quot;" comment="">
</when>
</rule>
</ruleSet>
</ruleDefinition>
}

}
