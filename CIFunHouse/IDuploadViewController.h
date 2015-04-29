//
//  IDuploadViewController.h
//  SquareCam 
//
//  Created by 駿逸 陳 on 2015/4/14.
//
//

#import <UIKit/UIKit.h>
#import "MBProgressHUD.h"

@interface IDuploadViewController : UIViewController <UIImagePickerControllerDelegate, UIActionSheetDelegate, UINavigationControllerDelegate, UIAlertViewDelegate>

@property (retain, nonatomic) IBOutlet UIImageView *id1ImageView;
@property (retain, nonatomic) IBOutlet UIImageView *id2ImageView;
@property (retain, nonatomic) IBOutlet UIButton *btn1;
@property (retain, nonatomic) IBOutlet UIButton *btn2;
@property (strong, nonatomic) NSTimer *timer2;
@property (strong, nonatomic) NSTimer *timer3;
@property (nonatomic, strong) MBProgressHUD *hud;

@property (nonatomic) int IntPhoto;

@property (nonatomic) BOOL isPhoto1Uploaded;
@property (nonatomic) BOOL isPhoto2Uploaded;
@property (retain, nonatomic) IBOutlet UIButton *sendBtn;

- (IBAction)btn1Pressed:(id)sender;
- (IBAction)btn2Pressed:(id)sender;
- (IBAction)sendBtnPressed:(id)sender;
@end
