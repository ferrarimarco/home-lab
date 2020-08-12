idf_component_register(SRCS "smart_desk_main.c"
    INCLUDE_DIRS ""
    REQUIRES debug_utils crypto_utils i2c_manager network_manager storage_manager provisioning_manager gpio_manager)
