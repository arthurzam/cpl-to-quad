#include <iostream>
#include <cassert>

#include "driver.h"
#include "parser.hpp"


driver::driver(const std::string &f)
    : file(f) {
    location.initialize(&file);
}

bool driver::parse() {
    scan_begin();
    yy::parser parse(*this);
    // parse.set_debug_level(true); // when hell opens, uncommenting this line will trace all and might bring us salvation
    int res = parse();
    scan_end();
    return is_ok = is_ok && (res == 0);
}

void driver::gen(const char *op, const std::string &operand1, const std::string &operand2, const std::string &operand3) {
    nextinst++;
    this->code.emplace_back(op, operand1, operand2, operand3);
}

std::string driver::newtemp(VAR_TYPE type) {
    const char *prefix = (type == VAR_TYPE::INT ? "_i" : "_f");
    return prefix + std::to_string(++tmp_counter);
}

void instruction::backpatch(const std::string &addr) {
    assert(operand1 == OPERAND_PLACEHOLDER);
    operand1 = addr;
}

void driver::backpatch(const std::vector<int> &list, int addr) {
    std::string dst = std::to_string(addr);
    for (int i : list) {
        assert(i - 1 < code.size());
        code[i - 1].backpatch(dst);
    }
}

std::ostream &driver::error(const yy::location &loc) {
    is_ok = false;
    return std::cerr << loc << ": ";
}

std::pair<std::string, std::string> driver::auto_upcast(const std::string &tmp, const expression &first, const expression &second) {
    VAR_TYPE type = (first.type == VAR_TYPE::INT && second.type == VAR_TYPE::INT) ? VAR_TYPE::INT : VAR_TYPE::FLOAT;
    if (type != first.type) {
        gen("ITOR", tmp, first);
        return {tmp, second};
    } else if (type != second.type) {
        gen("ITOR", tmp, second);
        return {first, tmp};
    } else {
        return {first, second};
    }
}

std::ostream &operator<<(std::ostream &os, const instruction &inst) {
    os << inst.op;
    if (!inst.operand1.empty())
        os << '\t' << inst.operand1;
    if (!inst.operand2.empty())
        os << '\t' << inst.operand2;
    if (!inst.operand3.empty())
        os << '\t' << inst.operand3;
    return os << std::endl;
}

std::ostream &operator<<(std::ostream &os, const driver &drv) {
    for (const auto &inst : drv.code)
        os << inst;
    return os;
}
