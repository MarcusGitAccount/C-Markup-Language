xml: lex.yy.c y.tab.c
	gcc y.tab.c lex.yy.c -ly -ll -lm -o xml

lex.yy.c: y.tab.c xml.l
	lex xml.l

y.tab.c: xml.y
	yacc -d xml.y

clean: 
	rm -f lex.yy.c y.tab.c y.tab.h xml

