#include <iostream>
#include <vector>
#include <algorithm>
#include <cmath>
#include <cstdint>

using namespace std;

struct Anchor {
    int64_t ref_pos;
    int64_t query_pos;
    int32_t score;
};

vector<Anchor> chain_anchors(const vector<Anchor> &anchors, int max_dist_x, int max_dist_y, int bw, int max_skip, int max_iter, int min_sc) {
    int n = anchors.size();
    if (n == 0) return {};

    vector<int32_t> f(n, 0), p(n, -1), t(n, 0), v(n, 0);
    int64_t sum_qspan = 0;

    for (const auto &a : anchors) {
        sum_qspan += a.query_pos >> 32 & 0xff;
    }
    float avg_qspan = static_cast<float>(sum_qspan) / n;

    for (int i = 0; i < n; ++i) {
        int64_t ri = anchors[i].ref_pos;
        int64_t max_j = -1;
        int32_t qi = static_cast<int32_t>(anchors[i].query_pos), q_span = anchors[i].query_pos >> 32 & 0xff;
        int32_t max_f = q_span, n_skip = 0, min_d;
        int32_t st = 0;
        while (st < i && ri > anchors[st].ref_pos + max_dist_x) ++st;
        if (i - st > max_iter) st = i - max_iter;

        for (int j = i - 1; j >= st; --j) {
            int64_t dr = ri - anchors[j].ref_pos;
            int32_t dq = qi - static_cast<int32_t>(anchors[j].query_pos);
            int32_t dd, sc, log_dd;
            if (dq <= 0) continue;
            if (dq > max_dist_x || dr > max_dist_y) continue;
            dd = abs(dr - dq);
            if (dd > bw) continue;

            // A(j,i)
            min_d = min(dq, dr);
            sc = min_d > q_span ? q_span : min_d;
            log_dd = dd ? log2(dd) : 0;

            // Weight(j, i) = A(j,i) - B(j, i)
            sc -= static_cast<int32_t>(dd * 0.01 * avg_qspan + (log_dd >> 1));

            // Score = Score(j) + Weight(j, i)
            sc += f[j];

            if (sc > max_f) {
                max_f = sc;
                max_j = j;
                if (n_skip > 0) --n_skip;
            } else if (t[j] == i) {
                if (++n_skip > max_skip)
                    break;
            }
            if (p[j] >= 0) t[p[j]] = i;
        }
        f[i] = max_f;
        p[i] = max_j;
        v[i] = max_j >= 0 && v[max_j] > max_f ? v[max_j] : max_f;
    }

    memset(t.data(), 0, n * sizeof(int32_t));
    vector<Anchor> best_chain;
    for (int i = 0; i < n; ++i) {
        if (p[i] >= 0) t[p[i]] = 1;
    }
    for (int i = 0; i < n; ++i) {
        if (t[i] == 0 && v[i] >= min_sc) {
            int j = i;
            while (j >= 0 && f[j] < v[j]) j = p[j];
            if (j < 0) j = i;
            best_chain.push_back(anchors[j]);
        }
    }
    return best_chain;
}

int main() {
    // Example anchors
    vector<Anchor> anchors = {
        {10, 2, 1},
        {20, 3, 1},
        {30, 10, 1},
        {40, 15, 1},
        {50, 25, 1}
    };

    // Parameters for DP
    int max_dist_x = 10;
    int max_dist_y = 10;
    int bw = 5;
    int max_skip = 25;
    int max_iter = 50;
    int min_sc = 1;

    // Get best chains
    vector<Anchor> best_chain = chain_anchors(anchors, max_dist_x, max_dist_y, bw, max_skip, max_iter, min_sc);

    // Output the best chains
    cout << "Best Chain:" << endl;
    for (const auto &a : best_chain) {
        cout << "Ref: " << a.ref_pos << ", Query: " << a.query_pos << ", Score: " << a.score << endl;
    }

    return 0;
}

