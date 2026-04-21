// AgentScriptLexer.g4
// This lexer defines the raw tokens of the language.
// The logic for INDENT/DEDENT is handled in a custom Python base class.
lexer grammar AgentScriptLexer;

// --- VIRTUAL TOKENS ---
// These tokens are manually created and injected by our custom lexer class.
// They will never be matched by a lexer rule.
INDENT: 'INDENT';
DEDENT: 'DEDENT';
MEANINGFUL_INDENT: 'MEANINGFUL_INDENT';

// --- KEYWORDS ---
LLM_INPUT:   '...';
MODEL_CONFIG:   'model_config';
MODEL:       'model';
TOPIC:       'topic';
START_AGENT: 'start_agent';
SYSTEM:      'system';
CONFIG:      'config';
LANGUAGE:    'language';
VARIABLES:   'variables';
KNOWLEDGE:   'knowledge';
CONNECTION:  'connection';
EMPTY:       'empty';
DESCRIPTION: 'description';
SOURCE:      'source';
SCHEMA:      'schema';
OVERRIDE:    'override';
REASONING:   'reasoning';
INSTRUCTIONS:      'instructions';
VISIBILITY:      'visibility';

ACTIONS:     'actions';
INPUTS:      'inputs';
OUTPUTS:     'outputs';
TARGET:      'target';

BEFORE_REASONING: 'before_reasoning';
AFTER_REASONING: 'after_reasoning';

// --- KEYWORDS that usually gets defaulted unless specified in the script ---
// action, parameters, actionreturns related keywords
LABEL:       'label';
REQUIRE_USER_CONFIRMATION: 'require_user_confirmation';
INCLUDE_IN_PROGRESS_INDICATOR: 'include_in_progress_indicator';
PROGRESS_INDICATOR_MESSAGE: 'progress_indicator_message';
IS_USER_INPUT: 'is_user_input';
IS_REQUIRED: 'is_required';
DEVELOPER_NAME: 'developer_name';
COMPLEX_DATA_TYPE_NAME: 'complex_data_type_name';
FILTER_FROM_AGENT: 'filter_from_agent';
IS_USED_BY_PLANNER: 'is_used_by_planner';
IS_DISPLAYABLE: 'is_displayable';

// Config-specific keywords
MODEL_PROVIDER: 'model_provider';
AGENT_ID:       'agent_id';
AGENT_NAME:     'agent_name';
AGENT_VERSION:  'agent_version';
AGENT_TYPE:     'agent_type';

// Language-specific keywords
DEFAULT_LOCALE: 'default_locale';
ADDITIONAL_LOCALES: 'additional_locales';
ALL_ADDITIONAL_LOCALES: 'all_additional_locales';

// Connection-specific keywords
ESCALATION_MESSAGE: 'escalation_message';
OUTBOUND_ROUTE_TYPE: 'outbound_route_type';
OUTBOUND_ROUTE_NAME: 'outbound_route_name';
ADAPTIVE_RESPONSE_ALLOWED: 'adaptive_response_allowed';

// Knowledge-specific keywords
RAG_FEATURE_CONFIG_ID: 'rag_feature_config_id';
CITATIONS_ENABLED:     'citations_enabled';
CITATIONS_URL:         'citations_url';

// Security-specific keywords
SECURITY:                        'security';
VERIFIED_CUSTOMER_RECORD_ACCESS: 'verified_customer_record_access';
USE_DEFAULT_OBJECTS:             'use_default_objects';
ADDITIONAL_OBJECTS:              'additional_objects';

// Block-specific keywords
VARIABLE:               '@variables';
ACTION:                 '@actions';
UTILS:                  '@utils';
TOOLS:                  'tools';
INPUT:                  '@inputs';
OUTPUT:                 '@outputs';
TOPIC_REF:              '@topic';
KNOWLEDGE_REF:          '@knowledge';
SYSTEM_VARIABLES:       '@system_variables';
IF:                     'if';
TRANSITION_TO:          'transition' WS+ 'to';
ESCALATE:               'escalate';
DELEGATE_TO:            'delegate' WS+ 'to';
SET_VARIABLES:          'setVariables';
ELSE:                   'else';
RUN:                    'run';
WITH:                   'with';
AS:                     'as';

SET:         'set';

AVAILABLE_WHEN: 'available' WS+ 'when';

AND:         'and';
OR:          'or';
IS:          'is';
IS_NOT:      'is' WS+ 'not';
NOT:         'not';

// Boolean and None constants
TRUE:           'True';
FALSE:          'False';
NONE:           'None';

// System message types
MESSAGES:       'messages';
ERROR:          'error';
WELCOME:        'welcome';

// Type keywords (must be before ID to be recognized)
TYPE_STRING:    'string';
TYPE_NUMBER:    'number';
TYPE_BOOLEAN:   'boolean';
TYPE_OBJECT:    'object';
TYPE_DATE:      'date';
TYPE_TIMESTAMP: 'timestamp';
TYPE_DATETIME:  'datetime';
TYPE_TIME:      'time';
TYPE_CURRENCY:  'currency';
TYPE_ID:        'id';
TYPE_INTEGER:   'integer';
TYPE_LONG:      'long';
LIST:           'list';

// Mutability keywords (must be before ID to be recognized)
MUTABLE:        'mutable';
LINKED:         'linked';

// --- LITERALS AND IDENTIFIERS ---
// Variable source keywords (must come before ID to take precedence)
CUSTOM_VAR_DECLARATION: 'custom';
CONTEXT_VAR_DECLARATION: 'context';

// An identifier for the block name.
ID:          [a-zA-Z_] [a-zA-Z_0-9]*;

// A string literal, allowing for escaped quotes.
STRING:      '"' ( '\\"' | ~[\r\n"] )*? '"';

// A number literal
NUMBER:      [0-9]+ ('.' [0-9]+)?;

// Date literal (YYYY-MM-DD format)
DATE_STRING: [0-9][0-9][0-9][0-9] '-' [0-9][0-9] '-' [0-9][0-9];

// Timestamp literal (ISO 8601 with optional Z timezone)
TIMESTAMP_STRING: [0-9][0-9][0-9][0-9] '-' [0-9][0-9] '-' [0-9][0-9] 'T' [0-9][0-9] ':' [0-9][0-9] ( ':' [0-9][0-9] ( '.' [0-9]+ )? )? ( 'Z' )?;

// Multi-character symbols
fragment COLON_ARROW: ':' WS* '->';

// Procedure blocks
PROCEDURE_BLOCK_START: COLON_ARROW NEWLINE;

fragment F_TEMPLATE_START: '|' WS?;
TEMPLATE_START: F_TEMPLATE_START -> pushMode(TEMPLATE);

fragment F_TEMPLATE_EXPR_START: '{!';

// Single-character symbols
COLON:       ':';
EQUALS:      '=';
COMMA:       ',';
LBRACKET:    '[';
RBRACKET:    ']';
LBRACE:      '{';
RBRACE:      '}';
LPAREN:      '(';
RPAREN:      ')';
DOT:         '.';

// Non-alphanumeric operators
// (Alphanumeric operators must be declared before ID to be recognized)
PLUS:        '+';
MINUS:       '-';
// Arithmetic operators not supported in DSL expressions - commented out for 1:1 parity
// MULTIPLY:    '*';
// DIVIDE:      '/';
// MODULO:      '%';
EQ:          '==';
NE:          '!=';
LT:          '<';
LE:          '<=';
GT:          '>';
GE:          '>=';
// Left in for future use
// We'll want to be careful for this as it's ambiguous with `GT`
// GENERATION: '>';

// --- WHITESPACE, NEWLINES, AND COMMENTS ---
// Comments start with '#' and go to the end of the line. They are skipped entirely.
COMMENT:     '#' ~[\r\n]* -> skip;

// Newlines include lines entirely consisting of whitespace and/or comments.
fragment NEWLINE: '\r'? '\n';

fragment NEWLINES_WITH_WS:
    NEWLINE
    ( [ \t]* NEWLINE )*
    ;

fragment NEWLINES_WITH_WS_AND_COMMENTS:
    ( NEWLINE )
    ( [ \t]* COMMENT? NEWLINE )*
    ;

NEWLINES: NEWLINES_WITH_WS_AND_COMMENTS;

// Context variable token - matches @identifier (not reserved keywords)
CONTEXT_ID: '@' [a-zA-Z_] [a-zA-Z_0-9]*;

// Other whitespace is ignored and hidden from the parser.
fragment WS: [ \t]+;
DEFAULT_WS: WS -> channel(HIDDEN);

// Template mode, used in :| blocks and after |
mode TEMPLATE;

// Template expression start - matches {! and switches to expression mode
// Due to maximal munch, {! (2 chars) always beats { (1 char) from TMPL_BRACE
TMPL_EXPR_START: F_TEMPLATE_EXPR_START -> pushMode(TEMPLATE_EXPR_MODE);

// Content that doesn't contain { or newlines
TMPL_TEXT: ~[{\r\n]+;

// Single { - only matches when {! doesn't (due to maximal munch rule)
// This allows { at end of line (e.g., for JSON) while {! triggers expressions
TMPL_BRACE: '{';

TMPL_NEWLINES: NEWLINES_WITH_WS;

// n.b. whitespace is not hidden in this mode

// TEMPLATE_EXPR_MODE - for handling expressions inside {! }
mode TEMPLATE_EXPR_MODE;

// Template expression end - return to prompt mode
TEMPLATE_EXPR_END: '}' -> popMode;

// Expression keywords
EXPR_AND: 'and';
EXPR_OR: 'or';
EXPR_IF: 'if';
EXPR_ELSE: 'else';

// Expression operators
EXPR_EQ: '==';
EXPR_NE: '!=';
EXPR_LT: '<';
EXPR_LE: '<=';
EXPR_GT: '>';
EXPR_GE: '>=';
EXPR_IS: 'is';
EXPR_IS_NOT: 'is' WS+ 'not';
EXPR_PLUS: '+';
EXPR_MINUS: '-';

// Arithmetic modulo operator not supported in DSL expressions - commented out for 1:1 parity
// EXPR_MODULO: '%';

// Expression punctuation
EXPR_DOT: '.';
EXPR_LBRACKET: '[';
EXPR_RBRACKET: ']';
EXPR_LPAREN: '(';
EXPR_RPAREN: ')';
EXPR_AT: '@';
EXPR_COMMA: ',';

// Expression literals
EXPR_STRING: '"' ( '\\"' | . )*? '"' | '\'' ( '\\\'' | . )*? '\'';
EXPR_NUMBER: [0-9]+ ('.' [0-9]+)?;
EXPR_TRUE: 'True';
EXPR_FALSE: 'False';
EXPR_NONE: 'None';

// Expression identifiers
EXPR_ID: [a-zA-Z_] [a-zA-Z_0-9]*;

// Expression whitespace
EXPR_WS: [ \t]+ -> skip;
