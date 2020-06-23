ESP_EVENT_DECLARE_BASE(WIFI_CONNECTION_MANAGER_EVENTS);

enum
{
    WIFI_CONNECTION_MANAGER_EVENT_STA_INIT,     // raised when the wifi station manager needs to be initialized
    WIFI_CONNECTION_MANAGER_EVENT_STA_MODE_INIT // raised when the wifi station manager needs to be enabled
};

void initialize_wifi_station();

void register_wifi_manager_event_handlers();
