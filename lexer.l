%{
    #include <cstdlib>
    #include <string>
    #include "driver.h"
    #include "parser.hpp"
    #define YY_USER_ACTION loc.columns(yyleng); // Code run each time a pattern is matched.

    using yy::parser;
%}
%option noyywrap nounput noinput

%x COMMENT
%%
%{
    yy::location& loc = drv.location; // A handy shortcut to the location held by the driver.
    loc.step();
%}
[ \t\r]+    loc.step();
\n+         loc.lines(yyleng); loc.step();
<<EOF>>     return parser::make_YYEOF(loc);

"break"     return parser::make_BREAK(loc);
"case"      return parser::make_CASE(loc);
"default"   return parser::make_DEFAULT(loc);
"else"      return parser::make_ELSE(loc);
"float"     return parser::make_FLOAT(loc);
"if"        return parser::make_IF(loc);
"input"     return parser::make_INPUT(loc);
"int"       return parser::make_INT(loc);
"output"    return parser::make_OUTPUT(loc);
"switch"    return parser::make_SWITCH(loc);
"while"     return parser::make_WHILE(loc);

"("     return parser::make_LPAREN(loc);
")"     return parser::make_RPAREN(loc);
"{"     return parser::make_BEGIN(loc);
"}"     return parser::make_CLOSE(loc);
":"     return parser::make_COLON(loc);
","     return parser::make_COMMA(loc);
";"     return parser::make_ENDL(loc);
"="     return parser::make_ASSIGN(loc);

"=="    return parser::make_RELOP(REL_OPS::EQ, loc);
"!="    return parser::make_RELOP(REL_OPS::NE, loc);
"<"     return parser::make_RELOP(REL_OPS::LT, loc);
">"     return parser::make_RELOP(REL_OPS::GT, loc);
"<="    return parser::make_RELOP(REL_OPS::LE, loc);
">="    return parser::make_RELOP(REL_OPS::GE, loc);

"+"     return parser::make_ADDOP(ARITHMETIC_OPS::ADD, loc);
"-"     return parser::make_ADDOP(ARITHMETIC_OPS::SUB, loc);
"*"     return parser::make_MULOP(ARITHMETIC_OPS::MUL, loc);
"/"     return parser::make_MULOP(ARITHMETIC_OPS::DIV, loc);

"||"    return parser::make_OR(loc);
"&&"    return parser::make_AND(loc);
"!"     return parser::make_NOT(loc);

"static_cast<int>"      return parser::make_CAST(VAR_TYPE::INT, loc);
"static_cast<float>"    return parser::make_CAST(VAR_TYPE::FLOAT, loc);

[a-zA-Z][a-zA-Z0-9]*    return parser::make_ID(std::string{yytext, (size_t)yyleng}, loc);
[0-9]+                  return parser::make_NUM_INT(std::atoi(yytext), loc);
[0-9]+\.[0-9]*          return parser::make_NUM_FLOAT(std::atof(yytext), loc);

"/*"                BEGIN(COMMENT);
<COMMENT>"*/"       BEGIN(INITIAL);
<COMMENT>\n+        loc.lines(yyleng);
<COMMENT>[^*\n]*    ; /* eat up */
<COMMENT>.          ; /* eat up */
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
