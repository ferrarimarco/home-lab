#include "unity.h"
#include "esp_system.h"
#include "esp_spi_flash.h"

#include "board_info.h"

TEST_CASE("Should return the board info for ESP32", "[board_info]")
{
    esp_chip_info_t chip_info;
    esp_chip_info(&chip_info);

    int flash_chip_size = spi_flash_get_chip_size();
    int free_heap_size = esp_get_free_heap_size();

    int board_info_size = 200 * sizeof(char);
    char *expected = (char *)malloc(board_info_size);

    sprintf(expected, "This is a ESP32 CPU (esp32 IDF target) with 2 CPU cores, WiFi/BT/BLE, silicon revision 1, %dB external flash, Free heap: %d\n",
            flash_chip_size,
            free_heap_size);

    const char *actual = get_board_info(chip_info, flash_chip_size, free_heap_size);

    TEST_ASSERT_EQUAL_STRING(expected, actual);
}
