idf_component_register(SRCS "board_info.c" "app_info.c"
    INCLUDE_DIRS "."
    REQUIRES app_update spi_flash)
