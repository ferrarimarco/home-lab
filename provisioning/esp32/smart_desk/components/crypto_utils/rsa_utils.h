struct RsaKeyGenerationOptions
{
    int key_size;                  /* length of key in bits                */
    const char *private_key_filename; /* filename of the key file             */
    const char *public_key_filename;  /* filename of the key file             */
};

#define DEFAULT_RSA_KEY_SIZE 4096
#define DEFAULT_RSA_PRIVATE_KEY_FILENAME "rsa_private_key.pem"
#define DEFAULT_RSA_PUBLIC_KEY_FILENAME "rsa_public_key.pem"

int generate_rsa_keypair(struct RsaKeyGenerationOptions rsa_key_generation_options);
