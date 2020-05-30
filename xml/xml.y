%{
#include <stdio.h>  
#include <stdlib.h>  
#include <string.h>  
#include <assert.h>

#define STACK_SIZE 200

char *stack[STACK_SIZE];
int sp;

void yyerrork(char* msg);
char* top();
void pop(char* value);
void push(char *value);

%}

%union {
  char* str;
  int nbr;
  union value *val;
}

%token<nbr> NBR
%token<str> NAME
%token LSTART LEND RIGHT EQ REND Q

%start xml

%%

xml: xml tag
   | tag
   |
   ;

tag: start inner end
   | LSTART NAME attributes REND { push($2); pop($2); }
   ;

inner: tags
     | NAME   { printf("\tFound inner data %s\n", $1); }
     | NBR    { printf("\tFound inner data %d\n", $1); }
     |
     ;

tags: tag tags
    | tag
    ;

start: LSTART NAME attributes RIGHT  { push($2); }
     ;

end: LEND NAME RIGHT                 { pop($2); }
   ;

attributes: attribute attributes
          | attribute
          |
          ;

attribute: NAME EQ Q value Q { printf("\tFound attribute %s\n", $1); }
         ;

value: NBR  { printf("\tFound value %d\n", $1); }
     | NAME { printf("\tFound value %s\n", $1); }
     |      { printf("\tFound value \"\"\n"); }
     ;

%%

void yyerrork(char* msg) {
  printf("%s\n", msg);
}


char* top() {
  assert (sp > 0);
  return stack[sp - 1];
}

// @param value - closing xml tag => assert is identical
//                to the one on top of the stack
void pop(char *value) {
  assert (sp > 0);
  if (strcmp(stack[sp - 1], value) != 0) {
    yyerrork("Mismatched tags.");
    exit(1);
  }

  printf("Stack pop:  %s\n", value);
  sp -= 1;
}

void push(char *value) {
  assert (sp < STACK_SIZE);

  printf("Stack push: %s\n", value);
  stack[sp++] = value;
}

int main(void) {
  sp = 0;
  yyparse();

  if (sp > 0) {
    yyerrork("Invalid xml file. Not all tags are closed.");
    exit(1);
  }

  return 0;
}