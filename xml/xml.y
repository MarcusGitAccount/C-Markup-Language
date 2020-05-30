%{
#include <stdio.h>  
#include <stdlib.h>  
#include <string.h>  
#include <assert.h>

#define STACK_SIZE 200

typedef enum {false, true} bool_t;

typedef enum {TAG, ATTR, VALUE} nodetype_t;

typedef struct _node {
  char *name;
  int *nbr;
  nodetype_t type;
  struct _node *attributes;
  struct _node *siblings;
  struct _node *children;
} node_t;

char *stack[STACK_SIZE];
int sp;

void yyerror(char* msg);
char* top();
void pop(char* value);
void push(char *value);

node_t* create_node(char *name);
int* get_int(int n);
node_t* create_val_nbr(int nbr);
node_t* create_val_name(char* name);
void print_node(node_t *node, int indent);

%}

%union {
  char *str;
  int nbr;
  struct _node *node;
}

%token<nbr> NBR
%token<str> NAME
%type<node> tag tags inner start attributes attribute value
%token LSTART LEND RIGHT EQ REND Q

%start xml

%%

xml: xml tag { print_node($2, 0); }
   |
   ;

tag: start inner end             { $$ = $1; $$->children = $2; }
   | LSTART NAME attributes REND { push($2); pop($2); $$ = create_node($2); $$->attributes = $3; }
   ;

inner: tags   { $$ = $1; }
     | NAME   { $$ = create_val_name($1); }
     | NBR    { $$ = create_val_nbr($1);  }
     |        { $$ = NULL; }
     ;

tags: tag tags  { $1->siblings = $2; $$ = $1; }
    | tag       { $$ = $1; }
    ;

start: LSTART NAME attributes RIGHT  { push($2); $$ = create_node($2); $$->attributes = $3; }
     ;

end: LEND NAME RIGHT                 { pop($2); }
   ;

attributes: attribute attributes  { $$->siblings = $2; $$ = $1; }
          | attribute             { $$ = $1; }
          |                       { $$ = NULL; }
          ;

attribute: NAME EQ Q value Q { $$ = create_node($1); $$->children =  $4; }
         ;

value: NBR  { $$ = create_val_nbr($1); }
     | NAME { $$ = create_val_name($1); }
     |      { $$ = create_val_name(NULL); }
     ;

%%

void yyerror(char* msg) {
  printf("%s\n", msg);
}

// Preorder traversal
void print_node(node_t *node, int indent) {
  if (!node) {
    return;
  }

  for (int i = 0; i < indent; i++) {
    printf(" ");
  }

  if (node->name) {
    printf("%s", node->name);
  } else if (node->nbr) {
    printf("%d", *(node->nbr));
  }

  for (node_t* curr = node->attributes; curr; curr = curr->siblings) {
    printf(" %s=", curr->name);
    node_t* val = curr->children;
    if (val->name) {
      printf("%s\n", val->name);
    } else if (val->nbr) {
      printf("%d\n", *(val->nbr));
    } else {
      printf("");
    }
  }

  printf("\n");
  for (node_t* curr = node->children; curr; curr = curr->siblings) {
    print_node(curr, indent + 4);
  }
}

node_t* create_node(char *name) {
  node_t* node = (node_t*)malloc(sizeof(node_t));

  printf("[TREE] Creating node with name = %s\n", name);
  node->name = name;
  node->children = node->siblings = NULL;
  node->nbr = NULL;
  node->type = TAG;
  return node;
}

int* get_int(int n) {
  int* pointer = (int*)malloc(sizeof(int));

  *pointer = n;
  return pointer;
}

node_t* create_val_name(char* name) {
  node_t* node = create_node(name);

  node->type = VALUE;
  return node;
}

node_t* create_val_nbr(int nbr) {
  node_t* node = create_node(NULL);

  node->nbr = get_int(nbr);
  node->type = VALUE;
  return node;
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
    yyerror("Mismatched tags.");
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
    yyerror("Invalid xml file. Not all tags are closed.");
    exit(1);
  }

  return 0;
}