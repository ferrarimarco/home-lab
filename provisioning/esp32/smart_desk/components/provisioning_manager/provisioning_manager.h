enum
{
    WIFI_PROV_MANAGER_INIT, // raised when the wifi provisioning manager needs to be initialized
};

void register_provisioning_manager_event_handlers();
void start_wifi_provisioning();
