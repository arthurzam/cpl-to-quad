%require "3.2"
%language "c++"
%locations
%define api.value.type variant
%define api.token.constructor
%define parse.assert
%defines
%param { driver& drv }

%code requires {
    #include <map>
	#include <string>
	#include <vector>

    enum class REL_OPS {
        EQ = 0,
        NE,
        LT,
        GT,
        LE,
        GE,
    };

    enum class ARITHMETIC_OPS {
        ADD = 0,
        SUB,
        MUL,
        DIV
    };

    enum class VAR_TYPE {
        INT = 0,
        FLOAT
    };

    struct expression {
        std::string addr;
        VAR_TYPE type;
        bool isConst;
    };

    using pos = int;
    using addrlist = std::vector<pos>;

    struct boolexpr {
        using pos = int;
        addrlist falselist, truelist;
    };

    class driver;
}
%code {
    #include "driver.h"
	#include "assembly.h"
	static int yyerror(const char *);
    static VAR_TYPE upcast(VAR_TYPE first, VAR_TYPE second);
}
%define api.token.prefix {TOK_}

%start program
%token LPAREN  "("
%token RPAREN  ")"
%token COLON   ":"
%token BEGIN   "{"
%token CLOSE   "}"
%token ASSIGN  "="
%token COMMA   ","
%token ENDL    ";"

%token BREAK
%token CASE
%token DEFAULT
%token ELSE
%token FLOAT
%token IF
%token INPUT
%token INT
%token OUTPUT
%token SWITCH
%token WHILE

%token <REL_OPS> RELOP
%token <ARITHMETIC_OPS> ADDOP
%token <ARITHMETIC_OPS> MULOP
%token OR
%token AND
%token NOT
%token <VAR_TYPE> CAST

%token <std::string> ID
%token <int> NUM_INT
%token <float> NUM_FLOAT

%type <std::vector<std::string>> idlist
%type <VAR_TYPE> type
%type <expression> expression term factor
%type <boolexpr> boolexpr boolterm boolfactor
%type <int> mark_pos mark_goto
%type <addrlist> stmt stmtlist if_stmt while_stmt break_stmt stmt_block

%%
program : declarations stmt_block mark_pos {
			drv.gen("HALT");
			drv.backpatch($2, $3);
		}

declarations : /* empty */ |
			 declarations declaration;

declaration : idlist ":" type ";" {
				for (const std::string &id : $1) {
                    if (!drv.symtable.emplace(id, $3).second) {
                        std::cerr << @1 << ":" << "symbol '" << id << "' was already declared" << std::endl;
                    }
                }
			}

idlist : idlist "," ID { $$ = std::move($1); $$.push_back(std::move($3)); }
	   | ID            { $$.push_back(std::move($1)); }

type : INT { $$ = VAR_TYPE::INT; }
	 | FLOAT { $$ = VAR_TYPE::FLOAT; }

stmt : assignment_stmt {}
	 | input_stmt {}
	 | output_stmt {}
	 | if_stmt { $$ = std::move($1); }
	 | while_stmt { $$ = std::move($1); }
	 | switch_stmt {}
	 | break_stmt {}
	 | stmt_block { $$ = std::move($1); }

assignment_stmt : ID "=" expression ";" {
				auto type = drv.symtable[$1];
				if (type == $3.type)
					drv.gen(g_asm_instructions[(int)type].assign, $1, $3.addr);
				else if (type == VAR_TYPE::FLOAT) {
					auto tmp = drv.newtemp();
					drv.gen("ITOR", tmp, $3.addr);
					drv.gen(g_asm_instructions[(int)type].assign, $1, tmp);
				} else {
					std::cerr << @$ << ": assigning float into int " << $1 << std::endl;
				}
			 }

input_stmt : INPUT "(" ID ")" ";" {
				drv.gen(g_asm_instructions[(int)drv.symtable[$3]].input, $3);
		   }

output_stmt : OUTPUT "(" expression ")" ";" {
				 drv.gen(g_asm_instructions[(int)$3.type].output, $3.addr);
			}

if_stmt : IF "(" boolexpr ")" mark_pos stmt mark_goto ELSE mark_pos stmt {
			drv.backpatch($3.truelist, $5);
			drv.backpatch($3.falselist, $9);
			$$ = std::move($6);
			$$.insert($$.end(), $10.begin(), $10.end());
			$$.push_back($7);
		}

while_stmt : WHILE mark_pos "(" boolexpr ")" mark_pos stmt {
				 drv.backpatch($7, $2);
				 drv.backpatch($4.truelist, $6);
				 $$ = std::move($4.falselist);
				 drv.gen("JUMP", std::to_string($2));
			 }

switch_stmt : SWITCH "(" expression ")" "{" caselist DEFAULT ':' stmtlist "}"

caselist : caselist CASE NUM_INT ":" stmtlist
         | caselist CASE NUM_FLOAT ":" stmtlist
		 | /* empty */

break_stmt : BREAK ";" mark_goto {
				$$.push_back($3);
		   }

stmt_block : "{" stmtlist "}" { $$ = std::move($2); }

stmtlist : /* empty */ { }
		 | stmtlist mark_pos stmt {
				drv.backpatch($1, $2);
				$$ = std::move($3);
		 }

boolexpr : boolexpr OR mark_pos boolterm {
				drv.backpatch($1.falselist, $3);
				$$.truelist = std::move($1.truelist);
				$$.truelist.insert($$.truelist.end(), $4.truelist.begin(), $4.truelist.end());
				$$.falselist = std::move($4.falselist);
			 }
		 | boolterm { $$ = std::move($1); }

boolterm : boolterm AND mark_pos boolfactor{
				 drv.backpatch($1.truelist, $3);
				 $$.falselist = std::move($1.falselist);
				 $$.falselist.insert($$.falselist.end(), $4.falselist.begin(), $4.falselist.end());
				 $$.truelist = std::move($4.truelist);
			  }
		  | boolfactor { $$ = std::move($1); }

boolfactor : NOT "(" boolexpr ")" {
                $$.truelist = $3.falselist;
				$$.falselist = $3.truelist;
		   }
		   | expression RELOP expression mark_pos {
				 auto type = upcast($1.type, $3.type);
				 auto inst_set = g_asm_instructions[(int)type];
				 auto tmp = drv.newtemp();
				 switch ($2) {
					 case REL_OPS::EQ: drv.gen(inst_set.eql, tmp, $1.addr, $3.addr); break;
					 case REL_OPS::NE: drv.gen(inst_set.nql, tmp, $1.addr, $3.addr); break;
					 case REL_OPS::LT: drv.gen(inst_set.lss, tmp, $1.addr, $3.addr); break;
					 case REL_OPS::GT: drv.gen(inst_set.grt, tmp, $1.addr, $3.addr); break;
					 case REL_OPS::LE: drv.gen(inst_set.grt, tmp, $3.addr, $1.addr); break;
					 case REL_OPS::GE: drv.gen(inst_set.lss, tmp, $3.addr, $1.addr); break;
				 }
				 $$.falselist.push_back(drv.get_nextinst());
				 drv.gen("JMPZ", OPERAND_PLACEHOLDER, std::move(tmp));
				 $$.truelist.push_back(drv.get_nextinst());
				 drv.gen("JUMP", OPERAND_PLACEHOLDER);
		   }

expression : term { $$ = $1; }
    | expression ADDOP term {
            $$.type = upcast($1.type, $3.type);
            $$.addr = drv.newtemp();
            const char *op = ($2 == ARITHMETIC_OPS::ADD ? g_asm_instructions[(int)$$.type].add : g_asm_instructions[(int)$$.type].sub);
            if ($$.type != $1.type) {
				drv.gen("ITOR", $$.addr, $1.addr);
				drv.gen(op, $$.addr, $$.addr, $3.addr);
            } else if ($$.type != $3.type) {
				drv.gen("ITOR", $$.addr, $3.addr);
				drv.gen(op, $$.addr, $1.addr, $$.addr);
            } else {
				drv.gen(op, $$.addr, $1.addr, $3.addr);
            }
	}

term : factor { $$ = $1; }
    | term MULOP factor {
            $$.type = upcast($1.type, $3.type);
            $$.addr = drv.newtemp();
            const char *op = ($2 == ARITHMETIC_OPS::MUL ? g_asm_instructions[(int)$$.type].mul : g_asm_instructions[(int)$$.type].div);
			if ($$.type != $1.type) {
				drv.gen("ITOR", $$.addr, $1.addr);
				drv.gen(op, $$.addr, $$.addr, $3.addr);
			} else if ($$.type != $3.type) {
				drv.gen("ITOR", $$.addr, $3.addr);
				drv.gen(op, $$.addr, $1.addr, $$.addr);
			} else {
				drv.gen(op, $$.addr, $1.addr, $3.addr);
			}
	 }

factor : "(" expression ")" { $$ = $2; }
       | CAST "(" expression ")" {
            if ($1 == $3.type) {
                $$ = $3;
            } else if ($1 == VAR_TYPE::INT && $3.type == VAR_TYPE::FLOAT) {
                $$.addr = drv.newtemp();
                $$.type = $1;
				drv.gen("RTOI", $$.addr, $3.addr);
            } else if ($1 == VAR_TYPE::FLOAT && $3.type == VAR_TYPE::INT) {
                $$.addr = drv.newtemp();
                $$.type = $1;
				drv.gen("ITOR", $$.addr, $3.addr);
            }
       }
       | ID {
            $$.type = drv.symtable[$1];
            $$.addr = std::move($1);
       }
       | NUM_INT {
            $$.type = VAR_TYPE::INT;
            $$.addr = drv.newtemp();
			drv.gen("IASN", $$.addr, std::to_string($1));
       }
       | NUM_FLOAT {
           $$.type = VAR_TYPE::FLOAT;
           $$.addr = drv.newtemp();
		   drv.gen("RASN", $$.addr, std::to_string($1));
	   }
mark_pos: /* empty */ {
			$$ = drv.get_nextinst();
		}
mark_goto: /* empty */ {
			$$ = drv.get_nextinst();
			drv.gen("JUMP", OPERAND_PLACEHOLDER);
		}
%%
void yy::parser::error(const location_type& l, const std::string& m) {
    std::cerr << l << ": " << m << '\n';
}

static VAR_TYPE upcast(VAR_TYPE first, VAR_TYPE second) {
    if (first == VAR_TYPE::INT && second == VAR_TYPE::INT)
        return VAR_TYPE::INT;
    return VAR_TYPE::FLOAT;
}
