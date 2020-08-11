#include <stdio.h>
#include <string.h>

#include "sdkconfig.h"

#include "board_info.h"

char *get_board_info(esp_chip_info_t chip_info, int flash_chip_size, int free_heap_size)
{
    int board_info_size = 200 * sizeof(char);
    char *board_info = (char *)malloc(board_info_size);

    sprintf(board_info, "This is a %s CPU (%s IDF target) with %d CPU cores, WiFi%s%s, silicon revision %d, %dB %s flash, Free heap: %d\n",
        (chip_info.model == CHIP_ESP32) ? "ESP32" : (chip_info.model == CHIP_ESP32S2) ? "ESP32-S2" : "N/A",
        CONFIG_IDF_TARGET,
        chip_info.cores,
        (chip_info.features & CHIP_FEATURE_BT) ? "/BT" : "",
        (chip_info.features & CHIP_FEATURE_BLE) ? "/BLE" : "",
        chip_info.revision,
        flash_chip_size,
        (chip_info.features & CHIP_FEATURE_EMB_FLASH) ? "embedded" : "external",
        free_heap_size);

    return board_info;
}
