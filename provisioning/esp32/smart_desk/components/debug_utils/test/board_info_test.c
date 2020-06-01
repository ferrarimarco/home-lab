#include "unity.h"
#include "esp_system.h"

#include "board_info.h"

TEST_CASE("Should return the board info for ESP32", "[board_info]")
{
    esp_chip_info_t chip_info;
    esp_chip_info(&chip_info);
    get_board_info(chip_info);

    char board_info_sz[] = "This is a ESP32 CPU (esp32 IDF target) with: \
                            2 CPU cores, \
                            WiFi/BT/BLE, \
                            silicon revision %d, \
                            3MB embedded flash";

    TEST_ASSERT_EQUAL(board_info_sz, get_board_info(chip_info));
}
