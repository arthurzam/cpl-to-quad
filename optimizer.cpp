#include <set>
#include <stack>
#include <algorithm>
#include <iostream>

#include "driver.h"
#include "declarations.h"

struct basic_block {
    std::vector<instruction> code;
    basic_block *follow_block = nullptr;
    basic_block *jmpz_block = nullptr;

    mutable bool visited;
    mutable int addr;
};

struct flow_graph {
    std::vector<basic_block> blocks;
    basic_block *first;

    flow_graph(std::vector<instruction> &&code);

    void jmp_jmp_optimize();

    std::vector<instruction> convert() &&;

    template<typename Func>
    void blocks_dfs(Func &&func);
};

/**
 * return list of position in code where a new basic block starts
 */
static std::vector<int> calc_block_starts(const std::vector<instruction> &code) {
    std::set<int> dividers;
    int pos = 0;
    for (const auto &inst : code) {
        if (inst.op == "JUMP" || inst.op == "JMPZ") {
            dividers.emplace(pos + 1);
            int dst = std::stoi(inst.operand1);
            if (dst > 1)
                dividers.emplace(dst - 1);
        }
        pos++;
    }
    dividers.emplace(code.size());
    return {dividers.begin(), dividers.end()};
}

/**
 * traverse the flow graph starting from first node, and run the func on each node
 * the final block (which holds HALT) will always be the last
 */
template<typename Func>
void flow_graph::blocks_dfs(Func &&func) {
    for (auto &block : blocks)
        block.visited = false;
    std::stack<basic_block *, std::vector<basic_block *>> ptrs;
    blocks.back().visited = true;
    ptrs.push(first);
    while (!ptrs.empty()) {
        basic_block *block = ptrs.top();
        ptrs.pop();
        if (block->visited)
            continue;

        block->visited = true;
        func(block);
        if (block->jmpz_block)
            ptrs.push(block->jmpz_block);
        if (block->follow_block)
            ptrs.push(block->follow_block);
    }
    func(&blocks.back());
}

/**
 * construct a full flow graph based on the unoptimized code
 */
flow_graph::flow_graph(std::vector<instruction> &&code) {
    const auto dividers = calc_block_starts(code);
    auto find_position = [&dividers](const std::string &addr) {
        return std::distance(dividers.begin(), std::upper_bound(dividers.begin(), dividers.end(), std::stoi(addr) - 1));
    };

    auto prev = code.begin();
    blocks.resize(dividers.size());
    auto block = blocks.begin();
    for (int curr : dividers) {
        auto iter = code.begin() + curr;
        std::move(prev, iter, std::back_inserter(block->code));
        auto last = block->code.back();
        if (last.op == "JUMP") {
            block->follow_block = &blocks[find_position(last.operand1)];
        } else {
            if (last.op == "JMPZ")
                block->jmpz_block = &blocks[find_position(last.operand1)];
            if (curr != code.size())
                block->follow_block = &*(block + 1);
        }

        block++;
        prev = iter;
    }
    first = &blocks[0];
}

/**
 * Basic JUMP optimization:
 * every JUMP/JMPZ to another JUMP directive is reduced to the final destination
 * if JMPZ to the following block, replace with JUMP
 */
void flow_graph::jmp_jmp_optimize() {
    for (auto &block : blocks) {
        while (block.follow_block && block.follow_block->code.front().op == "JUMP")
            block.follow_block = block.follow_block->follow_block;
        while (block.jmpz_block && block.jmpz_block->code.front().op == "JUMP")
            block.jmpz_block = block.jmpz_block->follow_block;

        if (block.follow_block && block.follow_block == block.jmpz_block) {
            block.jmpz_block = nullptr;
            block.code.back().op = "JUMP";
            block.code.back().operand2 = "";
        }
    }
    while (first->code.front().op == "JUMP")
        first = first->follow_block;
}

/**
 * based on the new_order list, prepares the code of the blocks for reorganization.
 * If the blocks will be one after another, remove the JUMP (to use fall through)
 * If the blocks won't be one after another, add a JUMP
 */
static void blocks_add_jumps(const std::vector<basic_block *> &new_order) {
    int curr_addr = 0;
    for (auto iter = new_order.cbegin(); iter != new_order.cend(); iter++) {
        basic_block *block = *iter;
        bool needs_jump = (iter + 1 != new_order.cend() && block->follow_block != *(iter + 1));
        if (block->code.back().op == "JUMP") {
            if (!needs_jump)
                block->code.pop_back();
            else
                block->code.back().operand1 = OPERAND_PLACEHOLDER;
        } else {
            if (block->code.back().op == "JMPZ")
                block->code.back().operand1 = OPERAND_PLACEHOLDER;
            if (needs_jump)
                block->code.emplace_back("JUMP", OPERAND_PLACEHOLDER, "", "");
        }

        block->addr = curr_addr;
        curr_addr += block->code.size();
    }
}

/**
 * convert the current flow graph into the instructions list
 */
std::vector<instruction> flow_graph::convert() && {
    std::vector<basic_block *> new_order;
    blocks_dfs([&new_order](basic_block *block){
        new_order.push_back(block);
    });
    blocks_add_jumps(new_order);

    std::vector<instruction> result;
    for (basic_block *block : new_order) {
        if (block->code.back().op == "JUMP") {
            block->code.back().backpatch(std::to_string(block->follow_block->addr + 1));
            if (block->jmpz_block)
                (block->code.end() - 2)->backpatch(std::to_string(block->jmpz_block->addr + 1));
        } else if (block->code.back().op == "JMPZ")
            block->code.back().backpatch(std::to_string(block->jmpz_block->addr + 1));
        std::move(block->code.begin(), block->code.end(), std::back_inserter(result));
    }
    return result;
}

/**
 * enable outputting the whole flow graph for debugging purposes
 */
static std::ostream &operator<<(std::ostream &os, const flow_graph &g) {
    int pos = 0;
    os << "Start at " << (g.first - &g.blocks[0]) << std::endl << std::endl;
    for (const auto &b : g.blocks) {
        os << '[' << (pos++) << ']' << std::endl;
        for (const auto &inst : b.code)
            os << inst;

        if (b.follow_block)
            os << (b.follow_block - &g.blocks[0]);
        else
            os << "xx";
        os << ", ";
        if (b.jmpz_block)
            os << (b.jmpz_block - &g.blocks[0]);
        else
            os << "xx";
        os << std::endl << std::endl;
    }
    return os;
}

void driver::optimize() {
    flow_graph graph(std::move(code));
    graph.jmp_jmp_optimize();
//    std::cout << graph;
    code = std::move(graph).convert();
}
