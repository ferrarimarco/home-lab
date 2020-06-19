#include <string.h>

#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"

#include "wifi_connection_manager.h"
#include "nvs_manager.h"

static const char *TAG = "wifi_connection_manager";

static void handle_wifi_sta_init_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_ERROR_CHECK(initialize_nvs_flash());

    ESP_LOGI(TAG, "Initializing the network stack...");
    ESP_ERROR_CHECK(esp_netif_init());

    ESP_LOGI(TAG, "Creating the WiFi station...");
    esp_netif_create_default_wifi_sta();

    ESP_LOGI(TAG, "Initializing the WiFi station...");
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
}

static void handle_wifi_sta_mode_init_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "Initializing the WiFi station mode...");
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));

    ESP_LOGI(TAG, "Starting WiFi...");
    ESP_ERROR_CHECK(esp_wifi_start());
}

static void handle_wifi_sta_start_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "Connecting to the access point...");
    ESP_ERROR_CHECK(esp_wifi_connect());
}

static void handle_wifi_sta_disconnected_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "Retry connecting to the access point...");
    ESP_ERROR_CHECK(esp_wifi_connect());
}

void register_wifi_manager_event_handlers()
{
    ESP_LOGI(TAG, "Registering the handler for WIFI_EVENT_STA_INIT event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT, WIFI_EVENT_STA_INIT, handle_wifi_sta_init_event, NULL, NULL));

    ESP_LOGI(TAG, "Registering the handler for WIFI_EVENT_STA_MODE_INIT event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT, WIFI_EVENT_STA_MODE_INIT, handle_wifi_sta_mode_init_event, NULL, NULL));

    ESP_LOGI(TAG, "Registering the handler for WIFI_EVENT_STA_START event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT, WIFI_EVENT_STA_START, handle_wifi_sta_start_event, NULL, NULL));

    ESP_LOGI(TAG, "Registering the handler for WIFI_EVENT_STA_DISCONNECTED event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT, WIFI_EVENT_STA_DISCONNECTED, handle_wifi_sta_disconnected_event, NULL, NULL));
}
