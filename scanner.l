%{
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include "y.tab.h"

char* strip_whitespace(const char* input) {
    if (!input) return NULL;

    size_t len = strlen(input);
    char* result = (char*)malloc(len + 1);
    if (!result) return NULL;

    char* dst = result;
    for (const char* src = input; *src != '\0'; ++src) {
        if (!isspace((unsigned char)*src)) {
            *dst++ = *src;
        }
    }
    *dst = '\0';

    return result;
}

%}

%x COMMENT

type ((const)?[ \t]*(signed|unsigned)?[ \t]*(long[ \t]*long|long|short)?[ \t]*int)|((const)?[ \t]*(signed|unsigned)?[ \t]*(long[ \t]*long|long|short|char))|((const)?[ \t]*(signed|unsigned|float|double|void))|(const)

id [a-zA-Z_][a-zA-Z0-9_]*

int [0-9]+
float (([0-9]*\.[0-9]+)|([0-9]+\.[0-9]*))
ESCAPE_CHAR \\[abfnrtv\\'"?0]|\\[0-9][0-9]?[0-9]?|\\x[0-9A-Fa-f]+|\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]|\\U[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]
char \'([^\\']|{ESCAPE_CHAR})\'
string  \"([^\\"]|{ESCAPE_CHAR})*\"

%%

"//".* {
    
}
"/*" {
    BEGIN(COMMENT);
}
<COMMENT>"*/" {
    BEGIN(0);
}
<COMMENT>.|\n {
    
}

"#pragma"[ \t]*"source"[ \t]*"on" {
    
}
"#pragma"[ \t]*"source"[ \t]*"off" {
    
}
"#pragma"[ \t]*"token"[ \t]*"on" {
    
}
"#pragma"[ \t]*"token"[ \t]*"off" {
    
}

"HIGH" {
    return HIGH;
}

"LOW" {
    return LOW;
}

"return" {
    return RETURN;
}

"break" {
    return BREAK;
}

"continue" {
    return CONTINUE;
}

"for" {
    return FOR;
}

"while" {
    return WHILE;
}

"do" {
    return DO;
}

"switch" {
    return SWITCH;
}

"case" {
    return CASE;
}

"default" {
    return DEFAULT;
}

"if" {
    return IF;
}

"else" {
    return ELSE;
}

"++" {
    return INC;
}

"--" {
    return DEC;
}

"<<" {
    return LS;
}

">>" {
    return RS;
}

"<=" {
    return LE;
}

">=" {
    return GE;
}

"==" {
    return EQ;
}

"!=" {
    return NE;
}

"&&" {
    return AND;
}

"||" {
    return OR;
}

"NULL" {
    yylval.intVal = 0;
    return INT;
}

{type} {
    yylval.stringVal = strdup(strip_whitespace(yytext));
    return TYPE;
}

{id} {
    yylval.stringVal = strdup(yytext);
    return ID;
}

{int} {
    yylval.intVal = atoi(yytext);
    return INT;
}

{float} {
    yylval.floatVal = atof(yytext);
    return FLOAT;
}

{char} {
    yylval.stringVal = strdup(yytext);
    return CHAR;
}

{string} {
    yylval.stringVal = strdup(yytext);
    return STRING;
}

[ \t\r\n]+ ;

. {return yytext[0];}

%%
