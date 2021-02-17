#ifndef DRIVER_H
#define DRIVER_H
#include <map>
#include "parser.hpp"

# define YY_DECL yy::parser::symbol_type yylex (driver& drv)

YY_DECL;

class driver {
private:
	int result;
	int nextinst = 1;
	int tmp_counter = 0;

	std::vector<instruction> code;
	std::string file;
public:

	driver ();

	std::map<std::string, VAR_TYPE> symtable;

	int parse(const std::string& f);

	// Handling the scanner.
	void scan_begin();
	void scan_end();
	// The token's location used by the scanner.
	yy::location location;

	void gen(const char *op, const std::string &operand1 = "", const std::string &operand2 = "", const std::string &operand3 = "");
	std::string newtemp();
	void backpatch(const std::vector<int> &list, int addr);

	std::pair<const std::string&, const std::string&> auto_upcast(const std::string &tmp, const expression &first, const expression &second);

	int get_nextinst() const {
		return nextinst;
	}

	void optimize();

	friend std::ostream &operator<<(std::ostream &os, const driver &drv);
};
#endif // ! DRIVER_H
