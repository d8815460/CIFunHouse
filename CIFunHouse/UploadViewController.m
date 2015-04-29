//
//  UploadViewController.m
//  SquareCam 
//
//  Created by ALEX on 2015/4/13.
//
//

#import "UploadViewController.h"
#import <MobileCoreServices/UTCoreTypes.h>

@interface UploadViewController ()

@end

@implementation UploadViewController
@synthesize hud = _hud;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.myPhotoImageView.layer setCornerRadius:80.0f];
    [self.myPhotoImageView.layer setBorderWidth:1.0f];
    self.myPhotoImageView.layer.masksToBounds = YES;
    [self.myPhotoImageView.layer setBorderColor:[UIColor lightGrayColor].CGColor];
    
    self.sendBtn.layer.cornerRadius = 15.0f;
    self.myPhotoBtn.layer.cornerRadius = 15.0f;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


//- (void)dealloc {
//    [_myPhotoImageView release];
//    [_sendBtn release];
//    [_myPhotoBtn release];
//    [super dealloc];
//}

- (void)viewDidUnload {
    [self setMyPhotoImageView:nil];
    [self setSendBtn:nil];
    [self setMyPhotoBtn:nil];
    [super viewDidUnload];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)uploadButtonPressed:(id)sender {
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
    self.myPhotoImageView.image = image;
    _hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [_hud setLabelText:[NSString stringWithFormat:@"上傳中，請稍待"]];
    [_hud setDimBackground:YES];
    //倒數2秒然後轉場
    self.timer1 = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(performSegue2:) userInfo:nil repeats:NO];
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
        if (buttonIndex == 0) {
            [self shouldStartCameraController];
        } else if (buttonIndex == 1){
            [self shouldStartPhotoLibraryPickerController];
        } else if (buttonIndex == 2){
            self.myPhotoImageView.image = [UIImage imageNamed:@"avatar"];;
        }
    }
}


- (void)performSegue2:(NSTimer *)timer{
    [self.timer1 invalidate];
    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
    //轉場至下一頁
    self.sendBtn.hidden = NO;
//    [self performSegueWithIdentifier:@"gohome" sender:nil];
//    [self dismissViewControllerAnimated:YES completion:^{
//        
//    }];
}

- (IBAction)sendBtnPressed:(id)sender {
    /*開始上傳至parse，完成上傳之後，才轉場。*/
//    [self.navigationController dismissViewControllerAnimated:YES completion:^{
//    }];
    [self performSegueWithIdentifier:@"gohome" sender:nil];
}
@end
