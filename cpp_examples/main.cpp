#include <iostream>
#include <fstream>
#include <utility>  
#include <string>
#include <vector>
#include <cstdint>  
#include <algorithm>

using namespace std;

uint64_t get_kmer(string s, int st, int k)
{
    if (st + k > (int)s.size())
        return 0;

    uint64_t res = 0;
    for (int i = st; i < st + k; ++i) {
        uint64_t nu = 0;
        switch (s[i]) {
            case 'A': nu = 0;
            case 'C': nu = 1;
            case 'T': nu = 2;
            case 'G': nu = 3;
        }
        res = (res << 2) | nu;
    }

    return res;
}

void find_minimizers(vector<pair<uint64_t, uint64_t>> kmers, string reads, int k, int w, uint64_t file_idx)
{
    for (int i = 0; i < (int)reads.size(); i += w) {
        if (i + w + k > (int)reads.size())
            break;

        uint64_t min = UINT64_MAX;
        uint64_t addr = 0;
        for (int j = 0; j  < w; j++) {
            uint64_t tmp = get_kmer(reads, i + j, k);
            if (tmp < min) {
                min = tmp;
                addr = i + j + file_idx;
            }
        }
        kmers.push_back(make_pair(min, addr));
    }
}

vector<pair<uint64_t, uint64_t>> get_minimizers(string ref_file, int k, int w)
{
    ifstream ref_stream(ref_file);
    string line;
    uint64_t file_idx = 0;

    vector<pair<uint64_t, uint64_t>> minimizers; // kmer , addr

    while (getline(ref_stream, line)) {
        find_minimizers(minimizers, line, k, w, file_idx);
        file_idx += (uint64_t)line.size();
    }

    return minimizers;
}

vector<pair<uint64_t, uint64_t>> generate_anchors()
{
    
}

int main(int argc, char *argv[])
{
    if (argc != 5) {
        cerr << "Usage: " << argv[0] << " <reference_genome_file> <query_file> <k-mer_size> <window_size>" << endl;
        return 1;
    }

    string ref_file = argv[1];
    string query_file = argv[2];
    int k = stoi(argv[3]);
    int window_size = stoi(argv[4]);

    vector<pair<uint64_t, uint64_t>> minimizers_ref =  get_minimizers(ref_file, k, window_size);

    sort(minimizers_ref.begin(), minimizers_ref.end(), [](pair<uint64_t, uint64_t>& a, pair<uint64_t, uint64_t>& b) {
            return a.first < b.first;
            });

    // Build B-tree level 3 // need to check size of hashtable for human (Around 21GB for human genome) , more than 50GB for all data
 

    // Get anchors based on query referencing B-tree
    vector<pair<uint64_t, uint64_t>> minimizers_qu =  get_minimizers(query_file, k, window_size); // get minimzers from query
    vector<pair<uint64_t, uint64_t>> anchors = generate_anchors(); // generate anchors


    // Sort anchors based on address
    

    // Check exact matching score each anchors


    // Chaining to get best chain , Z-drop, Best chain , etc...


    // Sequence alignment
    

}
