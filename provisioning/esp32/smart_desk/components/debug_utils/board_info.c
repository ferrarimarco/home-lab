#include "board_info.h"
#include "esp_spi_flash.h"

void get_board_info(esp_chip_info_t chip_info)
{
    printf("This is a %s CPU (%s IDF target) with %d CPU cores, WiFi%s%s, ",
           (chip_info.model == CHIP_ESP32) ? "ESP32" : (chip_info.model == CHIP_ESP32S2) ? "ESP32-S2" : "N/A",
           CONFIG_IDF_TARGET,
           chip_info.cores,
           (chip_info.features & CHIP_FEATURE_BT) ? "/BT" : "",
           (chip_info.features & CHIP_FEATURE_BLE) ? "/BLE" : "");

    printf("silicon revision %d, ", chip_info.revision);

    printf("%dMB %s flash\n", spi_flash_get_chip_size() / (1024 * 1024),
           (chip_info.features & CHIP_FEATURE_EMB_FLASH) ? "embedded" : "external");

    printf("Free heap: %d\n", esp_get_free_heap_size());
}
