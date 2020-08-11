#include <stdio.h>
#include <string.h>

#include "esp_ota_ops.h"

#include "app_info.h"

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

char *get_app_info()
{
    const esp_app_desc_t *app_description = esp_ota_get_app_description();

    int app_info_size = 250 * sizeof(char);
    char *app_info = (char *)malloc(app_info_size);

    const int sha256_hex_len = 64;
    char ref_sha256[sha256_hex_len + 1];
    for (int i = 0; i < sizeof(ref_sha256) / 2; ++i)
    {
        snprintf(ref_sha256 + 2 * i, 3, "%02x", app_description->app_elf_sha256[i]);
    }
    ref_sha256[sha256_hex_len] = 0;

    sprintf(app_info, "Application version: %s. IDF version: %s. Compile time and date: %s %s. SHA256 of the ELF: %s\n",
        app_description->version,
        app_description->idf_ver,
        app_description->time,
        app_description->date,
        ref_sha256);

    return app_info;
}

char *get_tasks_info()
{
    const size_t bytes_per_task = 40; /* see vTaskList description */
    const size_t task_list_buffer_size = uxTaskGetNumberOfTasks() * bytes_per_task;
    char *task_list_buffer = malloc(task_list_buffer_size);

    int task_info_size = 60 + task_list_buffer_size;
    char *task_info = (char *)malloc(task_info_size);
    vTaskList(task_list_buffer);

    sprintf(task_info, "\nTask Name\tStatus\tPrio\tHWM\tTask#\tAffinity\n%s", task_list_buffer);
    free(task_list_buffer);

    return task_info;
}
