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

Property ContextHelper As FHIR.FHIRPath.FHIRContextHelper;

Method %OnNew(pPackageId = "hl7.fhir.r4.core@4.0.1", pValidResource = "") As %Status
{
	Set ..Loader = ##class(HS.FHIRMeta.Load.NpmLoader).Load($lb(pPackageId))
	Set ..ResourceFilter = pValidResource
	Quit $$$OK
}

/// Helper method to convert an operator to it's corresponding function (if applicable)
Method OpAsFn(pOp As %String)
{
	Return $CASE(pOp, "|":"union", :"")
}

Method InorderTraversal(pExpr As FHIR.FHIRPath.Expr.Expression, ByRef pCtx As FHIR.FHIRPath.FHIRContextHelper, ByRef finalTokenPrefix, ByRef suggestValues, ByRef refWithinFunctionCall = 0, withinFunctionCall = 0)
{
	/// Reach a leaf node
	If (pExpr = "") {
		Quit
	}

	Set cls = $CLASSNAME(pExpr)
	If cls = "FHIR.FHIRPath.Expr.BinaryExpr" {
		Set savedContext = pCtx.Context
		/// Traverse down the left tree
		Do ..InorderTraversal(pExpr.Left, .pCtx, .finalTokenPrefix, .suggestValues, .refWithinFunctionCall, withinFunctionCall)
		
		Set opFn = ..OpAsFn(pExpr.Op)
		Do:opFn'="" pCtx.AdvanceContext(opFn, 1)
		If pExpr.Op = "|" {
			/// If this is the union operator, we want to merge the context resulting from the RHS
			/// Instantiate a new Context obj

			/// TODO: Review code, unnecessary - can remove whole IF block?
			Set leftCtx = ##class(FHIR.FHIRPath.FHIRContextHelper).%New(savedContext)
			Do ..InorderTraversal(pExpr.Right, leftCtx, .finalTokenPrefix, .suggestValues, .refWithinFunctionCall, withinFunctionCall)

			Do pCtx.MergeContext(leftCtx.Context)
		}

		/// Suggest values only if the operator is equal to "="
		Set suggestValues = (pExpr.Op = "=")
		
		/// If we successfully advance the operator, it means the operator doubles as both
		/// a function and operator, so we move within
		Set opSuccess = pCtx.AdvanceOperator(pExpr.Op)
		Set:pCtx.AdvanceOperator(pExpr.Op) withinFunctionCall = 1
		Do ..InorderTraversal(pExpr.Right, .pCtx, .finalTokenPrefix, .suggestValues, .refWithinFunctionCall, withinFunctionCall)
	} ElseIf cls = "FHIR.FHIRPath.Expr.IdentExpr" {
		Set finalTokenPrefix = pExpr.Name
		Set refWithinFunctionCall = withinFunctionCall
		Do pCtx.AdvanceContext(finalTokenPrefix, 0)
	} ElseIf cls = "FHIR.FHIRPath.Expr.PartialExpr" {
		Set refWithinFunctionCall = withinFunctionCall
		Set finalTokenPrefix = ""
		#; Do pCtx.AdvanceContext(pExpr.Value)
	} ElseIf cls = "FHIR.FHIRPath.Expr.CallExpr" {
		/// Duplicate the current context for use within the function
		Set scopedCtx = pCtx.Duplicate()
		Do scopedCtx.AdvanceContext(pExpr.Callee.Name, 1)

		/// We only need to traverse through the last argument to update the context

		Do ..InorderTraversal(pExpr.Args.GetAt(pExpr.Args.Size), .scopedCtx, .finalTokenPrefix, .suggestValues, .refWithinFunctionCall, 1)
		Set:'pExpr.Partial suggestValues = 0

		/// TODO: Check if the following plays nicely with all types of supported functions....
		/// If the function call is partial (i.e. the function does not have a closing ')'),
		/// we want to change the context to the new scoped context
		Set:pExpr.Partial pCtx = scopedCtx
	} ElseIf cls = "FHIR.FHIRPath.Expr.IndexExpr" {
		Do ..InorderTraversal(pExpr.Field, .pCtx, .finalTokenPrefix, .suggestValues, .refWithinFunctionCall, withinFunctionCall)
	} ElseIf (cls = "FHIR.FHIRPath.Expr.NumberExpr") || (cls = "FHIR.FHIRPath.Expr.DecimalExpr") {
	} ElseIf (cls = "FHIR.FHIRPath.Expr.StringExpr") {
		#; Do pCtx.AdvanceString()
	} ElseIf cls = "FHIR.FHIRPath.Expr.UnaryExpr" { 
		Do ..InorderTraversal(pExpr.Expr, .pCtx, .finalTokenPrefix, .suggestValues, .refWithinFunctionCall, withinFunctionCall)
	} Else {
		Throw ##class(%Exception.General).%New("Unable to handle class " _cls)
	}

	Quit
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
		Set pNode.ContainsCursor = ..MarkCursor(pNode.Args.GetAt(pNode.Args.Size))
		Return pNode.ContainsCursor
	} ElseIf cls = "FHIR.FHIRPath.Expr.IndexExpr" {
		Set pNode.ContainsCursor = ..MarkCursor(pNode.Field)
		Return pNode.ContainsCursor
	} ElseIf (cls = "FHIR.FHIRPath.Expr.NumberExpr") || (cls = "FHIR.FHIRPath.Expr.DecimalExpr") || (cls = "FHIR.FHIRPath.Expr.StringExpr") {
		Set pNode.ContainsCursor = 1
		Return 1
	} ElseIf cls = "FHIR.FHIRPath.Expr.UnaryExpr" { 
		Set pNode.ContainsCursor = ..MarkCursor(pNode.Expr)
		Return pNode.ContainsCursor
	} Else {
		Throw ##class(%Exception.General).%New("Unable to handle class " _cls)
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
		Set pScope.CompletionType = "IDENTIFIER"
		Set pScope.ScopedVariables = pScope.ScopedVariables _ $lb("$this", "$index")
	}

	If (pFnName = "aggregate") {
		Set pScope.CompletionType = "IDENTIFIER"
		Set pScope.ScopedVariables = pScope.ScopedVariables _ $lb("$total", "$this", "$index")
	} ElseIf (pFnName = "as") {
		/// Reset scope
		Set pScope.CompletionType = "TYPE"
		Set pScope.CompletionScope = "DIRECT"
	} ElseIf (pFnName = "is") || (pFnName = "ofType") {
		Set pScope.CompletionType = "TYPE"
		Set pScope.CompletionScope = "ALL"
	} ElseIf (pFnName = "union") {
		Set pScope.CompletionType = "RESOURCE,IDENTIFIER"
		Set pScope.CompletionScope = "DIRECT"
		Set pScope.GlobalRef = pScope.RootRef
		Set pScope.Cardinality = 1
	}
	Return pScope
}

Method CreateScope(pIdent As %String, pInitialScope As FHIR.FHIRPath.Context.Scope, ByRef success As %Boolean) As FHIR.FHIRPath.Context.Scope
{
	/// TODO: Messy way of dealing with context and helpers...
	/// the goal was to ensure an empty context at the beginning, and allowing the engine
	/// to determine the context based off the first InferType

	If (..ContextHelper '= "") && (pInitialScope.GlobalRef '= "") {
		Return ..ContextHelper.CreateScope(pIdent, pInitialScope, .success)
	}

	Try {
		Set ctxHelper = ##class(FHIR.FHIRPath.FHIRContextHelper).BuildResourceContext(..Loader, pIdent)
		Set ..ContextHelper = ctxHelper
		Set nScope = ctxHelper.CreateScope(pIdent, pInitialScope, .success)
	} Catch ex {
		/// Were not successful in loading a new resource, which means the resource does not exist
		/// or it may be a prefix, add the scope to search resources
		Set success = 0
	}

	/// If we were not successful in creating a scope, send back the original scope
	Set:'success nScope = pInitialScope
	Return nScope
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

	If name = "BinaryExpr" {
		/// We traverse down the left to get the type of the left side
		/// We pass the scope down to the left side, which will update the scope based on the type of the left side expression
		Set leftScope = ..InferType(pNode.Left, pScope)

		/// Operators that double as functions
		Set fnOps = $lb("is", "as")

		If pNode.Op = "." {
			Set rightScope = ..InferType(pNode.Right, leftScope)
			
			/// Right scope is empty and does not contain any identifier/prefix, so we suggest based on the left scope
			If (rightScope.DataType = "UNKNOWN") {
				Set leftScope.CompletionType = "ANY"
				/// Reset the token prefix set on the left side, as RHS is empty
				Set leftScope.PrefixToken = ""
				Return leftScope
			}
			Return rightScope
		} ElseIf ((pNode.Op = "=") || (pNode.Op = "!=")) {

			Set rightScope = ..InferType(pNode.Right, leftScope)
			If rightScope.DataType = "UNKNOWN" {
				/// The RHS does not have any data within it
				Set leftScope.CompletionType = "VALUE"
				Return leftScope
			}

			/// If the RHS does have data in it, we assume this BEXP is complete
			Set newScope = ##class(FHIR.FHIRPath.Context.Scope).%New()
			Set newScope.CompletionType = "OPERATOR"
			Set newScope.DataType = "BOOLEAN"

			Return newScope
		} ElseIf $LF(fnOps, pNode.Op) {
			Set fnScope = ..InferFunctionScope(pNode.Op, leftScope)
			Set fnScope.PrefixToken = ""

			Set rightScope = ..InferType(pNode.Right, fnScope)

			Return:rightScope'="UNKNOWN" rightScope
			Return pScope
		} Else {
			/// By default, we pass the initial scope to the RHS tree of the BEXP
			Set rightScope = ..InferType(pNode.Right, pScope)

			Return rightScope
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

			#; zw "Passing scope to " _ pNode.Callee.Name _ " with partial call"
			#; zw pScope
			Set fnScope = ..InferFunctionScope(pNode.Callee.Name, pScope)
			Set fnScope.PrefixToken = ""
			Set lastArgScope = ..InferType(pNode.Args.GetAt(pNode.Args.Size), fnScope)

			Return:lastArgScope.DataType'="UNKNOWN" lastArgScope
			Return pScope
		} Else {
			/// If the call is not partial, we can infer the type based on the function definition
			Set unchangedScopeFns = $lb("where","skip","single","first","last","tail")
			If $LF(unchangedScopeFns, pNode.Callee.Name) {
				/// These functions do not change the scope
				Return pScope
			} ElseIf (pNode.Callee.Name = "exists") || (pNode.Callee.Name = "not") {
				Set pScope.DataType = "BOOLEAN"
				Set pScope.FHIRType = "BOOLEAN"
				Set pScope.CompletionType = "ANY"
				Set pScope.Cardinality = 1
				Return pScope
			} ElseIf (pNode.Callee.Name = "first") {
				Set pScope.Cardinality = 1
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
			} Else {
				/// TODO: This else statement should be removed, only here for development purposes until
				/// tests pass
				W !,"[NOT IMPLEMENTED]: Unable to handle function " _ pNode.Callee.Name,!
				Return pScope
			}
		}
	} ElseIf (name = "IdentExpr") {
		/// This may change the scope...
		Set scope = ..CreateScope(pNode.Name, pScope, .success)

		If (success) {

			/// If this IdentityExpr successfully advanced the scope, we consume the "PrefixToken" and send back
			// the updated scope
			Set scope.PrefixToken = ""
			Set scope.CompletionType = "ANY"

			Return scope
		}

		/// Otherwise update the PrefixToken as this is not a valid token
		Set scope.PrefixToken = pNode.Name
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
	}ElseIf (name = "NumberExpr") || (name = "DecimalExpr") {
	}ElseIf (name = "StringExpr") {
		#;Do pCtx.AdvanceString()
	}ElseIf name = "UnaryExpr" { 
		#; Do ..InorderTraversal(pExpr.Expr, .pCtx, .finalTokenPrefix, .suggestValues, .refWithinFunctionCall, withinFunctionCall)
	}Else {
		Throw ##class(%Exception.General).%New("Unable to handle class " _cls)
	}

	Return pScope
}

/// Returns a list of resources to search or "" (empty string) if pSearch is a valid resource
Method SearchResources(pSearch As %String) As %ListOfDataTypes [ Private ]
{
	Set output = ##class(%ListOfDataTypes).%New()
	Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT DISTINCT(type) FROM HS_FHIRMeta_Storage.Rsrc WHERE (packageId %INLIST ?) AND kind='resource' AND %UPPER(type) LIKE ?", ..Loader.packageIdList, $ZCVT(pSearch, "U") _ "%")
	While tRS.%Next() '= 0 {
		Set type = tRS.%Get("type")
		If ($ZCVT(type, "U") = $ZCVT(pSearch, "U")) {
			Return ""
		}
		Do output.Insert(tRS.%Get("type") _ ".")
	}

	Return output
}

Method Suggest(pExpression As %String, scope As %RegisteredObject = "") As %ListOfDataTypes
{
	Set outputList = ##class(%ListOfDataTypes).%New()

	Set searchString = pExpression
	Set resourceFilter = ..ResourceFilter

	/// If a resource filter isn't set, extract it from the expression
	/// typically the FHIRPath expression begins with the resource type
	If (resourceFilter = "") {
		Set resourceSearch = $PIECE(pExpression, ".")
		Set searchString = $PIECE(pExpression, ".", 2, *)

		#; Set resourceFilter = resourceSearch
	}

	Set:resourceFilter'="" searchString = resourceFilter _ "." _ searchString

	If (..ResourceFilter '= "") {
		Set ctx = ##class(FHIR.FHIRPath.FHIRContextHelper).BuildResourceContext(..Loader, resourceFilter)
		Set ..ContextHelper = ctx
		Set scope = ##class(FHIR.FHIRPath.Context.Scope).%New()
		Set scope.Cardinality = 1
		Set scope.DataType = "RESOURCE"
		Set scope.CompletionType = "ANY"
		Set scope.FHIRType = resourceFilter
		Set scope.RootRef = ctx.GlobalRef
	} Else {
		Set scope = ##class(FHIR.FHIRPath.Context.Scope).%New()
	}
	
	Set ast = ##class(FHIR.FHIRPath.Parser).ParseString(pExpression)

	/// We want to start by advancing into the resource itself
	#; Do ctx.AdvanceContext(..Resource)
	Set suggestValues = 0
	#; Do ..InorderTraversal(ast, .ctx, .lastTokenFilter, .suggestValues, .withinFnCall)

	/// Try to infer the type of the current expression to provide better suggestions
	#; Set scope = ..CreateScope()
	#; Set scope = ##class(FHIR.FHIRPath.Context.Scope).%New()
	#; Set scope.Cardinality = 1
	#; Set scope.DataType = "RESOURCE"
	#; Set scope.CompletionType = "ANY"
	#; Set scope.FHIRType = resourceFilter
	#; Set scope.RootRef = ctx.GlobalRef

	Do ..MarkCursor(ast)
	Set endScope = ..InferType(ast, scope)

	#; w !,!,!,"Final scope:",!
	/// TODO: Remove this line..
	zw:^AFPDEBUG endScope
	#; Set scope = endScope

	Set assist = ##class(FHIR.TypeAssist.Engine).%New(..Loader)
	Set suggestions = assist.Suggest(endScope)
	Set prefix = endScope.PrefixToken

	For i=1:1:suggestions.Size {
		Set suggestion = suggestions.GetAt(i)
		If ($EXTRACT(suggestion, 1, $L(prefix)) = prefix) || (prefix = "") {
			Do outputList.Insert(suggestion)
		}
	}
	Return outputList

	/// Create a context helper
	Set ctx = ##class(FHIR.FHIRPath.FHIRContextHelper).BuildResourceContext(..Loader, resourceFilter)
	Set ..ContextHelper = ctx
	
	Set ast = ##class(FHIR.FHIRPath.Parser).ParseString(searchString)

	/// We want to start by advancing into the resource itself
	#; Do ctx.AdvanceContext(..Resource)
	Set suggestValues = 0
	Do ..InorderTraversal(ast, .ctx, .lastTokenFilter, .suggestValues, .withinFnCall)

	/// Try to infer the type of the current expression to provide better suggestions
	Set scope = ##class(FHIR.FHIRPath.Context.Scope).%New()
	Set scope.Cardinality = 1
	Set scope.DataType = "RESOURCE"
	Set scope.CompletionType = "ANY"
	Set scope.FHIRType = resourceFilter

	Do ..MarkCursor(ast)
	Set endScope = ..InferType(ast, scope)
	#; w !,!,!,"Final scope:",!
	#; zw endScope
	#; Set scope = endScope

	Set assist = ##class(FHIR.TypeAssist.Engine).%New(..Loader)
	Set suggestions = assist.Suggest(endScope)
	Return suggestions
	
	#; Write "LastTokenFilter="_lastTokenFilter,!

	Set propertyList = ctx.GetPropertyList()
	Set fnList = ctx.GetFunctionsList()
	Set suggestionList = ""
	Set:suggestValues suggestionList = ctx.GetSuggestionsList()

	#; Write "lasttoken=" _ lastTokenFilter,!,!
	
	Set suffix = ""
	Set:withinFnCall=0 suffix = "."
	
	Quit:'$DATA(lastTokenFilter) outputList

	/// Filter 
	For i=1:1:propertyList.Size {
		Set propName = ctx.GetFieldDisplayName(propertyList.GetAt(i))
		If ($EXTRACT(propName, 1, $L(lastTokenFilter)) = lastTokenFilter) {
			Do outputList.Insert(propName _ suffix)
			Do:ctx.IsCollectionField(propertyList.GetAt(i)) outputList.Insert(propName _ "[")
			Do:propName="extension" outputList.Insert("extension(")
		}
	}

	For i=1:1:fnList.Size {
		/// Commented out -- maybe needed?
		#; Continue:withinFnCall
		If ($EXTRACT(fnList.GetAt(i), 1, $L(lastTokenFilter)) = lastTokenFilter) {
			Do outputList.Insert(fnList.GetAt(i))
		}
	}

	If suggestionList'="" {
		For i=1:1:suggestionList.Size {
			If ($EXTRACT(suggestionList.GetAt(i), 1, $L(lastTokenFilter)) = lastTokenFilter) {
				Do outputList.Insert("'" _ suggestionList.GetAt(i) _ "'")
			}
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
