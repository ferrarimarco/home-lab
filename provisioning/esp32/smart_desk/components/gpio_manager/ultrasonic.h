#ifndef __ULTRASONIC_H__
#define __ULTRASONIC_H__

#include "driver/gpio.h"
#include "esp_err.h"
#include "esp_event.h"

#define ESP_ERR_ULTRASONIC_PING 0x200
#define ESP_ERR_ULTRASONIC_PING_TIMEOUT 0x201
#define ESP_ERR_ULTRASONIC_ECHO_TIMEOUT 0x202

// For events coming from the ultrasonic sensor
ESP_EVENT_DECLARE_BASE(ULTRASONIC_EVENTS);

enum
{                                       // declaration of the specific events under the ultrasonic event family
    ULTRASONIC_EVENT_MEASURE_AVAILABLE, // raised when a new measure is available
};

/**
 * Device descriptor
 */
typedef struct
{
    gpio_num_t trigger_pin;
    gpio_num_t echo_pin;
} ultrasonic_sensor_t;

/**
 * Init ranging module
 * @param dev Pointer to the device descriptor
 * @return `ESP_OK` on success
 */
esp_err_t ultrasonic_init(const ultrasonic_sensor_t *dev);

/**
 * Measure distance
 * @param dev Pointer to the device descriptor
 * @param max_distance Maximal distance to measure, centimeters
 * @param distance Distance in centimeters or ULTRASONIC_ERROR_xxx if error occured
 * @return `ESP_OK` on success
 */
esp_err_t ultrasonic_measure_cm(const ultrasonic_sensor_t *dev, uint32_t max_distance, uint32_t *distance);

void ultrasonic_sensor_demo(const ultrasonic_sensor_t *dev, uint32_t max_distance);

#endif /* __ULTRASONIC_H__ */
