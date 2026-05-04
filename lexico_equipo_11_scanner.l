%{

/* Librerias estandar para I/O, memoria y cadenas. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* IDs de token definidos en la tabla informal. */
#define TOKEN_IDENTIFIER 100
#define TOKEN_KEYWORD    101
#define TOKEN_INTEGER    200
#define TOKEN_FLOAT      300
#define TOKEN_STRING     400
#define TOKEN_OPERATOR   500
#define TOKEN_DELIMITER  600
#define TOKEN_COMMENT    700
#define TOKEN_WS_COUNT   900
#define TOKEN_WHITESPACE 901
#define TOKEN_NEWLINE    950
#define TOKEN_ERROR      999

/* Limites para tablas de simbolos. */
#define MAX_SYMBOLS 5000
#define MAX_LEXEME_LEN 1500

/* Entrada generica para almacenar lexemas en tablas. */
typedef struct {
    char lexeme[MAX_LEXEME_LEN];
} SymbolEntry;

/* Tablas de simbolos por categoria. */
static SymbolEntry id_table[MAX_SYMBOLS];
static SymbolEntry int_table[MAX_SYMBOLS];
static SymbolEntry float_table[MAX_SYMBOLS];
static SymbolEntry string_table[MAX_SYMBOLS];

/* Contadores de entradas por tabla. */
static int id_count = 0;
static int int_count = 0;
static int float_count = 0;
static int string_count = 0;

/* Contador de linea para reportar errores lexicos. */
static int line_no = 1;

/* Prototipos de funciones auxiliares. */
static int is_keyword(const char *lex);
static int add_to_table(SymbolEntry *table, int *count, const char *lexeme);
static void emit_token_simple(int token_id, const char *token_name, const char *lexeme);
static void emit_token_ref(int token_id, const char *token_name, const char *lexeme, int index);
static void print_symbol_tables(void);
%}

/* Definiciones de regex para cada tipo de token. */
LETTER          [a-zA-Z_]
DIGIT           [0-9]
ID              [a-zA-Z_][a-zA-Z0-9_]*
INT             {DIGIT}+
FLOAT           ({DIGIT}*\.{DIGIT}+([eE][+-]?{DIGIT}+)?|{DIGIT}+[eE][+-]?{DIGIT}+)
STRING          \"[^\"\n]*\"|\'[^\'\n]*\'
STRING_UNCLOSED_LINE  \"[^\"\n]*\n|\'[^\'\n]*\n
STRING_UNCLOSED_EOF   \"[^\"\n]*|\'[^\'\n]*
COMMENT         \#[^\n]*
WS_COUNT        ^[ \t]+
WHITESPACE      [ \t]+
NEWLINE         \n+
OPERATOR        "**"|"=="|"!="|"<="|">="|"//"|"<<"|">>"|"+="|"-="|"*="|"/="|"%="|[=+\-*/%&^<>|~]
DELIMITER       [()\[\]{}.,;:@]|"->"

%%
{COMMENT} {
    emit_token_simple(TOKEN_COMMENT, "COMMENT", yytext);
}

{FLOAT} {
    int idx = add_to_table(float_table, &float_count, yytext);
    emit_token_ref(TOKEN_FLOAT, "FLOAT", yytext, idx);
}

{INT} {
    int idx = add_to_table(int_table, &int_count, yytext);
    emit_token_ref(TOKEN_INTEGER, "INTEGER", yytext, idx);
}

{STRING} {
    int idx = add_to_table(string_table, &string_count, yytext);
    emit_token_ref(TOKEN_STRING, "STRING", yytext, idx);
}

{STRING_UNCLOSED_LINE} {
    fprintf(stderr,
            "LEXICAL_ERROR: token_id=<%d> line=%d lexeme=\"%s\" (cadena sin cerrar)\n",
            TOKEN_ERROR, line_no, yytext);
    line_no++; /* patron termina en un solo \n */
}

{STRING_UNCLOSED_EOF} {
    fprintf(stderr,
            "LEXICAL_ERROR: token_id=<%d> line=%d lexeme=\"%s\" (cadena sin cerrar al EOF)\n",
            TOKEN_ERROR, line_no, yytext);
}

{ID} {
    if (is_keyword(yytext)) {
        emit_token_simple(TOKEN_KEYWORD, "KEYWORD", yytext);
    } else {
        int idx = add_to_table(id_table, &id_count, yytext);
        emit_token_ref(TOKEN_IDENTIFIER, "IDENTIFIER", yytext, idx);
    }
}

{OPERATOR} {
    emit_token_simple(TOKEN_OPERATOR, "OPERATOR", yytext);
}

{DELIMITER} {
    emit_token_simple(TOKEN_DELIMITER, "DELIMITER", yytext);
}

{WS_COUNT} {
    /* Indentacion al inicio de linea, enviada al parser. */
    if (yyleng > 0) {
        emit_token_simple(TOKEN_WS_COUNT, "WS_COUNT", yytext);
    }
}

{WHITESPACE} {
    /* Espacios/tabs intermedios son separadores visuales y se descartan. */
}

{NEWLINE} {
    emit_token_simple(TOKEN_NEWLINE, "NEW_LINE", yytext);
    line_no += (int)strlen(yytext);
}

. {
    /* Cualquier simbolo fuera de especificacion cae en error. */
    fprintf(stderr,
            "LEXICAL_ERROR: token_id=<%d> line=%d lexeme=\"%s\"\n",
            TOKEN_ERROR, line_no, yytext);
}

%%

/* Verifica si un identificador coincide con palabra reservada. */
static int is_keyword(const char *lex) {
    /* Conjunto de palabras reservadas definido en la tabla informal. */
    static const char *keywords[] = {
        "import", "as", "None", "True", "def", "return", "if", "else", "while", "for", "in",
        "False", "elif", "switch", "and", "or", "not", "is", "break", "continue", "pass",
        "lambda", "class", "with", "try", "except", "finally", "raise", "yield", "del",
        "global", "nonlocal", "assert", "from"
    };
    int i;
    int n = (int)(sizeof(keywords) / sizeof(keywords[0]));
    for (i = 0; i < n; ++i) {
        if (strcmp(lex, keywords[i]) == 0) {
            return 1;
        }
    }
    return 0;
}

/* Inserta lexema en su tabla o reutiliza indice existente. */
static int add_to_table(SymbolEntry *table, int *count, const char *lexeme) {
    int i;
    for (i = 0; i < *count; ++i) {
        if (strcmp(table[i].lexeme, lexeme) == 0) {
            return i + 1;
        }
    }

    if (*count >= MAX_SYMBOLS) {
        fprintf(stderr, "ERROR: symbol table overflow\n");
        exit(1);
    }

    strncpy(table[*count].lexeme, lexeme, MAX_LEXEME_LEN - 1);
    table[*count].lexeme[MAX_LEXEME_LEN - 1] = '\0';
    (*count)++;
    return *count;
}

/* Emite token sin referencia a tabla de simbolos. */
static void emit_token_simple(int token_id, const char *token_name, const char *lexeme) {
    printf("<%d> %-12s %s\n", token_id, token_name, lexeme);
}

/* Emite token con referencia a indice de tabla de simbolos. */
static void emit_token_ref(int token_id, const char *token_name, const char *lexeme, int index) {
    printf("<%d,%d> %-12s %s\n", token_id, index, token_name, lexeme);
}

/* Imprime tablas de simbolos acumuladas al final del analisis. */
static void print_symbol_tables(void) {
    int i;

    printf("\n=== SYMBOL TABLE: IDENTIFIERS ===\n");
    for (i = 0; i < id_count; ++i) {
        printf("%d\t%s\n", i + 1, id_table[i].lexeme);
    }

    printf("\n=== SYMBOL TABLE: INTEGERS ===\n");
    for (i = 0; i < int_count; ++i) {
        printf("%d\t%s\n", i + 1, int_table[i].lexeme);
    }

    printf("\n=== SYMBOL TABLE: FLOATS ===\n");
    for (i = 0; i < float_count; ++i) {
        printf("%d\t%s\n", i + 1, float_table[i].lexeme);
    }

    printf("\n=== SYMBOL TABLE: STRINGS ===\n");
    for (i = 0; i < string_count; ++i) {
        printf("%d\t%s\n", i + 1, string_table[i].lexeme);
    }
}

/* Funcion requerida por lex al terminar el flujo de entrada. */
int yywrap(void) {
    return 1;
}

/* Punto de entrada: abre archivo, ejecuta scanner e imprime tablas. */
int main(int argc, char **argv) {
    if (argc > 1) {
        FILE *in = fopen(argv[1], "r");
        if (!in) {
            perror("Could not open input file");
            return 1;
        }
        yyin = in;
    }

    yylex();
    print_symbol_tables();

    if (yyin && yyin != stdin) {
        fclose(yyin);
    }
    return 0;
}
