//
//  ViewController.m
//  Theremin
//
//  Created by Cody Mace on 9/1/15.
//  Copyright (c) 2015 Cody Mace. All rights reserved.
//

#import "ViewController.h"
#import <AudioToolbox/MusicPlayer.h>

@interface ViewController ()

@property (assign, nonatomic) CGPoint touchPoint;
@property (assign, nonatomic) AUGraph processingGraph;
@property (assign, nonatomic) AudioUnit samplerUnit;
@property (assign, nonatomic) AudioUnit ioUnit;

@end

static MusicPlayer player;
static MusicSequence sequence;

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    OSStatus result = noErr;


    [self createAUGraph];
    [self configureAndStartAudioProcessingGraph: self.processingGraph];

    // Create a client
    MIDIClientRef virtualMidi;
    result = MIDIClientCreate(CFSTR("Virtual Client"),
                              MyMIDINotifyProc,
                              NULL,
                              &virtualMidi);

    NSAssert( result == noErr, @"MIDIClientCreate failed. Error code: %d '%.4s'", (int) result, (const char *)&result);

    // Create an endpoint
    MIDIEndpointRef virtualEndpoint;
    result = MIDIDestinationCreate(virtualMidi, @"Virtual Destination", MyMIDIReadProc, self.samplerUnit, &virtualEndpoint);

    NSAssert( result == noErr, @"MIDIDestinationCreate failed. Error code: %d '%.4s'", (int) result, (const char *)&result);



    // Initialise the music sequence
    NewMusicSequence(&sequence);

    // Get a string to the path of the MIDI file which
    // should be located in the Resources folder
    NSString *midiFilePath = [[NSBundle mainBundle]
                              pathForResource:@"simpletest"
                              ofType:@"mid"];

    // Create a new URL which points to the MIDI file
    NSURL * midiFileURL = [NSURL fileURLWithPath:midiFilePath];


    MusicSequenceFileLoad(sequence, (__bridge CFURLRef) midiFileURL, 0, 0);

////     Create a new music player
//    MusicPlayer  p;
    // Initialise the music player
    NewMusicPlayer(&player);

    // ************* Set the endpoint of the sequence to be our virtual endpoint
    MusicSequenceSetMIDIEndpoint(sequence, virtualEndpoint);

    // Load the ound font from file
    NSURL *presetURL = [[NSURL alloc] initFileURLWithPath:[[NSBundle mainBundle] pathForResource:@"Gorts_Filters" ofType:@"SF2"]];

    // Initialise the sound font
    [self loadFromDLSOrSoundFont: (NSURL *)presetURL withPatch: (int)10];

    // Load the sequence into the music player
    MusicPlayerSetSequence(player, sequence);
    // Called to do some MusicPlayer setup. This just
    // reduces latency when MusicPlayerStart is called
    MusicPlayerPreroll(player);

    // Starts the music playing
    MusicPlayerStart(player);


}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        CGPoint location = [touch locationInView:self.view];
        self.touchPoint = location;
        [self playSound];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        CGPoint location = [touch locationInView:self.view];
        self.touchPoint = location;
        [self playSound];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        CGPoint location = [touch locationInView:self.view];
        self.touchPoint = location;
        [self endSound];
    }
}

- (void)playSound {
    NSLog(@"x:%f, y:%f", self.touchPoint.x, self.touchPoint.y);

    MusicTrack t;
    MusicSequenceGetIndTrack(sequence, 1, &t);
    MusicTimeStamp time;
    MusicPlayerGetTime(player, &time);
    MIDINoteMessage note;
    note.channel = 1;
    note.note = 40;
    note.velocity = 255;
    note.releaseVelocity = 0;
    note.duration = 1;
//    MusicTrackNewMIDINoteEvent(t, time, &note);
    MusicDeviceMIDIEvent (self.samplerUnit, -112, (UInt8)self.touchPoint.y, -32, 0);


//    // Get length of track so that we know how long to kill time for
//    MusicTrack t;
//    MusicTimeStamp len;
//    UInt32 sz = sizeof(MusicTimeStamp);
//    MusicSequenceGetIndTrack(s, 1, &t);
//    MusicTrackGetProperty(t, kSequenceTrackProperty_TrackLength, &len, &sz);
//    
//    
//    while (1) { // kill time until the music is over
//        usleep (3 * 1000 * 1000);
//        MusicTimeStamp now = 0;
//        MusicPlayerGetTime (p, &now);
//        if (now >= len)
//            break;
//    }
//    
//    // Stop the player and dispose of the objects
//    MusicPlayerStop(p);
//    DisposeMusicSequence(s);
//    DisposeMusicPlayer(p);


}
- (void)endSound {
}

- (BOOL)createAUGraph {
    
    // Each core audio call returns an OSStatus. This means that we
    // Can see if there have been any errors in the setup
	OSStatus result = noErr;
    
    // Create 2 audio units one sampler and one IO
	AUNode samplerNode, ioNode;
    
    // Specify the common portion of an audio unit's identify, used for both audio units
    // in the graph.
    // Setup the manufacturer - in this case Apple
	AudioComponentDescription cd = {};
	cd.componentManufacturer     = kAudioUnitManufacturer_Apple;
    
    // Instantiate an audio processing graph
	result = NewAUGraph (&_processingGraph);
    NSCAssert (result == noErr, @"Unable to create an AUGraph object. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
	//Specify the Sampler unit, to be used as the first node of the graph
	cd.componentType = kAudioUnitType_MusicDevice; // type - music device
	cd.componentSubType = kAudioUnitSubType_Sampler; // sub type - sampler to convert our MIDI
	
    // Add the Sampler unit node to the graph
	result = AUGraphAddNode (self.processingGraph, &cd, &samplerNode);
    NSCAssert (result == noErr, @"Unable to add the Sampler unit to the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
	// Specify the Output unit, to be used as the second and final node of the graph	
	cd.componentType = kAudioUnitType_Output;  // Output
	cd.componentSubType = kAudioUnitSubType_RemoteIO;  // Output to speakers
    
    // Add the Output unit node to the graph
	result = AUGraphAddNode (self.processingGraph, &cd, &ioNode);
    NSCAssert (result == noErr, @"Unable to add the Output unit to the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Open the graph
	result = AUGraphOpen (self.processingGraph);
    NSCAssert (result == noErr, @"Unable to open the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Connect the Sampler unit to the output unit
	result = AUGraphConnectNodeInput (self.processingGraph, samplerNode, 0, ioNode, 0);
    NSCAssert (result == noErr, @"Unable to interconnect the nodes in the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
	// Obtain a reference to the Sampler unit from its node
	result = AUGraphNodeInfo (self.processingGraph, samplerNode, 0, &_samplerUnit);
    NSCAssert (result == noErr, @"Unable to obtain a reference to the Sampler unit. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
	// Obtain a reference to the I/O unit from its node
	result = AUGraphNodeInfo (self.processingGraph, ioNode, 0, &_ioUnit);
    NSCAssert (result == noErr, @"Unable to obtain a reference to the I/O unit. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    return YES;
}
// Starting with instantiated audio processing graph, configure its 
// audio units, initialize it, and start it.
- (void)configureAndStartAudioProcessingGraph: (AUGraph) graph {
    
    OSStatus result = noErr;
    if (graph) {
        
        // Initialize the audio processing graph.
        result = AUGraphInitialize (graph);
        NSAssert (result == noErr, @"Unable to initialze AUGraph object. Error code: %d '%.4s'", (int) result, (const char *)&result);
        
        // Start the graph
        result = AUGraphStart (graph);
        NSAssert (result == noErr, @"Unable to start audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
        
        // Print out the graph to the console
        //CAShow (graph); 
    }
}
void MyMIDINotifyProc (const MIDINotification  *message, void *refCon) {
    printf("MIDI Notify, messageId=%d,", message->messageID);
}

static void MyMIDIReadProc(const MIDIPacketList *pktlist,
                           void *refCon,
                           void *connRefCon) {

    
    AudioUnit *player = (AudioUnit*) refCon;
    
    MIDIPacket *packet = (MIDIPacket *)pktlist->packet;
    for (int i=0; i < pktlist->numPackets; i++) {
        Byte midiStatus = packet->data[0];
        Byte midiCommand = midiStatus >> 4;
        
        
        if (midiCommand == 0x09) {
            Byte note = packet->data[1] & 0x7F;
            Byte velocity = packet->data[2] & 0x7F;
            
            int noteNumber = ((int) note) % 12;
            NSString *noteType;
            switch (noteNumber) {
                case 0:
                    noteType = @"C";
                    break;
                case 1:
                    noteType = @"C#";
                    break;
                case 2:
                    noteType = @"D";
                    break;
                case 3:
                    noteType = @"D#";
                    break;
                case 4:
                    noteType = @"E";
                    break;
                case 5:
                    noteType = @"F";
                    break;
                case 6:
                    noteType = @"F#";
                    break;
                case 7:
                    noteType = @"G";
                    break;
                case 8:
                    noteType = @"G#";
                    break;
                case 9:
                    noteType = @"A";
                    break;
                case 10:
                    noteType = @"Bb";
                    break;
                case 11:
                    noteType = @"B";
                    break;
                default:
                    break;
            }
            NSLog([noteType stringByAppendingFormat:[NSString stringWithFormat:@": %i", noteNumber]]);
           
            
            OSStatus result = noErr;
            result = MusicDeviceMIDIEvent (player, midiStatus, note, velocity, 0);
        }
        packet = MIDIPacketNext(packet);
    }
}
// this method assumes the class has a member called mySamplerUnit
// which is an instance of an AUSampler
-(OSStatus) loadFromDLSOrSoundFont: (NSURL *)bankURL withPatch: (int)presetNumber {

    OSStatus result = noErr;

    // fill out a bank preset data structure
    AUSamplerBankPresetData bpdata;
    bpdata.bankURL  = (__bridge CFURLRef) bankURL;
    bpdata.bankMSB  = kAUSampler_DefaultMelodicBankMSB;
    bpdata.bankLSB  = kAUSampler_DefaultBankLSB;
    bpdata.presetID = (UInt8) presetNumber;

    // set the kAUSamplerProperty_LoadPresetFromBank property
    result = AudioUnitSetProperty(self.samplerUnit,
                              kAUSamplerProperty_LoadPresetFromBank,
                              kAudioUnitScope_Global,
                              0,
                              &bpdata,
                              sizeof(bpdata));

    // check for errors
    NSCAssert (result == noErr,
           @"Unable to set the preset property on the Sampler. Error code:%d '%.4s'",
           (int) result,
           (const char *)&result);

    return result;
}
@end
