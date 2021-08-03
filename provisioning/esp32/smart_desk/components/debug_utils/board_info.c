#include <stdio.h>
#include <string.h>

#include "esp_log.h"
#include "sdkconfig.h"

#include "board_info.h"

static const char *TAG = "board_info";

void get_board_info(esp_chip_info_t chip_info, int flash_chip_size, int free_heap_size)
{
    ESP_LOGI(TAG, "This is a %s CPU (%s IDF target) with %d CPU cores, WiFi%s%s, silicon revision %d, %dB %s flash, Free heap: %d\n",
        (chip_info.model == CHIP_ESP32) ? "ESP32" : "N/A",
        CONFIG_IDF_TARGET,
        chip_info.cores,
        (chip_info.features & CHIP_FEATURE_BT) ? "/BT" : "",
        (chip_info.features & CHIP_FEATURE_BLE) ? "/BLE" : "",
        chip_info.revision,
        flash_chip_size,
        (chip_info.features & CHIP_FEATURE_EMB_FLASH) ? "embedded" : "external",
        free_heap_size);
}
