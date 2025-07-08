%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

int yylex(void);

char* alloc_sprintf(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    int n = vsnprintf(NULL, 0, fmt, args);
    va_end(args);

    char* buf = (char*)malloc(n + 1);
    va_start(args, fmt);
    vsprintf(buf, fmt, args);
    va_end(args);
    return buf;
}

FILE* fp;

typedef struct {
    char name[20];
} Symbol;

Symbol Symbol_table[100];
int Symbol_count = 0;

int var_place(char* var_name){
    for (int i=0;i<Symbol_count;i++){
        if (strcmp(Symbol_table[i].name, var_name) == 0){
            return i;
        }
    }
    strcpy(Symbol_table[Symbol_count++].name, var_name);
    return Symbol_count-1;
}

int arr_place(char* arr_name, int arr_len){
    for (int i=0;i<Symbol_count;i++){
        if (strcmp(Symbol_table[i].name, arr_name) == 0){
            return i;
        }
    }
    strcpy(Symbol_table[Symbol_count++].name, arr_name);
    arr_name = alloc_sprintf("%s'", arr_name);
    for (int i=0;i<arr_len;i++){
        strcpy(Symbol_table[Symbol_count++].name, arr_name);
    }
    return Symbol_count-arr_len-1;
}

int arg_stack[10];
int arg_stack_it = 0;

int label_stack[10];
int label_stack_it = 0;
int label_count = -4;

void push_label(){
    label_stack[++label_stack_it] = label_count+=4;
}

void pop_label(){
    label_stack_it--;
}

int ifelse_label_count = 0;

char* str_replace(const char* str, const char* old_sub, const char* new_sub) {
    int old_len = strlen(old_sub);
    int new_len = strlen(new_sub);

    int count = 0;
    const char* tmp = str;
    while ((tmp = strstr(tmp, old_sub)) != NULL) {
        count++;
        tmp += old_len;
    }

    int new_str_len = strlen(str) + count * (new_len - old_len) + 1;
    char* result = malloc(new_str_len);
    if (!result) return NULL;

    const char* current = str;
    char* dest = result;

    while ((tmp = strstr(current, old_sub)) != NULL) {
        int len = tmp - current;
        memcpy(dest, current, len);
        dest += len;
        memcpy(dest, new_sub, new_len);
        dest += new_len;
        current = tmp + old_len;
    }

    strcpy(dest, current);

    return result;
}

%}

%union {
    int intVal;
    double floatVal;
    char* stringVal;
}

%token <intVal>INT HIGH LOW INC DEC LS RS LE GE EQ NE AND OR BREAK CONTINUE RETURN FOR WHILE DO SWITCH CASE DEFAULT IF ELSE
%token <floatVal>FLOAT
%token <stringVal>TYPE ID CHAR STRING

%type <stringVal> INIT 
EXPR_ EXPR_bracket EXPR_variable_subscriptop EXPR_variable EXPR_functionparams EXPR_functioncall EXPR_literal expr_assign EXPR_functioncall_pre EXPR_functioncall_post
expr_logic_or expr_logic_and  expr_bitor expr_bitxor expr_bitand expr_eq expr_rel expr_shift expr_add expr_mul expr_pre expr_post expr_atom

SD_ident_wo_init SD_ident SD_idents SD_

AD_array_content AD_array_content_list AD_array_wo_init AD_array AD_arrays AD_

FD_param FD_params FD_

STMT_switch_clause_stmts STMT_switch_clause STMT_switch_clauses STMT_comp_content STMT_

FDef_ FD_arg_head_pre FD_arg_head_post

%start INIT

%right '='
%right ASSIGN
%left LOGIC_OR
%left LOGIC_AND OR
%left BITWISE_OR AND
%left BITWISE_XOR '|'
%left BITWISE_AND '^'
%left EQ_NE '&'
%left LE_GE EQ NE
%left SHIFT LE GE '<' '>'
%left ADD_SUB LS RS
%left MUL_DIV '+' '-'
%right PRE_UNI '*' '/' '%'
%left INC DEC
%left POST_UNI
%nonassoc ELEMENT

%%

INIT:
      /*empty*/   {}
    | INIT SD_    {}
    | INIT AD_    {}
    | INIT FD_    {}
    | INIT FDef_  {fprintf(fp, "%s", $2); free($2); }

EXPR_bracket:
      '(' EXPR_ ')'                             {$$ = alloc_sprintf("%s", $2); free($2); }
EXPR_variable_subscriptop:
      '[' EXPR_ ']'                             {$$ = alloc_sprintf("%s", $2); free($2); }
    | EXPR_variable_subscriptop '[' EXPR_ ']'   {}
EXPR_variable:
      ID                                        {
          int varpos = var_place($1);
          $$ = alloc_sprintf("\tld\ts0,%d(tp)\n", (varpos+2)*8);
      }
    | ID EXPR_variable_subscriptop              {
          int arrpos = arr_place($1, 0);
          $$ = alloc_sprintf("%s\tld\ts1,%d(tp)\n", $2, (arrpos+2)*8);
          $$ = alloc_sprintf("%s\tadd\ts0,s0,s1\n", $$);
          $$ = alloc_sprintf("%s\tli\tt0,8\n", $$);
          $$ = alloc_sprintf("%s\tmul\ts0,s0,t0\n", $$);
          $$ = alloc_sprintf("%s\tadd\ts0,s0,tp\n", $$);
          $$ = alloc_sprintf("%s\tld\ts0,0(s0)\n", $$);
      }

EXPR_functionparams:
      EXPR_                                     {
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $1);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n", $$);
          $$ = alloc_sprintf("%s@\tld\ta%d,0(sp)\n", $$, arg_stack[arg_stack_it]++);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
      }
    | EXPR_functionparams ',' EXPR_             {
          char* A = strtok($1, "@");
          char* B = strtok(NULL, "@");

          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $3);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n%s", $$, A);
          $$ = alloc_sprintf("%s@%s\tld\ta%d,0(sp)\n", $$, B, arg_stack[arg_stack_it]++);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
      }
EXPR_functioncall_pre:
      ID '(' {
          $$ = alloc_sprintf("\tcall\t%s\n", $1);
          arg_stack_it++;
      }
EXPR_functioncall_post:
      EXPR_functionparams ')' {
          $$ = alloc_sprintf("%s", $1);
          arg_stack[arg_stack_it] = 0;
          arg_stack_it--;
      }
EXPR_functioncall:
      EXPR_functioncall_pre EXPR_functioncall_post {
          char* A = strtok($2, "@");
          char* B = strtok(NULL, "@");

          $$ = alloc_sprintf("%s%s%s", A, B, $1);
          $$ = alloc_sprintf("%s\tmv\ts0,a0\n", $$);
      }
    | ID '(' ')'                     {
          $$ = alloc_sprintf("\tcall\t%s\n", $1);
          $$ = alloc_sprintf("%s\tmv\ts0,a0\n", $$);
      }

EXPR_literal:
      INT                                       {
          $$ = alloc_sprintf("\tli\ts0,%d\n", $1);
      }
    | HIGH                                       {
          $$ = alloc_sprintf("\tli\ts0,1\n");
      }
    | LOW                                       {
          $$ = alloc_sprintf("\tli\ts0,0\n");
      }
    | FLOAT                                     {}
    | CHAR                                      {}
    | STRING                                    {}

EXPR_: expr_assign {$$ = alloc_sprintf("%s", $1);}
expr_assign:
      ID '=' expr_assign   %prec ASSIGN {
          int varpos = var_place($1);
          $$ = alloc_sprintf("%s\tsd\ts0,%d(tp)\n", $3, (varpos+2)*8);
      }
    | ID EXPR_variable_subscriptop '=' expr_assign   %prec ASSIGN {
          int arrpos = arr_place($1, 0);
          $$ = alloc_sprintf("%s\tld\ts1,%d(tp)\n", $2, (arrpos+2)*8);
          $$ = alloc_sprintf("%s\tadd\ts0,s0,s1\n", $$);
          $$ = alloc_sprintf("%s\tli\tt0,8\n", $$);
          $$ = alloc_sprintf("%s\tmul\ts0,s0,t0\n", $$);
          $$ = alloc_sprintf("%s\tadd\ts0,s0,tp\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n", $$);
          $$ = alloc_sprintf("%s%s", $$, $4);
          $$ = alloc_sprintf("%s\tld\ts1,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(s1)\n", $$);
      }
    | '*' expr_pre '=' expr_assign   %prec ASSIGN {
          $$ = alloc_sprintf("%s\tli\tt0,8\n", $2);
          $$ = alloc_sprintf("%s\tmul\ts0,s0,t0\n", $$);
          $$ = alloc_sprintf("%s\tadd\ts0,s0,tp\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n", $$);
          $$ = alloc_sprintf("%s%s", $$, $4);
          $$ = alloc_sprintf("%s\tld\ts1,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(s1)\n", $$);
      }
    | expr_logic_or                   %prec ASSIGN {$$ = alloc_sprintf("%s", $1);}

expr_logic_or:
      expr_logic_or OR expr_logic_and %prec LOGIC_OR {}
    | expr_logic_and                  %prec LOGIC_OR {$$ = alloc_sprintf("%s", $1);}

expr_logic_and:
      expr_logic_and AND expr_bitor   %prec LOGIC_AND {}
    | expr_bitor                      %prec LOGIC_AND {$$ = alloc_sprintf("%s", $1);}

expr_bitor:
      expr_bitor '|' expr_bitxor      %prec BITWISE_OR {}
    | expr_bitxor                     %prec BITWISE_OR {$$ = alloc_sprintf("%s", $1);}

expr_bitxor:
      expr_bitxor '^' expr_bitand     %prec BITWISE_XOR {}
    | expr_bitand                     %prec BITWISE_XOR {$$ = alloc_sprintf("%s", $1);}

expr_bitand:
      expr_bitand '&' expr_eq         %prec BITWISE_AND {}
    | expr_eq                         %prec BITWISE_AND {$$ = alloc_sprintf("%s", $1);}

expr_eq:
      expr_eq EQ expr_rel             %prec EQ_NE {
          $$ = alloc_sprintf("%s", $3);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n", $$);
          $$ = alloc_sprintf("%s%s", $$, $1);
          $$ = alloc_sprintf("%s\tld\ts1,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
          $$ = alloc_sprintf("%s\txor\ts0,s0,s1\n", $$);
          $$ = alloc_sprintf("%s\tsltiu\ts0,s0,1\n", $$);
      }
    | expr_eq NE expr_rel             %prec EQ_NE {
          $$ = alloc_sprintf("%s", $3);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n", $$);
          $$ = alloc_sprintf("%s%s", $$, $1);
          $$ = alloc_sprintf("%s\tld\ts1,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
          $$ = alloc_sprintf("%s\txor\ts0,s0,s1\n", $$);
          $$ = alloc_sprintf("%s\tsltu\ts0,x0,s0\n", $$);
      }
    | expr_rel                        %prec EQ_NE {$$ = alloc_sprintf("%s", $1);}

expr_rel:
      expr_rel '>' expr_shift         %prec LE_GE {
          $$ = alloc_sprintf("%s", $3);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n", $$);
          $$ = alloc_sprintf("%s%s", $$, $1);
          $$ = alloc_sprintf("%s\tld\ts1,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
          $$ = alloc_sprintf("%s\tslt\ts0,s1,s0\n", $$);
      }
    | expr_rel '<' expr_shift         %prec LE_GE {
          $$ = alloc_sprintf("%s", $3);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n", $$);
          $$ = alloc_sprintf("%s%s", $$, $1);
          $$ = alloc_sprintf("%s\tld\ts1,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
          $$ = alloc_sprintf("%s\tslt\ts0,s0,s1\n", $$);
      }
    | expr_rel GE expr_shift          %prec LE_GE {
          $$ = alloc_sprintf("%s", $3);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n", $$);
          $$ = alloc_sprintf("%s%s", $$, $1);
          $$ = alloc_sprintf("%s\tld\ts1,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
          $$ = alloc_sprintf("%s\tslt\ts0,s0,s1\n", $$);
          $$ = alloc_sprintf("%s\tsltiu\ts0,s0,1\n", $$);
      }
    | expr_rel LE expr_shift          %prec LE_GE {
          $$ = alloc_sprintf("%s", $3);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n", $$);
          $$ = alloc_sprintf("%s%s", $$, $1);
          $$ = alloc_sprintf("%s\tld\ts1,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
          $$ = alloc_sprintf("%s\tsll\ts0,s1,s0\n", $$);
          $$ = alloc_sprintf("%s\tsltiu\ts0,s0,1\n", $$);
      }
    | expr_shift                      %prec LE_GE {$$ = alloc_sprintf("%s", $1);}

expr_shift:
      expr_shift LS expr_add          %prec SHIFT {
          $$ = alloc_sprintf("%s", $3);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n", $$);
          $$ = alloc_sprintf("%s%s", $$, $1);
          $$ = alloc_sprintf("%s\tld\ts1,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
          $$ = alloc_sprintf("%s\tsll\ts0,s0,s1\n", $$);
      }
    | expr_shift RS expr_add          %prec SHIFT {
          $$ = alloc_sprintf("%s", $3);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n", $$);
          $$ = alloc_sprintf("%s%s", $$, $1);
          $$ = alloc_sprintf("%s\tld\ts1,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
          $$ = alloc_sprintf("%s\tsra\ts0,s0,s1\n", $$);
      }
    | expr_add                        %prec SHIFT {$$ = alloc_sprintf("%s", $1);}

expr_add:
      expr_add '+' expr_mul           %prec ADD_SUB {
          $$ = alloc_sprintf("%s", $3);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n", $$);
          $$ = alloc_sprintf("%s%s", $$, $1);
          $$ = alloc_sprintf("%s\tld\ts1,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
          $$ = alloc_sprintf("%s\tadd\ts0,s0,s1\n", $$);
      }
    | expr_add '-' expr_mul           %prec ADD_SUB {
          $$ = alloc_sprintf("%s", $3);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n", $$);
          $$ = alloc_sprintf("%s%s", $$, $1);
          $$ = alloc_sprintf("%s\tld\ts1,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
          $$ = alloc_sprintf("%s\tsub\ts0,s0,s1\n", $$);
      }
    | expr_mul                        %prec ADD_SUB {$$ = alloc_sprintf("%s", $1);}

expr_mul:
      expr_mul '*' expr_pre           %prec MUL_DIV {
          $$ = alloc_sprintf("%s", $3);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n", $$);
          $$ = alloc_sprintf("%s%s", $$, $1);
          $$ = alloc_sprintf("%s\tld\ts1,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
          $$ = alloc_sprintf("%s\tmul\ts0,s0,s1\n", $$);
      }
    | expr_mul '/' expr_pre           %prec MUL_DIV {
          $$ = alloc_sprintf("%s", $3);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n", $$);
          $$ = alloc_sprintf("%s%s", $$, $1);
          $$ = alloc_sprintf("%s\tld\ts1,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
          $$ = alloc_sprintf("%s\tdiv\ts0,s0,s1\n", $$);
      }
    | expr_mul '%' expr_pre           %prec MUL_DIV {
          $$ = alloc_sprintf("%s", $3);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-8\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,0(sp)\n", $$);
          $$ = alloc_sprintf("%s%s", $$, $1);
          $$ = alloc_sprintf("%s\tld\ts1,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,8\n", $$);
          $$ = alloc_sprintf("%s\trem\ts0,s0,s1\n", $$);
      }
    | expr_pre                        %prec MUL_DIV {$$ = alloc_sprintf("%s", $1);}

expr_pre:
      INC ID                    %prec PRE_UNI {
          int varpos = var_place($2);
          $$ = alloc_sprintf("\tld\ts0,%d(tp)\n", (varpos+2)*8);
          $$ = alloc_sprintf("%s\taddi\ts0,s0,1\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,%d(tp)\n", $$, (varpos+2)*8);
      }
    | DEC ID                    %prec PRE_UNI {
          int varpos = var_place($2);
          $$ = alloc_sprintf("\tld\ts0,%d(tp)\n", (varpos+2)*8);
          $$ = alloc_sprintf("%s\taddi\ts0,s0,-1\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,%d(tp)\n", $$, (varpos+2)*8);
      }
    | '+' expr_pre                    %prec PRE_UNI {
          $$ = alloc_sprintf("%s", $2);
      }
    | '-' expr_pre                    %prec PRE_UNI {
          $$ = alloc_sprintf("%s\tsub\ts0,x0,s0\n", $2);
      }
    | '!' expr_pre                    %prec PRE_UNI {
          $$ = alloc_sprintf("%s\tsltiu\ts0,s0,1\n", $2);
      }
    | '~' expr_pre                    %prec PRE_UNI {
          $$ = alloc_sprintf("%s\tli\tt0,-1\n", $2);
          $$ = alloc_sprintf("%s\txor\ts0,s0,t0\n", $$);
      }
    | '*' expr_pre                    %prec PRE_UNI {
          $$ = alloc_sprintf("%s\tli\tt0,8\n", $2);
          $$ = alloc_sprintf("%s\tmul\ts0,s0,t0\n", $$);
          $$ = alloc_sprintf("%s\tadd\ts0,s0,tp\n", $$);
          $$ = alloc_sprintf("%s\tld\ts0,0(s0)\n", $$);
      }
    | '&' ID                    %prec PRE_UNI {
          int varpos = var_place($2);
          $$ = alloc_sprintf("\tli\ts0,%d\n", varpos+2);
      }
    | '(' TYPE ')' expr_pre           %prec PRE_UNI {}
    | '(' TYPE '*' ')' expr_pre       %prec PRE_UNI {}
    | expr_post                       %prec PRE_UNI {$$ = alloc_sprintf("%s", $1);}

expr_post:
      ID INC                   %prec POST_UNI {
          int varpos = var_place($1);
          $$ = alloc_sprintf("\tld\ts0,%d(tp)\n", (varpos+2)*8);
          $$ = alloc_sprintf("%s\taddi\ts0,s0,1\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,%d(tp)\n", $$, (varpos+2)*8);
          $$ = alloc_sprintf("%s\taddi\ts0,s0,-1\n", $$);
      }
    | ID DEC                   %prec POST_UNI {
          int varpos = var_place($1);
          $$ = alloc_sprintf("\tld\ts0,%d(tp)\n", (varpos+2)*8);
          $$ = alloc_sprintf("%s\taddi\ts0,s0,-1\n", $$);
          $$ = alloc_sprintf("%s\tsd\ts0,%d(tp)\n", $$, (varpos+2)*8);
          $$ = alloc_sprintf("%s\taddi\ts0,s0,1\n", $$);
      }
    | expr_atom                       %prec POST_UNI {$$ = alloc_sprintf("%s", $1);}

expr_atom:
      EXPR_variable                   %prec ELEMENT  {$$ = alloc_sprintf("%s", $1);}
    | EXPR_bracket                    %prec ELEMENT  {$$ = alloc_sprintf("%s", $1);}
    | EXPR_functioncall               %prec ELEMENT  {$$ = alloc_sprintf("%s", $1);}
    | EXPR_literal                    %prec ELEMENT  {$$ = alloc_sprintf("%s", $1);}

STMT_switch_clause_stmts:
      /*empty*/                                                                 {}
    | STMT_switch_clause_stmts STMT_                                            {}
STMT_switch_clause:
      CASE EXPR_ ':' STMT_switch_clause_stmts                                   {}
    | DEFAULT ':' STMT_switch_clause_stmts                                      {}
STMT_switch_clauses:
      /*empty*/                                                                 {}
    | STMT_switch_clauses STMT_switch_clause                                    {}
STMT_comp_content:
      /*empty*/                                                                 {$$ = alloc_sprintf("");}
    | STMT_comp_content STMT_                                                   {$$ = alloc_sprintf("%s%s", $1, $2);}
    | STMT_comp_content SD_                                                     {$$ = alloc_sprintf("%s%s", $1, $2);}
    | STMT_comp_content AD_                                                     {$$ = alloc_sprintf("%s%s", $1, $2);}
STMT_WHILE_start: WHILE   {push_label();}
STMT_DO_start: DO         {push_label();}
STMT_FOR_start: FOR       {push_label();}
STMT_:
      EXPR_ ';'                                                                         {$$ = alloc_sprintf("%s", $1);}
    | IF '(' EXPR_ ')' '{' STMT_comp_content '}'                                        {
          $$ = alloc_sprintf("%s\tbeq\ts0,x0,.LL%d\n", $3, ifelse_label_count);
          $$ = alloc_sprintf("%s%s", $$, $6);
          $$ = alloc_sprintf("%s.LL%d:\n", $$, ifelse_label_count);
          ifelse_label_count+=2;
      }
    | IF '(' EXPR_ ')' '{' STMT_comp_content '}' ELSE '{' STMT_comp_content '}'         {
          $$ = alloc_sprintf("%s\tbeq\ts0,x0,.LL%d\n", $3, ifelse_label_count);
          $$ = alloc_sprintf("%s%s", $$, $6);
          $$ = alloc_sprintf("%s\tj\t.LL%d\n", $$, ifelse_label_count+1);
          $$ = alloc_sprintf("%s.LL%d:\n", $$, ifelse_label_count);
          $$ = alloc_sprintf("%s%s", $$, $10);
          $$ = alloc_sprintf("%s.LL%d:\n", $$, ifelse_label_count+1);
          ifelse_label_count+=2;
      }
    | SWITCH '(' EXPR_ ')' '{' STMT_switch_clauses '}'                                  {}
    | STMT_WHILE_start '(' EXPR_ ')' STMT_                                                         {
          $$ = alloc_sprintf("\tj\t.L%d\n", label_stack[label_stack_it]+2);
          $$ = alloc_sprintf("%s.L%d:\n", $$, label_stack[label_stack_it]);
          $$ = alloc_sprintf("%s%s", $$, $5);
          $$ = alloc_sprintf("%s.L%d:\n", $$, label_stack[label_stack_it]+1);
          $$ = alloc_sprintf("%s.L%d:\n", $$, label_stack[label_stack_it]+2);
          $$ = alloc_sprintf("%s%s", $$, $3);
          $$ = alloc_sprintf("%s\tbne\ts0,x0,.L%d\n", $$, label_stack[label_stack_it]);
          $$ = alloc_sprintf("%s.L%d:\n", $$, label_stack[label_stack_it]+3);
          pop_label();
      }
    | STMT_DO_start STMT_ WHILE '(' EXPR_ ')' ';'                                                  {
          $$ = alloc_sprintf(".L%d:\n", label_stack[label_stack_it]);
          $$ = alloc_sprintf("%s%s", $$, $2);
          $$ = alloc_sprintf("%s.L%d:\n", $$, label_stack[label_stack_it]+1);
          $$ = alloc_sprintf("%s.L%d:\n", $$, label_stack[label_stack_it]+2);
          $$ = alloc_sprintf("%s%s", $$, $5);
          $$ = alloc_sprintf("%s\tbne\ts0,x0,.L%d\n", $$, label_stack[label_stack_it]);
          $$ = alloc_sprintf("%s.L%d:\n", $$, label_stack[label_stack_it]+3);
          pop_label();
      }
    | STMT_FOR_start '(' EXPR_ ';' EXPR_ ';' EXPR_ ')' STMT_                                       {
          $$ = alloc_sprintf("%s\tj\t.L%d\n", $3, label_stack[label_stack_it]+2);
          $$ = alloc_sprintf("%s.L%d:\n", $$, label_stack[label_stack_it]);
          $$ = alloc_sprintf("%s%s", $$, $9);
          $$ = alloc_sprintf("%s.L%d:\n", $$, label_stack[label_stack_it]+1);
          $$ = alloc_sprintf("%s%s", $$, $7);
          $$ = alloc_sprintf("%s.L%d:\n", $$, label_stack[label_stack_it]+2);
          $$ = alloc_sprintf("%s%s", $$, $5);
          $$ = alloc_sprintf("%s\tbne\ts0,x0,.L%d\n", $$, label_stack[label_stack_it]);
          $$ = alloc_sprintf("%s.L%d:\n", $$, label_stack[label_stack_it]+3);
          pop_label();
      }
    | '{' STMT_comp_content '}'                                                         {$$ = alloc_sprintf("%s", $2);}
    | BREAK ';'                                                                         {
          $$ = alloc_sprintf("\tj\t.L%d\n", label_stack[label_stack_it]+3);
      }
    | CONTINUE ';'                                                                      {
          $$ = alloc_sprintf("\tj\t.L%d\n", label_stack[label_stack_it]+1);
      }
    | RETURN ';'                                                                        {
          $$ = alloc_sprintf("RETURN\n");
      }
    | RETURN EXPR_ ';'                                                                  {
          $$ = alloc_sprintf("%s\tmv\ta0,s0\n", $2);
          $$ = alloc_sprintf("%sRETURN\n", $$);
      }

SD_ident_wo_init:
      ID                              {$$ = alloc_sprintf("%s", $1); free($1); }
    | '*' ID                          {$$ = alloc_sprintf("%s", $2); free($2); }
SD_ident:
      SD_ident_wo_init                {
          $$ = alloc_sprintf("\tsd\tx0,%d(tp)\n", (var_place($1)+2)*8);
      }
    | SD_ident_wo_init '=' EXPR_      {
          $$ = alloc_sprintf("%s\tsd\ts0,%d(tp)\n", $3, (var_place($1)+2)*8);
      }
SD_idents:
      SD_ident                        {$$ = alloc_sprintf("%s", $1); free($1); }
    | SD_idents ',' SD_ident          {$$ = alloc_sprintf("%s%s", $1, $3); free($1); free($3); }
SD_: TYPE SD_idents ';'               {$$ = alloc_sprintf("%s", $2); free($2); }

AD_array_content:
      '{' EXPR_functionparams '}'                 {}
    | '{' AD_array_content_list '}'               {}
AD_array_content_list:
      AD_array_content                            {}
    | AD_array_content_list ',' AD_array_content  {}
AD_array_wo_init:
      ID '[' INT ']'                {
          int arr_len = $3;
          int arrpos = arr_place($1, arr_len);
          $$ = alloc_sprintf("\tli\ts0,%d\n", arrpos+1+2);
          $$ = alloc_sprintf("%s\tsd\ts0,%d(tp)\n", $$, (arrpos+2)*8);
      }
AD_array:
      AD_array_wo_init                            {$$ = alloc_sprintf("%s", $1);}
    | AD_array_wo_init '=' AD_array_content       {}
AD_arrays:
      AD_array                                    {$$ = alloc_sprintf("%s", $1);}
    | AD_arrays ',' AD_array                      {$$ = alloc_sprintf("%s%s", $1, $3);}
AD_: TYPE AD_arrays ';'                           {$$ = alloc_sprintf("%s", $2);}

FD_param:
      TYPE ID                                     {
          $$ = alloc_sprintf("\tsd\ta%d,%d(tp)\n", arg_stack[arg_stack_it]++, (var_place($2)+2)*8);
      }
    | TYPE '*' ID                                 {
          $$ = alloc_sprintf("\tld\tt0,8(tp)\n");
          $$ = alloc_sprintf("%s\tsub\tt0,t0,tp\n", $$);
          $$ = alloc_sprintf("%s\tli\tt1,8\n", $$);
          $$ = alloc_sprintf("%s\tdiv\tt0,t0,t1\n", $$);
          $$ = alloc_sprintf("%s\tadd\ta%d,a%d,t0\n", $$, arg_stack[arg_stack_it], arg_stack[arg_stack_it]);
          $$ = alloc_sprintf("%s\tsd\ta%d,%d(tp)\n", $$, arg_stack[arg_stack_it]++, (var_place($3)+2)*8);
      }
FD_params:
      FD_param                                    {$$ = alloc_sprintf("%s", $1); free($1); }
    | FD_params ',' FD_param                      {
          $$ = alloc_sprintf("%s%s", $1, $3);
      }
FD_arg_head_pre:
      TYPE ID '('                          {
          $$ = alloc_sprintf("%s", $2);
          arg_stack_it++;
      }
FD_arg_head_post: 
      FD_params ')'            {
          $$ = alloc_sprintf("%s", $1);
          arg_stack[arg_stack_it] = 0;
          arg_stack_it--;
      }
FD_:
      FD_arg_head_pre FD_arg_head_post ';'        {Symbol_count = 0;}
    | TYPE '*' ID '(' FD_params ')' ';'           {Symbol_count = 0;}
    | TYPE ID '(' ')' ';'                         {Symbol_count = 0;}
    | TYPE '*' ID '(' ')' ';'                     {Symbol_count = 0;}

FDef_:
      FD_arg_head_pre FD_arg_head_post '{' STMT_comp_content '}'     {
          $$ = alloc_sprintf("%s:\n", $1);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-%d\n", $$, 8*(Symbol_count+2));
          $$ = alloc_sprintf("%s\tsd\tra,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\tsd\ttp,8(sp)\n", $$);
          $$ = alloc_sprintf("%s\tmv\ttp,sp\n", $$);

          $$ = alloc_sprintf("%s%s", $$, $2);
          $$ = alloc_sprintf("%s%s", $$, $4);
          
          char* ret_stmt = alloc_sprintf("\tmv\tsp,tp\n");
          ret_stmt = alloc_sprintf("%s\tld\ttp,8(sp)\n", ret_stmt);
          ret_stmt = alloc_sprintf("%s\tld\tra,0(sp)\n", ret_stmt);
          ret_stmt = alloc_sprintf("%s\taddi\tsp,sp,%d\n", ret_stmt, 8*(Symbol_count+2));
          ret_stmt = alloc_sprintf("%s\tjr\tra\n", ret_stmt);

          $$ = str_replace($$, "RETURN\n", ret_stmt);

          $$ = alloc_sprintf("%s%s", $$, ret_stmt);

          Symbol_count = 0;
      }
    | TYPE '*' ID '(' FD_params ')' '{' STMT_comp_content '}' {}
    | TYPE ID '(' ')' '{' STMT_comp_content '}'               {
          $$ = alloc_sprintf("%s:\n", $2);
          $$ = alloc_sprintf("%s\taddi\tsp,sp,-%d\n", $$, 8*(Symbol_count+2));
          $$ = alloc_sprintf("%s\tsd\tra,0(sp)\n", $$);
          $$ = alloc_sprintf("%s\tsd\ttp,8(sp)\n", $$);
          $$ = alloc_sprintf("%s\tmv\ttp,sp\n", $$);

          $$ = alloc_sprintf("%s%s", $$, $6);

          char* ret_stmt = alloc_sprintf("\tmv\tsp,tp\n");
          ret_stmt = alloc_sprintf("%s\tld\ttp,8(sp)\n", ret_stmt);
          ret_stmt = alloc_sprintf("%s\tld\tra,0(sp)\n", ret_stmt);
          ret_stmt = alloc_sprintf("%s\taddi\tsp,sp,%d\n", ret_stmt, 8*(Symbol_count+2));
          ret_stmt = alloc_sprintf("%s\tjr\tra\n", ret_stmt);

          $$ = str_replace($$, "RETURN\n", ret_stmt);

          $$ = alloc_sprintf("%s%s", $$, ret_stmt);
          
          Symbol_count = 0;
      }
    | TYPE '*' ID '(' ')' '{' STMT_comp_content '}'           {}
    
%%
int main() {
    fp = fopen("codegen.S", "w");
    fprintf(fp, "\t.globl codegen\n");
    yyparse();
    fclose(fp);
    return 0;
}

int yyerror(const char *s) {
    fprintf(stderr, "%s\n", s);
    return 0;
}