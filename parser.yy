%require "3.2"
%language "c++"
%locations
%define api.value.type variant
%define api.token.constructor
%define parse.assert
%defines
%define parse.trace
%param { driver& drv }

%code requires {
	#include <string>
	#include <vector>
	#include "declarations.h"

	class driver;

	struct expression {
		std::string addr;
		VAR_TYPE type;
    };

    using pos = int;
    using addrlist = std::vector<pos>;

	struct boolexpr {
        addrlist falselist, truelist;
    };

	struct stmtaddrs {
		addrlist nextlist, breaklist;
	};

	struct caselist {
		std::vector<std::pair<int, std::string>> cases;
		addrlist nextlist, breaklist;
	};
}
%code {
    #include "driver.h"
	#include "assembly.h"
    static VAR_TYPE upcast(VAR_TYPE first, VAR_TYPE second);
	template<typename T, typename ...Args> static void mergelist(std::vector<T> &dst, std::vector<T> &&op1, Args&&... args);
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

%token BREAK   "break"
%token CASE    "case"
%token DEFAULT "default"
%token ELSE    "else"
%token FLOAT   "float"
%token IF      "if"
%token INPUT   "input"
%token INT     "int"
%token OUTPUT  "output"
%token SWITCH  "switch"
%token WHILE   "while"

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
%type <addrlist> while_stmt switch_stmt break_stmt
%type <stmtaddrs> stmt stmtlist stmt_block if_stmt
%type <caselist> caselist

%%
program : declarations stmt_block mark_pos {
			drv.gen("HALT");
			drv.backpatch($2.nextlist, $3);
		}

declarations : %empty |
			 declarations declaration;

declaration : idlist ":" type ";" {
				for (const std::string &id : $1) {
					if ( const auto& [iter, flag] = drv.symtable.emplace(std::move(id), $3); !flag) {
						std::cerr << @1 << ": symbol '" << iter->first << "' was already declared" << std::endl;
                    }
                }
			} | error ":" type ";" { std::cerr << @1 << ": Illegal identifier" << std::endl; }
			| idlist ":" error ";" { std::cerr << @1 << ": Illegal type declaration" << std::endl; }
			| error ";" { std::cerr << @1 << ": Illegal declaration" << std::endl; }

idlist : idlist "," ID { $$ = std::move($1); $$.push_back(std::move($3)); }
	   | ID            { $$.push_back(std::move($1)); }

type : "int" { $$ = VAR_TYPE::INT; }
	 | "float" { $$ = VAR_TYPE::FLOAT; }

stmt : assignment_stmt {}
	 | input_stmt {}
	 | output_stmt {}
	 | if_stmt { $$ = std::move($1); }
	 | while_stmt { $$.nextlist = std::move($1); }
	 | switch_stmt { $$.nextlist = std::move($1); }
	 | break_stmt { $$.breaklist = std::move($1); }
	 | stmt_block { $$ = std::move($1); }

assignment_stmt : ID "=" expression ";" {
				auto iter = drv.symtable.find($1);
				if (iter == drv.symtable.end()) {
					std::cerr << @1 << ": Unknown identifier " << $1 << std::endl;
					break;
				}
				auto type = iter->second;
				if (type == $3.type)
					drv.gen(opcodes::typed_ops(type).assign, $1, $3.addr);
				else if (type == VAR_TYPE::FLOAT) {
					auto tmp = drv.newtemp(VAR_TYPE::FLOAT);
					drv.gen("ITOR", tmp, $3.addr);
					drv.gen(opcodes::typed_ops(type).assign, $1, tmp);
				} else
					std::cerr << @$ << ": assigning float into int " << $1 << std::endl;
			 }

input_stmt : "input" "(" ID ")" ";" {
				auto iter = drv.symtable.find($3);
				if (iter == drv.symtable.end()) {
					std::cerr << @3 << ": Unknown identifier " << $3 << std::endl;
					break;
				}
				drv.gen(opcodes::typed_ops(iter->second).input, $3);
		   }

output_stmt : "output" "(" expression ")" ";" {
				 drv.gen(opcodes::typed_ops($3.type).output, $3.addr);
			}

if_stmt : "if" "(" boolexpr ")" mark_pos stmt mark_goto "else" mark_pos stmt {
			drv.backpatch($3.truelist, $5);
			drv.backpatch($3.falselist, $9);
			mergelist($$.nextlist, std::move($6.nextlist), std::move($10.nextlist));
			$$.nextlist.push_back($7);
			mergelist($$.breaklist, std::move($6.breaklist), std::move($10.breaklist));
		}

while_stmt : "while" mark_pos "(" boolexpr ")" mark_pos stmt {
				 drv.backpatch($7.nextlist, $2);
				 drv.backpatch($4.truelist, $6);
				 mergelist($$, std::move($4.falselist), std::move($7.breaklist)); // eat all breaks
				 drv.gen("JUMP", std::to_string($2));
			 }

switch_stmt : "switch" "(" expression ")" mark_goto "{" caselist "default" ":" mark_pos stmtlist mark_goto "}" {
				if ($3.type != VAR_TYPE::INT) {
					std::cerr << @3 << ": expression inside switch must be of int type" << std::endl;
					break;
				}
				mergelist($$, std::move($7.breaklist), std::move($7.nextlist), std::move($11.breaklist), std::move($11.nextlist));
				$$.push_back($12);
				drv.backpatch({$5}, drv.get_nextinst());

				auto inst = opcodes::typed_ops($3.type).nql;
				std::string tmp = drv.newtemp(VAR_TYPE::INT);
				for (const auto &[addr, value] : $7.cases) {
					drv.gen(inst, tmp, $3.addr, std::move(value));
					drv.gen("JMPZ", std::to_string(addr), tmp);
				}
				drv.gen("JUMP", std::to_string($10)); // default
			}

caselist : caselist "case" NUM_INT ":" mark_pos stmtlist {
				mergelist($$.breaklist, std::move($1.breaklist), std::move($6.breaklist));
				drv.backpatch($1.nextlist, $5);
				$$.nextlist = std::move($6.nextlist);
				$$.cases = std::move($1.cases);
				$$.cases.emplace_back($5, std::to_string($3));
		} | caselist "case" NUM_FLOAT ":" stmtlist {
				std::cerr << @3 << ": expression of case must be of int type" << std::endl;
		} | %empty { }

break_stmt : "break" ";" mark_goto { $$.push_back($3); }

stmt_block : "{" stmtlist "}" { $$ = std::move($2); }

stmtlist : stmtlist mark_pos stmt {
				drv.backpatch($1.nextlist, $2);
				$$.nextlist = std::move($3.nextlist);
				mergelist($$.breaklist, std::move($1.breaklist), std::move($3.breaklist));
		 } | %empty { }

boolexpr : boolexpr OR mark_pos boolterm {
				drv.backpatch($1.falselist, $3);
				$$.falselist = std::move($4.falselist);
				mergelist($$.truelist, std::move($1.truelist), std::move($4.truelist));
		} | boolterm { $$ = std::move($1); }

boolterm : boolterm AND mark_pos boolfactor {
				 drv.backpatch($1.truelist, $3);
				 $$.truelist = std::move($4.truelist);
				 mergelist($$.falselist, std::move($1.falselist), std::move($4.falselist));
		} | boolfactor { $$ = std::move($1); }

boolfactor : NOT "(" boolexpr ")" {
				$$.truelist = std::move($3.falselist);
				$$.falselist = std::move($3.truelist);
		   } | expression RELOP expression mark_pos {
				 auto type = upcast($1.type, $3.type);
				 auto inst_set = opcodes::typed_ops(type);
				 auto tmp = drv.newtemp(VAR_TYPE::INT);
				 auto [operand1, operand2] = drv.auto_upcast(drv.newtemp(VAR_TYPE::FLOAT), $1, $3);
				 switch ($2) {
					 case REL_OPS::EQ: drv.gen(inst_set.eql, tmp, operand1, operand2); break;
					 case REL_OPS::NE: drv.gen(inst_set.nql, tmp, operand1, operand2); break;
					 case REL_OPS::LT: drv.gen(inst_set.lss, tmp, operand1, operand2); break;
					 case REL_OPS::GT: drv.gen(inst_set.grt, tmp, operand1, operand2); break;
					 case REL_OPS::LE: drv.gen(inst_set.grt, tmp, operand2, operand1); break;
					 case REL_OPS::GE: drv.gen(inst_set.lss, tmp, operand2, operand1); break;
				 }
				 $$.falselist.push_back(drv.get_nextinst());
				 drv.gen("JMPZ", OPERAND_PLACEHOLDER, std::move(tmp));
				 $$.truelist.push_back(drv.get_nextinst());
				 drv.gen("JUMP", OPERAND_PLACEHOLDER);
		   }

expression : term { $$ = std::move($1); }
		| expression ADDOP term {
				$$.type = upcast($1.type, $3.type);
				$$.addr = drv.newtemp($$.type);
				const char *op = opcodes::typed_ops($$.type).get_op($2);
				auto [operand1, operand2] = drv.auto_upcast($$.addr, $1, $3);
				drv.gen(op, $$.addr, operand1, operand2);
		}

term : factor { $$ = std::move($1); }
	 | term MULOP factor {
			$$.type = upcast($1.type, $3.type);
			$$.addr = drv.newtemp($$.type);
			const char *op = opcodes::typed_ops($$.type).get_op($2);
			auto [operand1, operand2] = drv.auto_upcast($$.addr, $1, $3);
			drv.gen(op, $$.addr, operand1, operand2);
	 }

factor : "(" expression ")" { $$ = std::move($2); }
       | CAST "(" expression ")" {
            if ($1 == $3.type) {
				$$ = std::move($3);
            } else if ($1 == VAR_TYPE::INT && $3.type == VAR_TYPE::FLOAT) {
				$$.addr = drv.newtemp(VAR_TYPE::INT);
                $$.type = $1;
				drv.gen("RTOI", $$.addr, std::move($3.addr));
            } else if ($1 == VAR_TYPE::FLOAT && $3.type == VAR_TYPE::INT) {
				$$.addr = drv.newtemp(VAR_TYPE::FLOAT);
                $$.type = $1;
				drv.gen("ITOR", $$.addr, std::move($3.addr));
            }
	   } | ID {
			auto iter = drv.symtable.find($1);
			if (iter == drv.symtable.end()) {
				std::cerr << @1 << ": Unknown identifier " << $1 << std::endl;
				break;
			}
			$$.type = iter->second;
			$$.addr = std::move($1);
	   } | NUM_INT {
            $$.type = VAR_TYPE::INT;
			$$.addr = drv.newtemp(VAR_TYPE::INT);
			drv.gen("IASN", $$.addr, std::to_string($1));
	   } | NUM_FLOAT {
           $$.type = VAR_TYPE::FLOAT;
		   $$.addr = drv.newtemp(VAR_TYPE::FLOAT);
		   drv.gen("RASN", $$.addr, std::to_string($1));
	   }

mark_pos:  %empty { $$ = drv.get_nextinst(); }
mark_goto: %empty { $$ = drv.get_nextinst(); drv.gen("JUMP", OPERAND_PLACEHOLDER); }
%%
void yy::parser::error(const location_type& l, const std::string& m) {
    std::cerr << l << ": " << m << '\n';
}

static VAR_TYPE upcast(VAR_TYPE first, VAR_TYPE second) {
    if (first == VAR_TYPE::INT && second == VAR_TYPE::INT)
        return VAR_TYPE::INT;
    return VAR_TYPE::FLOAT;
}

template<typename T, typename ...Args>
static void mergelist(std::vector<T> &dst, std::vector<T> &&op1, Args&&... args) {
	dst = std::move(op1);
	(dst.insert(dst.end(), std::make_move_iterator(args.begin()), std::make_move_iterator(args.end())), ...);
}
