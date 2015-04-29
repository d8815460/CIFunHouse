/*
     File: FHViewController.m
 Abstract: The view controller for the capture preview
  Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2013 Apple Inc. All Rights Reserved.
 
 */

#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>

#import "FHViewController.h"
#import "FHAppDelegate.h"
#import "FilterListController.h"

#import "CIFilter+FHAdditions.h"
#import "FilterAttributeBinding.h"

/*SquareCam載入的framework*/
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import <AssertMacros.h>
#import <AssetsLibrary/AssetsLibrary.h>

#define iPhone6 ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && MAX([UIScreen mainScreen].bounds.size.height,[UIScreen mainScreen].bounds.size.width) == 667)
#define iPhone6Plus ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && MAX([UIScreen mainScreen].bounds.size.height,[UIScreen mainScreen].bounds.size.width) == 736)

#pragma mark- SquareCam的方程式
// used for KVO observation of the @"capturingStillImage" property to perform flash bulb animation
static const NSString *AVCaptureStillImageIsCapturingStillImageContext = @"AVCaptureStillImageIsCapturingStillImageContext";
static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};

static void ReleaseCVPixelBuffer(void *pixel, const void *data, size_t size);
static void ReleaseCVPixelBuffer(void *pixel, const void *data, size_t size)
{
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)pixel;
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
    CVPixelBufferRelease( pixelBuffer );
}

// create a CGImage with provided pixel buffer, pixel buffer must be uncompressed kCVPixelFormatType_32ARGB or kCVPixelFormatType_32BGRA
static OSStatus CreateCGImageFromCVPixelBuffer(CVPixelBufferRef pixelBuffer, CGImageRef *imageOut);
static OSStatus CreateCGImageFromCVPixelBuffer(CVPixelBufferRef pixelBuffer, CGImageRef *imageOut)
{
    OSStatus err = noErr;
    OSType sourcePixelFormat;
    size_t width, height, sourceRowBytes;
    void *sourceBaseAddr = NULL;
    CGBitmapInfo bitmapInfo;
    CGColorSpaceRef colorspace = NULL;
    CGDataProviderRef provider = NULL;
    CGImageRef image = NULL;
    
    sourcePixelFormat = CVPixelBufferGetPixelFormatType( pixelBuffer );
    if ( kCVPixelFormatType_32ARGB == sourcePixelFormat )
        bitmapInfo = kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipFirst;
    else if ( kCVPixelFormatType_32BGRA == sourcePixelFormat )
        bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst;
    else
        return -95014; // only uncompressed pixel formats
    
    sourceRowBytes = CVPixelBufferGetBytesPerRow( pixelBuffer );
    width = CVPixelBufferGetWidth( pixelBuffer );
    height = CVPixelBufferGetHeight( pixelBuffer );
    
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
    sourceBaseAddr = CVPixelBufferGetBaseAddress( pixelBuffer );
    
    colorspace = CGColorSpaceCreateDeviceRGB();
    
    CVPixelBufferRetain( pixelBuffer );
    provider = CGDataProviderCreateWithData( (void *)pixelBuffer, sourceBaseAddr, sourceRowBytes * height, ReleaseCVPixelBuffer);
    image = CGImageCreate(width, height, 8, 32, sourceRowBytes, colorspace, bitmapInfo, provider, NULL, true, kCGRenderingIntentDefault);
    
bail:
    if ( err && image ) {
        CGImageRelease( image );
        image = NULL;
    }
    if ( provider ) CGDataProviderRelease( provider );
    if ( colorspace ) CGColorSpaceRelease( colorspace );
    *imageOut = image;
    return err;
}

// utility used by newSquareOverlayedImageForFeatures for
static CGContextRef CreateCGBitmapContextForSize(CGSize size);
static CGContextRef CreateCGBitmapContextForSize(CGSize size)
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    int             bitmapBytesPerRow;
    
    bitmapBytesPerRow = (size.width * 4);
    
    colorSpace = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate (NULL,
                                     size.width,
                                     size.height,
                                     8,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaPremultipliedLast);
    CGContextSetAllowsAntialiasing(context, NO);
    CGColorSpaceRelease( colorSpace );
    return context;
}

#pragma mark-

@interface UIImage (RotationMethods)
- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees;
@end

@implementation UIImage (RotationMethods)

- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees
{
    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.size.width, self.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(DegreesToRadians(degrees));
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    
    // Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    
    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
    
    //   // Rotate the image context
    CGContextRotateCTM(bitmap, DegreesToRadians(degrees));
    
    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-self.size.width / 2, -self.size.height / 2, self.size.width, self.size.height), [self CGImage]);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
    
}

@end


#pragma mark- 另一個故事
static NSString *const kUserDefaultsKey = @"FilterSettings";

NSString *const FHViewControllerDidStartCaptureSessionNotification = @"FHViewControllerDidStartCaptureSessionNotification";

static NSString *const kTempVideoFilename = @"recording.mov";
static NSTimeInterval kFPSLabelUpdateInterval = 0.25;

static CGColorSpaceRef sDeviceRgbColorSpace = NULL;


static CGAffineTransform FCGetTransformForDeviceOrientation(UIDeviceOrientation orientation, BOOL mirrored)
{
    // Internal comment: This routine assumes that the native camera image is always coming from a UIDeviceOrientationLandscapeLeft (i.e. the home button is on the RIGHT, which equals AVCaptureVideoOrientationLandscapeRight!), although in the future this assumption may not hold; better to get video output's capture connection's videoOrientation property, and apply the transform according to the native video orientation
    
    // Also, it may be desirable to apply the flipping as a separate step after we get the rotation transform
    CGAffineTransform result;
    switch (orientation) {
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
            result = CGAffineTransformMakeRotation(M_PI_2);
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            result = CGAffineTransformMakeRotation((3 * M_PI_2));
            break;
        case UIDeviceOrientationLandscapeLeft:
            result = mirrored ?  CGAffineTransformMakeRotation(M_PI) : CGAffineTransformIdentity;
            break;
        default:
            result = mirrored ? CGAffineTransformIdentity : CGAffineTransformMakeRotation(M_PI);
            break;
    }
    
    return result;
}

// an inline function to filter a CIImage through a filter chain; note that each image input attribute may have different source
static inline CIImage *RunFilter(CIImage *cameraImage, CIFilter *filters)
{
    CIImage *currentImage = nil;
    NSMutableArray *activeInputs = [NSMutableArray array];
    
//    for (CIFilter *filter in filters)
//    {
        if ([filters isKindOfClass:[SourceVideoFilter class]])
        {
            [filters setValue:cameraImage forKey:kCIInputImageKey];
        }
        else if ([filters isKindOfClass:[SourcePhotoFilter class]])
        {
            ; // nothing to do here
        }
        else
        {
            for (NSString *attrName in [filters imageInputAttributeKeys])
            {
                CIImage* top = [activeInputs lastObject];
                if (top)
                {
                    [filters setValue:top forKey:attrName];
                    [activeInputs removeLastObject];
                }
                else
                    NSLog(@"failed to set %@ for %@", attrName, filters.name);
            }
        }
        
        currentImage = filters.outputImage;
        if (currentImage == nil)
            return nil;
        [activeInputs addObject:currentImage];
//    }
    
    if (CGRectIsEmpty(currentImage.extent))
        return nil;
    return currentImage;
}

@interface FHViewController (PrivateMethods)
- (void)_start;

- (void)_startWriting;
- (void)_abortWriting;
- (void)_stopWriting;

- (void)_startLabelUpdateTimer;
- (void)_stopLabelUpdateTimer;
- (void)_updateLabel:(NSTimer *)timer;

- (void)_handleFilterStackActiveFilterListDidChangeNotification:(NSNotification *)notification;
- (void)_handleAVCaptureSessionWasInterruptedNotification:(NSNotification *)notification;
- (void)_handleUIApplicationDidEnterBackgroundNotification:(NSNotification *)notification;

- (void)_showAlertViewWithMessage:(NSString *)message title:(NSString *)title;
- (void)_showAlertViewWithMessage:(NSString *)message;  // can be called in any thread, any queue

- (void)_stop;

- (void)_handleFHFilterImageAttributeSourceChange:(NSNotification *)notification;
- (void)_handleSettingUpdate:(NSNotification *)notification;
@end


@implementation FHViewController
@synthesize recordStopButton = _recordStopButton;
@synthesize filtersButton = _filtersButton;
@synthesize currentVideoTime = _currentVideoTime;
@synthesize toolbar = _toolbar;
@synthesize settingsButton = _settingsButton;
@synthesize fpsLabel = _fpsLabel;
@synthesize settingsPopoverController = _settingsPopoverController;
@synthesize settingsNavigationController = _settingsNavigationController;
@synthesize isCounDown;
@synthesize IntSec;
@synthesize timer4 = _timer4;
@synthesize timer5;
@synthesize hud = _hud;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        // create the shared color space object once
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            sDeviceRgbColorSpace = CGColorSpaceCreateDeviceRGB();
        });

        // load the filters and their configurations
        _filterStack = [[FilterStack alloc] init];
        
        _activeFilters = [_filterStack.activeFilters copy];
        
        _frameRateCalculator = [[FrameRateCalculator alloc] init];

        // create the dispatch queue for handling capture session delegate method calls
        videoDataOutputQueue = dispatch_queue_create("capture_session_queue", NULL);
        
        self.wantsFullScreenLayout = YES;        
        [UIApplication sharedApplication].statusBarHidden = YES;
        
        self.fpsLabel.enabled = true;
        self.recordStopButton.enabled = true;
    }
    return self;
}

- (void)dealloc
{
    if (_currentAudioSampleBufferFormatDescription)
        CFRelease(_currentAudioSampleBufferFormatDescription);

    //dispatch_release(_captureSessionQueue);
}

- (void)viewDidLoad
{
    [super viewDidLoad];
 
    /*錄製影片用到的參數*/
    self.isCounDown = false;
    self.IntSec = 5;
    _isStartWriting = false;
    self.navigationController.navigationBarHidden = YES;
    
    
    
    square = [UIImage imageNamed:@"squarePNG"];
    NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:CIDetectorAccuracyLow, CIDetectorAccuracy, nil];
    faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
    
    
    FilterListController *filterListController = [[FilterListController alloc] initWithStyle:UITableViewStylePlain];
    filterListController.filterStack = _filterStack;
    filterListController.delegate = self;
    filterListController.contentSizeForViewInPopover = CGSizeMake(480.0, 320.0);
    self.filterListNavigationController = [[UINavigationController alloc] initWithRootViewController:filterListController];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        self.filterListPopoverController = [[UIPopoverController alloc] initWithContentViewController:self.filterListNavigationController];
    
    SettingsController *settingsController = [[SettingsController alloc] initWithStyle:UITableViewStyleGrouped];
    settingsController.delegate = self;
    settingsController.contentSizeForViewInPopover = CGSizeMake(480.0, 320.0);
    self.settingsNavigationController = [[UINavigationController alloc] initWithRootViewController:settingsController];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        self.settingsPopoverController = [[UIPopoverController alloc] initWithContentViewController:self.settingsNavigationController];
    
    // remove the view's background color; this allows us not to use the opaque property (self.view.opaque = NO) since we remove the background color drawing altogether
    self.view.backgroundColor = nil;
    
    // setup the GLKView for video/image preview
    UIView *window = ((FHAppDelegate *)[UIApplication sharedApplication].delegate).window;
    _eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    _videoPreviewView = [[GLKView alloc] initWithFrame:window.bounds context:_eaglContext];
    _videoPreviewView.enableSetNeedsDisplay = NO;
    
    // because the native video image from the back camera is in UIDeviceOrientationLandscapeLeft (i.e. the home button is on the right), we need to apply a clockwise 90 degree transform so that we can draw the video preview as if we were in a landscape-oriented view; if you're using the front camera and you want to have a mirrored preview (so that the user is seeing themselves in the mirror), you need to apply an additional horizontal flip (by concatenating CGAffineTransformMakeScale(-1.0, 1.0) to the rotation transform)
    _videoPreviewView.transform = CGAffineTransformMakeRotation(M_PI_2);
    _videoPreviewView.frame = window.bounds;
    
    // we make our video preview view a subview of the window, and send it to the back; this makes FHViewController's view (and its UI elements) on top of the video preview, and also makes video preview unaffected by device rotation
    [window addSubview:_videoPreviewView];
    [window sendSubviewToBack:_videoPreviewView];
        
    // create the CIContext instance, note that this must be done after _videoPreviewView is properly set up
    _ciContext = [CIContext contextWithEAGLContext:_eaglContext options:@{kCIContextWorkingColorSpace : [NSNull null]} ];
    
    // bind the frame buffer to get the frame buffer width and height;
    // the bounds used by CIContext when drawing to a GLKView are in pixels (not points),
    // hence the need to read from the frame buffer's width and height;
    // in addition, since we will be accessing the bounds in another queue (_captureSessionQueue),
    // we want to obtain this piece of information so that we won't be
    // accessing _videoPreviewView's properties from another thread/queue
    [_videoPreviewView bindDrawable];            
    _videoPreviewViewBounds = CGRectZero;
    _videoPreviewViewBounds.size.width = _videoPreviewView.drawableWidth;
    _videoPreviewViewBounds.size.height = _videoPreviewView.drawableHeight;
    

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleAttributeValueUpdate:)
                                                 name:FilterAttributeValueDidUpdateNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleFHFilterImageAttributeSourceChange:)
                                                 name:kFHFilterImageAttributeSourceDidChangeNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleSettingUpdate:)
                                                 name:kFHSettingDidUpdateNotification object:nil];
    
    // handle filter list change
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleFilterStackActiveFilterListDidChangeNotification:)
                                                 name:FilterStackActiveFilterListDidChangeNotification object:nil];
    
    // handle AVCaptureSessionWasInterruptedNotification (such as incoming phone call)
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleAVCaptureSessionWasInterruptedNotification:)
                                                 name:AVCaptureSessionWasInterruptedNotification object:nil];
    
    // handle UIApplicationDidEnterBackgroundNotification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleUIApplicationDidEnterBackgroundNotification:)
                                                 name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    // check the availability of video and audio devices
    // create and start the capture session only if the devices are present
    {
        #if TARGET_IPHONE_SIMULATOR
        #warning On iPhone Simulator, the app still gets a video device, but the video device will not work;
        #warning On iPad Simulator, the app gets no video device
        #endif
        
        // populate the defaults
        FCPopulateDefaultSettings();
        
        // see if we have any video device
        if ([[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count] > 0)
        {
            // find the audio device
            NSArray *audioDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
            if ([audioDevices count])
                _audioDevice = [audioDevices objectAtIndex:0];  // use the first audio device
            
            NSLog(@"開始執行");
            [self _start];
        }
    }
    
    self.toolbar.translucent = NO;
//    self.fpsLabel.title = @"";
    self.fpsLabel.enabled = true;
    self.recordStopButton.enabled = true;
}

- (void)viewDidUnload
{
    // remove the _videoPreviewView
    [_videoPreviewView removeFromSuperview];
    _videoPreviewView = nil;
    
    [self _stopWriting];
    [self _stop];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:FilterAttributeValueDidUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kFHFilterImageAttributeSourceDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kFHSettingDidUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:FilterStackActiveFilterListDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionWasInterruptedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];    
    
    [super viewDidUnload];    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{

    _settingsPopoverVisibleBeforeRotation = self.settingsPopoverController.popoverVisible;
    if (_settingsPopoverVisibleBeforeRotation)
        [self.settingsPopoverController dismissPopoverAnimated:NO];
    
    
    // makes the UI more Camera.app like
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
    {
        [UIView setAnimationsEnabled:NO];
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
    {
        [UIView setAnimationsEnabled:YES];
        [UIView beginAnimations:@"reappear" context:NULL];
        [UIView setAnimationDuration:0.75];
        [UIView commitAnimations];
    }

    // settingsPopoverController is nil when on iPhone, so no effect if used
    if (_settingsPopoverVisibleBeforeRotation)
        [self.settingsPopoverController presentPopoverFromBarButtonItem:_settingsButton
                                               permittedArrowDirections:UIPopoverArrowDirectionAny
                                                               animated:YES];
}

#pragma mark - Actions

- (IBAction)recordStopAction:(UIBarButtonItem *)sender event:(UIEvent *)event
{
    if (_assetWriter)
        [self _stopWriting];
    else
        [self _startWriting];    
}

- (IBAction)filtersAction:(UIBarButtonItem *)sender event:(UIEvent *)event
{
    // set the global crop max
    FCSetGlobalCropFilterMaxValue(MAX(_currentVideoDimensions.width, _currentVideoDimensions.height));

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        [[UIApplication sharedApplication] setStatusBarHidden:NO
                                                withAnimation:UIStatusBarAnimationSlide];
        [self presentViewController:self.filterListNavigationController animated:YES completion:nil];
    }
    else
    {
        if (self.settingsPopoverController.popoverVisible)
            [self.settingsPopoverController dismissPopoverAnimated:NO];
        
        if (self.filterListPopoverController.popoverVisible)
            [self.filterListPopoverController dismissPopoverAnimated:NO];
        else
            [self.filterListPopoverController presentPopoverFromBarButtonItem:sender
                                                     permittedArrowDirections:UIPopoverArrowDirectionAny
                                                                     animated:YES];
    }
}

- (IBAction)settingsAction:(UIBarButtonItem *)sender event:(UIEvent *)event
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        [[UIApplication sharedApplication] setStatusBarHidden:NO
                                                withAnimation:UIStatusBarAnimationSlide];
        
        [self presentViewController:self.settingsNavigationController animated:YES completion:nil];
    }
    else
    {
        
        if (self.settingsPopoverController.popoverVisible)
            [self.settingsPopoverController dismissPopoverAnimated:NO];
        else
            [self.settingsPopoverController presentPopoverFromBarButtonItem:sender
                                                   permittedArrowDirections:UIPopoverArrowDirectionAny
                                                                   animated:YES];
    }
}

#pragma mark - Private methods

- (void)_start
{
    if (_captureSession)
        return;
    
    [self _stopLabelUpdateTimer];
    
    dispatch_async(videoDataOutputQueue, ^(void) {
        NSError *error = nil;
        
        // get the input device and also validate the settings
        NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        
        AVCaptureDevicePosition position = AVCaptureDevicePositionFront;
        
        _videoDevice = nil;
        for (AVCaptureDevice *device in videoDevices)
        {
            if (device.position == position) {
                _videoDevice = device;
                break;
            }
        }
        
        if (!_videoDevice)
        {
            _videoDevice = [videoDevices objectAtIndex:0];            
            [[NSUserDefaults standardUserDefaults] setObject:@(_videoDevice.position) forKey:kFHSettingCameraPositionKey];
        }

        
        // obtain the preset and validate the preset
        NSString *preset = [[NSUserDefaults standardUserDefaults] objectForKey:kFHSettingCaptureSessionPresetKey];
        if (![_videoDevice supportsAVCaptureSessionPreset:preset])
        {
            preset = AVCaptureSessionPresetMedium;
            [[NSUserDefaults standardUserDefaults] setObject:preset forKey:kFHSettingCaptureSessionPresetKey];
        }
        if (![_videoDevice supportsAVCaptureSessionPreset:preset])
        {
            [self _showAlertViewWithMessage:[NSString stringWithFormat:@"Capture session preset not supported by video device: %@", preset]];
            return;
        }
        
        
        // obtain device input
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:_videoDevice error:&error];
        require( error == nil, bail );
        
    bail:
        if (error) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Failed with error %d", (int)[error code]]
                                                                message:[error localizedDescription]
                                                               delegate:nil
                                                      cancelButtonTitle:@"Dismiss"
                                                      otherButtonTitles:nil];
            [alertView show];
            [self teardownAVCapture];
        }
        
        if (!videoDeviceInput)
        {
            [self _showAlertViewWithMessage:[NSString stringWithFormat:@"Unable to obtain video device input, error: %@", error]];
            return;
        }
        
        AVCaptureDeviceInput *audioDeviceInput = nil;
        if (_audioDevice)
        {
            audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:_audioDevice error:&error];
            if (!audioDeviceInput)
            {
                [self _showAlertViewWithMessage:[NSString stringWithFormat:@"Unable to obtain audio device input, error: %@", error]];
                return;            
            }
        }
        
        

        
        
        
        // create the capture session
        _captureSession = [[AVCaptureSession alloc] init];
        _captureSession.sessionPreset = preset;
        
        // connect the video device input and video data and still image outputs
        // add the input to the session
        if ( [_captureSession canAddInput:videoDeviceInput] ){
            [_captureSession addInput:videoDeviceInput];
        }
        
        // Make a still image output
        stillImageOutput = [AVCaptureStillImageOutput new];
        [stillImageOutput addObserver:self forKeyPath:@"capturingStillImage" options:NSKeyValueObservingOptionNew context:(__bridge void *)(AVCaptureStillImageIsCapturingStillImageContext)];
        if ( [_captureSession canAddOutput:stillImageOutput] )
            [_captureSession addOutput:stillImageOutput];
        
        
        // create and configure video data output
        videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
        NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:
                                           [NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        videoDataOutput.videoSettings = rgbOutputSettings;
        videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
        // create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured
        // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
        // see the header doc for setSampleBufferDelegate:queue: for more information
//        videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
        [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
        
        // configure audio data output
        AVCaptureAudioDataOutput *audioDataOutput = nil;
        if (_audioDevice) {
            audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
            [audioDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
        }
        
        // begin configure capture session
        [_captureSession beginConfiguration];
        
        if (![_captureSession canAddOutput:videoDataOutput])
        {
            [self _showAlertViewWithMessage:@"Cannot add video data output"];
            _captureSession = nil;
            return;                    
        }

        if (audioDataOutput)
        {
            if (![_captureSession canAddOutput:audioDataOutput])
            {
                [self _showAlertViewWithMessage:@"Cannot add still audio data output"];
                _captureSession = nil;
                return;                    
            }        
        }
        
        
        [_captureSession addOutput:videoDataOutput];
        
        if (_audioDevice)
        {
            [_captureSession addInput:audioDeviceInput];
            [_captureSession addOutput:audioDataOutput];
        }
        
       
        
        
        /*偵測臉部程式*/
        detectFaces = true;
        [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:detectFaces]; //開始連結影片，以利臉部偵測
        if (!detectFaces) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                NSLog(@"detectFaces start drawFaceboxesForFeatures");
                // clear out any squares currently displaying.
                [self drawFaceBoxesForFeatures:[NSArray array] forVideoBox:CGRectZero orientation:UIDeviceOrientationPortrait];
            });
        }
        
        
        [_captureSession commitConfiguration];
        
        // then start everything
        [_frameRateCalculator reset];
        [_captureSession startRunning];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self _startLabelUpdateTimer];

            UIView *window = ((FHAppDelegate *)[UIApplication sharedApplication].delegate).window;

            CGAffineTransform transform = CGAffineTransformMakeRotation(M_PI_2);
            // apply the horizontal flip
            BOOL shouldMirror = (AVCaptureDevicePositionFront == _videoDevice.position);
            if (shouldMirror)
                transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(-1.0, 1.0));

            _videoPreviewView.transform = transform;
            _videoPreviewView.frame = window.bounds;
            
            [[NSNotificationCenter defaultCenter] postNotificationName:FHViewControllerDidStartCaptureSessionNotification object:self];
        });
        
    });
}

// clean up capture setup
- (void)teardownAVCapture
{
    if (videoDataOutputQueue)
        //        dispatch_release(videoDataOutputQueue);
        [stillImageOutput removeObserver:self forKeyPath:@"isCapturingStillImage"];
    [previewLayer removeFromSuperlayer];
}


- (void)_stop
{
    if (!_captureSession || !_captureSession.running)
        return;

    [_captureSession stopRunning];

    dispatch_sync(videoDataOutputQueue, ^{
        NSLog(@"waiting for capture session to end");
    });
    
    [self _stopWriting];

    _captureSession = nil;
    _videoDevice = nil;    
}

- (void)_startWriting
{
    _recordStopButton.title = @"Stop";
//    _fpsLabel.title = @"00:00";
    
    _videoWritingStarted = true;
    dispatch_async(videoDataOutputQueue, ^{
        
        NSError *error = nil;
        
        // remove the temp file, if any
        NSURL *outputFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:kTempVideoFilename]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:[outputFileURL path]])
            [[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:NULL];
        
        
        AVAssetWriter *newAssetWriter = [AVAssetWriter assetWriterWithURL:outputFileURL fileType:AVFileTypeQuickTimeMovie error:&error];
        if (!newAssetWriter || error) {
            [self _showAlertViewWithMessage:[NSString stringWithFormat:@"Cannot create asset writer, error: %@", error]];
            return;
        }
        
        NSDictionary *videoCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                                  AVVideoCodecH264, AVVideoCodecKey,
                                                  [NSNumber numberWithInteger:_currentVideoDimensions.width], AVVideoWidthKey,
                                                  [NSNumber numberWithInteger:_currentVideoDimensions.height], AVVideoHeightKey,
                                                  nil];
        
        _assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
        _assetWriterVideoInput.expectsMediaDataInRealTime = YES;
        
        // create a pixel buffer adaptor for the asset writer; we need to obtain pixel buffers for rendering later from its pixel buffer pool
        _assetWriterInputPixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_assetWriterVideoInput sourcePixelBufferAttributes:
                                               [NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithInteger:kCVPixelFormatType_32BGRA], (id)kCVPixelBufferPixelFormatTypeKey,
                                                [NSNumber numberWithUnsignedInteger:_currentVideoDimensions.width], (id)kCVPixelBufferWidthKey,
                                                [NSNumber numberWithUnsignedInteger:_currentVideoDimensions.height], (id)kCVPixelBufferHeightKey,
                                                (id)kCFBooleanTrue, (id)kCVPixelFormatOpenGLESCompatibility,
                                                nil]];
        
        
        UIDeviceOrientation orientation = ((FHAppDelegate *)[UIApplication sharedApplication].delegate).realDeviceOrientation;
        //UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
        
        // give correct orientation information to the video
        if (_videoDevice.position == AVCaptureDevicePositionFront)
            _assetWriterVideoInput.transform = FCGetTransformForDeviceOrientation(orientation, YES);
        else
            _assetWriterVideoInput.transform = FCGetTransformForDeviceOrientation(orientation, NO);
        
        BOOL canAddInput = [newAssetWriter canAddInput:_assetWriterVideoInput];
        if (!canAddInput) {
            [self _showAlertViewWithMessage:@"Cannot add asset writer video input"];
            _assetWriterAudioInput = nil;
            _assetWriterVideoInput = nil;
            return;
        }
        
        [newAssetWriter addInput:_assetWriterVideoInput];    
        
        if (_audioDevice) {
            size_t layoutSize = 0;
            const AudioChannelLayout *channelLayout = CMAudioFormatDescriptionGetChannelLayout(_currentAudioSampleBufferFormatDescription, &layoutSize);
            const AudioStreamBasicDescription *basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(_currentAudioSampleBufferFormatDescription);
            
            NSData *channelLayoutData = [NSData dataWithBytes:channelLayout length:layoutSize];
            
            // record the audio at AAC format, bitrate 64000, sample rate and channel number using the basic description from the audio samples
            NSDictionary *audioCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithInteger:kAudioFormatMPEG4AAC], AVFormatIDKey,
                                                      [NSNumber numberWithInteger:basicDescription->mChannelsPerFrame], AVNumberOfChannelsKey,                                                  
                                                      [NSNumber numberWithFloat:basicDescription->mSampleRate], AVSampleRateKey,
                                                      [NSNumber numberWithInteger:64000], AVEncoderBitRateKey,
                                                      channelLayoutData, AVChannelLayoutKey,
                                                      nil];
            
            if ([newAssetWriter canApplyOutputSettings:audioCompressionSettings forMediaType:AVMediaTypeAudio]) {
                _assetWriterAudioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioCompressionSettings];
                _assetWriterAudioInput.expectsMediaDataInRealTime = YES;
                
                if ([newAssetWriter canAddInput:_assetWriterAudioInput])
                    [newAssetWriter addInput:_assetWriterAudioInput];
                else
                    [self _showAlertViewWithMessage:@"Couldn't add asset writer audio input"
                                              title:@"Warning"];
            }
            else 
                [self _showAlertViewWithMessage:@"Couldn't apply audio output settings."
                                          title:@"Warning"];
        }
        
        // Make sure we have time to finish saving the movie if the app is backgrounded during recording
        // cf. the RosyWriter sample app from WWDC 2011
        if ([[UIDevice currentDevice] isMultitaskingSupported])
            _backgroundRecordingID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{}];    
        
        _videoWritingStarted = NO;
        
        _assetWriter = newAssetWriter;
    });    
}

- (void)_abortWriting
{
    if (!_assetWriter)
        return;
    
    [_assetWriter cancelWriting];
    _assetWriterAudioInput = nil;
    _assetWriterVideoInput = nil;
    _assetWriter = nil;
    
    // remove the temp file
    NSURL *fileURL = [_assetWriter outputURL];
    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:NULL];

    void (^resetUI)(void) = ^(void) {
        _recordStopButton.title = @"Record";
        _recordStopButton.enabled = YES;
        
        // end the background task if it's done there
        // cf. The RosyWriter sample app from WWDC 2011
        if ([[UIDevice currentDevice] isMultitaskingSupported])
            [[UIApplication sharedApplication] endBackgroundTask:_backgroundRecordingID];        
    };

    dispatch_async(dispatch_get_main_queue(), resetUI);    
}

- (void)_stopWriting
{
    if (!_assetWriter)
        return;
    _hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [_hud setLabelText:[NSString stringWithFormat:@"上傳中，請稍待"]];
    [_hud setDimBackground:YES];
    
    AVAssetWriter *writer = _assetWriter;
    
    
    
    [self _stopLabelUpdateTimer];
//    _fpsLabel.title = @"Saving...";
    _recordStopButton.enabled = NO;

    void (^resetUI)(void) = ^(void) {
        _recordStopButton.title = @"Record";
        _recordStopButton.enabled = YES;
        
        [self _startLabelUpdateTimer];
        
        // end the background task if it's done there
        // cf. The RosyWriter sample app from WWDC 2011
        if ([[UIDevice currentDevice] isMultitaskingSupported])
            [[UIApplication sharedApplication] endBackgroundTask:_backgroundRecordingID];        
    };
    
    dispatch_async(videoDataOutputQueue, ^(void){
        NSURL *fileURL = [writer outputURL];
        
        [writer finishWritingWithCompletionHandler:^(void){
            if (writer.status == AVAssetWriterStatusFailed)
            {
                dispatch_async(dispatch_get_main_queue(), resetUI);
                [self _showAlertViewWithMessage:@"Cannot complete writing the video, the output could be corrupt."];
            }
            else if (writer.status == AVAssetWriterStatusCompleted)
            {
                
                NSString *URL = [fileURL path];
                NSError *attributesError = nil;
                NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:URL  error:&attributesError];
                int fileSize = (int)[fileAttributes fileSize];
                
                NSLog(@"file size = %i", fileSize);
                
                // 將影片上傳到Parse，必須要整合Parse的SDK
                 NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
                 
                 PFFile *file = [PFFile fileWithData:fileData];
                 
                 NSLog(@"file = %@", file);
                 
                 PFObject *userPhoto = [PFObject objectWithClassName:@"UserVideo"];
                 userPhoto[@"videoFile"] = file;
                 userPhoto[@"user"] = [PFUser currentUser];
                 
                 [userPhoto saveInBackground];
                 
                
                /*直接導航至下一頁，上傳驗證照片*/
                [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
                
                //轉場至下一頁
                [self performSegueWithIdentifier:@"photo" sender:nil];
                
                /*將影片儲存在本機的相簿裡面*/
                ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                [library writeVideoAtPathToSavedPhotosAlbum:fileURL
                                            completionBlock:^(NSURL *assetURL, NSError *error){
                                                if (error) {
                                                    NSString *mssg = [NSString stringWithFormat:@"Error saving the video to the photo library. %@", error];
                                                    [self _showAlertViewWithMessage:mssg];
                                                }
                                                
                                                // remove the temp file
                                                [[NSFileManager defaultManager] removeItemAtURL:fileURL error:NULL];
                                            }];
                
                _assetWriterAudioInput = nil;
                _assetWriterVideoInput = nil;
                _assetWriterInputPixelBufferAdaptor = nil;
                _assetWriter = nil;
            }
            dispatch_async(dispatch_get_main_queue(), resetUI);
        }];
        
    });    
}


- (void)doSearch:(NSTimer *)timer {
    if (self.IntSec > 0) {
        self.IntSec = self.IntSec -1;
        self.fpsLabeltext.text = [NSString stringWithFormat:@"還剩下%d秒", self.IntSec];
        if (_videoWritingStarted) {
            
        }else{
            [self _startWriting];
        }
    }else{
        
        self.fpsLabeltext.text = @"結束，正在準備影片檔案...";
        [self.timer4 invalidate];
        self.timer4 = nil;
        detectFaces = false;
        [self toggleFaceDetection:nil];
        [self _stopWriting];
        
        //如果不是iPhone6，可能要再等個一兩秒再_stopWriting
        CGSize screenSize = [[UIScreen mainScreen] bounds].size;
        
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && MAX([UIScreen mainScreen].bounds.size.height,[UIScreen mainScreen].bounds.size.width) == 667) {
            NSLog(@"這是iphone 6");
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
                
            }else{
                /*Do iPad stuff here.*/
            }
        }else{
            NSLog(@"這是iphone 5 以下");
            if (!_assetWriter) {
                if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
                    if (screenSize.height > 480.0f) {
                        /*Do iPhone 5 stuff here.*/
                        self.timer5 = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(stopW:) userInfo:nil repeats:YES];
                    } else {
                        /*Do iPhone Classic stuff here.*/
                        self.timer5 = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(stopW:) userInfo:nil repeats:YES];
                    }
                } else {
                    /*Do iPad stuff here.*/
                }
            }else{
                
            }
        }
    }
}

- (void)stopW:(NSTimer *)timer{
    NSLog(@"這是iphone 5 以下 xx");
    if (_assetWriter) {
        [self _stopWriting];
        [self.timer5 invalidate];
        self.timer5 = nil;
    }else{
        
    }
}

// turn on/off face detection
- (IBAction)toggleFaceDetection:(id)sender
{
    detectFaces = [(UISwitch *)sender isOn];
    [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:detectFaces];
    if (!detectFaces) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            // clear out any squares currently displaying.
            [self drawFaceBoxesForFeatures:[NSArray array] forVideoBox:CGRectZero orientation:UIDeviceOrientationPortrait];
        });
    }
}


- (void)_startLabelUpdateTimer
{
    _labelUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:kFPSLabelUpdateInterval target:self selector:@selector(_updateLabel:) userInfo:nil repeats:YES];    
}

- (void)_stopLabelUpdateTimer
{
    [_labelUpdateTimer invalidate];
    _labelUpdateTimer = nil;
}

- (void)_updateLabel:(NSTimer *)timer
{
//    _fpsLabel.title = [NSString stringWithFormat:@"%.1f fps", _frameRateCalculator.frameRate];
    if (_assetWriter)
    {
        CMTime diff = CMTimeSubtract(self.currentVideoTime, _videoWrtingStartTime);
        NSUInteger seconds = (NSUInteger)CMTimeGetSeconds(diff);
        
//        _fpsLabel.title = [NSString stringWithFormat:@"%02lu:%02lu", seconds / 60UL, seconds % 60UL];
    }
}


- (void)_handleAttributeValueUpdate:(NSNotification *)notification
{
    NSDictionary *info = [notification userInfo];
    CIFilter *filter = [info valueForKey:kFilterObject];
    id key = [info valueForKey:kFilterInputKey];
    id value = [info valueForKey:kFilterInputValue];
    
    if (filter && key && value) {
        dispatch_async(videoDataOutputQueue, ^{
            [filter setValue:value forKey:key];
        });
    }
}

- (void)_handleFHFilterImageAttributeSourceChange:(NSNotification *)notification
{
    [self _handleFilterStackActiveFilterListDidChangeNotification:notification];
}

- (void)_handleSettingUpdate:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    NSString *updatedKey = [userInfo objectForKey:kFHSettingUpdatedKeyNameKey];
    
    if ([updatedKey isEqualToString:kFHSettingColorMatchKey])
    {
        BOOL colormatch = [[NSUserDefaults standardUserDefaults] boolForKey:updatedKey];
        NSDictionary *options = colormatch ? @{kCIContextWorkingColorSpace : [NSNull null]} : nil;
        
        dispatch_async(videoDataOutputQueue, ^{
            _ciContext = [CIContext contextWithEAGLContext:_eaglContext options:options];
        });
    }
    
    [self _stop];
    [self _start];
}


- (void)_handleFilterStackActiveFilterListDidChangeNotification:(NSNotification *)notification
{
    // the active filter list gets updated, and we use this to ensure that the our _activeFilters array gets changed in the designated queue (to avoid the race condition where _activeFilters is being used by RunFilter()
//    NSArray *newActiveFilters = _filterStack.activeFilters;
    dispatch_async(videoDataOutputQueue, ^() {
//        _activeFilters = newActiveFilters;
    });
    
//    self.fpsLabel.enabled = (_filterStack.containsVideoSource);
//    self.recordStopButton.enabled = (_filterStack.containsVideoSource);
}

- (void)_handleAVCaptureSessionWasInterruptedNotification:(NSNotification *)notification
{
    [self _stopWriting];
}

- (void)_handleUIApplicationDidEnterBackgroundNotification:(NSNotification *)notification
{
    [self _stopWriting];
}

- (void)_showAlertViewWithMessage:(NSString *)message title:(NSString *)title
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"Dismiss"
                                              otherButtonTitles:nil];
        [alert show];
    });
}

- (void)_showAlertViewWithMessage:(NSString *)message
{
    [self _showAlertViewWithMessage:message title:@"Error"];
}

#pragma mark - 偵測臉部 methods
// called asynchronously as the capture output is capturing sample buffers, this method asks the face detector (if on)
// to detect features and for each draw the red square in a layer and set appropriate orientation
- (void)drawFaceBoxesForFeatures:(NSArray *)features forVideoBox:(CGRect)clap orientation:(UIDeviceOrientation)orientation
{
    
    NSArray *sublayers = [NSArray arrayWithArray:[previewLayer sublayers]];
    NSInteger sublayersCount = [sublayers count], currentSublayer = 0;
    NSInteger featuresCount = [features count], currentFeature = 0;
    
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    
    // hide all the face layers
    for ( CALayer *layer in sublayers ) {
        if ( [[layer name] isEqualToString:@"FaceLayer"] )
            [layer setHidden:YES];
    }
    
    if ( featuresCount == 0 || !detectFaces ) {
        [CATransaction commit];
        return; // early bail.
    }
    
    CGSize parentFrameSize = [_videoPreviewView frame].size;
    NSString *gravity = [previewLayer videoGravity];
    BOOL isMirrored = [previewLayer isMirrored];
    CGRect previewBox = [FHViewController videoPreviewBoxForGravity:gravity
                                                          frameSize:parentFrameSize
                                                       apertureSize:clap.size];
    
    for ( CIFaceFeature *ff in features ) {
        
        
        // find the correct position for the square layer within the previewLayer
        // the feature box originates in the bottom left of the video frame.
        // (Bottom right if mirroring is turned on)
        CGRect faceRect = [ff bounds];
        
        // flip preview width and height
        CGFloat temp = faceRect.size.width;
        faceRect.size.width = faceRect.size.height;
        faceRect.size.height = temp;
        temp = faceRect.origin.x;
        faceRect.origin.x = faceRect.origin.y;
        faceRect.origin.y = temp;
        // scale coordinates so they fit in the preview box, which may be scaled
        CGFloat widthScaleBy = previewBox.size.width / clap.size.height;
        CGFloat heightScaleBy = previewBox.size.height / clap.size.width;
        faceRect.size.width *= widthScaleBy;
        faceRect.size.height *= heightScaleBy;
        faceRect.origin.x *= widthScaleBy;
        faceRect.origin.y *= heightScaleBy;
        
        
        
        
        if ( isMirrored )
            faceRect = CGRectOffset(faceRect, previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 3), previewBox.origin.y);
        else
            faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
        
        CALayer *featureLayer = nil;
        
        // re-use an existing layer if possible
        while ( !featureLayer && (currentSublayer < sublayersCount) ) {
            CALayer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
            if ( [[currentLayer name] isEqualToString:@"FaceLayer"] ) {
                featureLayer = currentLayer;
                [currentLayer setHidden:NO];
            }
        }
        
        // create a new one if necessary
        if ( !featureLayer ) {
            featureLayer = [CALayer new];
            [featureLayer setContents:(id)[square CGImage]];
            [featureLayer setName:@"FaceLayer"];
            [previewLayer addSublayer:featureLayer];
        }
        [featureLayer setFrame:faceRect];
        
        if (faceRect.origin.x == 160) {
            //初始值，不做事情
        }else{
            if ((faceRect.origin.x + faceRect.size.width/2) >  150 && (faceRect.origin.x + faceRect.size.width/2) <  170) {
                self.facebgImageView.image = [UIImage imageNamed:@"face.png"];
                
                
                if (self.isCounDown) {
                    //不做任何事情
                }else{
                    self.isCounDown = true;
                    self.fpsLabeltext.text = @"開始倒數5秒";
                    self.timer4 = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(doSearch:) userInfo:nil repeats:YES];
                }
                
                NSLog(@"有執行到這裡來表示有抓到臉，立刻關閉抓臉程式，並且可以啟動錄影");
                detectFaces = false;
            }
        }
        
        
        switch (orientation) {
            case UIDeviceOrientationPortrait:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(0.))];
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(180.))];
                break;
            case UIDeviceOrientationLandscapeLeft:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(90.))];
                break;
            case UIDeviceOrientationLandscapeRight:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(-90.))];
                break;
            case UIDeviceOrientationFaceUp:
            case UIDeviceOrientationFaceDown:
            default:
                break; // leave the layer in its last known orientation
        }
        currentFeature++;
    }
    
    [CATransaction commit];
}


// find where the video box is positioned within the preview layer based on the video size and gravity
+ (CGRect)videoPreviewBoxForGravity:(NSString *)gravity frameSize:(CGSize)frameSize apertureSize:(CGSize)apertureSize
{
    CGFloat apertureRatio = apertureSize.height / apertureSize.width;
    CGFloat viewRatio = frameSize.width / frameSize.height;
    
    CGSize size = CGSizeZero;
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
        if (viewRatio > apertureRatio) {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        } else {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        if (viewRatio > apertureRatio) {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        } else {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResize]) {
        size.width = frameSize.width;
        size.height = frameSize.height;
    }
    
    CGRect videoBox;
    videoBox.size = size;
    if (size.width < frameSize.width)
        videoBox.origin.x = (frameSize.width - size.width) / 2;
    else
        videoBox.origin.x = (size.width - frameSize.width) / 2;
    
    if ( size.height < frameSize.height )
        videoBox.origin.y = (frameSize.height - size.height) / 2;
    else
        videoBox.origin.y = (size.height - frameSize.height) / 2;
    
    return videoBox;
}




#pragma mark - Delegate methods

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:(__bridge NSDictionary *)attachments];
    
    if (attachments)
        CFRelease(attachments);
    NSDictionary *imageOptions = nil;
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    int exifOrientation;
    
    /* kCGImagePropertyOrientation values
     The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
     by the TIFF and EXIF specifications -- see enumeration of integer constants.
     The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
     
     used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
     If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
    
    enum {
        PHOTOS_EXIF_0ROW_TOP_0COL_LEFT			= 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
        PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT			= 2, //   2  =  0th row is at the top, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
        PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
        PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
    };
    
    switch (curDeviceOrientation) {
        case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
            break;
        case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
            if (isUsingFrontFacingCamera)
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            else
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            break;
        case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
            if (isUsingFrontFacingCamera)
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            else
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            break;
        case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
        default:
            exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
            break;
    }
    
    imageOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:exifOrientation] forKey:CIDetectorImageOrientation];
    
    NSArray *features = [faceDetector featuresInImage:ciImage options:imageOptions];
    
    // get the clean aperture
    // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
    // that represents image data valid for display.
    CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    CGRect clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft == false*/);
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self drawFaceBoxesForFeatures:features forVideoBox:clap orientation:curDeviceOrientation];
    });
    
    
    CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDesc);
    
    // write the audio data if it's from the audio connection
    if (mediaType == kCMMediaType_Audio)
    {
        CMFormatDescriptionRef tmpDesc = _currentAudioSampleBufferFormatDescription;
        _currentAudioSampleBufferFormatDescription = formatDesc;
        CFRetain(_currentAudioSampleBufferFormatDescription);
        
        if (tmpDesc)
            CFRelease(tmpDesc);
        
        // we need to retain the sample buffer to keep it alive across the different queues (threads)
        if (_assetWriter &&
            _assetWriterAudioInput.readyForMoreMediaData &&
            ![_assetWriterAudioInput appendSampleBuffer:sampleBuffer])
        {
            [self _showAlertViewWithMessage:@"Cannot write audio data, recording aborted"];
            [self _abortWriting];
        }
        
        return;
    }
    
    // if not from the audio capture connection, handle video writing    
    CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    [_frameRateCalculator calculateFramerateAtTimestamp:timestamp];
    
    // update the video dimensions information
    _currentVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDesc);
    
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *sourceImage = [CIImage imageWithCVPixelBuffer:(CVPixelBufferRef)imageBuffer options:nil];    
    
    // run the filter through the filter chain
    CIFilter* filter = [CIFilter filterWithName:@"SourceVideoFilter"];
    CIImage *filteredImage = RunFilter(sourceImage, filter);
    
    CGRect sourceExtent = sourceImage.extent;
    
    CGFloat sourceAspect = sourceExtent.size.width / sourceExtent.size.height;
    CGFloat previewAspect = _videoPreviewViewBounds.size.width  / _videoPreviewViewBounds.size.height;

    // we want to maintain the aspect radio of the screen size, so we clip the video image
    CGRect drawRect = sourceExtent;
    if (sourceAspect > previewAspect)
    {
        // use full height of the video image, and center crop the width
        drawRect.origin.x += (drawRect.size.width - drawRect.size.height * previewAspect) / 2.0;
        drawRect.size.width = drawRect.size.height * previewAspect;
    }
    else
    {
        // use full width of the video image, and center crop the height
        drawRect.origin.y += (drawRect.size.height - drawRect.size.width / previewAspect) / 2.0;
        drawRect.size.height = drawRect.size.width / previewAspect;
    }

    if (_assetWriter == nil)
    {
        [_videoPreviewView bindDrawable];
        
        if (_eaglContext != [EAGLContext currentContext])
            [EAGLContext setCurrentContext:_eaglContext];
        
        // clear eagl view to grey
        glClearColor(0.5, 0.5, 0.5, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        
        // set the blend mode to "source over" so that CI will use that
        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        
        if (filteredImage)
            [_ciContext drawImage:filteredImage inRect:_videoPreviewViewBounds fromRect:drawRect];
        
        [_videoPreviewView display];
    }
    else
    {
        // if we need to write video and haven't started yet, start writing
        if (!_videoWritingStarted)
        {
            _videoWritingStarted = YES;
            BOOL success = [_assetWriter startWriting];
            if (!success)
            {
                [self _showAlertViewWithMessage:@"Cannot write video data, recording aborted"];
                [self _abortWriting];
                return;
            }
            
            [_assetWriter startSessionAtSourceTime:timestamp];
            _videoWrtingStartTime = timestamp;
            self.currentVideoTime = _videoWrtingStartTime;
        }
        
        CVPixelBufferRef renderedOutputPixelBuffer = NULL;
        
        OSStatus err = CVPixelBufferPoolCreatePixelBuffer(nil, _assetWriterInputPixelBufferAdaptor.pixelBufferPool, &renderedOutputPixelBuffer);
        if (err)
        {
            NSLog(@"Cannot obtain a pixel buffer from the buffer pool");
            return;
        }
        
        // render the filtered image back to the pixel buffer (no locking needed as CIContext's render method will do that
        if (filteredImage)
            [_ciContext render:filteredImage toCVPixelBuffer:renderedOutputPixelBuffer bounds:[filteredImage extent] colorSpace:sDeviceRgbColorSpace];

        // pass option nil to enable color matching at the output, otherwise the color will be off
        CIImage *drawImage = [CIImage imageWithCVPixelBuffer:renderedOutputPixelBuffer options:nil];
        
        [_videoPreviewView bindDrawable];
        [_ciContext drawImage:drawImage inRect:_videoPreviewViewBounds fromRect:drawRect];
        [_videoPreviewView display];

        
        self.currentVideoTime = timestamp;                
        
        // write the video data
        if (_assetWriterVideoInput.readyForMoreMediaData)           
            [_assetWriterInputPixelBufferAdaptor appendPixelBuffer:renderedOutputPixelBuffer withPresentationTime:timestamp];

        CVPixelBufferRelease(renderedOutputPixelBuffer);
    }
}


- (void)filterListEditorDidDismiss
{
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
    
    [self dismissViewControllerAnimated:YES completion: ^(void){
//        self.recordStopButton.enabled = (_filterStack.containsVideoSource);
        self.recordStopButton.enabled = true;
    }];
}

- (void) settingsDidDismiss
{
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
    
    [self dismissViewControllerAnimated:YES completion: ^(void){
//        self.recordStopButton.enabled = (_filterStack.containsVideoSource);
        self.recordStopButton.enabled = true;
    }];
}
@end
