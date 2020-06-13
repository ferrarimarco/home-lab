#include "unity.h"
#include "sdkconfig.h"
#include "esp_system.h"
#include "nvs_manager.h"
#include "esp_event.h"
#include "esp_log.h"

#include "wifi_connection_manager.h"
#include "ip_address_manager.h"

TEST_CASE("Should connect to the specified wifi network as a client", "[network_manager]")
{
    initialize_nvs_flash();
    register_wifi_manager_event_handlers();
    register_ip_address_manager_event_handlers();
    connect_to_wifi_network("ssid", "password", 10);
}
