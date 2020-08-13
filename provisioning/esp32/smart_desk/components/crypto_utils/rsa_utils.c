#include "rsa_utils.h"

#include "freertos/FreeRTOS.h"
#include "esp_log.h"

static const char *TAG = "rsa_utils";

#include "mbedtls/config.h"

#include "mbedtls/platform.h"

#include "mbedtls/error.h"
#include "mbedtls/pk.h"
#include "mbedtls/rsa.h"
#include "mbedtls/error.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"

#include "nvs_manager.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <unistd.h>

static int write_key_pair(mbedtls_pk_context *key, const char *storage_namespace, const char *private_key_file_path, const char *public_key_file_path)
{
    int ret;
    int output_buf_size = 16000;
    unsigned char output_buf[output_buf_size];

    ESP_LOGI(TAG, "Writing private key...");
    memset(output_buf, 0, output_buf_size);
    if ((ret = mbedtls_pk_write_key_pem(key, output_buf, output_buf_size)) != 0)
    {
        memset(output_buf, 0, output_buf_size);
        ESP_LOGE(TAG, "mbedtls_pk_write_key_pem returned %d", ret);
        return ret;
    }
    // Add 1 to hold the null-termination character
    size_t key_size = strlen((char *)output_buf) + 1;
    ESP_LOGI(TAG, "Saving private key to non-volatile storage...");
    ESP_ERROR_CHECK(save_blob(storage_namespace, private_key_file_path, output_buf, key_size));

    ESP_LOGI(TAG, "Writing public key...");
    memset(output_buf, 0, output_buf_size);
    if ((ret = mbedtls_pk_write_pubkey_pem(key, output_buf, output_buf_size)) != 0)
    {
        memset(output_buf, 0, output_buf_size);
        ESP_LOGE(TAG, "mbedtls_pk_write_pubkey_pem returned %d", ret);
        return ret;
    }
    key_size = strlen((char *)output_buf) + 1;
    ESP_LOGI(TAG, "Saving public key to non-volatile storage...");
    ESP_ERROR_CHECK(save_blob(storage_namespace, public_key_file_path, output_buf, key_size));

    memset(output_buf, 0, output_buf_size);
    return 0;
}

int generate_rsa_keypair(struct RsaKeyGenerationOptions rsa_key_generation_options)
{
    int ret = 1;
    int exit_code = MBEDTLS_EXIT_FAILURE;
    mbedtls_pk_context key;
    mbedtls_mpi N, P, Q, D, E, DP, DQ, QP;
    mbedtls_entropy_context entropy;

    ESP_LOGI(TAG, "Initializing contexts...");

    mbedtls_mpi_init(&N);
    mbedtls_mpi_init(&P);
    mbedtls_mpi_init(&Q);
    mbedtls_mpi_init(&D);
    mbedtls_mpi_init(&E);
    mbedtls_mpi_init(&DP);
    mbedtls_mpi_init(&DQ);
    mbedtls_mpi_init(&QP);

    mbedtls_pk_init(&key);

    mbedtls_ctr_drbg_context ctr_drbg;
    mbedtls_ctr_drbg_init(&ctr_drbg);

    char buf[1024];
    memset(buf, 0, sizeof(buf));

    ESP_LOGI(TAG, "Seeding the random number generator...");
    mbedtls_entropy_init(&entropy);
    if ((ret = mbedtls_ctr_drbg_seed(&ctr_drbg, mbedtls_entropy_func, &entropy, NULL, 0)) != 0)
    {
        ESP_LOGE(TAG, "mbedtls_ctr_drbg_seed returned %d", ret);
        goto exit;
    }

    ESP_LOGI(TAG, "Initializing key context...");
    if ((ret = mbedtls_pk_setup(&key, mbedtls_pk_info_from_type(MBEDTLS_PK_RSA))) != 0)
    {
        ESP_LOGE(TAG, "mbedtls_pk_info_from_type returned %d", ret);
        goto exit;
    }

    ESP_LOGI(TAG, "Generating the private key...");
    ret = mbedtls_rsa_gen_key(mbedtls_pk_rsa(key), mbedtls_ctr_drbg_random, &ctr_drbg, rsa_key_generation_options.key_size, 65537);
    if (ret != 0)
    {
        ESP_LOGE(TAG, "mbedtls_rsa_gen_key returned %d", ret);
        goto exit;
    }

    ESP_LOGI(TAG, "Retrieving the RSA context...");
    mbedtls_rsa_context *rsa = mbedtls_pk_rsa(key);

    ESP_LOGI(TAG, "Exporting RSA key parameters...");
    if ((ret = mbedtls_rsa_export(rsa, &N, &P, &Q, &D, &E)) != 0 ||
        (ret = mbedtls_rsa_export_crt(rsa, &DP, &DQ, &QP)) != 0)
    {
        ESP_LOGE(TAG, "Could not export RSA parameters");
        goto exit;
    }

    ESP_LOGI(TAG, "Writing key pair to file...");
    if ((ret = write_key_pair(&key, rsa_key_generation_options.storage_namespace, rsa_key_generation_options.private_key_filename, rsa_key_generation_options.public_key_filename)) != 0)
    {
        ESP_LOGE(TAG, "write_private_key returned %d", ret);
        goto exit;
    }

    ESP_LOGI(TAG, "Key generated successfully.");
    exit_code = MBEDTLS_EXIT_SUCCESS;
exit:
    mbedtls_mpi_free(&N);
    mbedtls_mpi_free(&P);
    mbedtls_mpi_free(&Q);
    mbedtls_mpi_free(&D);
    mbedtls_mpi_free(&E);
    mbedtls_mpi_free(&DP);
    mbedtls_mpi_free(&DQ);
    mbedtls_mpi_free(&QP);

    mbedtls_pk_free(&key);
    mbedtls_ctr_drbg_free(&ctr_drbg);
    mbedtls_entropy_free(&entropy);

    return exit_code;
}
