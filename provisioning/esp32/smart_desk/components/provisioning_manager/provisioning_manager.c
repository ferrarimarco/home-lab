#include "esp_event.h"
#include "esp_log.h"
#include "esp_wifi.h"
#include "wifi_provisioning/manager.h"
#include "wifi_provisioning/scheme_ble.h"

#include "provisioning_manager.h"
#include "wifi_connection_manager.h"

static const char *TAG = "provisioning_manager";

ESP_EVENT_DEFINE_BASE(PROVISIONING_MANAGER_EVENTS);

void handle_prov_manager_init_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "Initializing provisioning manager...");

    initialize_wifi_station();

    wifi_prov_mgr_config_t wifi_provisioning_manager_config = {
        .scheme = wifi_prov_scheme_ble,
        .scheme_event_handler = WIFI_PROV_SCHEME_BLE_EVENT_HANDLER_FREE_BTDM,
    };

    ESP_LOGI(TAG, "Initializing WiFi provisioning manager...");
    ESP_ERROR_CHECK(wifi_prov_mgr_init(wifi_provisioning_manager_config));
}

void handle_wifi_prov_init_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "WiFi provisioning manager initialization completed.");

    ESP_LOGI(TAG, "Checking if WiFi is already provisioned...");
    bool provisioned = false;
    ESP_ERROR_CHECK(wifi_prov_mgr_is_provisioned(&provisioned));

    if (!provisioned)
    {
        ESP_LOGI(TAG, "WiFi is not already provisioned. Starting WiFi provisioning...");

        char service_name[12];
        uint8_t eth_mac[6];
        const char *ssid_prefix = "PROV_";
        ESP_ERROR_CHECK(esp_wifi_get_mac(WIFI_IF_STA, eth_mac));
        snprintf(service_name, sizeof(service_name), "%s%02X%02X%02X", ssid_prefix, eth_mac[3], eth_mac[4], eth_mac[5]);
        ESP_LOGI(TAG, "Setting service name to %s...", service_name);

        wifi_prov_security_t security = WIFI_PROV_SECURITY_1;

        const char *pop = "abcd1234";

        uint8_t custom_service_uuid[] = {
            /* LSB <---------------------------------------
             * ---------------------------------------> MSB */
            0xb4,
            0xdf,
            0x5a,
            0x1c,
            0x3f,
            0x6b,
            0xf4,
            0xbf,
            0xea,
            0x4a,
            0x82,
            0x03,
            0x04,
            0x90,
            0x1a,
            0x02,
        };
        ESP_ERROR_CHECK(wifi_prov_scheme_ble_set_service_uuid(custom_service_uuid));

        ESP_ERROR_CHECK(wifi_prov_mgr_start_provisioning(security, pop, service_name, NULL));
    }
    else
    {
        ESP_LOGI(TAG, "The WiFi is already provisioned. Completing the provisioning process...");
        ESP_ERROR_CHECK(esp_event_post(WIFI_PROV_EVENT, WIFI_PROV_END, NULL, 0, portMAX_DELAY));
    }
}

void handle_wifi_prov_start_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "Provisioning started");
}

void handle_wifi_prov_cred_recv_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    wifi_sta_config_t *wifi_sta_cfg = (wifi_sta_config_t *)event_data;
    ESP_LOGI(TAG, "Received Wi-Fi credentials"
                  "\n\tSSID     : %s\n\tPassword : %s",
             (const char *)wifi_sta_cfg->ssid,
             (const char *)wifi_sta_cfg->password);
}

void handle_wifi_prov_cred_fail_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    wifi_prov_sta_fail_reason_t *reason = (wifi_prov_sta_fail_reason_t *)event_data;
    ESP_LOGE(TAG, "Provisioning failed!\n\tReason : %s"
                  "\n\tPlease reset to factory and retry provisioning",
             (*reason == WIFI_PROV_STA_AUTH_ERROR) ? "Wi-Fi station authentication failed" : "Wi-Fi access-point not found");
}

void handle_wifi_prov_cred_success_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "Provisioning successful");
}

void handle_wifi_prov_end_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "WiFi provisioning completed. De-initializing the WiFi provisioning manager...");
    wifi_prov_mgr_deinit();
}

void handle_wifi_prov_deinit_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "WiFi provisioning manager de-initialization completed. Initializing WiFi station mode...");
    ESP_ERROR_CHECK(esp_event_post(WIFI_EVENT, WIFI_EVENT_STA_MODE_INIT, NULL, 0, portMAX_DELAY));
}

void register_provisioning_manager_event_handlers()
{
    ESP_LOGI(TAG, "Registering the handler for PROVISIONING_MANAGER_INIT event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(PROVISIONING_MANAGER_EVENTS, PROVISIONING_MANAGER_INIT, handle_prov_manager_init_event, NULL, NULL));

    ESP_LOGI(TAG, "Registering the handler for WIFI_PROV_INIT event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_PROV_EVENT, WIFI_PROV_INIT, handle_wifi_prov_init_event, NULL, NULL));

    ESP_LOGI(TAG, "Registering the handler for WIFI_PROV_START event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_PROV_EVENT, WIFI_PROV_START, handle_wifi_prov_start_event, NULL, NULL));

    ESP_LOGI(TAG, "Registering the handler for WIFI_PROV_CRED_RECV event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_PROV_EVENT, WIFI_PROV_CRED_RECV, handle_wifi_prov_cred_recv_event, NULL, NULL));

    ESP_LOGI(TAG, "Registering the handler for WIFI_PROV_CRED_FAIL event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_PROV_EVENT, WIFI_PROV_CRED_FAIL, handle_wifi_prov_cred_fail_event, NULL, NULL));

    ESP_LOGI(TAG, "Registering the handler for WIFI_PROV_CRED_SUCCESS event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_PROV_EVENT, WIFI_PROV_CRED_SUCCESS, handle_wifi_prov_cred_success_event, NULL, NULL));

    ESP_LOGI(TAG, "Registering the handler for WIFI_PROV_END event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_PROV_EVENT, WIFI_PROV_END, handle_wifi_prov_end_event, NULL, NULL));

    ESP_LOGI(TAG, "Registering the handler for WIFI_PROV_DEINIT event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_PROV_EVENT, WIFI_PROV_DEINIT, handle_wifi_prov_deinit_event, NULL, NULL));
}

void start_wifi_provisioning()
{
    ESP_LOGI(TAG, "Starting WiFi provisioning...");
    ESP_ERROR_CHECK(esp_event_post(PROVISIONING_MANAGER_EVENTS, PROVISIONING_MANAGER_INIT, NULL, 0, portMAX_DELAY));
}
