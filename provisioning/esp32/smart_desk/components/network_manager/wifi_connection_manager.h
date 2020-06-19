#include "esp_system.h"

enum
{
    WIFI_EVENT_STA_INIT,     // raised when the wifi station manager needs to be initialized
    WIFI_EVENT_STA_MODE_INIT // raised when the wifi station manager needs to be enabled
};

void register_wifi_manager_event_handlers();
