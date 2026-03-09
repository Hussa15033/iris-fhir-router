/// 
/// The generator class which converts the rule XML into the corresponding objectscript code
/// Much of these methods are copied from the parent "Ens.Rule.Generator" class.
/// 
/// Overridden functionality here expects all expressions to be valid FHIRPath expression - there is
/// currently no fallback to ObjectScript code if the FHIRPath evaluation fails.
/// 
/// The generateFHIRPathEval() method generates the code to evaluate FHIR expressions on the go
/// 
/// @author Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRRouter.Rule.Generator Extends Ens.Rule.Generator
{

/// todo; Update FHIR version to NOT be fixed...
ClassMethod generateOneAction(pClassname As %String, variables As %String, pAction As Ens.Rule.Model.action, pReason As %String, pAssistClass As %String, %code As %Stream.MethodGenerator, pLevel As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		if ( pAction.type = "rule" ) {
			if ( pAction.disabled ) quit
			do ..line("; Evaluating rule: "_pReason,pLevel)
			if ( pAssistClass'="" ) {
				do ..line("kill tConstraints",pLevel)
				for i=1:1:pAction.constraints.Count() {
					If (($f(pAction.constraints.GetAt(i).value,"""_")'=0) && ($f(pAction.constraints.GetAt(i).value,"_""",$f(pAction.constraints.GetAt(i).value,"""_"))'=0)) {
						set tSC = $$$ERROR($$$EnsErrGeneral,"Invalid Constraint: "_pAction.constraints.GetAt(i).name_"="_pAction.constraints.GetAt(i).value_". Constraint values should not contain ""_ and _""")
						quit
					}
					do ..line("set tConstraints("""_pAction.constraints.GetAt(i).name_""")="""_pAction.constraints.GetAt(i).value_"""",pLevel)
				}
				Quit:$$$ISERR(tSC)
				do ..line("set tSC=##class("_pAssistClass_").RuntimeConstraintCheck(.tConstraints,pContext,.pPassed) quit:$$$ISERR(tSC)",pLevel)
				do ..line("if (pLogLevel [ $$$eRuleLogTypeConditionDebug) set tSC = ##class(Ens.Rule.DebugLog).Log(pDebugId,$$$eRuleLogTypeConditionDebug,"_$$$quote(pReason)_","_$$$quote("Constraints for rule '"_$select(pAction.name = "": pReason, 1: pAction.name)_"' ")_"_$select(pPassed: ""passed"",1: ""failed"") _ $CASE($G(tConstraints(""constraintErrorMsg"")), """":"""", :"": ""_tConstraints(""constraintErrorMsg"")),0) quit:$$$ISERR(tSC)",pLevel)
				do ..line("if pPassed {",pLevel)
				set pLevel=pLevel+1
			}
			Set tSC = ..generateWhens(pClassname,.variables,pAction,pReason,pAssistClass,%code,pLevel)
			if ( pAssistClass'="" ) { set pLevel=pLevel-1 do ..line("}",pLevel) }
			Quit:$$$ISERR(tSC)
		} elseif ( pAction.type = "assign" ) {
			/// Override the value of the expression to be an objectscript call to the FHIRPath evaluator
			set tSC = ..generateFHIRPathEval(pAction.value, .tValueExpression, 0, pLevel)
			return:'$$$ISOK(tSC) tSC
			#; set tSC=##class(Ens.Rule.Model.expression).convertToCOS(pAction.value,.tValueExpression,.variables) quit:$$$ISERR(tSC)
			set tSC = ##class(Ens.Rule.Model.expression).convertToCOS(pAction.property, .tVProp,.variables,1) quit:$$$ISERR(tSC)
			if tVProp["SetValueAt" {
				do ..line("do "_$p(tVProp,",",1)_tValueExpression_","_$p(tVProp,",",2),pLevel)
			}
			else {
				do ..line("set "_tVProp_"="_tValueExpression,pLevel)
			}
		} elseif ( pAction.type = "return" ) {
			set tSC = ..generateFHIRPathEval(pAction.value, .tExpression, 0, pLevel)
			return:'$$$ISOK(tSC) tSC

			#; set tSC=##class(Ens.Rule.Model.expression).convertToCOS(pAction.value,.tExpression,.variables) quit:$$$ISERR(tSC)
			do ..line("set tReturn = 1",pLevel)
			if tExpression'="" {
				do ..line("set pReturnValue="_tExpression_" quit",pLevel)
			} else {
				do ..line("quit",pLevel)
			}
		} elseif ( pAction.type = "trace" ) {
			// Old method to convert to ObjectScript:
			// set tSC=##class(Ens.Rule.Model.expression).convertToCOS(pAction.value,.tExpression,.variables)
			// quit:$$$ISERR(tSC)
			
			set tSC = ..generateFHIRPathEval(pAction.value, .tExpression, 0, pLevel)
			return:'$$$ISOK(tSC) tSC

			do ..line("do ##class(Ens.Util.Trace).WriteTrace(""user"",$$$CurrentClass,$$$CurrentMethod,"_tExpression_")",pLevel)
		} elseif ( pAction.type = "debug" ) {
			set tSC = ..generateFHIRPathEval(pAction.value, .tExpression, 0, pLevel)
			return:'$$$ISOK(tSC) tSC
			#; set tSC=##class(Ens.Rule.Model.expression).convertToCOS(pAction.value,.tExpression,.variables) quit:$$$ISERR(tSC)
			set tDebug = $select(pAction.value = tExpression: tExpression, 1: $$$quote(pAction.value) _ "_"" = '""_" _ tExpression _ "_""'""")
			do ..line("if (pLogLevel [ $$$eRuleLogTypeUserDebug) set tSC = ##class(Ens.Rule.DebugLog).Log(pDebugId,$$$eRuleLogTypeUserDebug,"_$$$quote(pReason)_","_tDebug_",0) quit:$$$ISERR(tSC)",pLevel)
		} else {
			Set tSC = ##super(pClassname, .variables, pAction, pReason, pAssistClass, %code, pLevel)
		}
	} catch {
		set tSC=$$$SystemError
	}
	quit tSC
}

ClassMethod Trace(pMsg As %String)
{
	do ..line("$$$TRACE(""" _ pMsg _ """)")
}

ClassMethod generateFHIRPathEval(pExpression As %String, Output pValue As %String, pForceBoolean As %Boolean, pLevel)
{
	/// todo: Add a FHIRpath parser check here BEFORE evaluating
	/// todo: Handle error checking here too with precise error messages for use in the UI
	
	/// First we use the original FHIRPath evaluator to check if the expression is valid FHIRPath syntax-wise
	Try {
		Set fAPI = ##class(HS.FHIRPath.Parser).%New()
		Set node = fAPI.parse(pExpression)
	} Catch ex {
		Return ex.AsStatus()
	}


	/// Next we use the custom parser to ensure the FHIRPath is semantically correct too
	/// TODO: Use the custom parser and return an error status here if the FHIRPath syntax is not valid

	do ..line("set fAPI = ##class(HS.FHIRPath.API).getInstance($lb(tConstraints(""FHIRPackage"")))", pLevel)
	do ..line("set fExpr = """ _ $REPLACE(pExpression, """", "'") _ """")
	#; do ..line("$$$TRACE(""Evaluating expression""_fExpr)")
	do ..line("set fTree = fAPI.parse(fExpr)", pLevel)
	#; do ..line("$$$TRACE(""Trace: ""_pContext.FHIRJSON.%ToJSON())")
	do ..line("Do fAPI.evaluate(pContext.FHIRJSON, fTree, .fOutput)", pLevel)
	#; do ..line("$$$TRACE(""Value of fOutput:""_fOutput)")
	#; do ..line("$$$TRACE(""Value of fOutput(1):""_fOutput(1))")

	If (pForceBoolean) {
		/// We expect the output from the FHIRPath eval to be a boolean (e.g. for a condition)
		/// todo: Add a FHIRPath collection check if we expect a single value, as the FHIRPath expression should evaluate to a value
		/// however if a bool is expected, then as long as the expression has values, it will succeed
		do ..line("if (fOutput '= 1) || (fOutput(1, ""t"") '= ""boolean"") {", pLevel)
		do ..line("$$$ThrowStatus($$$ERROR($$$GeneralError, ""Expression must evaluate to a single boolean value ""))", pLevel + 1)
		do ..line("}", pLevel)
		do ..line("set tVal = fOutput(1)", pLevel)
	} Else {
		do ..line("set tVal = $CASE(fOutput, 1:fOutput(1),:fOutput)", pLevel)
	}
	set pValue = "tVal"

	Return $$$OK
}

ClassMethod generateWhens(pClassname As %String, variables As %String, pAction As Ens.Rule.Model.action, pReason As %String, pAssistClass As %String, %code As %Stream.MethodGenerator, pLevel As %Integer) As %Status
{
	Set tSC = $$$OK
	Try {
		for tIndex=1:1:pAction.whens.Count() {
			Set tWhen = pAction.whens.GetAt(tIndex)
			set tSC = ..generateFHIRPathEval(tWhen.condition, .tExpression, 1, pLevel)
			do ..line("set conditionIndexes(" _ tIndex _ ") = " _ tExpression)
		}
		If $case(pAction.type,"rule":1,"foreach":1,:0) {
			for tIndex=1:1:pAction.whens.Count() {
				set tWhen = pAction.whens.GetAt(tIndex)
				#; set tSC=##class(Ens.Rule.Model.expression).convertToCOS(tWhen.condition,.tExpression,.variables) quit:$$$ISERR(tSC)

				do ..line($s(tIndex=1:"if",1:"} elseif")_" (conditionIndexes("_tIndex_")) {",pLevel)
				set tReason = pReason_":when#"_tIndex
				do ..line("set pReason=pReason_"","_tReason_"""",pLevel+1)
				do ..setActionReasonLines(tReason, pLevel)
				do ..line("if (pLogLevel [ $$$eRuleLogTypeConditionDebug) set tSC = ##class(Ens.Rule.DebugLog).Log(pDebugId,$$$eRuleLogTypeConditionDebug,"_$$$quote(tReason)_","_$$$quote("When ("_tWhen.condition_") succeeded")_",0) quit:$$$ISERR(tSC)",pLevel+1)
				set tSC = ..generateActions(pClassname,.variables,tWhen.actions,tReason,pAssistClass,%code,pLevel+1) quit:$$$ISERR(tSC)
			}
			quit:$$$ISERR(tSC)
			if $isObject(pAction.otherwise) {
				do ..line("} else {",pLevel)
				set tReason = pReason_":otherwise"
				do ..line("set pReason=pReason_"","_tReason_"""",pLevel+1)
				do ..setActionReasonLines(tReason, pLevel)
				do ..line("if (pLogLevel [ $$$eRuleLogTypeConditionDebug) set tSC = ##class(Ens.Rule.DebugLog).Log(pDebugId,$$$eRuleLogTypeConditionDebug,"_$$$quote(tReason)_",""Otherwise called"",1) quit:$$$ISERR(tSC)",pLevel+1)
				set tSC = ..generateActions(pClassname,.variables,pAction.otherwise.actions,tReason,pAssistClass,%code,pLevel+1) quit:$$$ISERR(tSC)
			}
			elseif (pAction.whens.Count() > 0) {
				do ..line("} elseif (pLogLevel [ $$$eRuleLogTypeConditionDebug) {",pLevel)
				if (pAction.type="rule") {
					do ..line("set tSC = ##class(Ens.Rule.DebugLog).Log(pDebugId,$$$eRuleLogTypeConditionDebug,"_$$$quote(pReason)_","_$$$quote("For rule '"_$select(pAction.name = "": pReason, 1: pAction.name)_"', no whens matched and no otherwise defined")_",0) quit:$$$ISERR(tSC)",pLevel+1)
				} else {
					#; foreach
					do ..line("set tSC = ##class(Ens.Rule.DebugLog).Log(pDebugId,$$$eRuleLogTypeConditionDebug,"_$$$quote(pReason)_","_$$$quote("For foreach loop over'"_pAction.propertypath_"', no whens matched and no otherwise defined")_",0) quit:$$$ISERR(tSC)",pLevel+1)
				}
			}
			quit:$$$ISERR(tSC)
			if pAction.whens.Count()>0 do ..line("}",pLevel)
		} Else {
			#; Other actions don't have whens and otherwise
		}
	} catch {
		set tSC=$$$SystemError
	}
	quit tSC
}

ClassMethod generateLoop(pClassname As %String, variables As %String, pAction As Ens.Rule.Model.foreach, pReason As %String, pAssistClass As %String, %code As %Stream.MethodGenerator, pLevel As %Integer) As %Status
{
	Throw ##class(%Exception.General).%New("Loops not supported", $$$NotImplemented)
}

ClassMethod writeReturnForSend(pAction As Ens.Rule.Model.action, pLevel As %Integer) [ Internal ]
{
	#dim closingQuotesandOptionalFourthSendPiece = """"
	#; ought to be defined but safeguard to ensure compiles.
	if $Get(%usesRuleActionUserData,0) {
		Set closingQuotesandOptionalFourthSendPiece = """_$s($Data(tRuleActionReason):"":""_tRuleActionReason"_",1:"""")"
	}
	do ..line("set pReturnValue=pReturnValue_$s(pReturnValue'="""":"";"",1:"""")_""send:"_pAction.target_":"_pAction.transform_closingQuotesandOptionalFourthSendPiece,pLevel)
}

}
