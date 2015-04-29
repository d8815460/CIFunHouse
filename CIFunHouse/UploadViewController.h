//
//  UploadViewController.h
//  SquareCam 
//
//  Created by ALEX on 2015/4/13.
//
//

#import <UIKit/UIKit.h>
#import "MBProgressHUD.h"

@interface UploadViewController : UIViewController <UIImagePickerControllerDelegate, UIActionSheetDelegate, UINavigationControllerDelegate, UIAlertViewDelegate>
@property (retain, nonatomic) IBOutlet UIImageView *myPhotoImageView;
@property (retain, nonatomic) IBOutlet UIButton *sendBtn;
@property (retain, nonatomic) IBOutlet UIButton *myPhotoBtn;
@property (strong, nonatomic) NSTimer *timer1;
@property (nonatomic, strong) MBProgressHUD *hud;
- (IBAction)uploadButtonPressed:(id)sender;
- (IBAction)sendBtnPressed:(id)sender;
@end
