#include <string.h>

#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"

#include "wifi_connection_manager.h"

static const char *TAG = "wifi_connection_manager";

static int s_retry_num = 0;
static int s_max_retries = 1;

static void handle_wifi_sta_start_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    esp_wifi_connect();
}

static void handle_wifi_sta_disconnected_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    if (s_retry_num < s_max_retries)
    {
        esp_wifi_connect();
        s_retry_num++;
        ESP_LOGI(TAG, "Retry connecting to the access point...");
    }
    else
    {
        ESP_LOGI(TAG, "Failed to connect to the access point");
    }
}

void register_wifi_manager_event_handlers()
{
    ESP_LOGI(TAG, "Registering the handler for WIFI_EVENT_STA_START event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT, WIFI_EVENT_STA_START, handle_wifi_sta_start_event, NULL, NULL));

    ESP_LOGI(TAG, "Registering the handler for WIFI_EVENT_STA_DISCONNECTED event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT, WIFI_EVENT_STA_DISCONNECTED, handle_wifi_sta_disconnected_event, NULL, NULL));
}

void connect_to_wifi_network(char *ssid, char *password, int max_retries)
{
    ESP_LOGI(TAG, "Connecting to %s WiFi network...", ssid);
    s_max_retries = max_retries;

    ESP_ERROR_CHECK(esp_netif_init());

    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    wifi_config_t wifi_config = {
        .sta = {
            .pmf_cfg = {
                .capable = true,
                .required = false},
        },
    };

    strcpy((char *)wifi_config.sta.ssid, (char *)ssid);
    strcpy((char *)wifi_config.sta.password, (char *)password);

    ESP_LOGI(TAG, "Initializing the WiFi station mode...");

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(ESP_IF_WIFI_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());
}
