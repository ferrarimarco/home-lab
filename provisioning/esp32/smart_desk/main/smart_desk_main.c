#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#include "esp_event.h"
#include "esp_log.h"
#include "esp_spi_flash.h"
#include "esp_system.h"
#include "esp_task_wdt.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "sdkconfig.h"

#include "app_info.h"
#include "board_info.h"
#include "hd_44780.h"
#include "i2c_utils.h"
#include "relay_board.h"
#include "rsa_utils.h"
#include "ultrasonic.h"

#include "actuators_controller.h"
#include "ip_address_manager.h"
#include "nvs_manager.h"
#include "provisioning_manager.h"
#include "wifi_connection_manager.h"

#define SDA_PIN 23
#define SCL_PIN 22
// The PCF8574 has a 100 kHz I2C interface
#define I2C_MASTER_CLOCK_FREQUENCY_HZ 100000

#define LCD_ADDR 0x27
#define LCD_COLS 20
#define LCD_ROWS 4

#define ULTRASONIC_MAX_DISTANCE_CM 400  // 4m max
#define ULTRASONIC_MIN_DISTANCE_CM 2    // 2cm min
#define ULTRASONIC_TRIGGER_GPIO GPIO_NUM_27
#define ULTRASONIC_ECHO_GPIO GPIO_NUM_15

#define RELAY_COUNT 4
#define RELAY_1_GPIO GPIO_NUM_33
#define RELAY_2_GPIO GPIO_NUM_32
#define RELAY_3_GPIO GPIO_NUM_14
#define RELAY_4_GPIO GPIO_NUM_12

#define RSA_KEY_GEN_STACK_SIZE 25000
#define RSA_KEY_GEN_TASK_PRIORITY 2
#define RSA_KEY_SIZE DEFAULT_RSA_KEY_SIZE
#define RSA_KEY_STORAGE_NAMESPACE DEFAULT_RSA_KEY_STORAGE_NAMESPACE

#define ACTUATORS_COUNT 2

// The controller is on the floor, enclosed in a box,
// and the distance sensor is on one side of the box.
//
// 110 cm --------- Desk top (@ max extension)
//
// 75 cm  --------- Desk top
//        |       |
// 16 cm  |   ^   | distance sensor
//        |  | |  |
//  0 cm  --------- Floor

#define MAX_ACTUATORS_EXTENSION_CM 35                                       // Maximum actuators extension
#define MIN_DESK_HEIGHT_CM 70                                               // Minimum distance between the floor and (bottom of) the desk top
#define MAX_DESK_HEIGHT_CM MIN_DESK_HEIGHT_CM + MAX_ACTUATORS_EXTENSION_CM  // Moximum distance between the floor and the (bottom of) desk top

#define CONTROLLER_ENCLOSURE_HEIGHT_CM 16                                    // Distance between the distance sensor and the floor
#define MIN_DISTANCE_CM MIN_DESK_HEIGHT_CM - CONTROLLER_ENCLOSURE_HEIGHT_CM  // Minimum distance between the distance sensor and the desk top
#define MAX_DISTANCE_CM MIN_DISTANCE_CM + MAX_ACTUATORS_EXTENSION_CM         // Maximum distance between the distance sensor and the desk top
#define TOLERANCE_EXTENSION_CM 2

static const char *TAG = "smart_desk";

// Need this in both CPU tasks
static ultrasonic_sensor_t ultrasonic_sensor = {
    .trigger_pin = ULTRASONIC_TRIGGER_GPIO,
    .echo_pin = ULTRASONIC_ECHO_GPIO,
    .min_distance = ULTRASONIC_MIN_DISTANCE_CM,
    .max_distance = ULTRASONIC_MAX_DISTANCE_CM};

void vCpu1Task(void *pvParameters)
{
    struct RsaKeyGenerationOptions *rsa_key_gen_parameters = (struct RsaKeyGenerationOptions *)pvParameters;
    const char *rsa_storage_namespace = rsa_key_gen_parameters->storage_namespace;
    const char *rsa_public_key_filename = rsa_key_gen_parameters->public_key_filename;
    if (!blob_exists(rsa_storage_namespace, rsa_public_key_filename) || !blob_exists(rsa_storage_namespace, rsa_key_gen_parameters->private_key_filename))
    {
        ESP_LOGI(TAG, "Generating RSA keypair...");
        generate_rsa_keypair(*rsa_key_gen_parameters);
    }

    size_t public_key_length = 0;
    ESP_ERROR_CHECK(get_blob_length(rsa_storage_namespace, rsa_public_key_filename, &public_key_length));
    char *rsa_public_key = malloc(public_key_length + 1);
    ESP_ERROR_CHECK(load_blob(rsa_storage_namespace, rsa_public_key_filename, (void *)rsa_public_key, public_key_length));
    ESP_LOGI(TAG, "RSA Public key (length: %u):\n%s", public_key_length, rsa_public_key);
    free(rsa_public_key);

    esp_task_wdt_add(xTaskGetIdleTaskHandleForCPU(1));

    ESP_LOGI(TAG, "Starting to measure distance...");
    // FreeRTOS tasks must not terminate
    while (true)
    {
        uint32_t distance;
        esp_err_t res = ultrasonic_measure_cm(&ultrasonic_sensor, &distance);
        if (res == ESP_OK)
            ESP_LOGD(TAG, "Measured distance: %d cm", distance);

        vTaskDelay(100 / portTICK_PERIOD_MS);
    }
}

void app_main(void)
{
    ESP_ERROR_CHECK(i2c_master_driver_initialize(SDA_PIN, SCL_PIN, I2C_MASTER_CLOCK_FREQUENCY_HZ));

    esp_err_t ret;
    char err_msg[20];

    do
    {
        if ((ret = i2c_detect_device(LCD_ADDR)) != ESP_OK)
        {
            ESP_LOGE(TAG, "%s during I2C device detection at address 0x%02x. Retrying...", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)), LCD_ADDR);
        }
    } while (ret != ESP_OK);

    do
    {
        // i2c expander - LCD Pin mappings
        // P0 -> RS
        // P1 -> RW
        // P2 -> E
        // P3 -> Backlight (b)
        // P4 -> D4
        // P5 -> D5
        // P6 -> D6
        // P7 -> D7
        if ((ret = LCD_init(LCD_ADDR, LCD_COLS, LCD_ROWS, 2, 1, 0, 4, 5, 6, 7, 3, LCD_FUNCTION_SET_4_BIT)) != ESP_OK)
        {
            ESP_LOGE(TAG, "%s during LCD (I2C address 0x%02x) initialization. Retrying...", esp_err_to_name_r(ret, err_msg, sizeof(err_msg)), LCD_ADDR);
        }
    } while (ret == ESP_FAIL || ret == ESP_ERR_TIMEOUT);

    bool lcd_available = true;
    if (ret == ESP_FAIL)
    {
        lcd_available = false;
        ESP_LOGW(TAG, "The LCD (I2C address 0x%02x) is not available.", LCD_ADDR);
    }

    esp_chip_info_t chip_info;
    esp_chip_info(&chip_info);
    get_board_info(chip_info, spi_flash_get_chip_size(), esp_get_free_heap_size());

    get_app_info();

    ESP_LOGI(TAG, "Creating the default loop...");
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    ESP_LOGI(TAG, "Initializing the non-volatile storage flash...");
    ESP_ERROR_CHECK(initialize_nvs_flash());

    if (lcd_available)
    {
        ESP_LOGI(TAG, "Preparing the default LCD visualization...");
        LCD_clearScreen();
        LCD_home();
        LCD_writeStr("IP: ");
        LCD_setCursor(0, 1);
        LCD_writeStr("Distance:     cm");
    }

    ESP_LOGI(TAG, "Registering event handlers...");
    register_wifi_manager_event_handlers();
    register_ip_address_manager_event_handlers();
    register_provisioning_manager_event_handlers();

    if (lcd_available)
    {
        ESP_LOGI(TAG, "Registering LCD event handlers...");
        ESP_ERROR_CHECK(register_lcd_events());
    }

    get_tasks_info();

    ESP_LOGI(TAG, "Initializing the distance sensor...");
    ultrasonic_init(&ultrasonic_sensor);

    struct RsaKeyGenerationOptions rsa_key_generation_options = {
        RSA_KEY_SIZE,
        DEFAULT_RSA_PRIVATE_KEY_FILENAME,
        DEFAULT_RSA_PUBLIC_KEY_FILENAME,
        RSA_KEY_STORAGE_NAMESPACE};
    xTaskCreatePinnedToCore(vCpu1Task, "cpu1_heavy", RSA_KEY_GEN_STACK_SIZE, &rsa_key_generation_options, RSA_KEY_GEN_TASK_PRIORITY, NULL, 1);

    start_wifi_provisioning();

    size_t relays_num = RELAY_COUNT;
    struct Relay *relays;
    uint8_t relay_pins[] = {RELAY_1_GPIO, RELAY_2_GPIO, RELAY_3_GPIO, RELAY_4_GPIO};
    ESP_ERROR_CHECK(init_relays(relay_pins, relays_num, &relays));
    ESP_LOGI(TAG, "Completed relays initialization. Pointer to relays array: %p", relays);

    struct Actuator **actuators;
    size_t actuators_num = relays_num / 2;
    ESP_ERROR_CHECK(init_actuators(relays, relays_num, &actuators, actuators_num));
    ESP_LOGI(TAG, "Completed actuators initialization. Pointer to actuators pointers array: %p", actuators);

    ESP_ERROR_CHECK(register_actuators_events(actuators, actuators_num));

    uint32_t distance;
    ESP_ERROR_CHECK(ultrasonic_measure_cm(&ultrasonic_sensor, &distance));
    ESP_LOGI(TAG, "Max reachable distance: %u cm, min reachable distance: %u cm, current distance: %u cm", MAX_DISTANCE_CM, MIN_DISTANCE_CM, distance);

    if (distance <= MIN_DISTANCE_CM)
    {
        ESP_ERROR_CHECK(start_actuators_extension(MAX_DISTANCE_CM));
    }
    else
    {
        ESP_ERROR_CHECK(start_actuators_retraction(MIN_DISTANCE_CM - TOLERANCE_EXTENSION_CM));
    }
}
