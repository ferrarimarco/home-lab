#include <stdio.h>
#include "sdkconfig.h"
#include "freertos/FreeRTOS.h"
#include "esp_log.h"
#include "esp_system.h"
#include "esp_spi_flash.h"

#include "board_info.h"
#include "nvs_manager.h"
#include "wifi_connection_manager.h"

static const char *TAG = "smart_desk";

void app_main(void)
{
    esp_chip_info_t chip_info;
    esp_chip_info(&chip_info);
    const char *board_info = get_board_info(chip_info, spi_flash_get_chip_size(), esp_get_free_heap_size());
    printf(board_info);

    initialize_nvs_flash();

    ESP_LOGI(TAG, "Connecting to the WiFi station mode...");
    ESP_LOGI(TAG, "Connecting to WiFi access point with SSID: %s", CONFIG_ESP_WIFI_SSID);
    connect_to_wifi_network(CONFIG_ESP_WIFI_SSID, CONFIG_ESP_WIFI_PASSWORD);

    for (int i = 10; i >= 0; i--)
    {
        printf("Restarting in %d seconds...\n", i);
        vTaskDelay(1000 / portTICK_PERIOD_MS);
    }
    printf("Restarting now.\n");
    fflush(stdout);
    esp_restart();
}
