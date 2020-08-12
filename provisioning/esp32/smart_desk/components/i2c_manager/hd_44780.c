#include <stdio.h>
#include "sdkconfig.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_event.h"
#include "driver/i2c.h"
#include "esp32/rom/ets_sys.h"

#include "hd_44780.h"
#include "i2c_utils.h"

#include "print_utils.h"

#include "ultrasonic.h"

static const char *TAG = "hd_44780";

static uint8_t LCD_addr;
static uint8_t LCD_cols;
static uint8_t LCD_rows;

static uint8_t _backlightPinMask;    // Backlight IO pin mask
static uint8_t _backlightStatusMask; // Backlight status mask
static uint8_t _En;                  // LCD expander word for enable pin
static uint8_t _Rw;                  // LCD expander word for R/W pin
static uint8_t _Rs;                  // LCD expander word for Register Select pin
static uint8_t _data_pins[4];        // LCD data lines

static uint8_t _displayfunction;

static void
LCD_write_4_bits(uint8_t nibble, uint8_t reg)
{
    ESP_LOGD(TAG, "Preparing 4 bits to send to the LCD: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(nibble));

    uint8_t data = 0;

    // Map the value to LCD pin mapping
    // --------------------------------
    for (uint8_t i = 0; i < 4; i++)
    {
        if ((nibble & 0x1) == 1)
        {
            data |= _data_pins[i];
        }
        nibble = (nibble >> 1);
    }

    ESP_LOGD(TAG, "Mapped the data to send to LCD data pins: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(data));

    // Is it a command or data
    // -----------------------
    if (reg == LCD_DATA_REGISTER)
    {
        reg = _Rs;
    }

    data |= reg | _backlightStatusMask;

    ESP_LOGD(TAG, "Mapped the data to send to backlight, and RS pins: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(data));

    // Clock data into LCD
    uint8_t data_enable = data | _En;
    ESP_LOGD(TAG, "Mapped the data to send to Enable pin: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(data_enable));
    i2c_master_write_byte_to_client_ack(LCD_addr, data_enable);
    ets_delay_us(1);

    uint8_t data_not_enable = data & ~_En;
    ESP_LOGD(TAG, "Mapped the data to send to NOT Enable pin: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(data_not_enable));
    i2c_master_write_byte_to_client_ack(LCD_addr, data_not_enable);
    ets_delay_us(500);
}

static void send(uint8_t value, uint8_t mode, uint8_t reg)
{
    // No need to use the delay routines since the time taken to write takes
    // longer that what is needed both for toggling and enable pin an to execute
    // the command.

    if (mode == LCD_SEND_4_BITS)
    {
        ESP_LOGD(TAG, "Sending 4 bits: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(value));
        LCD_write_4_bits((value & 0x0F), reg);
    }
    else
    {
        ESP_LOGD(TAG, "Sending 8 bits: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(value));
        LCD_write_4_bits((value >> 4), reg);
        ets_delay_us(1);
        LCD_write_4_bits((value & 0x0F), reg);
    }
}

static void setBacklight(uint8_t value)
{
    // Check if backlight is available
    // ----------------------------------------------------
    if (_backlightPinMask != 0x0)
    {
        if (value > 0)
        {
            _backlightStatusMask = _backlightPinMask & LCD_BACKLIGHT_ON_MASK;
        }
        else
        {
            _backlightStatusMask = _backlightPinMask & LCD_BACKLIGHT_OFF_MASK;
        }

        i2c_master_write_byte_to_client_ack(LCD_addr, _backlightStatusMask);

        ets_delay_us(80);
    }
}

void LCD_init(uint8_t addr, uint8_t cols, uint8_t rows, uint8_t En, uint8_t Rw, uint8_t Rs, uint8_t d4, uint8_t d5, uint8_t d6, uint8_t d7, uint8_t backligh_pin, uint8_t initial_bit_mode)
{
    ESP_LOGI(TAG, "Initializing the LCD screen...");

    LCD_addr = addr;
    LCD_cols = cols;
    LCD_rows = rows;

    _backlightPinMask = 0;
    _backlightStatusMask = LCD_BACKLIGHT_OFF_MASK;

    ESP_LOGI(TAG, "Initializing pin mappings...");
    _En = (1 << En);
    _Rw = (1 << Rw);
    _Rs = (1 << Rs);
    _data_pins[0] = (1 << d4);
    _data_pins[1] = (1 << d5);
    _data_pins[2] = (1 << d6);
    _data_pins[3] = (1 << d7);
    _backlightPinMask = (1 << backligh_pin);

    ESP_LOGI(TAG, "RS pin mask:        " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_Rs));
    ESP_LOGI(TAG, "R/W pin mask:       " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_Rw));
    ESP_LOGI(TAG, "E pin mask:         " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_En));
    ESP_LOGI(TAG, "Backlight pin mask: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_backlightPinMask));
    ESP_LOGI(TAG, "D4 pin mask:        " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_data_pins[0]));
    ESP_LOGI(TAG, "D5 pin mask:        " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_data_pins[1]));
    ESP_LOGI(TAG, "D6 pin mask:        " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_data_pins[2]));
    ESP_LOGI(TAG, "D7 pin mask:        " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_data_pins[3]));

    ESP_LOGI(TAG, "Initializing the display function...");
    _displayfunction = LCD_FUNCTION_SET;
    if (rows > 1)
    {
        ESP_LOGI(TAG, "Enabling 2-lines mode...");
        _displayfunction |= LCD_FUNCTION_SET_2_LINES;
    }

    ESP_LOGI(TAG, "Enabling 5x8 (or x7) font...");
    _displayfunction |= LCD_FUNCTION_SET_5X8;

    ESP_LOGI(TAG, "Setting interface mode (4-bits or 8-bits)...");
    _displayfunction |= initial_bit_mode;

    // SEE PAGE 45/46 of the Hitachi HD44780 datasheet FOR INITIALIZATION SPECIFICATION!
    // according to datasheet, we need at least 40ms after power rises above 2.7V
    // before sending commands.
    // ---------------------------------------------------------------------------

    ESP_LOGI(TAG, "Waiting for the Vcc to raise to 4.5V (this needs at least 40 ms)...");
    vTaskDelay(100 / portTICK_RATE_MS);

    if (!(_displayfunction & LCD_FUNCTION_SET_8_BIT))
    {
        ESP_LOGI(TAG, "Initializing the display assuming a 4-bits interface...");

        ESP_LOGI(TAG, "Sending the first command of the initialization sequence....");
        send(LCD_FUNCTION_RESET, LCD_SEND_4_BITS, LCD_INSTRUCTION_REGISTER);
        ESP_LOGI(TAG, "Waiting 5ms (at least 4.1ms wait is needed at this point)...");
        vTaskDelay(10 / portTICK_RATE_MS);
        ESP_LOGI(TAG, "Sending the second command of the initialization sequence....");
        send(LCD_FUNCTION_RESET, LCD_SEND_4_BITS, LCD_INSTRUCTION_REGISTER);
        ESP_LOGI(TAG, "Waiting 200us (at least 100us wait is needed at this point)...");
        ets_delay_us(200);
        ESP_LOGI(TAG, "Sending the third command of the initialization sequence....");
        send(LCD_FUNCTION_RESET, LCD_SEND_4_BITS, LCD_INSTRUCTION_REGISTER);
        ets_delay_us(150);

        ESP_LOGI(TAG, "Setting LCD function - Enabling 4-bit mode...");
        send(LCD_FUNCTION_SET_4_BITS_RESET, LCD_SEND_4_BITS, LCD_INSTRUCTION_REGISTER);
        vTaskDelay(5 / portTICK_RATE_MS);
    }
    else
    {
        ESP_LOGI(TAG, "Initializing the display assuming a 8-bits interface...");

        ESP_LOGI(TAG, "Sending the first command of the initialization sequence....");
        send(_displayfunction, LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER);
        ESP_LOGI(TAG, "Waiting 5ms (at least 4.1ms wait is needed at this point)...");
        vTaskDelay(10 / portTICK_RATE_MS);
        ESP_LOGI(TAG, "Sending the second command of the initialization sequence....");
        send(_displayfunction, LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER);
        ESP_LOGI(TAG, "Waiting 200us (at least 100us wait is needed at this point)...");
        ets_delay_us(200);
        ESP_LOGI(TAG, "Sending the third command of the initialization sequence....");
        send(_displayfunction, LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER);
        ets_delay_us(150);
    }

    ESP_LOGI(TAG, "Setting LCD function to 4-bit mode...");
    _displayfunction |= LCD_FUNCTION_SET_4_BIT;
    ESP_LOGI(TAG, "Display function value: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(_displayfunction));

    ESP_LOGI(TAG, "Sending the Function Set command...");
    send(_displayfunction, LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER);
    ets_delay_us(80);

    LCD_turnDisplayOff();
    LCD_clearScreen();

    ESP_LOGI(TAG, "Setting LCD entry mode...");
    send(LCD_ENTRY_MODE_SET | LCD_ENTRY_MODE_SET_INCREMENT_DDRAM_ADDRESS, LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER);
    ets_delay_us(80);

    LCD_home();
    LCD_turnDisplayOn();
    LCD_switchBacklightOn();
}

void LCD_setCursor(uint8_t col, uint8_t row)
{
    ESP_LOGD(TAG, "Set cursor to col %d, row %d", col, row);
    if (row > LCD_rows - 1)
    {
        ESP_LOGE(TAG, "Cannot write to row %d. Please select a row in the range (0, %d)", row, LCD_rows - 1);
        row = LCD_rows - 1;
    }
    uint8_t row_offsets[] ={ LCD_LINEONE, LCD_LINETWO, LCD_LINETHREE, LCD_LINEFOUR };
    send(LCD_SET_DDRAM_ADDRESS | (col + row_offsets[row]), LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER);
    ets_delay_us(80);
}

void LCD_writeChar(char c)
{
    ESP_LOGD(TAG, "Write char: %c", c);
    send(c, LCD_SEND_8_BITS, LCD_DATA_REGISTER);
    ets_delay_us(80);
}

void LCD_writeStr(const char *str)
{
    ESP_LOGD(TAG, "Write string: %s", str);
    while (*str)
    {
        LCD_writeChar(*str++);
    }
}

void LCD_switchBacklightOff(void)
{
    ESP_LOGI(TAG, "Turning backlight off...");
    setBacklight(BACKLIGHT_OFF);
}

void LCD_switchBacklightOn(void)
{
    ESP_LOGI(TAG, "Turning backlight on...");
    setBacklight(BACKLIGHT_ON);
}

void LCD_home(void)
{
    ESP_LOGI(TAG, "Returning the cursor home...");
    send(LCD_RETURN_HOME, LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER);
    vTaskDelay(2 / portTICK_RATE_MS); // This command takes a while to complete
}

void LCD_clearScreen(void)
{
    ESP_LOGI(TAG, "Clearing the LCD...");
    send(LCD_CLEAR_DISPLAY, LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER);
    vTaskDelay(3 / portTICK_RATE_MS);
}

void LCD_turnDisplayOff(void)
{
    ESP_LOGI(TAG, "Turning the Display OFF...");
    send(LCD_DISPLAY_ON_OFF | LCD_DISPLAY_ON_OFF_DISPLAY_OFF, LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER);
    ets_delay_us(80);
}

void LCD_turnDisplayOn(void)
{
    ESP_LOGI(TAG, "Turning the Display ON...");
    send(LCD_DISPLAY_ON_OFF | LCD_DISPLAY_ON_OFF_DISPLAY_ON | LCD_DISPLAY_ON_OFF_CURSOR_OFF | LCD_DISPLAY_ON_OFF_BLINK_OFF, LCD_SEND_8_BITS, LCD_INSTRUCTION_REGISTER);
    ets_delay_us(80);
}

void LCD_Demo()
{
    ESP_LOGI(TAG, "Starting the LCD demo...");

    char txtBuf[11];
    while (true)
    {
        int row = 0, col = 0;

        LCD_home();
        LCD_clearScreen();

        LCD_switchBacklightOn();
        vTaskDelay(1000 / portTICK_RATE_MS);
        LCD_switchBacklightOff();
        vTaskDelay(1000 / portTICK_RATE_MS);
        LCD_switchBacklightOn();
        vTaskDelay(1000 / portTICK_RATE_MS);
        LCD_switchBacklightOff();
        vTaskDelay(1000 / portTICK_RATE_MS);
        LCD_switchBacklightOn();

        LCD_writeStr("----- 20x4 LCD -----");
        vTaskDelay(1000 / portTICK_RATE_MS);
        LCD_setCursor(0, 1);
        LCD_writeStr("LCD Demo");
        LCD_setCursor(12, 3);
        LCD_writeStr("Time: ");
        for (int i = 10; i >= 0; i--)
        {
            LCD_setCursor(18, 3);
            sprintf(txtBuf, "%02d", i);
            LCD_writeStr(txtBuf);
            vTaskDelay(1000 / portTICK_RATE_MS);
        }

        for (int i = 0; i < 80; i++)
        {
            LCD_clearScreen();
            LCD_setCursor(col, row);
            LCD_writeChar('*');

            if (i >= 19)
            {
                row = (i + 1) / 20;
            }
            if (col++ >= 19)
            {
                col = 0;
            }

            vTaskDelay(50 / portTICK_RATE_MS);
        }
    }
}

static void sta_got_ip_event_handler(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "%s: %u sta_got_ip_event_handler", event_base, event_id);
    ip_event_got_ip_t *event = (ip_event_got_ip_t *)event_data;
    esp_ip4_addr_t ip_address = event->ip_info.ip;

    char txtBuf[16];
    sprintf(txtBuf, IPSTR, IP2STR(&ip_address));
    ESP_LOGI(TAG, "Got IP address: %s", txtBuf);
    LCD_setCursor(4, 0);
    LCD_writeStr(txtBuf);
}

static void sta_ultrasonic_sensor_measure_available_handler(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data)
{
    ESP_LOGD(TAG, "%s: %u sta_ultrasonic_sensor_measure_available_handler", event_base, event_id);
    struct DistanceMeasure distance_measure = *((struct DistanceMeasure *)event_data);
    uint32_t measured_distance = distance_measure.distance;

    char txtBuf[11];

    if (measured_distance >= distance_measure.min_valid_distance && measured_distance <= distance_measure.max_valid_distance)
    {
        ESP_LOGD(TAG, "Measured distance: %d cm", measured_distance);
        sprintf(txtBuf, "%03u", measured_distance);
    }
    else
    {
        ESP_LOGD(TAG, "Measured distance (%d) is not in a valid range", measured_distance);
        sprintf(txtBuf, "N/A");
    }

    LCD_setCursor(10, 1);
    LCD_writeStr(txtBuf);
}

void register_lcd_events()
{
    ESP_LOGI(TAG, "Registering the handler for IP_EVENT_STA_GOT_IP event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(IP_EVENT, IP_EVENT_STA_GOT_IP, sta_got_ip_event_handler, NULL, NULL));

    ESP_LOGI(TAG, "Registering the handler for IP_EVENT_STA_GOT_IP event...");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(ULTRASONIC_EVENTS, ULTRASONIC_EVENT_MEASURE_AVAILABLE, sta_ultrasonic_sensor_measure_available_handler, NULL, NULL));
}
