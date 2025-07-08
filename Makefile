codegen: scanner.l parser.y
	flex scanner.l
	byacc -d parser.y
	gcc -o codegen lex.yy.c y.tab.c -lfl

	