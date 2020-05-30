cml: lex.yy.c y.tab.c
	gcc y.tab.c lex.yy.c -ly -ll -lm -o cml

lex.yy.c: y.tab.c cml.l
	lex cml.l

y.tab.c: cml.y
	yacc -d cml.y

clean: 
	rm -f lex.yy.c y.tab.c y.tab.h cml

