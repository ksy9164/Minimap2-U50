#include <iostream>
#include <vector>
#include <algorithm>
#include <limits>

struct Anchor {
    int x, y; // Positions in the reference and query
    int w; // Weight or score
};

struct DPCell {
    int score;
    int gap_open, gap_ext;
    int long_gap_open, long_gap_ext;
};

struct AlignmentResult {
    int score;
    std::vector<int> path; // Simplified to store the path
};

// 2.2.1 Alignment with 2-Piece Affine Gap Cost
AlignmentResult alignWithAffineGapCost(const std::vector<Anchor>& anchors, const int q, const int e, const int q_prime, const int e_prime) {
    int n = anchors.size();
    std::vector<int> dp(n, 0);
    std::vector<int> path(n, -1); // To store the backtracking path

    for (int i = 1; i < n; ++i) {
        for (int j = 0; j < i; ++j) {
            int gap_cost = std::min(q + e * (anchors[i].x - anchors[j].x - 1), q_prime + e_prime * (anchors[i].x - anchors[j].x - 1));
            int score = dp[j] + anchors[i].w - gap_cost;
            if (score > dp[i]) {
                dp[i] = score;
                path[i] = j; // Store the predecessor
            }
        }
    }

    int max_score = *std::max_element(dp.begin(), dp.end());
    int max_index = std::distance(dp.begin(), std::max_element(dp.begin(), dp.end()));
    
    AlignmentResult result;
    result.score = max_score;

    // Backtrack to find the alignment path
    int current = max_index;
    while (current != -1) {
        result.path.push_back(current);
        current = path[current];
    }
    std::reverse(result.path.begin(), result.path.end());
    
    return result;
}

// 2.2.2 The Suzuki-Kasahara Formulation (Simplified)
AlignmentResult suzukiKasaharaFormulation(const std::vector<Anchor>& anchors, const int q, const int e, const int q_prime, const int e_prime) {
    int n = anchors.size();
    std::vector<int> dp(n, 0);
    std::vector<int> path(n, -1); // To store the backtracking path

    // Transform to diagonal-antidiagonal coordinates and process with SIMD-like logic
    for (int diag = 1; diag < 2 * n; ++diag) {
        for (int i = std::max(0, diag - n + 1); i < std::min(n, diag); ++i) {
            int j = diag - i;
            if (j < 0 || j >= n) continue;

            int gap_cost = std::min(q + e * (anchors[i].x - anchors[j].x - 1), q_prime + e_prime * (anchors[i].x - anchors[j].x - 1));
            int score = dp[j] + anchors[i].w - gap_cost;
            if (score > dp[i]) {
                dp[i] = score;
                path[i] = j; // Store the predecessor
            }
        }
    }

    int max_score = *std::max_element(dp.begin(), dp.end());
    int max_index = std::distance(dp.begin(), std::max_element(dp.begin(), dp.end()));
    
    AlignmentResult result;
    result.score = max_score;

    // Backtrack to find the alignment path
    int current = max_index;
    while (current != -1) {
        result.path.push_back(current);
        current = path[current];
    }
    std::reverse(result.path.begin(), result.path.end());
    
    return result;
}

void printResult(const AlignmentResult& result, const std::vector<Anchor>& anchors) {
    std::cout << "Alignment Score: " << result.score << "\nPath: ";
    for (int idx : result.path) {
        std::cout << "(" << anchors[idx].x << ", " << anchors[idx].y << ", " << anchors[idx].w << ") ";
    }
    std::cout << std::endl;
}

int main() {
    std::vector<Anchor> anchors = {{0, 0, 10}, {5, 5, 20}, {10, 10, 15}, {15, 15, 25}};
    int q = 5, e = 2, q_prime = 10, e_prime = 1;
    
    // Perform alignment with 2-piece affine gap cost
    AlignmentResult result1 = alignWithAffineGapCost(anchors, q, e, q_prime, e_prime);
    printResult(result1, anchors);

    // Perform alignment with Suzuki-Kasahara formulation
    AlignmentResult result2 = suzukiKasaharaFormulation(anchors, q, e, q_prime, e_prime);
    printResult(result2, anchors);

    return 0;
}

#include <iostream>
#include <vector>
#include <algorithm>
#include <limits>

// 점수 매개변수 정의
const int M = 10; // 최대 매칭 점수
const int q = 5;  // 갭 시작 비용
const int e = 2;  // 갭 연장 비용
const int tilde_q = 8;  // 긴 갭 시작 비용
const int tilde_e = 1;  // 긴 갭 연장 비용

// 점수 매개변수로 값을 제한하는 함수
int limit(int val, int lower, int upper) {
    return std::max(lower, std::min(upper, val));
}

// Suzuki–Kasahara 공식화 함수
void suzuki_kasahara_affine_gap(const std::vector<int>& s1, const std::vector<int>& s2) {
    int n = s1.size();
    int m = s2.size();

    // DP 테이블 초기화
    std::vector<std::vector<int>> H(n + 1, std::vector<int>(m + 1, 0));
    std::vector<std::vector<int>> E(n + 1, std::vector<int>(m + 1, 0));
    std::vector<std::vector<int>> F(n + 1, std::vector<int>(m + 1, 0));

    // 초기 값 설정
    for (int i = 1; i <= n; ++i) H[i][0] = -q - (i - 1) * e;
    for (int j = 1; j <= m; ++j) H[0][j] = -q - (j - 1) * e;

    // DP 테이블 채우기
    for (int i = 1; i <= n; ++i) {
        for (int j = 1; j <= m; ++j) {
            int match = s1[i - 1] == s2[j - 1] ? M : -M;  // 간단한 매칭 점수
            int u = limit(H[i][j] - H[i - 1][j], -q - e, M + q + e);
            int v = limit(H[i][j] - H[i][j - 1], -q - e, M + q + e);
            int x = limit(E[i - 1][j] - H[i][j], -q - e, 0);
            int y = limit(F[i][j - 1] - H[i][j], -q - e, 0);

            H[i][j] = std::max({match, x + v, y + u});
            E[i][j] = std::max(0, x + v - q) - e;
            F[i][j] = std::max(0, y + u - q) - e;
        }
    }

    // 최종 점수 출력
    std::cout << "최종 점수: " << H[n][m] << std::endl;
}

int main() {
    // 예시 서열
    std::vector<int> s1 = {1, 2, 3, 4, 5};
    std::vector<int> s2 = {1, 2, 0, 4, 5};

    // Suzuki–Kasahara 공식화 적용
    suzuki_kasahara_affine_gap(s1, s2);

    return 0;
}

