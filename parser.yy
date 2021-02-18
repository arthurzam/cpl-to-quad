%require "3.2"
%language "c++"
%locations
%define api.value.type variant
%define api.token.constructor
%define parse.assert
%defines
%param { driver& drv }

%code requires {
	#include <string>
	#include <vector>
	#include <variant>
	#include "declarations.h"

	class driver;

	struct expression {
		std::variant<std::string, int, float> addr;
		VAR_TYPE type;

		bool is_const() const {
			return addr.index() != 0;
		}

		operator std::string() const {
			switch (addr.index()) {
				case 0: return std::get<std::string>(addr);
				case 1: return std::to_string(std::get<int>(addr));
				case 2:
				default: return std::to_string(std::get<float>(addr));
			}
		}

		template<int N> struct const_equals {
			bool operator()(int arg) const { return arg == N; }
			bool operator()(float arg) const { return arg == float(N); }
			bool operator()(const std::string &) { return false; }
		};
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
		std::vector<std::pair<int, int>> cases;
		addrlist nextlist, breaklist;
	};
}
%code {
	#include <functional>
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

%token OR      "||"
%token AND     "&&"
%token NOT     "!"

%token <REL_OPS> RELOP
%token <ARITHMETIC_OPS> ADDOP
%token <ARITHMETIC_OPS> MULOP
%token <VAR_TYPE> CAST

%token <std::string> ID
%token <int> NUM_INT
%token <float> NUM_FLOAT

%type <std::vector<std::string>> idlist
%type <VAR_TYPE> type
%type <expression> expression term factor
%type <boolexpr> boolexpr boolterm boolfactor
%type <addrlist> while_stmt switch_stmt break_stmt
%type <stmtaddrs> stmt stmtlist stmt_block if_stmt
%type <caselist> caselist
%type <int> mark_pos mark_goto

%%
program : declarations stmt_block mark_pos {
			drv.gen("HALT");
			drv.backpatch($2.nextlist, $3);
		}

declarations : %empty |
			 declarations declaration;

declaration : idlist ":" type ";" {
				for (const std::string &id : $1) {
					if (const auto& [iter, flag] = drv.symtable.emplace(std::move(id), $3); !flag) {
						drv.error(@1) << "symbol '" << iter->first << "' was already declared" << std::endl;
                    }
                }
			} | error ":" type ";" { drv.error(@1) << "Illegal identifier" << std::endl; }
			| idlist ":" error ";" { drv.error(@3) << "Illegal type declaration" << std::endl; }
			| error ";" { drv.error(@1) << "Illegal declaration" << std::endl; }

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
					drv.error(@1) << "Unknown identifier " << $1 << std::endl;
					break;
				}
				auto type = iter->second;
				if (type == $3.type)
					drv.gen(opcodes::typed_ops(type).assign, $1, $3);
				else if (type == VAR_TYPE::FLOAT) {
					if ($3.is_const())
						drv.gen(opcodes::typed_ops(type).assign, $1, $3);
					else
						drv.gen("ITOR", $1, $3);
				} else
					drv.error(@$) << "assigning float into int " << $1 << std::endl;
			 } | ID "=" error ";" { drv.error(@3) << "bad expression" << std::endl; }

input_stmt : "input" "(" ID ")" ";" {
				auto iter = drv.symtable.find($3);
				if (iter == drv.symtable.end())
					drv.error(@3) << "Unknown identifier " << $3 << std::endl;
				else
					drv.gen(opcodes::typed_ops(iter->second).input, $3);
		   } | "input" "(" error ")" ";" { drv.error(@3) << "bad identifier in input function" << std::endl; }

output_stmt : "output" "(" expression ")" ";" {
				 drv.gen(opcodes::typed_ops($3.type).output, $3);
			} | "output" "(" error ")" ";" { drv.error(@3) << "bad expression in output function" << std::endl; }

if_stmt : "if" "(" boolexpr ")" mark_pos stmt mark_goto "else" mark_pos stmt {
			drv.backpatch($3.truelist, $5);
			drv.backpatch($3.falselist, $9);
			mergelist($$.nextlist, std::move($6.nextlist), std::move($10.nextlist));
			$$.nextlist.push_back($7);
			mergelist($$.breaklist, std::move($6.breaklist), std::move($10.breaklist));
		} | "if" "(" error ")" stmt "else" stmt { drv.error(@3) << "bad expression inside if" << std::endl; }

while_stmt : "while" mark_pos "(" boolexpr ")" mark_pos stmt {
				 drv.backpatch($7.nextlist, $2);
				 drv.backpatch($4.truelist, $6);
				 mergelist($$, std::move($4.falselist), std::move($7.breaklist)); // eat all breaks
				 drv.gen("JUMP", std::to_string($2));
			 } | "while" mark_pos "(" error ")" stmt { drv.error(@4) << "bad expression inside while" << std::endl; }

switch_stmt : "switch" "(" expression ")" mark_goto "{" caselist "default" ":" mark_pos stmtlist mark_goto "}" {
				if ($3.type != VAR_TYPE::INT) {
					drv.error(@3) << "expression inside switch must be of int type" << std::endl;
					break;
				}
				mergelist($$, std::move($7.breaklist), std::move($7.nextlist), std::move($11.breaklist), std::move($11.nextlist));
				$$.push_back($12);
				drv.backpatch({$5}, drv.get_nextinst());

				if ($3.is_const()) { // we can select the exact one
					for (const auto &[addr, value] : $7.cases) {
						if (value == std::get<int>($3.addr)) {
							drv.gen("JUMP", std::to_string(addr));
							break;
						}
					}
				} else {
					auto inst = opcodes::typed_ops($3.type).nql;
					std::string tmp = drv.newtemp(VAR_TYPE::INT);
					for (const auto &[addr, value] : $7.cases) {
						drv.gen(inst, tmp, $3, std::to_string(value));
						drv.gen("JMPZ", std::to_string(addr), tmp);
					}
				}
				drv.gen("JUMP", std::to_string($10)); // default
			} | "switch" "(" expression ")" mark_goto "{" caselist "}" { drv.error(@$) << "missing default in switch" << std::endl; }
			| "switch" "(" error ")" "{" caselist "default" ":" mark_pos stmtlist "}" { drv.error(@3) << "bad expression" << std::endl; }

caselist : caselist "case" NUM_INT ":" mark_pos stmtlist {
				mergelist($$.breaklist, std::move($1.breaklist), std::move($6.breaklist));
				drv.backpatch($1.nextlist, $5);
				$$.nextlist = std::move($6.nextlist);
				$$.cases = std::move($1.cases);
				$$.cases.emplace_back($5, $3);
		} | caselist "case" NUM_FLOAT ":" stmtlist {
				drv.error(@3) << "expression of case must be of int type" << std::endl;
		} | caselist "case" error ":" stmtlist {
				drv.error(@3) << "unknown expression for case" << std::endl;
		} | caselist "case" ":" stmtlist {
				drv.error(@2) << "missing value for case" << std::endl;
		} | %empty { }

break_stmt : "break" ";" mark_goto { $$.push_back($3); }

stmt_block : "{" stmtlist "}" { $$ = std::move($2); }
		   | "{" error "}" { drv.error(@2) << "error with statements" << std::endl; }

stmtlist : stmtlist mark_pos stmt {
				drv.backpatch($1.nextlist, $2);
				$$.nextlist = std::move($3.nextlist);
				mergelist($$.breaklist, std::move($1.breaklist), std::move($3.breaklist));
		 } | %empty { }

boolexpr : boolexpr "||" mark_pos boolterm {
				drv.backpatch($1.falselist, $3);
				$$.falselist = std::move($4.falselist);
				mergelist($$.truelist, std::move($1.truelist), std::move($4.truelist));
		} | boolterm { $$ = std::move($1); }

boolterm : boolterm "&&" mark_pos boolfactor {
				 drv.backpatch($1.truelist, $3);
				 $$.truelist = std::move($4.truelist);
				 mergelist($$.falselist, std::move($1.falselist), std::move($4.falselist));
		} | boolfactor { $$ = std::move($1); }

boolfactor : "!" "(" boolexpr ")" {
				$$.truelist = std::move($3.falselist);
				$$.falselist = std::move($3.truelist);
		   } | expression RELOP expression mark_pos {
				 auto type = upcast($1.type, $3.type);
				 auto inst_set = opcodes::typed_ops(type);
				 auto tmp = drv.newtemp(VAR_TYPE::INT);
				 auto [operand1, operand2] = drv.auto_upcast(drv.newtemp(VAR_TYPE::FLOAT), $1, $3); // Fix: plan the passing
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
				if ($1.is_const() && $1.type != $$.type) {
					$1.type = $$.type;
					$1.addr = (float)std::get<int>($1.addr);
				} else if ($3.is_const() && $3.type != $$.type) {
					$3.type = $$.type;
					$3.addr = (float)std::get<int>($3.addr);
				}
				if ($1.is_const() && $3.is_const()) {
					auto op = [](auto op, auto a1, auto a2) { return op == ARITHMETIC_OPS::ADD ? a1 + a2 : a1 - a2; };
					if ($$.type == VAR_TYPE::INT)
						$$.addr = op($2, std::get<int>($1.addr), std::get<int>($3.addr));
					else
						$$.addr = op($2, std::get<float>($1.addr), std::get<float>($3.addr));
				} else {
					if (std::visit(expression::const_equals<0>(), $3.addr)) {
						if ($1.type == $$.type)
							$$.addr = std::move($1.addr);
						else {
							auto tmp = drv.newtemp($$.type);
							drv.gen("ITOR", tmp, std::get<std::string>($1.addr));
							$$.addr = std::move(tmp);
						}
					} else if ($2 == ARITHMETIC_OPS::ADD && std::visit(expression::const_equals<0>(), $1.addr)) {
						if ($3.type == $$.type)
							$$.addr = std::move($3.addr);
						else {
							auto tmp = drv.newtemp($$.type);
							drv.gen("ITOR", tmp, std::get<std::string>($3.addr));
							$$.addr = std::move(tmp);
						}
					} else {
						auto tmp = drv.newtemp($$.type);
						auto [operand1, operand2] = drv.auto_upcast(tmp, $1, $3);
						drv.gen(opcodes::typed_ops($$.type).get_op($2), tmp, operand1, operand2);
						$$.addr = std::move(tmp);
					}
				}
		}

term : factor { $$ = std::move($1); }
	 | term MULOP factor {
			if ($2 == ARITHMETIC_OPS::DIV && std::visit(expression::const_equals<0>(), $3.addr)) {
				drv.error(@$) << "division by zero evaluated expression at " << @3 << std::endl;
				break;
			}
			$$.type = upcast($1.type, $3.type);
			if ($1.is_const() && $1.type != $$.type) {
				$1.type = $$.type;
				$1.addr = (float)std::get<int>($1.addr);
			} else if ($3.is_const() && $3.type != $$.type) {
				$3.type = $$.type;
				$3.addr = (float)std::get<int>($3.addr);
			}
			if ($1.is_const() && $3.is_const()) {
				auto op = [](auto op, auto a1, auto a2) { return op == ARITHMETIC_OPS::MUL ? a1 * a2 : a1 / a2; };
				if ($$.type == VAR_TYPE::INT)
					$$.addr = op($2, std::get<int>($1.addr), std::get<int>($3.addr));
				else
					$$.addr = op($2, std::get<float>($1.addr), std::get<float>($3.addr));
			} else {
				if (std::visit(expression::const_equals<0>(), $3.addr) || std::visit(expression::const_equals<0>(), $1.addr)) {
					$$.addr = 0;
				} else if (std::visit(expression::const_equals<1>(), $3.addr)) {
					if ($1.type == $$.type)
						$$.addr = std::move($1.addr);
					else {
						auto tmp = drv.newtemp($$.type);
						drv.gen("ITOR", tmp, std::get<std::string>($1.addr));
						$$.addr = std::move(tmp);
					}
				} else if ($2 == ARITHMETIC_OPS::MUL && std::visit(expression::const_equals<1>(), $1.addr)) {
					if ($3.type == $$.type)
						$$.addr = std::move($3.addr);
					else {
						auto tmp = drv.newtemp($$.type);
						drv.gen("ITOR", tmp, std::get<std::string>($3.addr));
						$$.addr = std::move(tmp);
					}
				} else {
					auto tmp = drv.newtemp($$.type);
					auto [operand1, operand2] = drv.auto_upcast(tmp, $1, $3);
					drv.gen(opcodes::typed_ops($$.type).get_op($2), tmp, operand1, operand2);
					$$.addr = std::move(tmp);
				}
			}
	 }

factor : "(" expression ")" { $$ = std::move($2); }
	   | "(" error ")" { drv.error(@2) << "bad expression" << std::endl; }
       | CAST "(" expression ")" {
            if ($1 == $3.type) {
				$$ = std::move($3);
            } else if ($1 == VAR_TYPE::INT && $3.type == VAR_TYPE::FLOAT) {
				$$.type = $1;
				if ($3.is_const()) {
					$$.addr = (int)std::get<float>($3.addr);
				} else {
					auto tmp = drv.newtemp(VAR_TYPE::INT);
					drv.gen("RTOI", tmp, std::move(std::get<std::string>($3.addr)));
					$$.addr = std::move(tmp);
				}
            } else if ($1 == VAR_TYPE::FLOAT && $3.type == VAR_TYPE::INT) {
				$$.type = $1;
				if ($3.is_const()) {
					$$.addr = (float)std::get<int>($3.addr);
				} else {
					auto tmp = drv.newtemp(VAR_TYPE::FLOAT);
					drv.gen("ITOR", tmp, std::move(std::get<std::string>($3.addr)));
					$$.addr = std::move(tmp);
				}
            }
	   } | CAST "(" error ")" {
			drv.error(@3) << "bad expression" << std::endl;
	   } | ID {
			auto iter = drv.symtable.find($1);
			if (iter == drv.symtable.end()) {
				drv.error(@1) << "Unknown identifier " << $1 << std::endl;
				break;
			}
			$$.type = iter->second;
			$$.addr = std::move($1);
	   } | NUM_INT {
			$$.type = VAR_TYPE::INT;
			$$.addr = $1;
	   } | NUM_FLOAT {
           $$.type = VAR_TYPE::FLOAT;
		   $$.addr = $1;
	   }

mark_pos:  %empty { $$ = drv.get_nextinst(); }
mark_goto: %empty { $$ = drv.get_nextinst(); drv.gen("JUMP", OPERAND_PLACEHOLDER); }
%%
void yy::parser::error(const location_type& l, const std::string& m) {
	drv.error(l) << m << std::endl;
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
