/// 
/// This class is an autocomplete function for FHIRPath.
/// 
/// Auwais Hussain (ahussain@intersystems.com)
/// 
Class FHIR.FHIRPath.Autocomplete Extends %RegisteredObject
{

/// TODO: Structure:
/// FHIR.Autocomplete.Engine - main entry point for autocomplete, contains the Suggest method
/// FHIR.Autocomplete.Expr - Package containing all expression for AST
/// FHIR.Autocomplete.TypeAssist.Builder - Loads FHIR metadata and provides methods to access it
/// FHIR.Autocomplete.Utils - Package/class that helps with utility functions
/// FHIR.Autocomplete.TypeAssist.InferenceEngine - Inference Engine for working out type
/// 
/// Allow registration of FHIRPath functions
/// - We need to store their:
/// 	- OutputCardinality
/// 	- Name
/// 	- ScopedVariables (list)
/// 	- OutputType (or a method that modifies the scope based on the input scope)
/// The name of a resource or "" (empty string)
/// 
/// Signatures:
/// 	empty() : Boolean
/// 	exists([criteria : ($this, $index) => Boolean]) : Boolean
/// 	aggregate(aggregator : ($total, $this, $index) => collection [, init : collection]) : collection
Property ResourceFilter As %String;

/// The FHIR Loader to load all metadata once
Property Loader As HS.FHIRMeta.Load.NpmLoader;

Property ContextHelper As FHIR.TypeAssist.FHIRContextHelper;

Method %OnNew(pPackageId = "hl7.fhir.r4.core@4.0.1", pValidResource = "") As %Status
{
	Set ..Loader = ##class(HS.FHIRMeta.Load.NpmLoader).Load($lb(pPackageId))
	Set ..ContextHelper = ##class(FHIR.TypeAssist.FHIRContextHelper).%New(..Loader)
	Set ..ResourceFilter = pValidResource
	Quit $$$OK
}

/// Helper method to convert an operator to it's corresponding function (if applicable)
Method OpAsFn(pOp As %String)
{
	Return $CASE(pOp, "|":"union", :"")
}

ClassMethod MarkCursor(pNode As FHIR.FHIRPath.Expr.Expression) As %Boolean
{
	Set cls = $CLASSNAME(pNode)
	If cls = "FHIR.FHIRPath.Expr.BinaryExpr" {
		Set rightNode = ..MarkCursor(pNode.Right)
		If rightNode {
			Set pNode.ContainsCursor = 1
			Return 1
		}

		Set leftNode = ..MarkCursor(pNode.Left)
		If leftNode {
			Set pNode.ContainsCursor = 1
			Return 1
		}
	} ElseIf (cls = "FHIR.FHIRPath.Expr.IdentExpr") || (cls = "FHIR.FHIRPath.Expr.PartialExpr") {
		Set pNode.ContainsCursor = 1
		Return 1
	} ElseIf cls = "FHIR.FHIRPath.Expr.CallExpr" {
		Return:pNode.Partial 1
		Return:pNode.Args.Size=0 0
		Set pNode.ContainsCursor = ..MarkCursor(pNode.Args.GetAt(pNode.Args.Size))
		Return pNode.ContainsCursor
	} ElseIf cls = "FHIR.FHIRPath.Expr.IndexExpr" {
		Set pNode.ContainsCursor = ..MarkCursor(pNode.Field)
		Return pNode.ContainsCursor
	} ElseIf (cls = "FHIR.FHIRPath.Expr.NumberExpr") || (cls = "FHIR.FHIRPath.Expr.DecimalExpr") || (cls = "FHIR.FHIRPath.Expr.StringExpr") || (cls = "FHIR.FHIRPath.Expr.QuantityExpr") {
		Set pNode.ContainsCursor = 1
		Return 1
	} ElseIf cls = "FHIR.FHIRPath.Expr.UnaryExpr" { 
		Set pNode.ContainsCursor = ..MarkCursor(pNode.Expr)
		Return pNode.ContainsCursor
	} Else {
		Throw ##class(%Exception.General).%New("Unable to handle class " _ cls, "-33113")
	}

	Return 0
}

/// This method infers the scope from within a function. Should only be called if the function is not
/// yet complete
Method InferFunctionScope(pFnName As %String, pScope As FHIR.FHIRPath.Context.Scope) As FHIR.FHIRPath.Context.Scope
{
	Set pScope.Function = pFnName
	Set pScopedFunctions = $LISTFROMSTRING("exists,all,where,select,iif,aggregate")
	If $LF(pScopedFunctions, pFnName) {
		Set pScope.CompletionType = "PROPERTY"
		Set pScope.ScopedVariables = pScope.ScopedVariables _ $lb("$this", "$index")
	}

	If (pFnName = "aggregate") {
		Set pScope.CompletionType = "PROPERTY"
		Set pScope.ScopedVariables = pScope.ScopedVariables _ $lb("$total", "$this", "$index")
	} ElseIf (pFnName = "as") {
		/// Reset scope
		Set pScope.CompletionType = "TYPE"
		Set pScope.CompletionScope = "DIRECT"
	} ElseIf (pFnName = "is") || (pFnName = "ofType") {
		Set pScope.CompletionType = "TYPE"
		Set pScope.CompletionScope = "ALL"
	} ElseIf (pFnName = "union") || (pFnName = "|") {
		w "Within union...",!,!,!,!,!,!
		Set newScope = ##class(FHIR.FHIRPath.Context.Scope).%New()
		Set newScope.CompletionType = "RESOURCE,PROPERTY"
		Set newScope.CompletionScope = "DIRECT"
		Set newScope.GlobalRefs = pScope.RootRef
		Set newScope.Function = pFnName

		Set pScope = newScope
	} ElseIf (pFnName = "extension") {
		/// Simulate the expression of a BEXP and CallExpr
		Set nextScope = ..CreateScope("extension", pScope, .success)
		Return:'success pScope

		Set nextScope = ..CreateScope("url", nextScope, .success)
		Return:'success pScope

		Set nextScope.CompletionType = "VALUE"
		Set nextScope.CompletionScope = "DIRECT"

		Set pScope = nextScope
	}
	Return pScope
}

Method CreateScope(pIdent As %String, pInitialScope As FHIR.FHIRPath.Context.Scope, ByRef success As %Boolean) As FHIR.FHIRPath.Context.Scope
{
	/// TODO: Messy way of dealing with context and helpers...
	/// the goal was to ensure an empty context at the beginning, and allowing the engine
	/// to determine the context based off the first InferType

	Return ..ContextHelper.CreateScope(pIdent, pInitialScope, .success)
	#; If (..ContextHelper '= "") && (pInitialScope.GlobalRef '= "") {
	#; 	Return ..ContextHelper.CreateScope(pIdent, pInitialScope, .success)
	#; }

	#; Try {
	#; 	Set ctxHelper = ##class(FHIR.FHIRPath.FHIRContextHelper).BuildResourceContext(..Loader, pIdent)
	#; 	Set ..ContextHelper = ctxHelper
	#; 	Set pInitialScope.DataType = "RESOURCE"
	#; 	Set pInitialScope.FHIRType = $lb(pIdent)
	#; 	Set pInitialScope.GlobalRef = ..ContextHelper.GlobalRef
	#; 	Set pInitialScope.RootRef = ..ContextHelper.GlobalRef

	#; 	Set nScope = ctxHelper.CreateScope(pIdent, pInitialScope, .success)
	#; } Catch ex {
	#; 	/// Were not successful in loading a new resource, which means the resource does not exist
	#; 	/// or it may be a prefix, add the scope to search resources
	#; 	#; Do $System.OBJ.DisplayError(ex.AsStatus())
	#; 	Set success = 0
	#; }

	#; /// If we were not successful in creating a scope, send back the original scope
	#; Set:'success nScope = pInitialScope
	#; Return nScope
}

/// Note: We assume left side will never contain cursor
Method InferType(pNode As FHIR.FHIRPath.Expr.Expression, pScope As FHIR.FHIRPath.Context.Scope) As FHIR.FHIRPath.Context.Scope
{
	/// Infer the type of the current node based on the context and the type of expression
	Set cls = $CLASSNAME(pNode)
	Set package = $PIECE(cls, ".", 1, *-1)
	Set name = $PIECE(cls, ".", *)

	If package '= "FHIR.FHIRPath.Expr" {
		Throw ##class(%Exception.General).%New("Unable to handle package " _ package)
	}

	Set pScope = pScope.Duplicate()

	If name = "BinaryExpr" {
		/// We traverse down the left to get the type of the left side
		/// We pass the scope down to the left side, which will update the scope based on the type of the left side expression
		/// TODO: pScope becomes mutated ... should NEVER be the case...
		Set leftScope = ..InferType(pNode.Left, pScope)

		/// Operators that double as functions
		Set fnOps = $lb("is", "as", "|")
		Set compOps = $lb(">",">=","<","<=","=","!=")
		Set boolOps = $lb("and", "or", "implies", "xor")

		If pNode.Op = "." {
			Set leftScope.CompletionType = "PROPERTY,FUNCTION"
			Set leftScope.CompletionScope = "DIRECT"

			Set rightInputScope = ..InferType(pNode.Right, leftScope)
			
			/// Right scope is empty and does not contain any identifier/prefix, so we suggest based on the left scope
			If (rightInputScope.DataType = "UNKNOWN") {
				/// Reset the token prefix set on the left side, as RHS is empty
				Set leftScope.PrefixToken = ""
				Return leftScope
			} ElseIf (rightInputScope.DataType = "STRING") {
				/// There is a string on the LH
				/// The completion type is a function
				Set rightInputScope.CompletionType = "FUNCTION"
				Set rightInputScope.CompletionScope = "DIRECT"
			}

			Return rightInputScope
		} ElseIf ((pNode.Op = "=") || (pNode.Op = "!=")) {
			Set rightScope = ..InferType(pNode.Right, leftScope)

			Set newContext = ""
			If rightScope.DataType = "UNKNOWN" {
				/// The RHS does not have any data within it, the cursor is here
				Set leftScope.CompletionType = "VALUE"
				Set leftScope.CompletionScope = "ALL"
				Set leftScope.PrefixToken = ""

				Return leftScope
			} ElseIf (rightScope.DataType = "STRING") && (pNode.Op = "=") {
				/// RHS is a string, update the context
				Set newContext = $lb(leftScope.LastField _ ":" _ rightScope.LastField)
			}

			/// If the RHS does have data in it, we assume this BEXP is complete
			Set pScope.CompletionType = "OPERATOR"
			Set pScope.CompletionScope = "ALL"
			Set pScope.PrefixToken = ""

			#; Set leftScope.LastField = rightScope.LastField
			Set pScope.Context = pScope.Context _ newContext

			Return pScope
		} ElseIf $LF(fnOps, pNode.Op) {
			Set fnInScope = leftScope

			/// In the case of Union, we disregard the left scope and use the incoming scope
			Set:pNode.Op="|" fnInScope = pScope

			Set fnScope = ..InferFunctionScope(pNode.Op, fnInScope)

			Set fnScope.PrefixToken = ""

			Set rightScope = ..InferType(pNode.Right, fnScope)

			Return:rightScope'="UNKNOWN" rightScope
			Return pScope
		} Else {
			#; 109
			#; 118
			#; 98
			#; 85
			#; 69
			#; 70
			#; 71

			/// By default, we pass the LHS scope to the RHS tree of the BEXP
			Set inScope = leftScope

			/// For boolean operators, we pass the original scope down
			Set:$LF(boolOps, pNode.Op) inScope = pScope

			Set rightScope = ..InferType(pNode.Right, inScope)

			If (rightScope.DataType = "UNKNOWN") {
				Set leftScope.CompletionType = "PROPERTY"
				Set leftScope.CompletionScope = "DIRECT"
				Set leftScope.PrefixToken = ""

				Return leftScope
			
			} ElseIf (rightScope.CompletionType = "NONE") {
				Set scope = pScope
				Set scope.CompletionType = "OPERATOR"
				Set scope.Context = rightScope.Context _ leftScope.Context
				Set scope.PrefixToken = ""
			} Else {
				Set scope = rightScope
				Set scope.Context = rightScope.Context _ leftScope.Context
			}

			Return scope
		}
	} ElseIf name = "CallExpr" {

		/// TODO: This logic should not be in multiple branches, we should either use a dedicated class
		/// for handling various functions or use the InferFunctionScope method with a pPartial parameter
		/// to indicate whether the function is partial or not
		If pNode.Partial {
			/// If this is a partial call, the user has not typed the ) yet so
			/// we traverse down the last argument to get the type of the function call expression

			/// TODO: Resetting the prefix token here is a bit of a hack -- ideally we should set the prefix
			/// token in the correct places in the InferType method rather than resetting it here

			Set fnScope = ..InferFunctionScope(pNode.Callee.Name, pScope)
			Set fnScope.PrefixToken = ""

			Set lastArgScope = ..InferType(pNode.Args.GetAt(pNode.Args.Size), fnScope)

			Return:lastArgScope.DataType'="UNKNOWN" lastArgScope
			Return fnScope
		} Else {
			/// If the call is not partial, we can infer the type based on the function definition
			Set unchangedScopeFns = $lb("skip","tail")
			If $LF(unchangedScopeFns, pNode.Callee.Name) {
				/// These functions do not change the scope in any way
				Set pScope.CompletionType = "NONE"
				Return pScope
			} ElseIf (pNode.Callee.Name = "exists") || (pNode.Callee.Name = "not") {
				Set pScope.DataType = "FHIRTYPE"
				Set pScope.FHIRType = "boolean"
				Set pScope.CompletionType = "ANY"
				Set pScope.Cardinality = 1
				Return pScope
			} ElseIf (pNode.Callee.Name = "first") || (pNode.Callee.Name = "last") || (pNode.Callee.Name = "single") {
				Set pScope.Cardinality = 1
				Set pScope.CompletionType = "NONE"
				Return pScope
			} ElseIf (pNode.Callee.Name = "ofType") {
				/// Create a new scope to be modified
				Set freshScope = ##class(FHIR.FHIRPath.Context.Scope).%New()
				Set scope = ..InferType(pNode.Args.GetAt(1), freshScope)

				Set scope.CompletionType = "ANY"
				Set scope.CompletionScope = "DIRECT"
				Return scope
			} ElseIf (pNode.Callee.Name = "union") {
				Set freshScope = ##class(FHIR.FHIRPath.Context.Scope).%New()
				Set scopeOfArg = ..InferType(pNode.Args.GetAt(1), freshScope)

				/// Now merge the scopes
				Set scope = pScope.MergeScope(scopeOfArg)
				Return scope
			} ElseIf (pNode.Callee.Name = "as") {
				/// Try to cast/infer type
				Set tScope = ..InferType(pNode.Args.GetAt(1), pScope)

				/// For choice fields, attempt to create a scope
				Set type = tScope.PrefixToken
				
				/// TODO: Odd way of doing this, should perform this at the stage of setting the FHIRType,
				/// not here
				If ($LF($LISTFROMSTRING($LISTTOSTRING(tScope.FHIRType)), type)) {
					/// This is a valid type for this field, cast as this type
					/// and move the context to a subfield if this was a
					/// choice field
					Set tScope.GlobalRef = ..ContextHelper.AscendSubscript(tScope.GlobalRef)
					Set nScope = ..CreateScope(tScope.LastField _ type, tScope, .success)

					Set:success tScope = nScope
				}

				/// Consume the token regardless of if this type was valid
				Set tScope.PrefixToken = ""

				Set tScope.CompletionScope = "DIRECT"
				Set tScope.CompletionType = "PROPERTY,OPERATOR"

				Return tScope

			} ElseIf (pNode.Callee.Name = "where") {

				/// Create a context for resolving the extension
				Set nScope = ..InferType(pNode.Args.GetAt(1), pScope)

				Return nScope
			} Else {
				/// TODO: This else statement should be removed, only here for development purposes until
				/// tests pass
				W !,"[NOT IMPLEMENTED]: Unable to handle function " _ pNode.Callee.Name,!
				Return pScope
			}
		}
	} ElseIf (name = "IdentExpr") {
		w !,"Ident: " _ pNode.Name,!,!
		zw pScope
		Set pScope.PrefixToken = pNode.Name
		Set scope = ..CreateScope(pNode.Name, pScope, .success)

		If (success) {
			/// If this IdentityExpr successfully advanced the scope, we consume the "PrefixToken" and send back
			// the updated scope
			Set scope.PrefixToken = ""
			Set scope.CompletionType = "ANY"
			Set scope.DataType = "FHIRTYPE"

			Set scope.LastField = pNode.Name

			Return scope
		}

		/// Otherwise update the PrefixToken as this is not a valid token
		Set scope.PrefixToken = pNode.Name
		
		If (pNode.Name = "true") || (pNode.Name = "false") {
			/// True/false are special identifiers, consume
			/// the identifier
			Set scope.DataType = "BOOLEAN"
			Set scope.CompletionType = "NONE"
			Set scope.PrefixToken = ""
		}

		Return scope
	} ElseIf name = "PartialExpr" {
		Set scope = ##class(FHIR.FHIRPath.Context.Scope).%New()
		Set scope.DataType = "UNKNOWN"
		Return scope
	} ElseIf name = "IndexExpr" {
		Set scope = ..InferType(pNode.Field, pScope)
		Set scope.Cardinality = 1
		Return scope
		#; Do ..InorderTraversal(pExpr.Field, .pCtx, .finalTokenPrefix, .suggestValues, .refWithinFunctionCall, withinFunctionCall)
	}ElseIf (name = "NumberExpr") || (name = "DecimalExpr") || (name = "QuantityExpr") {
		Set pScope.CompletionType = "NONE"
	}ElseIf (name = "StringExpr") {
		/// This type is a literal
		Set scope = pScope.Duplicate()

		/// Consume the prefixToken
		/// TODO#3ERL: We need a uniform way of describing the data encapsulated in the scope,
		/// the below should be modified to have DataType = "FHIRTYPE" and FHIRType = $lb("string"),
		/// see linked TODO code
		Set scope.PrefixToken = ""
		Set scope.DataType = "STRING"
		Set scope.FHIRType = ""
		Set scope.CompletionType = "OPERATOR"
		Set scope.CompletionScope = "DIRECT"
		Set scope.LastField = pNode.Value

		Return scope
	}ElseIf name = "UnaryExpr" { 
		#; Do ..InorderTraversal(pExpr.Expr, .pCtx, .finalTokenPrefix, .suggestValues, .refWithinFunctionCall, withinFunctionCall)
	}Else {
		Throw ##class(%Exception.General).%New("Unable to handle class " _cls, "-33114")
	}

	Return pScope
}

Method Suggest(pExpression As %String) As %ListOfDataTypes
{
	Set outputList = ##class(%ListOfDataTypes).%New()
	Set scope = ##class(FHIR.FHIRPath.Context.Scope).%New()

	If (..ResourceFilter '= "") {
		Set scope = ..ContextHelper.CreateScope(..ResourceFilter, scope)
	}

	Set scope.RootRef = scope.GlobalRefs
	
	Set parser = ##class(FHIR.FHIRPath.Parser).ParseString(pExpression)
	Set ast = parser.Root

	/// Mark the cursor, not required but for future functionality..?
	Do ..MarkCursor(ast)
	Set endScope = ..InferType(ast, scope)

	#; w !,!,!,"Final scope:",!
	/// TODO: Remove this line..
	zw:^AFPDEBUG endScope
	#; Set scope = endScope

	Set assist = ##class(FHIR.TypeAssist.Engine).%New(..Loader)
	Set suggestions = assist.Suggest(endScope)
	Set prefix = endScope.PrefixToken
	Set endToken = parser.Peek()

	If (endToken.Type '= "EOF") {
		Set prefix = endToken.Lexeme
	}

	For i=1:1:suggestions.Size {
		Set suggestion = suggestions.GetAt(i)

		If ($EXTRACT(suggestion, 1, $L(prefix)) = prefix) || (prefix = "") {
			Do outputList.Insert(suggestion)
		}
	}

	Return outputList
}

ClassMethod Test(pExpr)
{
	Set a = ##class(FHIR.FHIRPath.Autocomplete).%New()
	Set l = a.Suggest(pExpr, .scope)
	For i=1:1:l.Size {
		Write l.GetAt(i),!
	}

	Set engine = ##class(FHIR.TypeAssist.Engine).%New(a.Loader)
	#; zw engine.Suggest(scope)

	Return scope
}

}
