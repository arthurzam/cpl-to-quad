%{
	#include <cerrno>
	#include <cstdlib>
	#include <string>
	#include "driver.h"
	#include "parser.hpp"
	#define YY_USER_ACTION  loc.columns (yyleng); // Code run each time a pattern is matched.
%}
%x COMMENT
%option noyywrap nounput noinput
 //%option batch never-interactive nounistd

%%
%{
	yy::location& loc = drv.location; // A handy shortcut to the location held by the driver.
	loc.step();
%}
[ \t\r]+	loc.step();
\n+			loc.lines(yyleng); loc.step();
<<EOF>>		return yy::parser::make_YYEOF(loc);

"break"		return yy::parser::make_BREAK(loc);
"case"		return yy::parser::make_CASE(loc);
"default"	return yy::parser::make_DEFAULT(loc);
"else"		return yy::parser::make_ELSE(loc);
"float"		return yy::parser::make_FLOAT(loc);
"if"		return yy::parser::make_IF(loc);
"input"		return yy::parser::make_INPUT(loc);
"int"		return yy::parser::make_INT(loc);
"output"	return yy::parser::make_OUTPUT(loc);
"switch"	return yy::parser::make_SWITCH(loc);
"while"		return yy::parser::make_WHILE(loc);

"("		return yy::parser::make_LPAREN(loc);
")"		return yy::parser::make_RPAREN(loc);
"{"		return yy::parser::make_BEGIN(loc);
"}"		return yy::parser::make_CLOSE(loc);
":"		return yy::parser::make_COLON(loc);
","		return yy::parser::make_COMMA(loc);
";"		return yy::parser::make_ENDL(loc);
"="		return yy::parser::make_ASSIGN(loc);

"=="	return yy::parser::make_RELOP(REL_OPS::EQ, loc);
"!="	return yy::parser::make_RELOP(REL_OPS::NE, loc);
"<"		return yy::parser::make_RELOP(REL_OPS::LT, loc);
">"		return yy::parser::make_RELOP(REL_OPS::GT, loc);
"<="	return yy::parser::make_RELOP(REL_OPS::LE, loc);
">="	return yy::parser::make_RELOP(REL_OPS::GE, loc);

"+"		return yy::parser::make_ADDOP(ARITHMETIC_OPS::ADD, loc);
"-"		return yy::parser::make_ADDOP(ARITHMETIC_OPS::SUB, loc);
"*"		return yy::parser::make_MULOP(ARITHMETIC_OPS::MUL, loc);
"/"		return yy::parser::make_MULOP(ARITHMETIC_OPS::DIV, loc);

"||"	return yy::parser::make_OR(loc);
"&&"	return yy::parser::make_AND(loc);
"!"		return yy::parser::make_NOT(loc);

"static_cast<int>"      return yy::parser::make_CAST(VAR_TYPE::INT, loc);
"static_cast<float>"	return yy::parser::make_CAST(VAR_TYPE::FLOAT, loc);

[a-zA-Z][a-zA-Z0-9]*	return yy::parser::make_ID(std::string{yytext, (size_t)yyleng}, loc);
[0-9]+                  return yy::parser::make_NUM_INT(std::atoi(yytext), loc);
[0-9]+\.[0-9]*          return yy::parser::make_NUM_FLOAT(std::atof(yytext), loc);

"/*"				BEGIN(COMMENT);
<COMMENT>"*/"		BEGIN(INITIAL);
<COMMENT>\n+		loc.lines(yyleng);
<COMMENT>[^*\n]*	; /* eat up */
<COMMENT>.			; /* eat up */
%%


void driver::scan_begin() {
	if (file.empty() || file == "-")
        yyin = stdin;
	else if (!(yyin = fopen(file.c_str (), "r"))) {
		std::cerr << "cannot open " << file << ": " << strerror(errno) << '\n';
		exit(EXIT_FAILURE);
    }
}

void driver::scan_end() {
	fclose(yyin);
}
