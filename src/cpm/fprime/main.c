#include <stdio.h>
#include <stdlib.h>
#include <cpm.h>

#define MAX_PRIMES 3000

#define CTRL_C 3

/*
 * Check for CTRL-C using BDOS function 6 (direct console I/O) with
 * E=0xFF, which returns a character if one is ready or 0 if not — a
 * single non-blocking read with no buffer draining. This is safe under
 * emulators with piped stdin (unlike getk(), which loops draining the
 * entire keyboard buffer). On real hardware it polls the keyboard
 * exactly once per call.
 */
static int check_break(void)
{
    return bdos(CPM_DCIO, 0xFF) == CTRL_C;
}

static int is_prime(long n, const long *primes, int count)
{
    int i;
    for (i = 0; i < count; i++) {
        long d = primes[i];
        if (d * d > n)
            return 1;
        if (n % d == 0)
            return 0;
    }
    return 1;
}

int main(void)
{
    long limit;
    long n;
    int count;
    long *primes;

    printf("MAX NUMBER TO CHECK\n");
    scanf("%ld", &limit);
    if (limit < 2)
        return 0;

    primes = malloc(MAX_PRIMES * sizeof(long));
    if (!primes)
        return 1;

    count = 0;
    primes[count++] = 2;
    printf("%ld ", 2L);

    for (n = 3; n <= limit; n += 2) {
        if (check_break()) {
            printf("^C\n");
            break;
        }
        if (is_prime(n, primes, count)) {
            primes[count++] = n;
            printf("%ld ", n);
        }
    }

    putchar('\n');
    free(primes);
    return 0;
}
