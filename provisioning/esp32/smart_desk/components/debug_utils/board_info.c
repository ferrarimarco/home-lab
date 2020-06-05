#include <stdio.h>
#include <string.h>

#include "board_info.h"
#include "esp_spi_flash.h"

const char *get_board_info(esp_chip_info_t chip_info)
{
    const char *board_info;
    int board_info_size = 60 * sizeof(char);
    board_info = (const char *)malloc(board_info_size);
    strcpy_s(board_info, board_info_size,
             printf("This is a %s CPU (%s IDF target) with %d CPU cores, WiFi%s%s, ",
                    (chip_info.model == CHIP_ESP32) ? "ESP32" : (chip_info.model == CHIP_ESP32S2) ? "ESP32-S2" : "N/A",
                    CONFIG_IDF_TARGET,
                    chip_info.cores,
                    (chip_info.features & CHIP_FEATURE_BT) ? "/BT" : "",
                    (chip_info.features & CHIP_FEATURE_BLE) ? "/BLE" : ""));

    strcat_s(board_info, board_info_size, printf("silicon revision %d, ", chip_info.revision));
    strcat_s(board_info, board_info_size, printf("%dMB %s flash\n", spi_flash_get_chip_size() / (1024 * 1024), (chip_info.features & CHIP_FEATURE_EMB_FLASH) ? "embedded" : "external"));
    strcat_s(board_info, board_info_size, printf("Free heap: %d\n", esp_get_free_heap_size()));

    return board_info;
}
