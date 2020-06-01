%{
#include <string.h>
#include "y.tab.h"
%}

%%

"<"             return LSTART;
"</"            return LEND;
"/>"            return REND;
">"             return RIGHT;
[a-zA-Z]+       {
                  yylval.str = strdup(yytext);
                  return NAME;
                }
"-"*[0-9]+          {
                  yylval.nbr = atoi(yytext);
                  return NBR;
                }
\"              return Q;
=               return EQ;
[ \t\n]         ;
.               return *yytext;
