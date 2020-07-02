void i2c_master_driver_initialize(uint8_t sda_pin, uint8_t scl_pin, uint8_t i2c_frequency);
void i2c_master_write_byte_to_client_ack(uint8_t client_address, uint8_t data);
int do_i2cdetect();
int do_i2cget(uint8_t chip_address, int8_t register_address, uint8_t data_length);
int do_i2cdump(uint8_t chip_address, uint8_t read_size);
