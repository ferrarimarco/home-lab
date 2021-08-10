#ifndef PROVISIONING_ESP32_SMART_DESK_COMPONENTS_CRYPTO_UTILS_RSA_UTILS_H_
#define PROVISIONING_ESP32_SMART_DESK_COMPONENTS_CRYPTO_UTILS_RSA_UTILS_H_

struct RsaKeyGenerationOptions
{
    int key_size;                     /* length of key in bits                */
    const char *private_key_filename; /* filename of the key file             */
    const char *public_key_filename;  /* filename of the key file             */
    const char *storage_namespace;    /* namespace of the NVS storage where keys have to be stored */
};

#define DEFAULT_RSA_KEY_SIZE 4096
#define DEFAULT_RSA_PRIVATE_KEY_FILENAME "private_key.pem"
#define DEFAULT_RSA_PUBLIC_KEY_FILENAME "public_key.pem"
#define DEFAULT_RSA_KEY_STORAGE_NAMESPACE "rsa_keys"

int generate_rsa_keypair(struct RsaKeyGenerationOptions rsa_key_generation_options);

#endif  // PROVISIONING_ESP32_SMART_DESK_COMPONENTS_CRYPTO_UTILS_RSA_UTILS_H_
