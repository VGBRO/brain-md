// AgentScriptParser.g4
// This parser defines the structure of the configuration file.
// It relies on the token vocabulary defined in AgentScriptLexer.g4.
parser grammar AgentScriptParser;

options {
    tokenVocab = AgentScriptLexer;
}

// The entry point: an agentScript can have system, config, language, variables, connection, security or block definitions.
agentScript:
    NEWLINES* (NEWLINES* (systemBlock | configBlock | languageBlock | variablesBlock | modelConfigBlock | connectionBlock | block | knowledgeBlock | securityBlock))* NEWLINES* EOF
    ;

// System block definition
systemBlock:
    SYSTEM COLON NEWLINES INDENT systemBody DEDENT
    ;

systemBody:
    NEWLINES* EMPTY NEWLINES*
    | (NEWLINES* systemStatement NEWLINES*)+
    ;

instructions:
    instructionsWithString | instructionsWithTemplate
    ;

systemStatement:
    instructions
    | systemMessages
    ;

systemMessages:
    MESSAGES COLON NEWLINES INDENT (NEWLINES* systemMessageStatement NEWLINES*)+ DEDENT
    ;

systemMessageStatement:
    welcomeMessage
    | errorMessage
    ;

welcomeMessage:
    WELCOME COLON (STRING | template)
    ;

errorMessage:
    ERROR COLON (STRING | template)
    ;
// Config block definition
configBlock:
    CONFIG COLON NEWLINES INDENT configBody DEDENT
    ;

configBody:
    NEWLINES* EMPTY NEWLINES*
    | NEWLINES* configStatement (NEWLINES+ configStatement)* NEWLINES*
    ;

configStatement:
    configKeyValue
    | predefinedConfigKey
    ;

predefinedConfigKey:
    (MODEL_PROVIDER COLON configValue NEWLINES*)
    | (AGENT_ID COLON configValue NEWLINES*)
    | (AGENT_NAME COLON configValue NEWLINES*)
    | (AGENT_VERSION COLON configValue NEWLINES*)
    | (AGENT_TYPE COLON configValue NEWLINES*)
    | (DEVELOPER_NAME COLON configValue NEWLINES*)
    | (DESCRIPTION COLON configValue NEWLINES*)
    ;

configKeyValue:
    ID COLON configValue NEWLINES*
    ;

configValue:
    STRING
    | NUMBER
    | boolValue
    ;

boolValue:
    TRUE
    | FALSE
    ;

dateLiteral:
    DATE_STRING
    ;

timestampLiteral:
    TIMESTAMP_STRING
    ;

// Language block definition
languageBlock:
    LANGUAGE COLON NEWLINES INDENT languageBody DEDENT
    ;

languageBody:
    NEWLINES* languageStatement (NEWLINES+ languageStatement)* NEWLINES*
    ;

languageStatement:
    DEFAULT_LOCALE COLON STRING NEWLINES*
    | ADDITIONAL_LOCALES COLON STRING NEWLINES*
    | ALL_ADDITIONAL_LOCALES COLON boolValue NEWLINES*
    ;

// Variables block definition
variablesBlock:
    VARIABLES COLON NEWLINES INDENT variablesBody DEDENT
    ;

variablesBody:
    variableDeclarationList
    ;

variableDeclarationList:
    (NEWLINES* variableDeclaration NEWLINES*)+
    ;

variableDeclaration:
    ID COLON variableModifier type (EQUALS defaultValue)? NEWLINES (NEWLINES* INDENT variableMetadataList DEDENT)?;  // modifier is required, variable metadata is optional - used to declare source and description

variableMetadataList:
    (NEWLINES* variableMetadata NEWLINES*)+
    ;

variableMetadata:
    DESCRIPTION COLON STRING NEWLINES*
    | DESCRIPTION COLON plainTemplate  // Supports multiline descriptions with | syntax
    | SOURCE COLON variableSource NEWLINES*
    | LABEL COLON STRING NEWLINES*
    | VISIBILITY COLON STRING NEWLINES*
    ;

variableSource:
    CUSTOM_VAR_DECLARATION
    | CONTEXT_VAR_DECLARATION                 // "custom" or "context"
    | customVariable                        // @variables.name, @outputs.value, etc.
    | contextVariable                         // @session.sessionID, @request.value, etc.
    ;

variableModifier:
    | MUTABLE
    | LINKED
    ;

// Model config block definition
modelConfigBlock:
    MODEL_CONFIG COLON NEWLINES INDENT modelConfigBody DEDENT
    ;

modelConfigBody:
    (NEWLINES* modelConfigStatement NEWLINES*)+
    ;

modelConfigStatement:
    MODEL COLON STRING NEWLINES
    ;

// Connection block definition
connectionBlock:
    CONNECTION ID COLON NEWLINES INDENT connectionBody DEDENT
    ;

connectionBody:
    (NEWLINES* connectionStatement NEWLINES*)+
    ;

connectionStatement:
    ESCALATION_MESSAGE COLON STRING
    | OUTBOUND_ROUTE_TYPE COLON STRING  // optional, default set in compiler
    | OUTBOUND_ROUTE_NAME COLON STRING
    | ADAPTIVE_RESPONSE_ALLOWED COLON boolValue
    | EMPTY
    ;

type:
    primitiveType
    | listType
    ;

primitiveType:
    TYPE_STRING
    | TYPE_NUMBER
    | TYPE_BOOLEAN
    | TYPE_OBJECT
    | TYPE_DATE
    | TYPE_TIMESTAMP
    | TYPE_DATETIME
    | TYPE_TIME
    | TYPE_CURRENCY
    | TYPE_ID
    | TYPE_INTEGER
    | TYPE_LONG
    ;

listType:
    LIST LBRACKET primitiveType RBRACKET
    ;

defaultValue:
    literal                                   // Basic literals: strings, numbers, booleans, dates, timestamps
    | arrayLiteral                           // Array literals: [1, 2, 3]
    | objectLiteral                          // Object literals: {key: "value"}
    | customVariable                         // Custom variables: @variables.name, @knowledge.config_id, etc.
    | contextVariable                        // Context variables: @session.id, @request.value, etc.
    ;

literal:
    NONE
    | STRING
    | numericLiteral
    | boolValue
    | dateLiteral
    | timestampLiteral
    ;

numericLiteral:
    MINUS? NUMBER
    ;

arrayLiteral:
    LBRACKET (arrayElement (COMMA arrayElement)*)? RBRACKET
    ;

arrayElement:
    literal
    | arrayLiteral
    | objectLiteral
    ;

objectLiteral:
    LBRACE (objectProperty (COMMA objectProperty)*)? RBRACE
    ;

objectProperty:
    STRING COLON (literal | arrayLiteral | objectLiteral)
    ;

// Actions block definition
actionsBlock:
    ACTIONS COLON NEWLINES INDENT actionsBody DEDENT
    ;

actionsBody:
    (NEWLINES* actionDefinition NEWLINES*)+
    ;

actionDefinition:
    ID COLON NEWLINES INDENT actionBody DEDENT
    ;

// Action body with a reference to an action
// must have a target, and may have inputs and outputs
actionBody:
    (NEWLINES* actionBodyPart NEWLINES*)+
    ;

actionBodyPart:
  actionDescription
    |  actionTarget
    |  actionManualDSLField
    |  actionInputs
    |  actionOutputs
    ;

actionDescription:
    DESCRIPTION COLON STRING NEWLINES
    | DESCRIPTION COLON plainTemplate  // Supports multiline descriptions with | syntax
    ;

actionLabel:
    LABEL COLON STRING NEWLINES
    ;

actionInputs:
    INPUTS COLON NEWLINES INDENT parameterDefinitionList DEDENT
    ;

parameterDefinitionList:
    (NEWLINES* parameterDefinition NEWLINES*)+
    ;

parameterDefinition:
    fieldName COLON type (EQUALS defaultValue)? NEWLINES (NEWLINES* INDENT parameterDefinitionStatement+ DEDENT NEWLINES*)?
    ;

parameterDefinitionStatement:
    DESCRIPTION COLON STRING NEWLINES*
    | DESCRIPTION COLON plainTemplate  // Supports multiline descriptions with | syntax
    | parameterManualDSLField
    ;

actionOutputs:
    OUTPUTS COLON NEWLINES INDENT returnDefinitionList DEDENT
    ;

returnDefinitionList:
    (NEWLINES* returnDefinition NEWLINES*)+
    ;

returnDefinition:
    fieldName COLON type NEWLINES (NEWLINES* INDENT returnDefinitionStatement+ DEDENT NEWLINES*)?
    ;

returnDefinitionStatement:
    DESCRIPTION COLON STRING NEWLINES*
    | DESCRIPTION COLON plainTemplate  // Supports multiline descriptions with | syntax
    | returnManualDSLField
    ;

// Manual DSL fields sections
actionManualDSLField:
    LABEL COLON STRING NEWLINES
    | REQUIRE_USER_CONFIRMATION COLON boolValue NEWLINES
    | INCLUDE_IN_PROGRESS_INDICATOR COLON boolValue NEWLINES
    | PROGRESS_INDICATOR_MESSAGE COLON STRING NEWLINES
    | SOURCE COLON STRING NEWLINES
    ;

parameterManualDSLField:
    LABEL COLON STRING NEWLINES
    | IS_REQUIRED COLON boolValue NEWLINES
    | IS_USER_INPUT COLON boolValue NEWLINES
    | DESCRIPTION COLON STRING NEWLINES
    | COMPLEX_DATA_TYPE_NAME COLON STRING NEWLINES
    | SCHEMA COLON STRING NEWLINES
    ;

returnManualDSLField:
    DEVELOPER_NAME COLON STRING NEWLINES
    | LABEL COLON STRING NEWLINES
    | COMPLEX_DATA_TYPE_NAME COLON STRING NEWLINES
    | FILTER_FROM_AGENT COLON boolValue NEWLINES
    | IS_USED_BY_PLANNER COLON boolValue NEWLINES
    | IS_DISPLAYABLE COLON boolValue NEWLINES
    | DESCRIPTION COLON STRING NEWLINES
    ;



actionTarget:
    TARGET COLON STRING NEWLINES                   // target: "foo"
    ;


// A block definition starts with the 'topic' or 'start_agent' keyword and a name.
block:
    ((TOPIC ID) | (START_AGENT ID?)) COLON NEWLINES INDENT blockBody DEDENT
    ;


// A block body contains components in any order, with description required
// We enforce the required description through semantic validation in the visitor/compiler
blockBody:
    (NEWLINES* blockBodyComponent NEWLINES*)+
    ;

// Block body components - order agnostic
// SEMANTIC CONSTRAINT: Exactly one blockDescription must be present
blockBodyComponent:
    blockDescription
    | blockLabel
    | blockSource
    | topicSystemBlock
    | actionsBlock
    | beforeReasoningDirectives
    | reasoningBlock
    | afterReasoningDirectives
    | modelConfigBlock
    ;

reasoningBlock:
    REASONING COLON NEWLINES INDENT reasoningBlockBody DEDENT
    ;

reasoningBlockBody:
    (NEWLINES* reasoningStatement NEWLINES*)+
    ;

reasoningStatement:
    blockInstructions
    | reasoningActionsDeclaration
    ;

blockLabel:
    LABEL COLON STRING NEWLINES
    ;

blockSource:
    SOURCE COLON STRING NEWLINES
    ;

instructionsWithString:
    INSTRUCTIONS COLON STRING NEWLINES?
    ;

instructionsWithProcedure:
    INSTRUCTIONS procedureBlock
    ;

instructionsWithTemplate:
    INSTRUCTIONS COLON template // Doesn't allow newlines between : and |
    ;

blockInstructions:
    instructionsWithProcedure | instructionsWithTemplate
    ;

procedureBlock:
    PROCEDURE_BLOCK_START INDENT directives DEDENT
    ;

// Helper for template text content (text without expressions)
// TMPL_TEXT is content without { or newlines, TMPL_BRACE is a literal {
templateTextContent: TMPL_TEXT | TMPL_BRACE;

// n.b.: in this template rule, both instances of TMPL_NEWLINES are optional.
// This is to support the case where EOF occurs inside of a template.
// You could alternatively make a rule where only the last TMPL_NEWLINES is optional,
// but that would probably change the parse tree.
template:
    TEMPLATE_START (templateTextContent | templateExpression)* TMPL_NEWLINES?
    (MEANINGFUL_INDENT (templateTextContent | templateExpression)+ TMPL_NEWLINES?)*
    DEDENT
    ;

// Plain template is like template but does NOT allow expressions (only plain text)
// Used for descriptions which support multiline text but not dynamic expressions
plainTemplate:
    TEMPLATE_START templateTextContent* TMPL_NEWLINES?
    (MEANINGFUL_INDENT templateTextContent+ TMPL_NEWLINES?)*
    DEDENT
    ;

blockDescription:
    DESCRIPTION COLON STRING NEWLINES
    | DESCRIPTION COLON NEWLINES INDENT STRING DEDENT
    | DESCRIPTION COLON plainTemplate  // Supports multiline descriptions with | syntax
    ;

// Before reasoning directives
beforeReasoningDirectives:
    BEFORE_REASONING (COLON NEWLINES | PROCEDURE_BLOCK_START) INDENT directives DEDENT
    ;

// After reasoning directives
afterReasoningDirectives:
    AFTER_REASONING (COLON NEWLINES | PROCEDURE_BLOCK_START) INDENT directives DEDENT
    ;

// Common directives rule
directives:
    (NEWLINES* directive NEWLINES*)+
    ;

// A directive can be a statement (I.E. action call, variable assignment, etc...), *or* a conditional statement (which, in turn, can contain statements)
// Note that the conditional will be expanded, but we do not do that now
directive:
    statement
    | conditionalStatement
    ;

// Topic System Block syntax for topic blocks
topicSystemBlock:
    SYSTEM COLON NEWLINES
        (INDENT
            instructions
        DEDENT NEWLINES*)?
    ;

// Template expression: {! expression }
templateExpression:
    TMPL_EXPR_START jinjaExpression TEMPLATE_EXPR_END
    ;

// Jinja expression - supports variable access, function calls, operators, and conditionals
jinjaExpression:
    jinjaExpression EXPR_IF jinjaExpression EXPR_ELSE jinjaExpression     // conditional (lowest precedence)
    | jinjaExpression (EXPR_EQ | EXPR_NE | EXPR_LT | EXPR_LE | EXPR_GT | EXPR_GE | EXPR_IS | EXPR_IS_NOT) jinjaExpression  // comparison
    | jinjaExpression (EXPR_AND | EXPR_OR) jinjaExpression               // logical
    | jinjaExpression (EXPR_PLUS | EXPR_MINUS) jinjaExpression           // arithmetic add/sub
    // Arithmetic modulo operator not supported in DSL expressions - commented out for 1:1 parity
    // | jinjaExpression EXPR_MODULO jinjaExpression                        // arithmetic mod
    | jinjaExpression EXPR_DOT EXPR_ID                                   // property access
    | jinjaExpression EXPR_LBRACKET jinjaExpression EXPR_RBRACKET        // array access
    | templateExpressionVariable                                         // variable reference
    | templateExpressionFunctionCall                                     // function call
    | templateLiteral                                                    // literal value
    | EXPR_LPAREN jinjaExpression EXPR_RPAREN                           // parentheses
    ;

// Template variables for use in expressions
templateExpressionVariable:
    EXPR_AT EXPR_ID (EXPR_DOT EXPR_ID)*                                 // @variables.name, @outputs.value, etc.
    | EXPR_AT EXPR_ID EXPR_LBRACKET jinjaExpression EXPR_RBRACKET       // @variable[index]
    | EXPR_ID (EXPR_DOT EXPR_ID)*                                       // regular identifiers
    ;

// Function calls within template expressions
templateExpressionFunctionCall:
    EXPR_ID EXPR_LPAREN (jinjaExpression (EXPR_COMMA jinjaExpression)*)? EXPR_RPAREN
    ;

// Literals within template expressions
templateLiteral:
    EXPR_STRING
    | EXPR_NUMBER
    | EXPR_TRUE
    | EXPR_FALSE
    | EXPR_NONE
    ;

// Action definitions (for actions: block)
action:
    ACTION DOT ID NEWLINES INDENT actionStatementList DEDENT
    ;

actionStatementList:
    (NEWLINES* actionStatement NEWLINES*)+
    ;

actionStatement:
    AVAILABLE_WHEN expression NEWLINES*
    | WITH toolParameters NEWLINES*
    | statementList NEWLINES*
    ;

// Actions (for actions: block)
tool:
    (ID COLON) actionDeclaration
    | ID COLON utilsDeclaration
    ;

actionDeclaration:
    ACTION DOT ID NEWLINES
        (INDENT actionDeclarationStatementList DEDENT NEWLINES*)?
    ;

actionDeclarationStatementList:
    (NEWLINES* actionDeclarationStatement NEWLINES*)*
    ;

actionDeclarationStatement:
    actionDescription
    | availableWhenClause
    | withClause
    | postActionStatement
    ;

availableWhenClause:
    AVAILABLE_WHEN expression
    ;

withClause:
    WITH toolParameters
    ;

postActionStatement:
    variableAssignment
    | actionCall
    | transitionStatement
    | conditionalStatement
    ;

// Utils declarations (available in tools blocks)
utilsDeclaration:
    utilsTransitionDeclaration
    | utilsSetVariablesDeclaration
    | utilsEscalationDeclaration
    ;

// Utils transition declaration
utilsTransitionDeclaration:
    (UTILS DOT TRANSITION_TO)? TOPIC_REF DOT (ID | TARGET) NEWLINES
        (INDENT utilsTransitionDeclarationStatementList DEDENT NEWLINES*)?
    ;
// utils transition declaration statement list
utilsTransitionDeclarationStatementList:
    (NEWLINES* utilsTransitionDeclarationStatement NEWLINES*)*
    ;

utilsTransitionDeclarationStatement:
    actionDescription
    | actionLabel
    | availableWhenClause
    ;

// Utils setVariables declaration
utilsSetVariablesDeclaration:
    UTILS DOT SET_VARIABLES NEWLINES*
        (INDENT utilsSetVariablesDeclarationStatementList DEDENT NEWLINES*)?
    ;

utilsSetVariablesDeclarationStatementList:
    (NEWLINES* utilsSetVariablesDeclarationStatement NEWLINES*)*
    ;

utilsSetVariablesDeclarationStatement:
    actionDescription
    | actionLabel
    | withClause
    | availableWhenClause
    ;

utilsEscalationDeclaration:
    UTILS DOT ESCALATE NEWLINES*
        (INDENT utilsEscalationDeclarationStatementList DEDENT NEWLINES*)?
    ;

utilsEscalationDeclarationStatementList:
    (NEWLINES* utilsEscalationDeclarationStatement NEWLINES*)*
    ;

utilsEscalationDeclarationStatement:
    actionDescription
    | actionLabel
    | availableWhenClause
    ;

toolList:
    (NEWLINES* tool NEWLINES*)+
    ;

// Reasoning Actions Declaration
reasoningActionsDeclaration:
    ACTIONS COLON NEWLINES INDENT toolList DEDENT
    ;

toolParameters:
    actionParameter (COMMA actionParameter)*
    ;

actionParameter:
    fieldName EQUALS (LLM_INPUT | expression)?
    ;

// Action Call
actionCall:
    RUN ACTION DOT ID (NEWLINES INDENT actionCallBody DEDENT)?
    ;

actionCallBody:
    (WITH parameterList NEWLINES*)*
    (NEWLINES* variableAssignment NEWLINES*)*
    (NEWLINES* transitionStatement)?
    ;

parameterList:
    parameter (COMMA parameter)*
    ;

parameter:
    (ID | STRING) EQUALS expression
    ;

// Conditional Statement
conditionalStatement:
    IF expression COLON NEWLINES INDENT statementList DEDENT (ELSE COLON NEWLINES INDENT statementList DEDENT)?
    ;

statementList:
    (NEWLINES* statement NEWLINES*)+
    ;

variableAssignment:
    SET VARIABLE DOT ID EQUALS expression
    ;

statement:
    variableAssignment
    | actionCall
    | transitionStatement
    | template
    // | conditionalStatement // This is not included as we do not support nested conditionals
    ;

// Transition Statement
transitionStatement:
    TRANSITION_TO TOPIC_REF DOT ID
    ;

// Expressions
expression:
    expression IF expression ELSE expression                         // conditional expression (ternary operator) - lowest precedence
    | expression (AND | OR) expression                               // logical operators
    | expression (EQ | NE | LT | LE | GT | GE | IS | IS_NOT) expression           // comparison operators
    | expression (PLUS | MINUS) expression                          // arithmetic add/sub
    // Arithmetic mul/div operators not supported in DSL expressions - commented out for 1:1 parity
    // | expression (MULTIPLY | DIVIDE) expression                     // arithmetic mul/div
    | expression DOT propertyName                                  // property access
    | expression LBRACKET expression RBRACKET         // array access (multiplication * not supported in DSL)
    | (PLUS | MINUS | NOT) expression                               // unary operations
    | ID LPAREN (expression (COMMA expression)*)? RPAREN            // function call
    | customVariable                                              // template variable
    | literal                                                       // literal
    | LPAREN expression RPAREN                                      // parentheses
    ;

customVariable:
    (VARIABLE | OUTPUT | INPUT | TOPIC_REF | KNOWLEDGE_REF | SYSTEM_VARIABLES) (DOT propertyName)*          // @variables.name, @outputs.value, @topic.name, @knowledge.rag_feature_config_id, @system_variables.user_input, etc.
    | (VARIABLE | OUTPUT | INPUT | TOPIC_REF | SYSTEM_VARIABLES) LBRACKET (expression) RBRACKET      // @variable[index], @system_variables["user_input"]
    ;

contextVariable:
    CONTEXT_ID (DOT propertyName)*                      // @session.sessionID, @request.value, etc.
    ;

// Property name rule to support identifiers and keywords as property names
// With the generic grammar we will not need this but this is for now to support the knowledge block
propertyName:
    ID
    | RAG_FEATURE_CONFIG_ID
    | CITATIONS_ENABLED
    | CITATIONS_URL
    ;

// Field name rule to support both regular identifiers and quoted strings
fieldName:
    ID
    | STRING
    ;

knowledgeBlock:
    KNOWLEDGE COLON NEWLINES INDENT knowledgeActionBody DEDENT NEWLINES*
    ;

knowledgeActionBody:
    NEWLINES* knowledgeActionField (NEWLINES+ knowledgeActionField)* NEWLINES*
    ;

knowledgeActionField:
    RAG_FEATURE_CONFIG_ID COLON STRING NEWLINES*
    | CITATIONS_ENABLED COLON boolValue NEWLINES*
    | CITATIONS_URL COLON STRING NEWLINES*
    ;

securityBlock:
    SECURITY COLON NEWLINES INDENT securityBody DEDENT NEWLINES*
    ;

securityBody:
    NEWLINES* verifiedCustomerRecordAccessBlock NEWLINES*
    ;

verifiedCustomerRecordAccessBlock:
    VERIFIED_CUSTOMER_RECORD_ACCESS COLON NEWLINES INDENT verifiedCustomerRecordAccessBody DEDENT NEWLINES*
    ;

verifiedCustomerRecordAccessBody:
    NEWLINES* verifiedCustomerRecordAccessField
    (NEWLINES+ verifiedCustomerRecordAccessField)* NEWLINES*
    ;

verifiedCustomerRecordAccessField:
    USE_DEFAULT_OBJECTS COLON boolValue NEWLINES*
    | ADDITIONAL_OBJECTS COLON NEWLINES INDENT additionalObjectsList DEDENT NEWLINES*
    ;

additionalObjectsList:
    (NEWLINES* MINUS objectFieldRef NEWLINES*)+
    ;

objectFieldRef:
    STRING
    ;
