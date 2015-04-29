//
//  IDuploadViewController.m
//  SquareCam 
//
//  Created by 駿逸 陳 on 2015/4/14.
//
//

#import "IDuploadViewController.h"
#import <MobileCoreServices/UTCoreTypes.h>

@interface IDuploadViewController ()

@end

@implementation IDuploadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    [self.id1ImageView.layer setCornerRadius:10.0f];
    [self.id1ImageView.layer setBorderWidth:1.0f];
    self.id1ImageView.layer.masksToBounds = YES;
    [self.id1ImageView.layer setBorderColor:[UIColor clearColor].CGColor];
    
    [self.id2ImageView.layer setCornerRadius:10.0f];
    [self.id2ImageView.layer setBorderWidth:1.0f];
    self.id2ImageView.layer.masksToBounds = YES;
    [self.id2ImageView.layer setBorderColor:[UIColor clearColor].CGColor];
    
    
    self.btn1.tag = 100;
    self.btn2.tag = 101;
    
    self.IntPhoto = 0;
    
    self.isPhoto1Uploaded = false;
    self.isPhoto2Uploaded = false;
    
    [self.sendBtn setHidden:YES];
    [self.sendBtn.layer setCornerRadius:15.0f];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

//- (void)dealloc {
//    [_id1ImageView release];
//    [_id2ImageView release];
//    [_btn1 release];
//    [_btn2 release];
//    [_sendBtn release];
//    [super dealloc];
//}

- (void)viewDidUnload {
    [self setId1ImageView:nil];
    [self setId2ImageView:nil];
    [self setBtn1:nil];
    [self setBtn2:nil];
    [self setSendBtn:nil];
    [super viewDidUnload];
}
- (IBAction)btn1Pressed:(id)sender {
    BOOL cameraDeviceAvailable = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    BOOL photoLibraryAvailable = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary];
    
    if (cameraDeviceAvailable && photoLibraryAvailable) {
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"拍張照片", @"從相簿選擇", nil];
        actionSheet.tag = 200;
        [actionSheet showInView:self.view];
    } else {
        // if we don't have at least two options, we automatically show whichever is available (camera or roll)
        [self shouldPresentPhotoCaptureController];
    }
}

- (IBAction)btn2Pressed:(id)sender {
    BOOL cameraDeviceAvailable = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    BOOL photoLibraryAvailable = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary];
    
    if (cameraDeviceAvailable && photoLibraryAvailable) {
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"拍張照片", @"從相簿選擇", nil];
        actionSheet.tag = 201;
        [actionSheet showInView:self.view];
    } else {
        // if we don't have at least two options, we automatically show whichever is available (camera or roll)
        [self shouldPresentPhotoCaptureController];
    }
}



#pragma mark - UIImagePickerDelegate

//上傳照片
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
#if TARGET_OS_IPHONE &&  (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0)
    [self dismissViewControllerAnimated:YES completion:nil];
#else
    [self dismissModalViewControllerAnimated:YES];
#endif
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
#if TARGET_OS_IPHONE &&  (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0)
    [self dismissViewControllerAnimated:YES completion:nil];
#else
    [self dismissModalViewControllerAnimated:YES];
#endif
    UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
    
    if (self.IntPhoto == 200) {
        self.isPhoto1Uploaded = true;
        self.id1ImageView.image = image;
        [self.id1ImageView.layer setCornerRadius:10.0f];
        [self.id1ImageView.layer setBorderWidth:1.0f];
        self.id1ImageView.layer.masksToBounds = YES;
        [self.id1ImageView.layer setBorderColor:[UIColor clearColor].CGColor];
    }else if (self.IntPhoto == 201){
        self.isPhoto2Uploaded = true;
        self.id2ImageView.image = image;
        [self.id2ImageView.layer setCornerRadius:10.0f];
        [self.id2ImageView.layer setBorderWidth:1.0f];
        self.id2ImageView.layer.masksToBounds = YES;
        [self.id2ImageView.layer setBorderColor:[UIColor clearColor].CGColor];
    }
    
    _hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [_hud setLabelText:[NSString stringWithFormat:@"上傳中，請稍待"]];
    [_hud setDimBackground:YES];
    //倒數1.5秒然後轉場
    
    if (self.isPhoto1Uploaded == true && self.isPhoto2Uploaded == true) {
        self.timer3 = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(performSegue4:) userInfo:nil repeats:NO];
        
    }else{
        self.timer2 = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(performSegue3:) userInfo:nil repeats:NO];
    }
}

- (BOOL)shouldPresentPhotoCaptureController {
    BOOL presentedPhotoCaptureController = [self shouldStartCameraController];
    
    if (!presentedPhotoCaptureController) {
        presentedPhotoCaptureController = [self shouldStartPhotoLibraryPickerController];
    }
    return presentedPhotoCaptureController;
}

- (BOOL)shouldStartCameraController {
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] == NO) {
        return NO;
    }
    UIImagePickerController *cameraUI = [[UIImagePickerController alloc] init];
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]
        && [[UIImagePickerController availableMediaTypesForSourceType:
             UIImagePickerControllerSourceTypeCamera] containsObject:(NSString *)kUTTypeImage]) {
        
        cameraUI.mediaTypes = [NSArray arrayWithObject:(NSString *) kUTTypeImage];
        cameraUI.sourceType = UIImagePickerControllerSourceTypeCamera;
        
        if ([UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear]) {
            cameraUI.cameraDevice = UIImagePickerControllerCameraDeviceRear;
        } else if ([UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront]) {
            cameraUI.cameraDevice = UIImagePickerControllerCameraDeviceFront;
        }
    } else {
        return NO;
    }
    cameraUI.allowsEditing = YES;
    cameraUI.showsCameraControls = YES;
    cameraUI.delegate = self;
    
#if TARGET_OS_IPHONE &&  (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0)
    [self presentViewController:cameraUI animated:YES completion:nil];
#else
    [self presentModalViewController:cameraUI animated:YES];
#endif
    
    return YES;
}

- (BOOL)shouldStartPhotoLibraryPickerController {
    if (([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary] == NO
         && [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeSavedPhotosAlbum] == NO)) {
        return NO;
    }
    UIImagePickerController *cameraUI = [[UIImagePickerController alloc] init];
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]
        && [[UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary] containsObject:(NSString *)kUTTypeImage]) {
        cameraUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        cameraUI.mediaTypes = [NSArray arrayWithObject:(NSString *) kUTTypeImage];
        
    } else if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeSavedPhotosAlbum]
               && [[UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum] containsObject:(NSString *)kUTTypeImage]) {
        cameraUI.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
        cameraUI.mediaTypes = [NSArray arrayWithObject:(NSString *) kUTTypeImage];
    } else {
        return NO;
    }
    cameraUI.allowsEditing = YES;
    cameraUI.delegate = self;
#if TARGET_OS_IPHONE &&  (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0)
    [self presentViewController:cameraUI animated:YES completion:nil];
#else
    [self presentModalViewController:cameraUI animated:YES];
#endif
    return YES;
}

#pragma mark - UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    //因為使用者所在位置會一直被用到，所以在這裡就不做release的動作了。否則會永遠沒辦法找到使用者。
    if (actionSheet.tag == 200) {
        self.IntPhoto = 200;
        if (buttonIndex == 0) {
            [self shouldStartCameraController];
        } else if (buttonIndex == 1){
            [self shouldStartPhotoLibraryPickerController];
        } else if (buttonIndex == 2){
            self.id1ImageView.image = [UIImage imageNamed:@"avatar"];
        }
    }else if (actionSheet.tag == 201){
        self.IntPhoto = 201;
        if (buttonIndex == 0) {
            [self shouldStartCameraController];
        } else if (buttonIndex == 1){
            [self shouldStartPhotoLibraryPickerController];
        } else if (buttonIndex == 2){
            self.id2ImageView.image = [UIImage imageNamed:@"avatar"];
        }
    }
}

- (void)performSegue3:(NSTimer *)timer{
    [self.timer2 invalidate];
    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
    //轉場至下一頁
    //    [self performSegueWithIdentifier:@"gohome" sender:nil];
//    [self dismissViewControllerAnimated:YES completion:^{
//        
//    }];
}

- (void)performSegue4:(NSTimer *)timer{
    [self.timer3 invalidate];
    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
    self.sendBtn.hidden = NO;
    //轉場至下一頁
    //    [self performSegueWithIdentifier:@"gohome" sender:nil];
//    [self dismissViewControllerAnimated:YES completion:^{
//        
//    }];
}

- (IBAction)sendBtnPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}
@end
