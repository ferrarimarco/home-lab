#include "esp_event.h"
#include "esp_log.h"
#include "wifi_provisioning/manager.h"

#include "provisioning_manager.h"
#include "wifi_connection_manager.h"

static const char *TAG = "provisioning_manager";

static void handle_wifi_prov_init_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "Initializing WiFi provisioning...");

    ESP_ERROR_CHECK(esp_event_post(WIFI_EVENT, WIFI_EVENT_STA_INIT, NULL, 0, portMAX_DELAY));

    wifi_prov_mgr_config_t wifi_provisioning_manager_config = {
        .scheme =,
        .scheme_event_handler =,
    };

    ESP_ERROR_CHECK(wifi_prov_mgr_init(wifi_provisioning_manager_config));

    bool provisioned = false;
    ESP_ERROR_CHECK(wifi_prov_mgr_is_provisioned(&provisioned));

    if (!provisioned)
    {
        ESP_LOGI(TAG, "Starting WiFi provisioning...");
        char service_name[12];
        get_device_service_name(service_name, sizeof(service_name));
        wifi_prov_security_t security = WIFI_PROV_SECURITY_1;
        const char *pop = "abcd1234";

        const char *service_key = NULL;

        ESP_ERROR_CHECK(wifi_prov_mgr_start_provisioning(security, pop, service_name, service_key));
    }
    else
    {
        ESP_LOGI(TAG, "The WiFi is already provisioned...");
        ESP_ERROR_CHECK(esp_event_post(WIFI_PROV_EVENT, WIFI_PROV_END, NULL, 0, portMAX_DELAY));
    }
}

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
    ESP_LOGI(TAG, "WiFi provisioning completed");
    wifi_prov_mgr_deinit();

    ESP_ERROR_CHECK(esp_event_post(WIFI_EVENT, WIFI_EVENT_STA_MODE_INIT, NULL, 0, portMAX_DELAY));
}

void register_provisioning_manager_event_handlers()
{
    ESP_LOGI(TAG, "Registering the handler for WIFI_PROV_MANAGER_INIT event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_PROV_EVENT, WIFI_PROV_MANAGER_INIT, handle_wifi_prov_init_event, NULL, NULL));

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

void start_wifi_provisioning()
{
    ESP_ERROR_CHECK(esp_event_post(WIFI_PROV_EVENT, WIFI_PROV_MANAGER_INIT, NULL, 0, portMAX_DELAY));
}
