#include <stdio.h>
#include "sdkconfig.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "driver/i2c.h"
#include "esp32/rom/ets_sys.h"

#include "hd_44780.h"

#include "print_utils.h"

static const char *TAG = "hd_44780";

static uint8_t LCD_addr;
static uint8_t LCD_cols;
static uint8_t LCD_rows;

void LCD_writeNibble(uint8_t nibble, uint8_t mode, uint8_t reg)
{
    uint8_t data = (nibble & 0xF0) | mode | LCD_BACKLIGHT_ON;
    ESP_LOGI(TAG, "Writing nibble: " NIBBLE_TO_BINARY_PATTERN, NIBBLE_TO_BINARY(data));

    i2c_cmd_handle_t cmd = i2c_cmd_link_create();
    ESP_ERROR_CHECK(i2c_master_start(cmd));
    ESP_ERROR_CHECK(i2c_master_write_byte(cmd, (LCD_addr << 1) | I2C_MASTER_WRITE, 1));
    ESP_ERROR_CHECK(i2c_master_write_byte(cmd, data, 1));
    ESP_ERROR_CHECK(i2c_master_stop(cmd));
    ESP_ERROR_CHECK(i2c_master_cmd_begin(I2C_NUM_0, cmd, 1000 / portTICK_PERIOD_MS));
    i2c_cmd_link_delete(cmd);

    // Clock data into LCD
    // was LCD_pulseEnable(data)
    cmd = i2c_cmd_link_create();
    ESP_ERROR_CHECK(i2c_master_start(cmd));
    ESP_ERROR_CHECK(i2c_master_write_byte(cmd, (LCD_addr << 1) | I2C_MASTER_WRITE, 1));
    ESP_ERROR_CHECK(i2c_master_write_byte(cmd, data | LCD_ENABLE_ON, 1));
    ESP_ERROR_CHECK(i2c_master_stop(cmd));
    ESP_ERROR_CHECK(i2c_master_cmd_begin(I2C_NUM_0, cmd, 1000 / portTICK_PERIOD_MS));
    i2c_cmd_link_delete(cmd);
    ets_delay_us(1);

    cmd = i2c_cmd_link_create();
    ESP_ERROR_CHECK(i2c_master_start(cmd));
    ESP_ERROR_CHECK(i2c_master_write_byte(cmd, (LCD_addr << 1) | I2C_MASTER_WRITE, 1));
    ESP_ERROR_CHECK(i2c_master_write_byte(cmd, (data & ~LCD_ENABLE_ON), 1));
    ESP_ERROR_CHECK(i2c_master_stop(cmd));
    ESP_ERROR_CHECK(i2c_master_cmd_begin(I2C_NUM_0, cmd, 1000 / portTICK_PERIOD_MS));
    i2c_cmd_link_delete(cmd);
    ets_delay_us(500);
}

void LCD_writeByte(uint8_t data, uint8_t mode, uint8_t reg)
{
    ESP_LOGI(TAG, "Writing byte: " BYTE_TO_BINARY_PATTERN, BYTE_TO_BINARY(data));

    LCD_writeNibble(data & 0xF0, mode, reg);
    LCD_writeNibble((data << 4) & 0xF0, mode, reg);
}

void LCD_init(uint8_t addr, uint8_t cols, uint8_t rows)
{
    ESP_LOGI(TAG, "Initializing the LCD screen...");

    LCD_addr = addr;
    LCD_cols = cols;
    LCD_rows = rows;
    vTaskDelay(100 / portTICK_RATE_MS); // Initial 40 mSec delay

    ESP_LOGI(TAG, "Resetting the LCD controller...");
    LCD_writeNibble(LCD_FUNCTION_RESET, LCD_WRITE_MODE, LCD_INSTRUCTION_REGISTER); // First part of reset sequence
    vTaskDelay(10 / portTICK_RATE_MS);                                             // 4.1 mS delay (min)
    LCD_writeNibble(LCD_FUNCTION_RESET, LCD_WRITE_MODE, LCD_INSTRUCTION_REGISTER); // second part of reset sequence
    ets_delay_us(200);                                                             // 100 uS delay (min)
    LCD_writeNibble(LCD_FUNCTION_RESET, LCD_WRITE_MODE, LCD_INSTRUCTION_REGISTER); // Third time's a charm

    ESP_LOGI(TAG, "Setting LCD function...");
    LCD_writeByte(LCD_FUNCTION_SET | LCD_FUNCTION_SET_4_BIT | LCD_FUNCTION_SET_2_LINES | LCD_FUNCTION_SET_5X8, LCD_WRITE_MODE, LCD_INSTRUCTION_REGISTER);
    ets_delay_us(80);

    ESP_LOGI(TAG, "Turning the LCD ON...");
    LCD_writeByte(LCD_DISPLAY_ON_OFF | LCD_DISPLAY_ON_OFF_DISPLAY_ON | LCD_DISPLAY_ON_OFF_CURSOR_OFF | LCD_DISPLAY_ON_OFF_BLINK_OFF, LCD_WRITE_MODE, LCD_INSTRUCTION_REGISTER);
    ets_delay_us(80);

    LCD_clearScreen();

    // shift cursor from left to right on read/write
    ESP_LOGI(TAG, "Setting LCD entry mode...");
    LCD_writeByte(LCD_ENTRY_MODE_SET | LCD_ENTRY_MODE_SET_INCREMENT_DDRAM_ADDRESS, LCD_WRITE_MODE, LCD_INSTRUCTION_REGISTER);
    ets_delay_us(80);
}

void LCD_setCursor(uint8_t col, uint8_t row)
{
    ESP_LOGI(TAG, "Set cursor to col %d, row %d", col, row);
    if (row > LCD_rows - 1)
    {
        ESP_LOGE(TAG, "Cannot write to row %d. Please select a row in the range (0, %d)", row, LCD_rows - 1);
        row = LCD_rows - 1;
    }
    uint8_t row_offsets[] = {LCD_LINEONE, LCD_LINETWO, LCD_LINETHREE, LCD_LINEFOUR};
    LCD_writeByte(LCD_SET_DDRAM_ADDRESS | (col + row_offsets[row]), LCD_WRITE_MODE, LCD_INSTRUCTION_REGISTER);
}

void LCD_writeChar(char c)
{
    ESP_LOGI(TAG, "Write char: %c", c);
    LCD_writeByte(c, LCD_WRITE_MODE, LCD_DATA_REGISTER);
}

void LCD_writeStr(char *str)
{
    ESP_LOGI(TAG, "Write string: %s", str);
    while (*str)
    {
        LCD_writeChar(*str++);
    }
}

void LCD_home(void)
{
    ESP_LOGI(TAG, "Return the cursor home");
    LCD_writeByte(LCD_RETURN_HOME, LCD_WRITE_MODE, LCD_INSTRUCTION_REGISTER);
    vTaskDelay(2 / portTICK_RATE_MS); // This command takes a while to complete
}

void LCD_clearScreen(void)
{
    ESP_LOGI(TAG, "Clearing the LCD...");
    LCD_writeByte(LCD_CLEAR_DISPLAY, LCD_WRITE_MODE, LCD_INSTRUCTION_REGISTER);
    vTaskDelay(2 / portTICK_RATE_MS); // This command takes a while to complete
}

void LCD_Demo()
{
    ESP_LOGI(TAG, "Showing the LCD demo...");
    char txtBuf[11];
    while (true)
    {
        int row = 0, col = 0;
        // LCD_home();
        // LCD_clearScreen();
        vTaskDelay(1000 / portTICK_RATE_MS);
        // LCD_writeStr("----- 20x4 LCD -----");
        // LCD_setCursor(0, 1);
        // LCD_writeStr("LCD Library Demo");
        // LCD_setCursor(12, 3);
        // LCD_writeStr("Time: ");
        // for (int i = 10; i >= 0; i--)
        // {
        //     LCD_setCursor(18, 3);
        //     sprintf(txtBuf, "%02d", i);
        //     LCD_writeStr(txtBuf);
        //     vTaskDelay(1000 / portTICK_RATE_MS);
        // }

        // for (int i = 0; i < 80; i++)
        // {
        //     LCD_clearScreen();
        //     LCD_setCursor(col, row);
        //     LCD_writeChar('*');

        //     if (i >= 19)
        //     {
        //         row = (i + 1) / 20;
        //     }
        //     if (col++ >= 19)
        //     {
        //         col = 0;
        //     }

        //     vTaskDelay(50 / portTICK_RATE_MS);
        // }
    }
}
