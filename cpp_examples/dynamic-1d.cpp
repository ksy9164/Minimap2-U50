#include <iostream>
#include <vector>
#include <algorithm>
#include <cmath>

// Define an anchor with position and score
struct Anchor {
    int x;  // Position of the reference
    int y;  // Position of the reads
    int score;     // Overlapped nucliotides
};

// Function to perform 1-D DP chaining on anchors
double w_avg = 64.0;
double rc(double l, double w)
{
    if (l < 0) {
        l = -l;
    }

    double r = (0.01 * w * l + 0.5 * log2(l));
    return r;
}
std::vector<Anchor> chainAnchors(const std::vector<Anchor>& anchors, int max_gap) {
    int n = anchors.size();
    if (n > 50) {
        n = 50;
    }
    std::vector<int> dp(n, 0);  // DP array to store the maximum score up to each anchor
    std::vector<int> parent(n, -1);  // Array to store the parent index of each anchor for traceback

    // Sort by reference
    std::vector<Anchor> sorted_anchors = anchors;
    std::sort(sorted_anchors.begin(), sorted_anchors.end(), [](const Anchor& a, const Anchor& b) {
        return a.x < b.x;
    });


    // Perform DP chaining

    for (int i = 1; i < anchors.size(); ++i) {
        int x = anchors[i].x;
        int y = anchors[i].y;
        int w = anchors[i].score;
        for (int j = i - 1; i - j < 50 && j >= 0; j--) {
            int t_x = anchors[j].x;
            int t_y = anchors[j].y;
            int t_w = anchors[j].score;

            double a = (double)std::min(std::min(y - t_y, x - t_x), w);
            double b = rc((double)((y - t_y) - (x - t_x)), w_avg);

            dp[i] = std::max(std::max(dp[j] + (int)a + (int)b, w), dp[i]);
        }
    }

    // Trace back the best chain
    int max_score_index = std::max_element(dp.begin(), dp.end()) - dp.begin();
    std::vector<Anchor> best_chain;
    for (int i = max_score_index; i != -1; i = parent[i]) {
        best_chain.push_back(sorted_anchors[i]);
    }
    std::reverse(best_chain.begin(), best_chain.end());

    return best_chain;
}

int main() {
    // Example usage
    std::vector<Anchor> anchors = {
        {1, 3, 10}, {4, 7, 20}, {6, 1, 15}, {8, 13, 30}, {10, 50, 10}
    };
    int max_gap = 3;

    std::vector<Anchor> best_chain = chainAnchors(anchors, max_gap);

    // Print the best chain
    std::cout << "Best chain of anchors:\n";
    for (const auto& anchor : best_chain) {
        std::cout << "Position: " << anchor.position << ", Score: " << anchor.score << '\n';
    }

    return 0;
}

