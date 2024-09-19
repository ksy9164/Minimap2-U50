#include <iostream>
#include <vector>
#include <string>
#include <unordered_map>
#include <algorithm>

using namespace std;

const int KMER_SIZE = 3; // Simplified k-mer size for the example
const int MAX_DIST_X = 50;
const int MAX_DIST_Y = 50;
const int BANDWIDTH = 500;
const int MAX_SKIP = 25;
const int MIN_CHAIN_SCORE = 3;

struct Anchor {
    int ref_pos;
    int query_pos;
};

// Function to compute minimizers (hash value)
uint64_t compute_minimizer(const string &kmer) {
    uint64_t hash = 0;
    for (char c : kmer) {
        hash = hash * 31 + c; // Simple hash function
    }
    return hash;
}

// Function to extract k-mers and their positions from a sequence
vector<pair<uint64_t, int>> extract_kmers(const string &sequence, int kmer_size) {
    vector<pair<uint64_t, int>> kmers;
    for (int i = 0; i <= sequence.size() - kmer_size; ++i) {
        string kmer = sequence.substr(i, kmer_size);
        uint64_t minimizer = compute_minimizer(kmer);
        kmers.emplace_back(minimizer, i);
    }
    return kmers;
}

// Function to match query kmers with reference kmers
vector<Anchor> find_anchors(const unordered_map<uint64_t, vector<int>> &ref_kmers, const vector<pair<uint64_t, int>> &query_kmers) {
    vector<Anchor> anchors;
    for (const auto &qk : query_kmers) {
        if (ref_kmers.find(qk.first) != ref_kmers.end()) {
            for (int pos : ref_kmers.at(qk.first)) {
                anchors.push_back({pos, qk.second});
            }
        }
    }
    return anchors;
}

// Function to chain anchors using dynamic programming
vector<Anchor> chain_anchors(const vector<Anchor> &anchors) {
    if (anchors.empty()) return {};

    int n = anchors.size();
    vector<int> dp(n, 0);
    vector<int> prev(n, -1);
    vector<int> chain_score(n, 0);

    // Initialize DP and chain_score
    for (int i = 0; i < n; ++i) {
        dp[i] = 1;
        chain_score[i] = 1;
    }

    // Perform dynamic programming to find the best chains
    for (int i = 1; i < n; ++i) {
        for (int j = 0; j < i; ++j) {
            int dr = anchors[i].ref_pos - anchors[j].ref_pos;
            int dq = anchors[i].query_pos - anchors[j].query_pos;
            if (dr >= 0 && dr <= MAX_DIST_X && dq >= 0 && dq <= MAX_DIST_Y) {
                int sc = min(dr, dq);
                if (chain_score[i] < chain_score[j] + sc) {
                    chain_score[i] = chain_score[j] + sc;
                    dp[i] = j;
                }
            }
        }
    }

    // Backtrack to find the best chain
    int max_score = 0;
    int max_idx = 0;
    for (int i = 0; i < n; ++i) {
        if (chain_score[i] > max_score) {
            max_score = chain_score[i];
            max_idx = i;
        }
    }

    vector<Anchor> best_chain;
    for (int i = max_idx; i >= 0; i = dp[i]) {
        best_chain.push_back(anchors[i]);
        if (dp[i] == i) break; // If it points to itself, stop
    }
    reverse(best_chain.begin(), best_chain.end());
    return best_chain;
}

int main() {
    // Reference genome
    string reference = "ACGGTGACCGATTAAAGCTAGATCCAGTAATGC";
    // Query sequence
    string query = "GATTAAAGCTAG";

    // Extract k-mers from reference
    auto ref_kmers = extract_kmers(reference, KMER_SIZE);
    unordered_map<uint64_t, vector<int>> ref_kmer_map;
    for (const auto &rk : ref_kmers) {
        ref_kmer_map[rk.first].push_back(rk.second);
    }

    // Extract k-mers from query
    auto query_kmers = extract_kmers(query, KMER_SIZE);

    // Find anchors
    auto anchors = find_anchors(ref_kmer_map, query_kmers);
    sort(anchors.begin(), anchors.end(), [](const Anchor &a, const Anchor &b) { return a.ref_pos < b.ref_pos; }); // Sort anchors by reference position

    // Chain anchors
    auto chains = chain_anchors(anchors);

    // Output results
    cout << "Anchors:" << endl;
    for (const auto &anchor : anchors) {
        cout << "Reference: " << anchor.ref_pos << ", Query: " << anchor.query_pos << endl;
    }

    cout << "\nChained Anchors:" << endl;
    for (const auto &chain : chains) {
        cout << "Reference: " << chain.ref_pos << ", Query: " << chain.query_pos << endl;
    }

    return 0;
}

