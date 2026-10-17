//
//  sndcoreaudio.mm
//  iNDS
//
//  Created by Zydeco on 3/7/2013.
//  Copyright (c) 2013 Homebrew. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#include "SPU.h"
#include "sndcoreaudio.h"
#include "main.h"
#include <pthread.h>

int SNDCoreAudioInit(int buffersize);
void SNDCoreAudioDeInit();
void SNDCoreAudioUpdateAudio(s16 *buffer, u32 num_samples);
u32 SNDCoreAudioGetAudioSpace();
void SNDCoreAudioMuteAudio();
void SNDCoreAudioUnMuteAudio();
void SNDCoreAudioSetVolume(int volume);

SoundInterface_struct SNDCoreAudio = {
	SNDCORE_COREAUDIO,
	"CoreAudio Sound Interface",
	SNDCoreAudioInit,
	SNDCoreAudioDeInit,
	SNDCoreAudioUpdateAudio,
	SNDCoreAudioGetAudioSpace,
	SNDCoreAudioMuteAudio,
	SNDCoreAudioUnMuteAudio,
	SNDCoreAudioSetVolume,
};

#define NUM_BUFFERS 2

static int curFillBuffer = 0;
static int curReadBuffer = 0;
static int numFullBuffers = 0;
static int sndBufferSize;
static s16 *sndBuffer[NUM_BUFFERS];
static bool audioQueueStarted = false;
static AudioQueueBufferRef aqBuffer[NUM_BUFFERS];
static AudioQueueRef audioQueue;
static pthread_mutex_t soundBufferMutex = PTHREAD_MUTEX_INITIALIZER;
static unsigned long long diagInputFrames = 0;
static unsigned long long diagOutputFrames = 0;
static unsigned long long diagEmptyCallbacks = 0;
static unsigned long long diagPaddedFrames = 0;

void SNDCoreAudioCallback(void *data, AudioQueueRef mQueue, AudioQueueBufferRef mBuffer) {
    mBuffer->mAudioDataByteSize = sndBufferSize;
    void *mAudioData = mBuffer->mAudioData;

    pthread_mutex_lock(&soundBufferMutex);

   if (numFullBuffers == 0) {
    diagEmptyCallbacks++;
    memset(mAudioData, 0, sndBufferSize);
    } else {
        memcpy(mAudioData, sndBuffer[curReadBuffer], sndBufferSize);

        numFullBuffers--;
        curReadBuffer = (curReadBuffer + 1) % NUM_BUFFERS;
    }

    // Count frames submitted to AudioQueue.
diagOutputFrames += sndBufferSize / 4;

pthread_mutex_unlock(&soundBufferMutex);

AudioQueueEnqueueBuffer(mQueue, mBuffer, 0, NULL);
}

int SNDCoreAudioInit(int buffersize) {
    OSStatus err;
    curReadBuffer = curFillBuffer = numFullBuffers = 0;
    diagInputFrames = 0;
    diagOutputFrames = 0;
    diagEmptyCallbacks = 0;
    diagPaddedFrames = 0;
    
    // create queue
    AudioStreamBasicDescription outputFormat;
    outputFormat.mSampleRate = 44100;
    outputFormat.mFormatID = kAudioFormatLinearPCM;
    outputFormat.mFormatFlags = kAudioFormatFlagsCanonical;
    outputFormat.mBytesPerPacket = 4;
    outputFormat.mFramesPerPacket = 1;
    outputFormat.mBytesPerFrame = 4;
    outputFormat.mChannelsPerFrame = 2;
    outputFormat.mBitsPerChannel = 16;
    outputFormat.mReserved = 0;
    err = AudioQueueNewOutput(&outputFormat, SNDCoreAudioCallback, NULL, NULL, NULL, 0, &audioQueue);
    if (err != noErr) return -1;
    
    // create buffers
    sndBufferSize = buffersize;
    for (int i=0; i<NUM_BUFFERS; i++) {
        AudioQueueAllocateBuffer(audioQueue, sndBufferSize, &aqBuffer[i]);
        SNDCoreAudioCallback(NULL, audioQueue, aqBuffer[i]);
        sndBuffer[i] = (s16*)malloc(sndBufferSize);
    }
    
    audioQueueStarted = false;
    
    return 0;
}

void SNDCoreAudioDeInit() {
    AudioQueueStop(audioQueue, true);
    
    for (int i=0; i<NUM_BUFFERS; i++) {
        AudioQueueFreeBuffer(audioQueue, aqBuffer[i]);
        free(sndBuffer[i]);
    }
    
    AudioQueueFlush(audioQueue);
    AudioQueueDispose(audioQueue, true);
}

void SNDCoreAudioUpdateAudio(s16 *buffer, u32 num_samples) {
    if (buffer == NULL || num_samples == 0) return;

    pthread_mutex_lock(&soundBufferMutex);

    if (numFullBuffers == NUM_BUFFERS) {
        pthread_mutex_unlock(&soundBufferMutex);
        return;
    }

    const u32 maxSamples = sndBufferSize / 4;
    const u32 samplesToCopy =
        num_samples < maxSamples ? num_samples : maxSamples;

    memset(sndBuffer[curFillBuffer], 0, sndBufferSize);

    memcpy(
        sndBuffer[curFillBuffer],
        buffer,
        samplesToCopy * 4
    );
    diagInputFrames += samplesToCopy;
    diagPaddedFrames += maxSamples - samplesToCopy;

    curFillBuffer = (curFillBuffer + 1) % NUM_BUFFERS;
    numFullBuffers++;

    pthread_mutex_unlock(&soundBufferMutex);

    if (!audioQueueStarted) {
        audioQueueStarted = true;
        AudioQueueStart(audioQueue, NULL);
    }
}

u32 SNDCoreAudioGetAudioSpace() {
    pthread_mutex_lock(&soundBufferMutex);

    u32 availableSpace =
        (numFullBuffers == NUM_BUFFERS) ? 0 : (sndBufferSize / 4);

    pthread_mutex_unlock(&soundBufferMutex);

    return availableSpace;
}

void SNDCoreAudioMuteAudio() {
    AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 0.0);
}

void SNDCoreAudioUnMuteAudio() {
    AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 1.0);
}

void SNDCoreAudioSetVolume(int volume) {
    /*
     This function was not implemented, but if it was implemented,
     this is how to do it.
    float scaled = volume / 100.0;
    AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, scaled);
     */
}

void SNDCoreAudioGetStats(SNDCoreAudioStats *stats) {
    if (stats == NULL) return;

    pthread_mutex_lock(&soundBufferMutex);

    stats->inputFrames = diagInputFrames;
    stats->outputFrames = diagOutputFrames;
    stats->emptyCallbacks = diagEmptyCallbacks;
    stats->paddedFrames = diagPaddedFrames;

    pthread_mutex_unlock(&soundBufferMutex);
}