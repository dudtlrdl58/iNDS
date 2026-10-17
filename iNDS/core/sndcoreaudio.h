//
//  sndcoreaudio.h
//  iNDS
//
//  Created by Zydeco on 3/7/2013.
//  Copyright (c) 2013 Homebrew. All rights reserved.
//

#ifndef iNDS_sndcoreaudio_h
#define iNDS_sndcoreaudio_h

#include "SPU.h"

extern SoundInterface_struct SNDCoreAudio;
struct SNDCoreAudioStats {
    unsigned long long inputFrames;
    unsigned long long outputFrames;
    unsigned long long emptyCallbacks;
    unsigned long long paddedFrames;
};

void SNDCoreAudioGetStats(SNDCoreAudioStats *stats);

#define SNDCORE_COREAUDIO 1


#endif
