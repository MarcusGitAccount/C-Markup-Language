%{
#include <stdio.h>  
#include <stdlib.h>  
#include <string.h>  
#include <assert.h>

#define STACK_SIZE 200
// #define __LOGGING__ 1

#ifdef __LOGGING__
	#define log(f, ...) printf(f, ##__VA_ARGS__)
#else
	#define log(f, ...)
#endif

typedef enum {false, true} bool_t;

typedef enum {TAG, ATTR, VALUE} nodetype_t;

typedef enum {VECTOR, INTEGER} vartype_t;

typedef struct _vector {
  int rows, cols;
  int **data;
} vector_t;

typedef struct _node {
  char *name;
  int *nbr;
  nodetype_t type;
  struct _node *attributes;
  struct _node *siblings;
  struct _node *children;
} node_t;

typedef union _var {
  int integer;
  vector_t *vector;
} var_t;

typedef struct _var_container {
  var_t data;
  vartype_t type;
} var_container_t;

var_container_t variables[26];

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

void print_row(int* row, int len);

int length(node_t* node);

var_container_t make_integer_container(int integer);
var_container_t make_vector_container(vector_t* vector);

var_container_t eval_node(node_t* node);

var_container_t eval_vector(node_t *node, var_container_t* below);
var_container_t eval_integer(node_t *node, var_container_t* below);
var_container_t eval_print(node_t *node, var_container_t* below);
var_container_t eval_var(node_t *node, var_container_t* below);
var_container_t eval_assign(node_t *node, var_container_t* below);

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

xml: xml tag { print_node($2, 0); eval_node($2); }
   |
   ;

tag: start inner end             { $$ = $1; $$->children = $2; }
   | LSTART NAME attributes REND { 
                                    push($2); 
                                    pop($2); 
                                    $$ = create_node($2); 
                                    $$->attributes = $3; 
                                  }
   ;

inner: tags   { $$ = $1; }
     | NAME   { $$ = create_val_name($1); }
     | NBR    { $$ = create_val_nbr($1);  }
     |        { $$ = NULL; }
     ;

tags: tag tags  { $1->siblings = $2; $$ = $1; }
    | tag       { $$ = $1; }
    ;

start: LSTART NAME attributes RIGHT  { 
                                        push($2); 
                                        $$ = create_node($2); 
                                        $$->attributes = $3; 
                                     }
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
  printf("Syntax error: %s\n", msg);
}

int length(node_t* node) {
  int len = 0;

  for (node_t* curr = node; curr; curr = curr->siblings) {
    len += 1;
  }

  return len;
}

void print_row(int* row, int len) {
  printf("[");
  if (len > 1) {
    for (int i = 0; i < len - 1; i++) {
      printf("%d, ", row[i]);
    }
    printf("%d", row[len - 1]);
  }
  printf("]");
}

var_container_t make_integer_container(int integer) {
  var_container_t container;

  container.data.integer = integer;
  container.type = INTEGER;
  return container;
}

var_container_t make_vector_container(vector_t* vector) {
  var_container_t container;

  container.data.vector = vector;
  container.type = VECTOR;
  return container;
}

var_container_t eval_vector(node_t *node, var_container_t* below) {
  int len = length(node->children);
  vector_t *vector = (vector_t*)malloc(sizeof(vector_t));
  int **data = (int**)malloc(sizeof(int*) * len);
  int cols = -1;

  for (node_t* curr = node->children; curr; curr = curr->siblings) {
    if (strcmp(curr->name, "row") != 0) {
      free(data);
      free(vector);
      yyerror("Invalid tag name for vector definition");
      return make_vector_container(NULL);
    }
  }

  for (int i = 0; i < len; i++) {
    if (cols < 0) {
      cols = below[i].data.vector->cols;
    }
    else if (below[i].data.vector->cols != cols) {
      yyerror("All vector rows must have the same size");
      break;
    }

    data[i] = below[i].data.vector->data[0];

    free(below[i].data.vector->data);
    free(below[i].data.vector);
  }

  vector->rows = len;
  vector->cols = cols;
  vector->data = data;
  return make_vector_container(vector);
}

var_container_t eval_row(node_t *node, var_container_t* below) {
  vector_t *vector = (vector_t*)malloc(sizeof(vector_t));
  int **data = (int**)malloc(sizeof(int*));

  vector->rows = 1;
  vector->cols = length(node->children);
  data[0] = (int*)malloc(sizeof(int) * vector->cols);
  for (int i = 0; i < vector->cols; i++) {
    if (below[i].type != INTEGER) {
      yyerror("Invalid tag name for row definition");
      return make_vector_container(NULL);
    }
    data[0][i] = below[i].data.integer;
  }
  vector->data = data;
  return make_vector_container(vector);
}

var_container_t eval_integer(node_t *node, var_container_t* below) {
  if (!node->children->nbr) {
    yyerror("Invalid integer.");
    return make_integer_container(false);
  }

  return make_integer_container(*(node->children->nbr));
}

var_container_t eval_print(node_t *node, var_container_t* below) {
  int len = length(node->children);

  log("Print len: %d\n", len);
  if (len != 1) {
    yyerror("Print takes only one argument");
    return make_integer_container(false);
  }
  
  if (below[0].type == INTEGER) {
    log("Printing of type %d\n", below[0].type);
    printf("%d\n", below[0].data.integer);
  } 
  else if (below[0].type == VECTOR) {
    if (below[0].data.vector == NULL) {
      printf("[]\n");
    }
    else {
      printf("[");
      int rows = below[0].data.vector->rows;
      for (int i = 0; i < rows - 1; i++) {
        print_row(below[0].data.vector->data[i], below[0].data.vector->cols);
        printf(", ");
      }
      print_row(below[0].data.vector->data[rows - 1], below[0].data.vector->cols);
      printf("]\n");
    }
  }

  return make_integer_container(true);
}

var_container_t eval_var(node_t *node, var_container_t* below) {
  if (!node->children) {
    yyerror("No variable name specified.");
    return make_integer_container(false);
  }

  char *name = node->children->name;

  if (strlen(name) != 1) {
    yyerror("Variable name should consist of only one lowercase letter.");
    return make_integer_container(false);
  }

  if (name[0] < 'a' || name[0] > 'z') {
    yyerror("Variable name should consist of only one lowercase letter.");
    return make_integer_container(false);
  }
  
  int index = name[0] - 'a';

  log("RETRIEVING var of type %d\n", variables[index].type);
  return variables[index];
}

var_container_t eval_assign(node_t *node, var_container_t* below) {
  node_t *attr_to = NULL;

  for (node_t* curr = node->attributes; curr; curr = curr->siblings) {
    if (strcmp(curr->name, "to") == 0) {
      attr_to = curr;
      break;
    }
  }

  if (!attr_to) {
    yyerror("Missing attribute to for assignment node.");
    return make_integer_container(false);
  }

  char *name = attr_to->children->name;

  if (strlen(name) != 1) {
    yyerror("Variable name should consist of only one lowercase letter.");
    return make_integer_container(false);
  }
  if (name[0] < 'a' || name[0] > 'z') {
    yyerror("Variable name should consist of only one lowercase letter.");
    return make_integer_container(false);
  }
  if (length(node->children) != 1) {
    yyerror("Only one value can be assigned to a variable at once");
    return make_integer_container(false);
  }

  int index = name[0] - 'a';
  variables[index] = below[0];
  return variables[index];
}

var_container_t eval_node(node_t* node) {
  if (!node || !node->name) {
    return make_integer_container(false);
  }

  int len = length(node->children);
  var_container_t* below = (var_container_t*)malloc(len * sizeof(var_container_t));
  var_container_t result = make_integer_container(true);
  int index = 0;

  log("Eval %s\n", node->name);
  for (node_t* curr = node->children; curr; curr = curr->siblings) {
    var_container_t var = eval_node(curr);

    below[index++] = var;
  }

  if (strcmp(node->name, "integer") == 0) {
    result = eval_integer(node, below);
  }
  else if (strcmp(node->name, "var") == 0) {
    result = eval_var(node, below);
  }
  else if (strcmp(node->name, "print") == 0) {
    result = eval_print(node, below);
  }
  else if (strcmp(node->name, "row") == 0) {
    result = eval_row(node, below);
  }
  else if (strcmp(node->name, "vector") == 0) {
    result = eval_vector(node, below);
  }
  else if (strcmp(node->name, "assign") == 0) {
    result = eval_assign(node, below);
  }

  free(below);
  return result;
}

// Preorder traversal
void print_node(node_t *node, int indent) {
  if (!node) {
    return;
  }

  for (int i = 0; i < indent; i++) {
    log(" ");
  }

  if (node->name) {
    log("%s", node->name);
  } else if (node->nbr) {
    log("%d", *(node->nbr));
  }

  for (node_t* curr = node->attributes; curr; curr = curr->siblings) {
    log(" %s=", curr->name);
    node_t* val = curr->children;
    if (val->name) {
      log("%s\n", val->name);
    } else if (val->nbr) {
      log("%d\n", *(val->nbr));
    }
    // } else {
    //   log("");
    // }
  }

  log("\n");
  for (node_t* curr = node->children; curr; curr = curr->siblings) {
    print_node(curr, indent + 4);
  }
}

node_t* create_node(char *name) {
  node_t* node = (node_t*)malloc(sizeof(node_t));

  log("[TREE] Creating node with name = %s\n", name);
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

  log("Stack pop:  %s\n", value);
  sp -= 1;
}

void push(char *value) {
  assert (sp < STACK_SIZE);

  log("Stack push: %s\n", value);
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