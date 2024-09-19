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

struct KmerInfo {
    uint64_t hashValue;
    string kmer;
    size_t address;
};


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
char decodeNucleotide(uint8_t byte, int position) {
    uint8_t value = (byte >> (2 * position)) & 0x03;
    switch (value) {
        case 0: return 'A';
        case 1: return 'C';
        case 2: return 'T';
        case 3: return 'G';
        default: throw invalid_argument("Invalid encoded value");
    }
}

// Function to process the binary file and find k-mers and minimizers
vector<KmerInfo> processEncodedFile(const string& filename) {
    ifstream input(filename, ios::binary);
    if (!input.is_open()) {
        cerr << "Error: Could not open " << filename << endl;
        exit(1);
    }

    vector<KmerInfo> kmers;
    size_t filePos = 0;

    while (true) {
        // Read the length of the sequence (32 bits)
        uint32_t length;
        input.read(reinterpret_cast<char*>(&length), sizeof(length));
        if (input.eof()) break;

        deque<char> kmerBuffer;
        vector<uint64_t> kmerHashes;

        // Process the encoded sequence
        for (uint32_t i = 0; i < (length + 3) / 4; ++i) {
            uint8_t encodedByte;
            input.read(reinterpret_cast<char*>(&encodedByte), sizeof(encodedByte));
            if (input.eof()) break;

            for (int j = 0; j < 4 && kmerBuffer.size() < length; ++j) {
                char nucleotide = decodeNucleotide(encodedByte, j);
                kmerBuffer.push_back(nucleotide);

                // If we have a full k-mer, calculate the hash and store it
                if (kmerBuffer.size() == KMER_SIZE) {
                    string kmer(kmerBuffer.begin(), kmerBuffer.end());
                    uint64_t hashValue = 0;
                    for (char n : kmer) {
                        hashValue = (hashValue << 2) | (n == 'A' ? 0 : n == 'C' ? 1 : n == 'T' ? 2 : 3);
                    }
                    hashValue = hash64(hashValue, MASK);
                    kmerHashes.push_back(hashValue);
                    kmerBuffer.pop_front();
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

            string kmer(kmerBuffer.begin() + minPos, kmerBuffer.begin() + minPos + KMER_SIZE);
            kmers.push_back({minHash, kmer, filePos + minPos});
        }

        filePos += sizeof(length) + ((length + 3) / 4);
    }

    input.close();
    return kmers;
}

bool compareKmer(const pair<string, size_t>& a, const pair<string, size_t>& b) {
    return a.first < b.first;
}

int main() {
    string filename = "plant.bin";

    // Process the encoded file to find k-mers and minimizers
    vector<KmerInfo> kmers = processEncodedFile(filename);

    // Create bins for the k-mers
    vector<vector<pair<string, size_t>>> bins(NUM_BINS);

    // Sort k-mers into bins
    for (const auto& kmerInfo : kmers) {
        uint16_t binIndex = kmerInfo.hashValue & (NUM_BINS - 1);
        bins[binIndex].emplace_back(kmerInfo.kmer, kmerInfo.address);
    }

    // Sort k-mers within each bin based on the k-mer value (alphabetical order)
    for (auto& bin : bins) {
        sort(bin.begin(), bin.end(), compareKmer);
    }


    // Output the k-mers in each bin (for demonstration purposes)
    for (size_t i = 0; i < bins.size(); ++i) {
        cout << "Bin " << i << ":" << endl;
        for (const auto& pair : bins[i]) {
            cout << "  K-mer: " << pair.first << ", Address: " << pair.second << endl;
        }
    }

    return 0;
}

