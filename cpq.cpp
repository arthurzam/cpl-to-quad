#include <iostream>
#include <fstream>
#include <cstring>

#include "driver.h"

static constexpr const char *INPUT_EXTENSION = ".ou";
static constexpr const char *OUTPUT_EXTENSION = ".qud";
static constexpr const char *AUTHOR_INFO = "Author: Arthur Zamarin";

static bool check_input_file(const std::string &path) {
    static constexpr size_t LEN = strlen(INPUT_EXTENSION);
    if (path.length() >= LEN) {
        return (0 == path.compare(path.length() - LEN, LEN, INPUT_EXTENSION));
    } else {
        return false;
    }
}

static std::ofstream open_output_file(const std::string &input_path) {
    static constexpr size_t LEN = strlen(INPUT_EXTENSION);
    return std::ofstream(input_path.substr(0, input_path.length() - LEN) + OUTPUT_EXTENSION, std::ios::out | std::ios::trunc);
}

int main(int argc, char *argv[]) {
    std::cerr << AUTHOR_INFO << std::endl;

    std::string filepath(argc > 1 ? argv[1] : "");
    if (!check_input_file(filepath)) {
        std::cerr << "Bad file path extension" << std::endl;
        return 1;
    }

    driver drv(filepath);
    if (drv.parse()) {
        drv.optimize();
        open_output_file(filepath) << drv << std::endl << AUTHOR_INFO << std::endl;
        return 0;
    } else {
        std::cerr << "Bad input file therefore output file wasn't created" << std::endl;
        return 1;
    }
}
