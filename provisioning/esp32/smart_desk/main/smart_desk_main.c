#include <stdio.h>
#include "sdkconfig.h"
#include "freertos/FreeRTOS.h"
#include "esp_log.h"
#include "esp_event.h"
#include "esp_system.h"
#include "esp_spi_flash.h"

#include "board_info.h"
#include "nvs_manager.h"

#include "ip_address_manager.h"
#include "wifi_connection_manager.h"

static const char *TAG = "smart_desk";

void app_main(void)
{
    esp_chip_info_t chip_info;
    esp_chip_info(&chip_info);
    const char *board_info = get_board_info(chip_info, spi_flash_get_chip_size(), esp_get_free_heap_size());
    printf(board_info);

    // Initialize the non-volatile storage flash
    ESP_ERROR_CHECK(initialize_nvs_flash());

    // Initialize the network stack
    ESP_ERROR_CHECK(esp_netif_init());

    ESP_LOGI(TAG, "Creating the default loop...");
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    ESP_LOGI(TAG, "Registering event handlers...");
    register_wifi_manager_event_handlers();
    register_ip_address_manager_event_handlers();

    ESP_LOGI(TAG, "Connecting to WiFi access point...");
    connect_to_wifi_network("ssid", "password", 10);

    for (int i = 10; i >= 0; i--)
    {
        printf("Restarting in %d seconds...\n", i);
        vTaskDelay(1000 / portTICK_PERIOD_MS);
    }
    printf("Restarting now.\n");
    fflush(stdout);
    esp_restart();
}
