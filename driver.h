#ifndef DRIVER_H
#define DRIVER_H
#include <map>
#include <vector>
#include <string>
#include "parser.hpp"

#define YY_DECL yy::parser::symbol_type yylex(driver& drv)

/**
 * @brief Main driver for controlling the parser, scanner and optimizer
 */
class driver {
    friend YY_DECL;
private:
    int result;
    int nextinst = 1;
    int tmp_counter = 0;
    bool is_ok = true;
    yy::location location;

    std::vector<instruction> code;
    std::string file;

    void scan_begin();
    void scan_end();
public:
    std::map<std::string, VAR_TYPE> symtable;

    driver(const std::string &f);
    bool parse();
    void optimize();
    friend std::ostream &operator<<(std::ostream &os, const driver &drv);

    std::pair<std::string, std::string> auto_upcast(const std::string &tmp, const expression &first, const expression &second);
    void gen(const char *op, const std::string &operand1 = "", const std::string &operand2 = "", const std::string &operand3 = "");
    std::string newtemp(VAR_TYPE type);
    void backpatch(const std::vector<int> &list, int addr);
    int get_nextinst() const {
        return nextinst;
    }

    std::ostream &error(const yy::location &loc);
    operator bool() const {
        return is_ok;
    }
};
#endif // ! DRIVER_H
