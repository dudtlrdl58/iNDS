#ifndef INDS_SNDCOREAUDIO_STATS_H
#define INDS_SNDCOREAUDIO_STATS_H

struct SNDCoreAudioStats {
    unsigned long long inputFrames;
    unsigned long long outputFrames;
    unsigned long long emptyCallbacks;
    unsigned long long paddedFrames;
};

void SNDCoreAudioGetStats(SNDCoreAudioStats *stats);

#endif