
#include <windows.h>

#if defined(__MINGW32__) || !defined(WINAPI_FAMILY_PARTITION) || !defined(WINAPI_PARTITION_DESKTOP)
#define MBEDTLS_WINDOWS_DESKTOP 1
#elif defined(WINAPI_FAMILY_PARTITION)
#if defined(WINAPI_PARTITION_DESKTOP) && WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)
#define MBEDTLS_WINDOWS_DESKTOP 1
#elif defined(WINAPI_PARTITION_PHONE_APP) && WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_PHONE_APP)
#define MBEDTLS_WINDOWS_PHONE 1
#elif defined(WINAPI_PARTITION_APP) && WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)
#define MBEDTLS_WINDOWS_UNIVERSAL 1
#endif
#endif

#ifdef MBEDTLS_WINDOWS_UNIVERSAL

using namespace Windows::Storage::Streams;
using namespace Windows::Security::Cryptography;

extern "C" int mbedtls_platform_entropy_poll(void *data, unsigned char *output, size_t len, size_t *olen) {
	IBuffer ^buffer = CryptographicBuffer::GenerateRandom(len);
	Platform::Array<unsigned char> ^outputByteArray;
	CryptographicBuffer::CopyToByteArray(buffer, &outputByteArray);
	memcpy(output, outputByteArray->Data, len);
	*olen = len;
	return 0;
}

#endif
