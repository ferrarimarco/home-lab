/* Example test application for testable component.

   This example code is in the Public Domain (or CC0 licensed, at your option.)

   Unless required by applicable law or agreed to in writing, this
   software is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
   CONDITIONS OF ANY KIND, either express or implied.
*/

#include <stdio.h>
#include <string.h>
#include "unity.h"
#include "esp_log.h"
#include "esp_event.h"

static const char *TAG = "smart_desk_test";

static void print_banner(const char *text);

void app_main(void)
{
    ESP_LOGI(TAG, "Creating the default loop...");
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    print_banner("Running all the registered tests");
    UNITY_BEGIN();
    unity_run_all_tests();
    UNITY_END();

    print_banner("Starting interactive test menu");
    unity_run_menu();
}

static void print_banner(const char *text)
{
    printf("\n#### %s #####\n\n", text);
}
