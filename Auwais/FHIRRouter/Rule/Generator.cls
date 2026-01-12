Class Auwais.FHIRRouter.Rule.Generator Extends Ens.Rule.Generator
{

ClassMethod correlateByObj(pObjClass As %Dictionary.ClassDefinition, Output pRuleDefinition As Ens.Rule.Model.ruleDefinition) As %Status
{
	set tSC=$$$OK
	try {
		; find XData with name RuleDefinition
		set tObjXData="" for i=1:1:pObjClass.XDatas.Count() if pObjClass.XDatas.GetAt(i).Name="RuleDefinition" set tObjXData=pObjClass.XDatas.GetAt(i) quit
		; RuleDefinition not found
		if tObjXData="" set tSC=$$$ERROR($$$EnsErrXDataBlockNotDefined,pObjClass.Name,"RuleDefinition") quit
		; open the reader and correlate the XData to Ens.Rule.Model.ruleDefinition
		set tReader = ##class(%XML.Reader).%New()
		set tSC=tReader.OpenStream(tObjXData.Data) quit:$$$ISERR(tSC)
		do tReader.Correlate("ruleDefinition","Ens.Rule.Model.ruleDefinition")
		; find the first object
		do tReader.Next(.pRuleDefinition,.tSC) quit:$$$ISERR(tSC)
		if $isObject($get(pRuleDefinition)) set pRuleDefinition.Timestamp = $zdatetime(pObjClass.TimeChanged,3,,6)
	} catch {
		set tSC=$$$SystemError
	}
	quit tSC
}

/// todo; Update FHIR version to NOT be fixed...
ClassMethod generateOneAction(pClassname As %String, variables As %String, pAction As Ens.Rule.Model.action, pReason As %String, pAssistClass As %String, %code As %Stream.MethodGenerator, pLevel As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		if ( pAction.type = "assign" ) {
			/// Override the value of the expression to be an objectscript call to the FHIRPath evaluator
			do ..generateFHIRPathEval(pAction.value, .tValueExpression, 0, pLevel)
			#; set tSC=##class(Ens.Rule.Model.expression).convertToCOS(pAction.value,.tValueExpression,.variables) quit:$$$ISERR(tSC)
			set tSC = ##class(Ens.Rule.Model.expression).convertToCOS(pAction.property, .tVProp,.variables,1) quit:$$$ISERR(tSC)
			if tVProp["SetValueAt" {
				do ..line("do "_$p(tVProp,",",1)_tValueExpression_","_$p(tVProp,",",2),pLevel)
			}
			else {
				do ..line("set "_tVProp_"="_tValueExpression,pLevel)
			}
		} elseif ( pAction.type = "return" ) {
			do ..generateFHIRPathEval(pAction.value, .tExpression, 0, pLevel)
			#; set tSC=##class(Ens.Rule.Model.expression).convertToCOS(pAction.value,.tExpression,.variables) quit:$$$ISERR(tSC)
			do ..line("set tReturn = 1",pLevel)
			if tExpression'="" {
				do ..line("set pReturnValue="_tExpression_" quit",pLevel)
			} else {
				do ..line("quit",pLevel)
			}
		} elseif ( pAction.type = "trace" ) {
			do ..generateFHIRPathEval(pAction.value, .tExpression, 0, pLevel)
			#; set tSC=##class(Ens.Rule.Model.expression).convertToCOS(pAction.value,.tExpression,.variables) quit:$$$ISERR(tSC)
			do ..line("do ##class(Ens.Util.Trace).WriteTrace(""user"",$$$CurrentClass,$$$CurrentMethod,"_tExpression_")",pLevel)
		} elseif ( pAction.type = "debug" ) {
			do ..generateFHIRPathEval(pAction.value, .tExpression, 0, pLevel)
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

ClassMethod generateFHIRPathEval(pExpression As %String, Output pValue As %String, pForceBoolean As %Boolean, pLevel)
{
	/// todo: Add a FHIRpath parser check here BEFORE evaluating
	/// todo: Handle error checking here too with precise error messages for use in the UI
	do ..line("set fAPI = ##class(HS.FHIRPath.API).getInstance($lb(""hl7.fhir.r4.core@4.0.1""))", pLevel)
	do ..line("set fExpr = """ _ $REPLACE(pExpression, """", "'") _ """")
	#; do ..line("$$$TRACE(""Evaluating expression""_fExpr)")
	do ..line("set fTree = fAPI.parse(fExpr)", pLevel)
	#; do ..line("$$$TRACE(""Trace: ""_pContext.FHIRJSON.%ToJSON())")
	do ..line("Do fAPI.evaluate(pContext.FHIRJSON, fTree, .fOutput)", pLevel)
	#; do ..line("$$$TRACE(""Value of fOutput:""_fOutput)")

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
}

ClassMethod generateWhens(pClassname As %String, variables As %String, pAction As Ens.Rule.Model.action, pReason As %String, pAssistClass As %String, %code As %Stream.MethodGenerator, pLevel As %Integer) As %Status
{
	Set tSC = $$$OK
	Try {
		If $case(pAction.type,"rule":1,"foreach":1,:0) {
			for tIndex=1:1:pAction.whens.Count() {
				set tWhen = pAction.whens.GetAt(tIndex)
				do ..generateFHIRPathEval(tWhen.condition, .tExpression, 1, pLevel)
				#; set tSC=##class(Ens.Rule.Model.expression).convertToCOS(tWhen.condition,.tExpression,.variables) quit:$$$ISERR(tSC)

				do ..line($s(tIndex=1:"if",1:"} elseif")_" ("_tExpression_") {",pLevel)
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
	#dim tSC As %Status = $$$OK
	#dim ex As %Exception.AbstractException
	#dim tExpression, tDocName, tSegmentPath, tPiece, tSegIndex As %String = ""
	#dim tExpressionObj As Ens.Rule.Model.expression
	#dim tLevelCount As %Integer = 0
	
	Try {
		If (""=pAction.propertypath) {
			Set tSC = $$$ERROR($$$EnsErrGeneral,"propertypath required for foreach action")
			Quit
		}
		
		#; Just to make sure there's no code being injected
		/// Todo: Check we are looping over the expression properly
		Throw $$$NotImplemented
		Set tSC = ##class(Ens.Rule.Model.expression).parseExpression(pAction.propertypath,.tExpressionObj)	Quit:$$$ISERR(tSC)
		
		If tExpressionObj.type="value" {
			Set tExpression=tExpressionObj.value
			If $e(tExpression)?1(1AZFWCHARZ,1"%") {
				Set tDocName="pContext."_$P(tExpression,".")
				Set tExpression = $P(tExpression,".",2,*)
				If (($E(tExpression)="{") && ($E(tExpression,*)="}")) {
					Set tExpression = $E(tExpression,2,*-1)
					do ..line("set tReturn = 0",pLevel)
					For i=1:1:$l(tExpression,".") {
						Set tPiece = $P(tExpression,".",i)
						If (tPiece'["(") {
							#; Not repeating
							Set tSegmentPath = $Select(tSegmentPath'="":tSegmentPath_".",1:"")_tPiece
						} ElseIf ($Piece(tPiece,"(",2,*)=")") {
							#; Empty parens -> repeating loop or segment
							#; Set index variable to be used at this level in the loop
							Set tSegIndex = "tSegIndex"_$S($I(tLevelCount)>1:tLevelCount,1:"")
							#; Start the for loop					
							do ..line("set "_tSegIndex_" = """"",pLevel)
							do ..line("for {",pLevel)
							do ..line("set "_tSegIndex_" = "_tDocName_".GetNextIndex("""_$Select(tSegmentPath'="":tSegmentPath_".",1:"")_tPiece_""","_tSegIndex_",.tSC)",$I(pLevel))
							do ..line("quit:($$$ISERR(tSC)||(""""="_tSegIndex_"))",pLevel)
							#; Add on to the property path so it includes this level in the loop
							Set tSegmentPath = $Select(tSegmentPath'="":tSegmentPath_".",1:"")_$P(tPiece,"(")_"(""_"_tSegIndex_"_"")"
						} Else {
							#; Deal with any values enclosed in parentheses and make sure we have matching open and close parentheses
							Set parenLevel=0, k=$F(tPiece,"(")-1
							For {
								Quit:$e(tPiece,k)=""
								If $e(tPiece,k)="(" {
									Set parenLevel = parenLevel+1
									Set:parenLevel=1 parenStart = k
								}
								If $e(tPiece,k)=")" {
									Set parenLevel = parenLevel -1
									If parenLevel = 0 {
										Set tIndex = $e(tPiece,parenStart+1, k-1)
										If (($f(tIndex,"""_")'=0) && ($f(tIndex,"_""",$f(tIndex,"""_"))'=0)) {
											Set tSC=$$$ERROR($$$EnsErrGeneral,"Invalid index value "_tIndex_" in "_tExpressionObj.value_". Index value should not contain ""_ and _""")
											Quit
										} ElseIf ((tIndex'="") && (tIndex '="*") && (tIndex '= "-")) {
											Set tSC = ##class(Ens.Rule.Model.expression).convertToCOS(tIndex, .result, .variables)	Quit:$$$ISERR(tSC)
											Set $e(tPiece,parenStart, k) = "(""_"_result_"_"")"
											set k = k+4+$l(result)
										}
									}
								}
								Set k = k+1
							}
							Quit:$$$ISERR(tSC)
							If parenLevel'=0 {
								Set tSC=$$$ERROR($$$EnsErrMissingCloseParen,$l(tExpressionObj.value)-1)
								Quit
							}
							#; Add on to the property path
							Set tSegmentPath = $Select(tSegmentPath'="":tSegmentPath_".",1:"")_tPiece
						}
					}
				} Else {
					#; No { to indicate start of VDoc path
					Set tSC = $$$ERROR($$$EnsErrGeneral,"Invalid value for propertypath")
					Quit
				}
			} Else {
				#; No VDoc variable
				Set tSC = $$$ERROR($$$EnsErrGeneral,"Invalid value for propertypath")
				Quit
			}
		} Else {
			#; Should only be the path - no operators or functions
			Set tSC = $$$ERROR($$$EnsErrGeneral,"Invalid value for propertypath")
			Quit
		}
		
		If (tLevelCount = 0) {
			#; No "()" to iterate over
			Set tSC = $$$ERROR($$$EnsErrGeneral,"Cannot iterate on given propertypath")
			Quit
		}
		
		#; Inner-most loop - access the segment and perform actions on it
		do ..line("set pContext.Segment = "_tDocName_".GetSegmentAt("""_tSegmentPath_""",.tSC1)",pLevel)
		do ..line("if $$$ISERR(tSC1) {",pLevel)
		do ..line("if (($$$StatusText(tSC1)'[""No segment found"")&&($$$StatusText(tSC1)'[""is not an element, instead this node"")) { set tSC=$$$ADDSC(tSC,tSC1)	quit }",pLevel+1)
		do ..line("else { continue }",pLevel+1)
		do ..line("}",pLevel)
		#; reason
		set tReason = pReason_":foreach"
		do ..line("set pReason=pReason_"","_tReason_"""",pLevel)
		do ..setActionReasonLines(tReason, pLevel)
		do ..line("if (pLogLevel [ $$$eRuleLogTypeConditionDebug) set tSC = ##class(Ens.Rule.DebugLog).Log(pDebugId,$$$eRuleLogTypeConditionDebug,"_$$$quote(tReason)_",""Segment ("_tSegmentPath_") loop"",0) quit:$$$ISERR(tSC)",pLevel)
		#; Code inside the loop
		Set tSC = ..generateWhens(pClassname,.variables,pAction,tReason,pAssistClass,%code,pLevel)
		#; Close the loop
		For i=1:1:(tLevelCount-1) {
			Set pLevel = pLevel - 1
			do ..line("}",pLevel)
			#; Make sure to quit out of the entire rule if there was a Return action
			do ..line("quit:tReturn",pLevel)
		}
		Set pLevel = pLevel - 1
		do ..line("}",pLevel)
		#; Clear out the Segment object
		do ..line("set pContext.Segment = $$$NULLOREF",pLevel)
		#; Make sure to quit out of the entire rule if there was a Return action
		do ..line("quit:tReturn",pLevel)
	
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	
	Quit tSC
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
