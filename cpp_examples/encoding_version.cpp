#include <iostream>
#include <fstream>
#include <vector>
#include <deque>
#include <string>
#include <cstdint>
#include <cstring>
#include <unordered_map>
#include <algorithm>

using namespace std;

const int WINDOW_SIZE = 5;
const int KMER_SIZE = 19;
const int NUM_BINS = 1 << 14; // 2^14
const uint64_t MASK = (1ULL << (2 * KMER_SIZE)) - 1;

// Hash function
static inline uint64_t hash64(uint64_t key, uint64_t mask) {
    key = (~key + (key << 21)) & mask;
    key = key ^ key >> 24;
    key = ((key + (key << 3)) + (key << 8)) & mask;
    key = key ^ key >> 14;
    key = ((key + (key << 2)) + (key << 4)) & mask;
    key = key ^ key >> 28;
    key = (key + (key << 31)) & mask;
    return key;
}

// Function to decode a single nucleotide from a byte
uint8_t decodeNucleotide(uint8_t byte, int position) {
    return (byte >> (2 * position)) & 0x03;
}

// Function to process the binary file and find k-mers and minimizers
vector<pair<uint64_t, size_t>> processEncodedFile(const string& filename) {
    ifstream input(filename, ios::binary);
    if (!input.is_open()) {
        cerr << "Error: Could not open " << filename << endl;
        exit(1);
    }

    vector<pair<uint64_t, size_t>> kmers;
    size_t filePos = 0;

    while (true) {
        // Read the length of the sequence (32 bits)
        uint32_t length;
        input.read(reinterpret_cast<char*>(&length), sizeof(length));
        if (input.eof()) break;

        deque<uint64_t> kmerBuffer;
        vector<uint64_t> kmerHashes;

        uint64_t currentKmer = 0;
        int currentKmerSize = 0;

        // Process the encoded sequence
        for (uint32_t i = 0; i < (length + 3) / 4; ++i) {
            uint8_t encodedByte;
            input.read(reinterpret_cast<char*>(&encodedByte), sizeof(encodedByte));
            if (input.eof()) break;

            for (int j = 0; j < 4 && (i * 4 + j) < length; ++j) {
                uint8_t nucleotide = decodeNucleotide(encodedByte, j);
                currentKmer = ((currentKmer << 2) | nucleotide) & MASK;
                currentKmerSize = min(currentKmerSize + 1, KMER_SIZE);

                // If we have a full k-mer, store its hash
                if (currentKmerSize == KMER_SIZE) {
                    uint64_t hashValue = hash64(currentKmer, MASK);
                    kmerHashes.push_back(hashValue);
                    kmerBuffer.push_back(currentKmer);
                    if (kmerBuffer.size() > WINDOW_SIZE) {
                        kmerBuffer.pop_front();
                    }
                }
            }
        }

        // Find minimizers within the window size
        for (size_t i = 0; i <= kmerHashes.size() - WINDOW_SIZE; ++i) {
            uint64_t minHash = kmerHashes[i];
            size_t minPos = i;
            for (size_t j = i + 1; j < i + WINDOW_SIZE; ++j) {
                if (kmerHashes[j] < minHash) {
                    minHash = kmerHashes[j];
                    minPos = j;
                }
            }
            kmers.emplace_back(kmerBuffer[minPos], filePos + minPos);
        }

        filePos += sizeof(length) + ((length + 3) / 4);
    }

    input.close();
    return kmers;
}

// Comparison function for sorting k-mers
bool compareKmer(const pair<uint64_t, size_t>& a, const pair<uint64_t, size_t>& b) {
    return a.first < b.first;
}

int main() {
    string filename = "plant.bin";

    // Process the encoded file to find k-mers and minimizers
    vector<pair<uint64_t, size_t>> kmers = processEncodedFile(filename);

    // Create bins for the k-mers
    vector<vector<pair<uint64_t, size_t>>> bins(NUM_BINS);

    // Sort k-mers into bins
    for (const auto& kmer : kmers) {
        uint16_t binIndex = kmer.first & (NUM_BINS - 1);
        bins[binIndex].emplace_back(kmer);
    }

    // Sort k-mers within each bin based on the k-mer value (alphabetical order)
    for (auto& bin : bins) {
        sort(bin.begin(), bin.end(), compareKmer);
    }

    // Output the k-mers in each bin (for demonstration purposes)
    for (size_t i = 0; i < bins.size(); ++i) {
        cout << "Bin " << i << ":" << endl;
        for (const auto& kmer : bins[i]) {
            cout << "  K-mer: " << hex << kmer.first << dec << ", Address: " << kmer.second << endl;
        }
    }

    return 0;
}

