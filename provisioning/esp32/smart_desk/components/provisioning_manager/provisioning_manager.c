#include "esp_event.h"
#include "esp_log.h"
#include "wifi_provisioning/manager.h"

#include "provisioning_manager.h"

static const char *TAG = "provisioning_manager";

static void handle_wifi_prov_start_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "Provisioning started");
}

static void handle_wifi_prov_cred_recv_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    wifi_sta_config_t *wifi_sta_cfg = (wifi_sta_config_t *)event_data;
    ESP_LOGI(TAG, "Received Wi-Fi credentials"
                  "\n\tSSID     : %s\n\tPassword : %s",
             (const char *)wifi_sta_cfg->ssid,
             (const char *)wifi_sta_cfg->password);
}

static void handle_wifi_prov_cred_fail_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    wifi_prov_sta_fail_reason_t *reason = (wifi_prov_sta_fail_reason_t *)event_data;
    ESP_LOGE(TAG, "Provisioning failed!\n\tReason : %s"
                  "\n\tPlease reset to factory and retry provisioning",
             (*reason == WIFI_PROV_STA_AUTH_ERROR) ? "Wi-Fi station authentication failed" : "Wi-Fi access-point not found");
}

static void handle_wifi_prov_cred_success_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "Provisioning successful");
}

static void handle_wifi_prov_end_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "Provisioning completed");
    wifi_prov_mgr_deinit();
}

void register_provisioning_manager_event_handlers()
{
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
}
