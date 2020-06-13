#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"

#include "esp_system.h"
#include "esp_event.h"
#include "esp_log.h"

#include "lwip/err.h"
#include "lwip/sys.h"

#include "ip_address_manager.h"

static const char *TAG = "ip_address_manager";

static void sta_got_ip_event_handler(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "%s: %u sta_got_ip_event_handler", event_base, event_id);
    ip_event_got_ip_t *event = (ip_event_got_ip_t *)event_data;
    ESP_LOGI(TAG, "Got IP address: " IPSTR, IP2STR(&event->ip_info.ip));
}

void register_ip_address_manager_event_handlers()
{
    ESP_LOGI(TAG, "Registering the handler for IP_EVENT_STA_GOT_IP event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(IP_EVENT, IP_EVENT_STA_GOT_IP, sta_got_ip_event_handler, NULL, NULL));
}
