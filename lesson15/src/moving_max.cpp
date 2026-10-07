#include <climits>
#include "moving_max.h"

/* Ковзний максимум: out_data[n] = найбільше з останніх WINDOW відліків,
   разом із поточним відліком n.

   Дві версії з одного файлу (вибір -- у hls_config.cfg компонента):
     hls/nopipe -- без директив, syn.compile.pipeline_loops=0 (автоконвеєризацію вимкнено);
     hls/pipe   -- те саме + syn.cflags=-DMM_PIPELINE  ->  #pragma HLS PIPELINE II=1 у MAIN_LOOP. */
void moving_max(int in_data[N_SAMPLES], int out_data[N_SAMPLES]) {
    int window[WINDOW];      /* останні WINDOW відліків, window[0] -- найновіший */

INIT_LOOP:
    for (int k = 0; k < WINDOW; k++) {
        window[k] = INT_MIN; /* "порожні" позиції ніколи не виграють -> для n<7 максимум з наявних */
    }

MAIN_LOOP:
    for (int n = 0; n < N_SAMPLES; n++) {
#ifdef MM_PIPELINE
#pragma HLS PIPELINE II=1
#endif
    SHIFT_LOOP:
        for (int k = WINDOW - 1; k > 0; k--) {
            window[k] = window[k - 1];
        }

        window[0] = in_data[n];  /* єдине читання in_data[n] */

        int m = window[0];
    MAX_LOOP:
        for (int k = 1; k < WINDOW; k++) {
            if (window[k] > m) m = window[k];
        }
        out_data[n] = m;
    }
}
