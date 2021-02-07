#ifndef DRIVER_HH
# define DRIVER_HH
# include <string>
# include <map>
# include "parser.hpp"

# define YY_DECL yy::parser::symbol_type yylex (driver& drv)

YY_DECL;

#define OPERAND_PLACEHOLDER "@"
class driver
{
private:
	struct instruction {
		const char *op;
		std::string operand1;
		std::string operand2;
		std::string operand3;

		instruction(const char *op, std::string operand1, std::string operand2, std::string operand3):
			op(op), operand1(std::move(operand1)), operand2(std::move(operand2)), operand3(std::move(operand3))
		{}
	};
	int result;
	int nextinst = 1;
	int tmp_counter = 0;

	std::vector<instruction> code;
public:

	driver ();

	std::map<std::string, VAR_TYPE> symtable;

	int parse (const std::string& f);
	std::string file;

	// Handling the scanner.
	void scan_begin ();
	void scan_end ();
	// The token's location used by the scanner.
	yy::location location;

	void gen(const char *op, const std::string &operand1 = "", const std::string &operand2 = "", const std::string &operand3 = "");
	std::string newtemp();
	void backpatch(const std::vector<int> &list, int addr);

	std::pair<const std::string&, const std::string&> auto_upcast(const std::string &tmp, const expression &first, const expression &second);

	int get_nextinst() const {
		return nextinst;
	}

	friend std::ostream &operator<<(std::ostream &os, const driver &drv);
};
#endif // ! DRIVER_HH
