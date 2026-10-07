#include <stdio.h>
#include <climits>
#include "moving_max.h"

/* Еталон: прямий перебір за правилом out[n] = max(in[max(0,n-7)] ... in[n]),
   без вікна-регістра зсуву і без INT_MIN -- інша реалізація, ніж у moving_max. */
static void reference(const int x[N_SAMPLES], int y[N_SAMPLES]) {
    for (int n = 0; n < N_SAMPLES; n++) {
        int lo = n - (WINDOW - 1);
        if (lo < 0) lo = 0;
        int m = x[lo];
        for (int i = lo + 1; i <= n; i++) {
            if (x[i] > m) m = x[i];
        }
        y[n] = m;
    }
}

static unsigned seed = 12345;
static int rnd() {                     /* простий повторюваний генератор, 31 біт */
    seed = seed * 1103515245u + 12345u;
    return (int)(seed >> 1);
}

#define N_VECTORS 7
static const char *NAMES[N_VECTORS] = {
    "random 0..999", "random signed (full int range)", "ascending", "descending",
    "constant -5", "alternating INT_MIN/INT_MAX", "single spikes + negatives"
};

static void make_vector(int v, int x[N_SAMPLES]) {
    for (int n = 0; n < N_SAMPLES; n++) {
        switch (v) {
        case 0: x[n] = rnd() % 1000; break;
        case 1: x[n] = (int)((unsigned)rnd() << 1 ^ (unsigned)rnd()); break;
        case 2: x[n] = 3 * n - 50; break;
        case 3: x[n] = 1000 - 7 * n; break;
        case 4: x[n] = -5; break;
        case 5: x[n] = (n & 1) ? INT_MAX : INT_MIN; break;
        default: x[n] = (n % 11 == 3) ? 100 + n : -1000 - n; break;
        }
    }
    if (v == 6) x[0] = INT_MIN;        /* перший відлік -- мінімально можливий int */
}

int main() {
    int errors = 0;

    for (int v = 0; v < N_VECTORS; v++) {
        int in_data[N_SAMPLES], out_data[N_SAMPLES], golden[N_SAMPLES];

        make_vector(v, in_data);
        reference(in_data, golden);
        moving_max(in_data, out_data);

        int bad = 0;
        for (int n = 0; n < N_SAMPLES; n++) {
            if (out_data[n] != golden[n]) {
                if (bad < 5)
                    printf("MISMATCH: вектор %d, відлік %d: in=%d DUT=%d, еталон=%d\n",
                           v, n, in_data[n], out_data[n], golden[n]);
                bad++;
            }
        }
        printf("vector %d (%s): %s\n", v, NAMES[v], bad ? "FAIL" : "ok");
        errors += bad;
    }

    if (errors == 0) {
        printf("Test passed !\n");
        return 0;
    }
    printf("Test FAILED: %d помилок\n", errors);
    return 1;
}
